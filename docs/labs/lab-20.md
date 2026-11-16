---
description: "Investigate a compromised host in isolated network namespaces (no real network touched): baseline its listeners, find a listening backdoor and a periodic outbound beacon to a fake C2, map each suspicious socket to its owning process and binary with ss and lsof, capture the beacon with a tight tcpdump filter, scan the victim from an admin namespace with nmap --reason, correlate with the host audit, and write a prioritised incident report; a clean-up script tears it all down."
---

# Lab 20: Suspicious Host Investigation

| Field | Value |
|---|---|
| **Lab ID** | LAB-20 |
| **Related lesson** | [Day 20: Network Security Investigation](../course/module-4/day-20.md) |
| **Difficulty** | Advanced |
| **Time** | 90–120 minutes (Linux 70 min, Windows 20–30 min) |
| **Risk level** | Low–Medium. Everything runs inside **isolated network namespaces** on a disposable Ubuntu 24.04 VM — no real interface, host or external network is scanned or captured. The "backdoor" and "C2" are harmless local processes (`nc` and a `curl` loop) the setup script creates and the clean-up script removes. **Never run the scanning/capture steps against anything outside this lab or `scanme.nmap.org`.** |

## Objective

A SIEM alert says **vic01** (10.44.0.10) is "beaconing to an external address and has an unexpected open port". You have authorisation to investigate vic01 and its lab segment only. Reproduce the SOC workflow:

1. **Baseline** vic01's listeners, then find the **new listener** (a backdoor) and map it to its process and binary.
2. Find the **periodic outbound connection** (a beacon), and identify its interval and destination.
3. **Capture** the beacon with a tight filter and confirm the pattern.
4. From the **admin** namespace, **scan** vic01 and read open/closed/filtered with `--reason`.
5. **Correlate** with the host audit (Day 19), write a **prioritised incident report**, and clean up.

## Required Environment

- A disposable Ubuntu 24.04 **VM** (snapshot first) with `sudo`. Packages:

    ```bash
    sudo apt update && sudo apt install -y nmap iproute2 lsof tcpdump tshark netcat-openbsd curl python3
    ```

- The topology, built by the setup script — three namespaces on one bridge, no connection to the real network:

    ```mermaid
    flowchart LR
        subgraph SW["lab20-sw (bridge br0) - ISOLATED"]
            BR(( ))
        end
        VIC["lab20-vic<br/>vic01 10.44.0.10<br/>listens: 22-sim, 80-sim, 4444 (backdoor)<br/>beacons to 10.44.0.66:443"] --- BR
        C2["lab20-c2<br/>10.44.0.66<br/>fake C2 listener :443"] --- BR
        ADM["lab20-admin<br/>10.44.0.20<br/>(your scanning host)"] --- BR
    ```

- **Windows (optional):** a Windows 11 lab VM with an elevated PowerShell to repeat the socket-hunt and a `pktmon` capture against a harmless local listener.

## Initial Conditions

- No `lab20-*` namespaces exist yet: `ip netns list | grep lab20` is empty.
- You will run the setup script once as root, investigate, then run the clean-up script.
- The "backdoor" (`nc -lk ... 4444`) and the beacon (a `curl` loop every 5 s) run **inside** the namespaces and reach nothing outside them.

## Setup script (Linux)

Save as `lab20-setup.sh` and run `sudo bash lab20-setup.sh`. **Read it first.**

```bash
#!/usr/bin/env bash
# lab20-setup.sh - build an ISOLATED 3-namespace lab with a fake backdoor and beacon.
set -o errexit -o nounset -o pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
ip netns list | grep -q lab20 && { echo "Already set up. Run lab20-cleanup.sh first." >&2; exit 1; }
LAB=/srv/lab20 ; mkdir -p "$LAB"

# three namespaces + a bridge namespace, joined by veth pairs (isolated: no uplink)
ip netns add lab20-sw ; ip netns add lab20-vic ; ip netns add lab20-c2 ; ip netns add lab20-admin
ip -n lab20-sw link add br0 type bridge ; ip -n lab20-sw link set br0 up
for pair in vic:10.44.0.10 c2:10.44.0.66 admin:10.44.0.20; do
    ns=lab20-${pair%:*} ; ip=${pair#*:}
    ip link add "v-${pair%:*}" type veth peer name "p-${pair%:*}"
    ip link set "v-${pair%:*}" netns "$ns" ; ip link set "p-${pair%:*}" netns lab20-sw
    ip -n lab20-sw link set "p-${pair%:*}" master br0 up
    ip -n "$ns" addr add "$ip/24" dev "v-${pair%:*}" ; ip -n "$ns" link set "v-${pair%:*}" up
    ip -n "$ns" link set lo up
done

# victim: two "normal" listeners (python http on 80, a stand-in sshd banner on 22) ...
ip netns exec lab20-vic sh -c 'cd /srv/lab20 && nohup python3 -m http.server 80 >/dev/null 2>&1 & echo $! > /srv/lab20/http.pid'
ip netns exec lab20-vic sh -c 'nohup nc -lk 10.44.0.10 22 >/dev/null 2>&1 & echo $! > /srv/lab20/ssh.pid'
# ... and the BACKDOOR: a listener on 4444 (simulated reverse shell handler)
ip netns exec lab20-vic sh -c 'nohup nc -lk 10.44.0.10 4444 >/dev/null 2>&1 & echo $! > /srv/lab20/backdoor.pid'

# fake C2 listener
ip netns exec lab20-c2 sh -c 'nohup nc -lk 10.44.0.66 443 >/dev/null 2>&1 & echo $! > /srv/lab20/c2.pid'

# the BEACON: victim connects to the C2 every 5 seconds
cat > "$LAB/beacon.sh" <<'EOF'
#!/bin/sh
while true; do echo "checkin $(date -u +%s)" | nc -w 2 10.44.0.66 443 || true; sleep 5; done
EOF
chmod +x "$LAB/beacon.sh"
ip netns exec lab20-vic sh -c 'nohup /srv/lab20/beacon.sh >/dev/null 2>&1 & echo $! > /srv/lab20/beacon.pid'

echo "Lab 20 ready. Investigate vic01 (10.44.0.10) from lab20-admin / inside lab20-vic."
echo "Run commands with: sudo ip netns exec lab20-<ns> <command>"
```

## Step-by-Step Instructions

### Task 1 — Baseline and find the backdoor

Inside the victim namespace, list the listening sockets and compare with what a web/ssh host *should* expose (22, 80). Identify the extra listener and map it to its process and binary.

```bash
sudo ip netns exec lab20-vic ss -tulpn
sudo ip netns exec lab20-vic lsof -nP -i :4444
```

### Task 2 — Find the beacon

List established/recent outbound connections from the victim and spot the repeated destination. Note the process that owns it.

```bash
sudo ip netns exec lab20-vic ss -tanp | grep 10.44.0.66
```

### Task 3 — Capture and confirm the interval

Capture the beacon from inside the victim namespace with a tight filter, then read it back and measure the interval.

```bash
sudo ip netns exec lab20-vic timeout 20 tcpdump -n -w /srv/lab20/beacon.pcap 'host 10.44.0.66'
tcpdump -n -r /srv/lab20/beacon.pcap 'tcp[tcpflags] & tcp-syn != 0' | head
```

### Task 4 — Scan the victim from the admin namespace

From `lab20-admin`, scan vic01 and read the states with `--reason`. (This is inside the lab only.)

```bash
sudo ip netns exec lab20-admin nmap -sT --reason -p 22,80,443,4444 10.44.0.10
```

### Task 5 — Correlate, report, clean up

Combine the findings with a host audit (Day 19: a quick SUID/listener check) into a short timeline and prioritised report, then run the clean-up.

## Commands to Execute

Try each step yourself; full commands are in the [Solution](#solution).

## Expected Results

- **Task 1:** listeners on 22, 80 **and 4444**; port 4444 owned by `nc` — a backdoor/reverse-shell handler.
- **Task 2:** repeated outbound connections to `10.44.0.66:443`, owned by the `beacon.sh`/`nc` process.
- **Task 3:** a SYN to `10.44.0.66` roughly **every 5 seconds** — a beaconing pattern.
- **Task 4:** `22/tcp open`, `80/tcp open`, `4444/tcp open` (`reason syn-ack`), `443/tcp closed` (`reason conn-refused`, nothing listens on 443 on the victim).
- **Task 5:** a prioritised report (backdoor = Critical, beacon = Critical, with evidence).

## Verification Steps

```bash
# the three namespaces exist during the lab
sudo ip netns list | grep lab20
# the suspicious listener is present
sudo ip netns exec lab20-vic ss -ltnp 'sport = :4444'
# after clean-up, nothing remains
sudo bash lab20-cleanup.sh
ip netns list | grep lab20 || echo "namespaces gone"
pgrep -af 'beacon.sh|10.44.0' || echo "no lab processes remain"
ls /srv/lab20 2>/dev/null || echo "lab dir gone"
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Already set up" | Previous run left namespaces | Run `lab20-cleanup.sh` first |
| `ss`/`nmap`/`tcpdump` not found | Toolkit not installed | `sudo apt install -y nmap iproute2 lsof tcpdump` |
| `nmap` shows 443 `filtered` not `closed` | A stray firewall rule in the ns | Expected is `closed`; check no nft/iptables rules were added |
| Capture empty | Wrong namespace or filter | Capture **inside** `lab20-vic`; filter `host 10.44.0.66` |
| Beacon not seen | The beacon process died | Check `/srv/lab20/beacon.pid`; re-run setup |
| Namespaces survive a reboot | They don't — they are runtime only | Just re-run setup after a reboot |

## Questions

1. Why is the listener on 4444 classed as a backdoor, and what one piece of evidence confirms which program opened it?
2. What makes the connection to `10.44.0.66:443` look like C2 beaconing rather than a normal HTTPS request?
3. In Task 4, why does the victim's port 443 come back **closed** while 4444 is **open**? Map both to the Day 12 refused/timed-out terms.
4. Why capture **inside** the victim namespace with a tight `host` filter rather than broadly?
5. You must contain vic01. Why do you collect the socket, PID, binary and capture evidence *before* killing the backdoor?
6. How would this investigation differ if the beacon used port 53 instead of 443?

## Solution

??? success "Bash solution"
    ```bash
    sudo bash lab20-setup.sh

    # ---- Task 1: baseline + backdoor ----
    sudo ip netns exec lab20-vic ss -tulpn
    #   LISTEN 0.0.0.0:22  python? no -> nc ; 0.0.0.0:80 python3 ; 0.0.0.0:4444 nc  <-- extra
    sudo ip netns exec lab20-vic lsof -nP -i :4444
    #   nc ... 4444 (LISTEN)  -> backdoor/reverse-shell handler
    pid=$(cat /srv/lab20/backdoor.pid)
    sudo ls -l /proc/"$pid"/exe ; sudo cat /proc/"$pid"/cmdline | tr '\0' ' '; echo

    # ---- Task 2: beacon ----
    sudo ip netns exec lab20-vic ss -tanp | grep 10.44.0.66
    #   repeated ESTAB/TIME-WAIT to 10.44.0.66:443 owned by nc (from beacon.sh)

    # ---- Task 3: capture + interval ----
    sudo ip netns exec lab20-vic timeout 20 tcpdump -n -w /srv/lab20/beacon.pcap 'host 10.44.0.66'
    tcpdump -n -r /srv/lab20/beacon.pcap 'tcp[tcpflags] & tcp-syn != 0'
    #   SYN to 10.44.0.66.443 about every 5 s  -> beacon interval
    tshark -r /srv/lab20/beacon.pcap -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' \
           -T fields -e frame.time_relative -e ip.dst 2>/dev/null

    # ---- Task 4: scan from admin ----
    sudo ip netns exec lab20-admin nmap -sT --reason -p 22,80,443,4444 10.44.0.10
    #   22/tcp open (syn-ack), 80/tcp open (syn-ack), 4444/tcp open (syn-ack),
    #   443/tcp closed (conn-refused)

    # ---- Task 5: quick host-audit correlation (Day 19) + report ----
    sudo ip netns exec lab20-vic ss -ltnp | awk 'NR>1{print $4}'   # listener inventory
    # build the timeline and report from the evidence above, then:
    sudo bash lab20-cleanup.sh
    ```

    The **clean-up script**:

    ```bash
    #!/usr/bin/env bash
    # lab20-cleanup.sh - tear down the lab (namespaces, processes, files).
    set -o nounset -o pipefail
    [ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
    for p in /srv/lab20/*.pid; do [ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null; done
    pkill -f '/srv/lab20/beacon.sh' 2>/dev/null
    for ns in lab20-vic lab20-c2 lab20-admin lab20-sw; do
        ip netns pids "$ns" 2>/dev/null | xargs -r kill 2>/dev/null
        ip netns del "$ns" 2>/dev/null && echo "removed $ns"
    done
    rm -rf -- /srv/lab20 && echo "removed /srv/lab20"
    ```

    Deleting a namespace removes its veths, but processes started inside it are not always reaped automatically, so the clean-up kills the saved PIDs and anything still in each namespace first.

??? success "PowerShell solution"
    ```powershell
    # On a Windows lab VM (elevated). Repeat the socket-hunt against a harmless local listener.
    # 1. Start a benign listener in another window: (lab only)
    #    $l=[System.Net.Sockets.TcpListener]::new([Net.IPAddress]::Any,4444); $l.Start()
    Get-NetTCPConnection -State Listen |
        Where-Object LocalPort -notin 135,139,445,3389,5985,49152..49170 |
        Select-Object LocalAddress,LocalPort,OwningProcess,
            @{n='Proc';e={(Get-Process -Id $_.OwningProcess -EA SilentlyContinue).ProcessName}}

    # Map an established connection to its binary
    Get-NetTCPConnection -State Established |
        Select-Object RemoteAddress,RemotePort,OwningProcess,
            @{n='Path';e={(Get-Process -Id $_.OwningProcess -EA SilentlyContinue).Path}} |
        Sort-Object RemoteAddress

    netstat -anob | Select-String '4444'           # connection + executable

    # Capture to pcapng for Wireshark (elevated)
    pktmon start --capture --pkt-size 0
    Start-Sleep 20
    pktmon stop
    pktmon etl2pcap "$env:SystemRoot\System32\PktMon.etl" --out C:\case\lab20.pcapng
    # $l.Stop()   # stop the benign listener when done
    ```

    The method is identical to Linux: list listeners, flag the unexpected one, resolve its owning process to a path, and capture only what you need.

??? success "Answers to questions"
    1. It is a listener on a non-standard port (4444) that is **not** part of the host's expected services (22/80) and is owned by `nc` acting as a listen handler — the shape of a reverse-shell/backdoor. The confirming evidence is the owning process: `lsof -nP -i :4444` / `ss -ltnp` ties the socket to the `nc` PID, and `/proc/PID/exe` + `cmdline` show the exact binary and arguments.
    2. It is **repeated, small and metronomic** — a new connection to the *same* address (`10.44.0.66`) every ~5 seconds — rather than a single on-demand request. Regularity to one destination is the beacon signature; using 443 makes it blend with normal HTTPS.
    3. Port 4444 has a listener, so the victim answers the SYN with a SYN-ACK → **open** → "refused" is not applicable, it simply accepts. Port 443 has **nothing listening on the victim** (the C2 is a different host), so the victim replies with a RST → **closed** = *refused* (Day 12). A dropped probe with no reply would be *filtered* = *timed out*.
    4. Capturing inside the victim's namespace sees exactly its traffic; a tight `host 10.44.0.66` filter records only the suspect conversation — smaller files, no unrelated/private traffic, and a focused, defensible piece of evidence. `-n` avoids reverse-DNS that could tip off a real attacker and avoids lookup delays.
    5. Killing the backdoor destroys the live socket, the running process and its in-memory state, and may close the attacker's session before you have learned anything. Collecting the socket table, PID, binary (copy from `/proc/PID/exe`, which survives a deleted file) and a capture first preserves a reproducible record; containment follows, per the IR plan.
    6. A beacon on **port 53** would masquerade as DNS. You would inspect it as DNS: look for an unusual volume of queries, long random subdomains or heavy TXT-record use (DNS tunnelling, Day 13) with `tshark -Y 'dns'`, and check whether the "DNS" traffic actually goes to your resolver or straight to the suspect address.
