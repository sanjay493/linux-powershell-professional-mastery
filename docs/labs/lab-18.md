---
description: "Build a least-privilege host firewall for a new application server: inventory listening services, apply a default-deny ufw policy without locking yourself out (backup, management first, timed rollback), prove it with a client-by-port test matrix, repair a broken change with rule numbers and counters, read [UFW BLOCK] logs, re-implement the policy as an atomic nftables file, and repeat on Windows with netsh advfirewall export, New-NetFirewallRule in a group, Test-NetConnection, pfirewall.log and Remove-NetFirewallRule -WhatIf."
---

# Lab 18: Least-Privilege Firewall

| Field | Value |
|---|---|
| **Lab ID** | LAB-18 |
| **Related lesson** | [Day 18: Firewall Management](../course/module-4/day-18.md) |
| **Difficulty** | Intermediate |
| **Time** | 90–120 minutes (Linux 70 min, Windows 30–40 min) |
| **Risk level** | Medium. Linux: everything happens inside network namespaces on a **disposable VM** whose own ufw firewall is **not** in use; `/etc/ufw` is backed up by the setup script and restored by the clean-up script. Windows: a lab VM only; export the firewall policy before any change (Task 7 does this first). |

## Objective

You are the administrator of **app01** (10.18.0.10), a new application server. Five services listen on all addresses and no firewall is active. Change ticket **CHG-1818** defines the approved inbound policy:

| Port | Service | Allowed from | Everyone else |
|---|---|---|---|
| 22/tcp | SSH | Admin subnet **10.18.0.16/28** | Drop |
| 443/tcp | Web application | Anyone | — |
| 9100/tcp | Metrics exporter | Monitoring host **10.18.0.50** only | Drop |
| 8080/tcp | Debug console | No one | **Reject** (fast failure for developers) |
| Anything else (e.g. 5432/tcp database) | — | No one | Drop and log |

Your job:

1. Record the **baseline exposure** with evidence.
2. Apply the policy with **ufw** without ever risking a lockout: backup, management access first, timed rollback, test from a **new** admin session.
3. Prove the policy with a **test matrix** (client × port → open / refused / filtered).
4. Repair change **CHG-1818b**, a colleague's "quick fix" that broke three things, using `ufw status numbered` and rule **counters** — without disabling the firewall.
5. Read and summarise **blocked-packet logs**.
6. Re-implement the identical policy as an **nftables** file, loaded atomically after a syntax check.
7. Do the same job on **Windows**: export, scoped rules in a group, test, log, roll back.

## Required Environment

- **Linux:** an Ubuntu 24.04 **VM** (not WSL, not a production or cloud host) with `sudo`, where `sudo ufw status` reports `Status: inactive`. The setup script refuses to run if ufw is active, because ufw keeps its configuration in `/etc/ufw` even when it is driven inside a namespace. Packages:

    ```bash
    sudo apt update && sudo apt install -y ufw nftables iproute2 netcat-openbsd curl nmap conntrack python3
    ```

- The lab topology, created by the setup script — four network namespaces on one bridge:

    ```mermaid
    flowchart LR
        subgraph SW["lab18-sw (bridge br0)"]
            BR(( ))
        end
        SRV["lab18-server<br/>app01 10.18.0.10<br/>listens: 22, 443, 5432, 8080, 9100<br/>ufw / nftables HERE"] --- BR
        ADM["lab18-admin<br/>10.18.0.20<br/>(admin subnet 10.18.0.16/28)"] --- BR
        MON["lab18-monitor<br/>10.18.0.50"] --- BR
        GST["lab18-guest<br/>10.18.0.100"] --- BR
    ```

- **Windows:** a Windows 11 or Windows Server **lab VM**, an **elevated** PowerShell (5.1 or 7). A second machine (another VM, or the Linux VM) on the same network to test from is strongly recommended: Windows does not filter loopback traffic, so tests against `localhost` prove nothing.

## Initial Conditions

- Linux: `sudo ufw status` → `Status: inactive`; no namespaces named `lab18-*` (`ip netns list`); `/srv/lab18` does not exist (if it does from an earlier attempt, run `sudo /srv/lab18/bin/cleanup.sh` and then rename the folder).
- Work in a **root shell** for the Linux tasks (`sudo -i`): every command that touches the lab must run inside a namespace, and two helper functions keep that short and safe:

    ```bash
    srv()  { ip netns exec lab18-server "$@"; }          # run a command ON app01
    from() { local c="$1"; shift; ip netns exec "lab18-$c" "$@"; }   # run a command on a client
    ```

    `srv ufw status` changes only the server namespace's firewall; the VM's own network stays untouched.

- Windows: note the current firewall state (`Get-NetFirewallProfile -PolicyStore ActiveStore`). Create `C:\Lab18` for backups and evidence.

### Setup script (Linux)

Save as `~/lab18-setup.sh`, read it, then run `sudo bash ~/lab18-setup.sh`. It creates the namespaces, a small Python service on five ports inside `lab18-server`, and three helper scripts in `/srv/lab18/bin`: `matrix.sh` (the test matrix), `break.sh` (change CHG-1818b, Task 4 only) and `cleanup.sh`.

```bash
#!/usr/bin/env bash
# Lab 18 setup: one server and three clients in network namespaces, joined by a bridge.
set -o errexit -o nounset -o pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
LAB=/srv/lab18
# Safety: this lab drives ufw inside a namespace, but ufw keeps its configuration in /etc/ufw.
# Refuse to run on a machine whose own ufw firewall is in use.
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
    echo "ufw is active on this host: use a disposable VM for Lab 18" >&2; exit 1
fi
ip netns list | grep -q '^lab18-' && { echo "Lab 18 namespaces exist: run cleanup.sh first" >&2; exit 1; }
mkdir -p "$LAB"/{bin,backups,logs}
tar -C /etc -czf "$LAB/backups/etc-ufw-original.tgz" ufw

ip netns add lab18-sw
ip -n lab18-sw link add br0 type bridge
ip -n lab18-sw link set br0 up
declare -A ADDR=([server]=10.18.0.10 [admin]=10.18.0.20 [monitor]=10.18.0.50 [guest]=10.18.0.100)
for n in server admin monitor guest; do
    ip netns add "lab18-$n"
    ip link add "v-$n" type veth peer name eth0 netns "lab18-$n"
    ip link set "v-$n" netns lab18-sw
    ip -n lab18-sw link set "v-$n" master br0 up
    ip -n "lab18-$n" addr add "${ADDR[$n]}/24" dev eth0
    ip -n "lab18-$n" link set eth0 up
    ip -n "lab18-$n" link set lo up
done

# Lab services: a tiny TCP/HTTP server that answers on every port it is given
cat > "$LAB/bin/services.py" <<'PY'
import socket, sys, threading
def serve(port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", port)); s.listen(16)
    while True:
        c, _ = s.accept()
        try:
            if port == 22:
                c.sendall(b"SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13 (lab18)\r\n")
            else:
                c.settimeout(2)
                try: c.recv(1024)
                except OSError: pass
                body = {443: b"lab18 web: OK\n", 9100: b"node_load1 0.42\n",
                        5432: b"lab18 database\n", 8080: b"lab18 debug console\n"}.get(port, b"lab18\n")
                c.sendall(b"HTTP/1.0 200 OK\r\nContent-Length: %d\r\n\r\n" % len(body) + body)
        except OSError:
            pass  # client went away (port scans do this): keep serving
        finally:
            c.close()
for p in map(int, sys.argv[1:]):
    threading.Thread(target=serve, args=(p,), daemon=True).start()
threading.Event().wait()
PY
# Helper scripts
cat > "$LAB/bin/matrix.sh" <<'SH'
#!/usr/bin/env bash
# Lab 18: test every client -> server port and print open / refused / filtered.
set -o nounset -o pipefail
SERVER=10.18.0.10
PORTS=(22 443 5432 8080 9100)
printf '%-8s' "client"; printf '%10s' "${PORTS[@]}"; echo
for c in admin monitor guest; do
    printf '%-8s' "$c"
    for p in "${PORTS[@]}"; do
        out="$(ip netns exec "lab18-$c" nc -z -v -w 2 "$SERVER" "$p" 2>&1)"
        case "$out" in
            *succeeded*) r=open ;;
            *refused*)   r=refused ;;
            *"timed out"*) r=filtered ;;
            *) r=error ;;
        esac
        printf '%10s' "$r"
    done
    echo
done
SH
cat > "$LAB/bin/break.sh" <<'SH'
#!/usr/bin/env bash
# Lab 18: "a colleague's quick fix" - introduces three faults into the ufw policy.
set -o nounset -o pipefail
S=(ip netns exec lab18-server)
"${S[@]}" ufw insert 1 allow 9100/tcp comment 'temp: grafana test' >/dev/null
"${S[@]}" ufw delete allow 443/tcp >/dev/null
"${S[@]}" ufw allow 443/udp comment 'web' >/dev/null
"${S[@]}" ufw delete allow from 10.18.0.16/28 to any port 22 proto tcp >/dev/null
"${S[@]}" ufw insert 1 allow from 10.18.0.32/28 to any port 22 proto tcp comment 'admin SSH' >/dev/null
echo "Change CHG-1818b applied. Users report: website down, admins cannot SSH, audit says metrics are public."
SH
cat > "$LAB/bin/cleanup.sh" <<'SH'
#!/usr/bin/env bash
# Lab 18 clean-up: stop the services, delete the namespaces, restore /etc/ufw.
set -o nounset -o pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
LAB=/srv/lab18
[[ -f "$LAB/services.pid" ]] && kill "$(cat "$LAB/services.pid")" 2>/dev/null
pkill -f "$LAB/bin/services.py" 2>/dev/null
for n in server admin monitor guest sw; do ip netns del "lab18-$n" 2>/dev/null; done
if [[ -f "$LAB/backups/etc-ufw-original.tgz" ]]; then
    rm -rf /etc/ufw && tar -C /etc -xzf "$LAB/backups/etc-ufw-original.tgz" && echo "/etc/ufw restored"
fi
sysctl -q -w net.netfilter.nf_log_all_netns=0 2>/dev/null
ip netns list | grep -c '^lab18-' || true
echo "Lab 18 removed. Evidence in $LAB/backups and $LAB/logs is kept; delete $LAB when you no longer need it."
SH
chmod 755 "$LAB/bin/"*.sh

nohup ip netns exec lab18-server python3 "$LAB/bin/services.py" 22 443 9100 5432 8080 \
    > "$LAB/logs/services.log" 2>&1 &
echo $! > "$LAB/services.pid"
sleep 1
ip netns exec lab18-server ss -ltn
echo "Lab 18 ready: server 10.18.0.10, admin 10.18.0.20, monitor 10.18.0.50, guest 10.18.0.100"
```

Expected output: the five `LISTEN` lines and `Lab 18 ready: server 10.18.0.10, admin 10.18.0.20, monitor 10.18.0.50, guest 10.18.0.100`.

## Step-by-Step Instructions

### Task 1 — Baseline: what is exposed?

1. On the server, list the listening sockets and save them to `/srv/lab18/logs/listening-before.txt`.
2. Run `/srv/lab18/bin/matrix.sh` and save the result as `/srv/lab18/logs/matrix-before.txt`. Which ports violate CHG-1818 from which clients?
3. Back up the current state **before any change**: `iptables-save` of the server namespace, and an archive of `/etc/ufw`, both into `/srv/lab18/backups/`.

### Task 2 — Lockout-safe enablement

You are pretending to manage app01 **over SSH from the admin network**. A mistake now means "drive to the data centre".

1. **Arm a rollback** that returns the server to its previous state (firewall inactive) in five minutes unless you cancel it.
2. Add the **SSH rule for the admin subnet first**, then set the defaults (deny incoming, allow outgoing), then enable ufw.
3. From the admin client, open a **new** connection to port 22. Only if it succeeds, **cancel** the rollback.
4. Explain why your existing SSH session would have survived even a wrong rule, and why that makes it useless as a test.

### Task 3 — Complete the policy and prove it

1. Add the remaining CHG-1818 rules: HTTPS for everyone, 9100 from the monitoring host only, 8080 rejected. Add a **comment** to every rule.
2. Show the rules with numbers.
3. Run the test matrix and save it as `/srv/lab18/logs/matrix-after.txt`. It must match the policy table exactly. Archive the working `/etc/ufw` as `etc-ufw-good.tgz` — your known-good state.

### Task 4 — Repair change CHG-1818b

A colleague "quickly fixed" a monitoring problem in production. Apply their change:

```bash
/srv/lab18/bin/break.sh
```

Users now report: *the website is down, admins cannot SSH, and the audit team says metrics are public*.

1. Run the test matrix and describe each deviation from the policy.
2. Use `ufw status numbered` **and** `iptables -L ufw-user-input -n -v --line-numbers` (counters) to find the three faulty rules. Which rule is **shadowed**, and how do the counters prove it?
3. Fix the policy **without disabling the firewall and without `ufw reset`**: delete and insert rules by number, previewing each delete.
4. Prove the fix: the matrix must be identical to `matrix-after.txt` (`diff`).

### Task 5 — Read the blocked-packet log

1. Set ufw logging to `low`. In this namespace lab, kernel log lines from a namespace are only written when `net.netfilter.nf_log_all_netns=1`; set it for this task (it is reset by the clean-up script). On an ordinary server you would not need this.
2. From the guest, probe ports 5432, 22, 3306 and 9100 once each.
3. Find the `[UFW BLOCK]` lines (`dmesg` or `journalctl -k`; on a normal host also `/var/log/ufw.log`), save them to `/srv/lab18/logs/ufw-block.txt`, and summarise them as *count, source, destination port*.
4. Set `nf_log_all_netns` back to `0`.

### Task 6 — The same policy in nftables

1. Disable ufw in the server namespace (one firewall manager at a time).
2. Write `/srv/lab18/lab18.nft`: an `inet` table with an `admin_nets` **set**, an `input` base chain with policy `drop`, the state rules, loopback, useful ICMP, the four service rules with **counters and comments**, and a rate-limited log rule before the policy.
3. Check it with `nft -c -f`. Save the current ruleset, arm a five-minute rollback (`nft flush ruleset` returns to the previous, empty state), load the file, test SSH from the admin client, cancel the rollback.
4. Prove that the matrix is identical to `matrix-after.txt`, and show the rule counters.

### Task 7 — Windows: the same discipline

On the Windows lab VM (elevated PowerShell):

1. Record the profiles (`-PolicyStore ActiveStore`) and the network category. **Export** the whole policy to `C:\Lab18\fw-before.wfw`.
2. Start two test listeners (ports 9100 and 8080) with .NET `TcpListener` so that there is something to reach.
3. Create, in a group named `Lab18`, an inbound rule for 9100/tcp from the monitoring address only (use your second machine's address) and a **Block** rule for 8080/tcp. Show the rules **with** their port and address filters.
4. Test from the second machine (`Test-NetConnection -Port`, or `nc -zv` from Linux) and from a third address if you have one.
5. Enable `LogBlocked` for all profiles, generate a blocked attempt, and read the newest `DROP` lines of `pfirewall.log`.
6. Remove the `Lab18` group with `-WhatIf` first, then for real; stop the listeners; restore logging settings. Finally prove that `C:\Lab18\fw-before.wfw` can restore the original policy (`netsh advfirewall import`) and compare the rule count before and after.

## Commands to Execute

Try each task yourself first; the complete commands are in the [Solution](#solution). Useful building blocks:

| Purpose | Linux (root shell, helper functions loaded) | Windows (elevated) |
|---|---|---|
| Listening services | `srv ss -ltn` | `Get-NetTCPConnection -State Listen` |
| Test matrix / single test | `/srv/lab18/bin/matrix.sh` · `from guest nc -zv -w 2 10.18.0.10 443` | `Test-NetConnection HOST -Port 9100` |
| Rules with numbers | `srv ufw status numbered` | `Get-NetFirewallRule -Group Lab18` |
| Counters | `srv iptables -L ufw-user-input -n -v --line-numbers` · `srv nft list ruleset` | — (use `pfirewall.log`) |
| Backup | `srv iptables-save` · `tar -C /etc -czf … ufw` · `srv nft list ruleset` | `netsh advfirewall export C:\Lab18\fw-before.wfw` |
| Timed rollback | `systemd-run --on-active=5m --unit=lab18-rollback ip netns exec lab18-server ufw disable` | Scheduled task running `netsh advfirewall import` |
| Logs | `dmesg` · `journalctl -k -g 'UFW BLOCK'` | `Get-Content …\pfirewall.log -Tail 50` |
| Remove | `srv ufw --force delete N` · `srv nft delete rule inet lab18 input handle N` | `Remove-NetFirewallRule -Group Lab18 -WhatIf` |

## Expected Results

The Linux results below were **captured** on 2026-11-15 by running this lab's setup, the Bash solution and the clean-up end to end as root on Ubuntu 24.04.5 in a container (ufw 0.36.2, iptables 1.8.10 nf_tables, nftables 1.0.9, OpenBSD netcat). The container had no systemd, so the rollback timer was replaced by the background-job variant given in the solution; and its kernel had no IPv6, so ufw created no `(v6)` rules — on a normal VM every rule without an IPv4 source also appears as a `(v6)` line. Windows results are **examples**.

- **Task 1** — every client reaches every port:

    ```text
    client          22       443      5432      8080      9100
    admin         open      open      open      open      open
    monitor       open      open      open      open      open
    guest         open      open      open      open      open
    ```

    Violations: 22 from monitor and guest, 5432 and 8080 from everyone, 9100 from admin and guest.

- **Task 2** — `Rules updated`, the two default-policy messages, `Firewall is active and enabled on system startup`, a successful new admin connection to 22, and `rollback cancelled`.
- **Task 3** — four numbered rules with comments and the approved matrix:

    ```text
    Status: active

         To                         Action      From
         --                         ------      ----
    [ 1] 22/tcp                     ALLOW IN    10.18.0.16/28              # admin SSH
    [ 2] 443/tcp                    ALLOW IN    Anywhere                   # HTTPS
    [ 3] 9100/tcp                   ALLOW IN    10.18.0.50                 # node exporter
    [ 4] 8080/tcp                   REJECT IN   Anywhere                   # debug console

    client          22       443      5432      8080      9100
    admin         open      open  filtered   refused  filtered
    monitor   filtered      open  filtered   refused      open
    guest     filtered      open  filtered   refused  filtered
    ```

- **Task 4** — after `break.sh`:

    ```text
    client          22       443      5432      8080      9100
    admin     filtered  filtered  filtered   refused      open
    monitor   filtered  filtered  filtered   refused      open
    guest     filtered  filtered  filtered   refused      open
    Status: active

         To                         Action      From
         --                         ------      ----
    [ 1] 22/tcp                     ALLOW IN    10.18.0.32/28              # admin SSH
    [ 2] 9100/tcp                   ALLOW IN    Anywhere                   # temp: grafana test
    [ 3] 9100/tcp                   ALLOW IN    10.18.0.50                 # node exporter
    [ 4] 8080/tcp                   REJECT IN   Anywhere                   # debug console
    [ 5] 443/udp                    ALLOW IN    Anywhere                   # web

    Chain ufw-user-input (1 references)
    num   pkts bytes target     prot opt in     out     source               destination
    1        0     0 ACCEPT     6    --  *      *       10.18.0.32/28        0.0.0.0/0            tcp dpt:22
    2        3   180 ACCEPT     6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9100
    3        0     0 ACCEPT     6    --  *      *       10.18.0.50           0.0.0.0/0            tcp dpt:9100
    4        3   180 REJECT     6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 reject-with tcp-reset
    5        0     0 ACCEPT     17   --  *      *       0.0.0.0/0            0.0.0.0/0            udp dpt:443
    ```

    After the repair the matrix is identical to Task 3 and `diff` prints `matrix matches the approved policy`.

- **Task 5** — four `[UFW BLOCK]` lines from `SRC=10.18.0.100` and the summary:

    ```text
          1 10.18.0.100 22
          1 10.18.0.100 3306
          1 10.18.0.100 5432
          1 10.18.0.100 9100
    ```

- **Task 6** — `check OK`, `SSH still works - rollback cancelled`, `nftables policy gives the same matrix`, and counters such as:

    ```text
    tcp dport 22 ip saddr @admin_nets counter packets 2 bytes 120 accept comment "SSH from admin subnet"
    tcp dport 443 counter packets 3 bytes 180 accept comment "HTTPS for everyone"
    tcp dport 9100 ip saddr 10.18.0.50 counter packets 1 bytes 60 accept comment "metrics from monitoring host"
    tcp dport 8080 counter packets 3 bytes 180 reject with tcp reset comment "debug console: refuse loudly"
    counter packets 14 bytes 840 comment "dropped by policy"
    ```

    The policy counter counts **packets**, not connection attempts: each dropped SYN is retransmitted once within `nc`'s two-second timeout, so seven blocked attempts give 14 packets.

- **Task 7 (example)** — `Ok.` from the export; the 9100 rule shows `RemoteAddress` = the monitoring address; `TcpTestSucceeded : True` for 9100 from the monitoring machine and `False` for 8080; `DROP TCP … 8080 … RECEIVE` lines in `pfirewall.log`; `What if:` lines for both rules; the rule count after the import equals the count before Task 7.

## Verification Steps

=== "Bash"

    ```bash
    srv ufw status | head -1                                   # Status: active (Tasks 3-5)
    diff <(/srv/lab18/bin/matrix.sh) /srv/lab18/logs/matrix-after.txt && echo "policy OK"
    srv iptables -L ufw-user-input -n -v --line-numbers        # every rule has hits, none shadowed
    ls -l /srv/lab18/backups/                                  # iptables-before.rules, etc-ufw-*.tgz
    srv nft -c -f /srv/lab18/lab18.nft && echo "nft file OK"   # Task 6
    srv nft list tables                                        # table inet lab18 (after Task 6)
    sysctl net.netfilter.nf_log_all_netns                      # 0 after Task 5
    ```

=== "PowerShell"

    ```powershell
    Test-Path C:\Lab18\fw-before.wfw                              # True
    Get-NetFirewallRule -Group Lab18 -ErrorAction SilentlyContinue  # nothing after Task 7.6
    Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, Enabled, DefaultInboundAction, LogBlocked
    (Get-NetFirewallRule).Count                                    # same as before the lab
    ```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Setup: `ufw is active on this host: use a disposable VM` | The VM's own ufw is in use | Use another VM; do not disable a firewall someone relies on |
| Setup: `RTNETLINK answers: File exists` | Namespaces from an earlier run | `sudo /srv/lab18/bin/cleanup.sh`, then rerun setup |
| Every matrix cell shows `error` | `nc` is not the OpenBSD variant, or the namespaces are gone | `sudo apt install netcat-openbsd`; `ip netns list` |
| A port shows `refused` from everywhere, even before Task 2 | The lab service died | `cat /srv/lab18/logs/services.log`; restart the `nohup … services.py` line from the setup script |
| `ERROR: Could not delete non-existent rule` in Task 4 | Rule text does not match exactly | Delete by number from `status numbered` |
| You deleted the wrong rule number | Numbers shift after every delete | Delete from the highest number down; re-run `status numbered` |
| `break.sh` caused fewer faults than described | Your Task 3 rules were written differently (e.g. `ufw allow https`) | Restore `etc-ufw-good.tgz` (`tar -C /etc -xzf …` then `srv ufw reload`) and write the rules as in the solution |
| No `[UFW BLOCK]` lines | Logging off, `nf_log_all_netns` = 0, or only allowed ports probed | `srv ufw logging low`; `sysctl -w net.netfilter.nf_log_all_netns=1`; probe a blocked port |
| Task 6: `Error: syntax error, unexpected …` | Typo in the nft file | Fix the line and column shown; nothing was loaded |
| Task 6: the matrix still shows ufw behaviour | ufw still enabled, or `flush ruleset` missing at the top of the file | `srv ufw disable`; check the first line of the file |
| `systemd-run: command not found` / *System has not been booted with systemd* | Container or WSL without systemd | Use the background-job rollback shown in the solution |
| Windows: `Access is denied` | Not elevated | Elevated PowerShell |
| Windows: tests from the same machine always succeed | Loopback is not filtered | Test from a second machine |
| Windows: `pfirewall.log` has no DROP lines | `LogBlocked` not set for the **active** profile, or nothing was blocked | `Get-NetConnectionProfile`; `Set-NetFirewallProfile -Profile Domain, Private, Public -LogBlocked True` |

## Questions

1. Which listening service in the baseline was the most dangerous, and why does the policy still need a host firewall even if the database is later bound to 127.0.0.1?
2. In Task 2, why must the SSH rule exist **before** `ufw enable`, and why does the already-open SSH session prove nothing?
3. In the approved matrix, why is 8080 `refused` while 5432 is `filtered`? Which is the better choice for each, and why?
4. In Task 4, which rule was shadowed, and which counter values proved it?
5. Why did the `443/udp` rule not restore the website, and how would you have spotted this in `ufw status` alone?
6. Why should you delete ufw rules from the highest number down?
7. What does the policy counter in Task 6 count, and why is it twice the number of blocked connection attempts?
8. Name two ways in which the Windows Block rule for 8080 behaves differently from the ufw `reject` rule.
9. Why is `netsh advfirewall import` a restore and not a merge, and what does that mean for rules created after the export?
10. Which three pieces of evidence would you attach to the change ticket to prove CHG-1818 was implemented correctly?

## Solution

??? success "Bash solution"
    Run as root (`sudo -i`) on the lab VM after the setup script. The outputs are those listed under *Expected Results*.

    ```bash
    LAB=/srv/lab18
    srv()  { ip netns exec lab18-server "$@"; }
    from() { local c="$1"; shift; ip netns exec "lab18-$c" "$@"; }

    # ---------- Task 1: baseline and backups ----------
    srv ss -ltnH | awk '{ print $4 }' | sort | tee "$LAB/logs/listening-before.txt"
    "$LAB/bin/matrix.sh" | tee "$LAB/logs/matrix-before.txt"
    srv iptables-save > "$LAB/backups/iptables-before.rules"
    tar -C /etc -czf "$LAB/backups/etc-ufw-before-chg1818.tgz" ufw
    ls "$LAB/backups"

    # ---------- Task 2: lockout-safe enablement ----------
    # (a) rollback in 5 minutes. On a VM with systemd:
    #       systemd-run --on-active=5m --unit=lab18-rollback ip netns exec lab18-server ufw disable
    #       ...and cancel later with: systemctl stop lab18-rollback.timer
    #     Without systemd (container/WSL) use a background job instead:
    srv bash -c "nohup sh -c 'sleep 300; ufw disable' >$LAB/logs/rollback.log 2>&1 & echo \$! > $LAB/rollback.pid"
    # (b) management FIRST, then defaults, then enable
    srv ufw allow from 10.18.0.16/28 to any port 22 proto tcp comment 'admin SSH'
    srv ufw default deny incoming
    srv ufw default allow outgoing
    srv ufw --force enable
    # (c) NEW connection from the admin network; cancel the rollback only if it works
    from admin nc -zv -w 2 10.18.0.10 22 && kill "$(cat "$LAB/rollback.pid")" && echo "rollback cancelled"
    #     (kill stops the shell that would run "ufw disable"; its orphaned "sleep" just exits later)

    # ---------- Task 3: complete the policy ----------
    srv ufw allow 443/tcp comment 'HTTPS'
    srv ufw allow from 10.18.0.50 to any port 9100 proto tcp comment 'node exporter'
    srv ufw reject 8080/tcp comment 'debug console'
    srv ufw status numbered
    "$LAB/bin/matrix.sh" | tee "$LAB/logs/matrix-after.txt"
    tar -C /etc -czf "$LAB/backups/etc-ufw-good.tgz" ufw

    # ---------- Task 4: repair CHG-1818b ----------
    "$LAB/bin/break.sh"
    "$LAB/bin/matrix.sh"
    srv ufw status numbered
    srv iptables -L ufw-user-input -n -v --line-numbers
    # faults: [1] wrong admin subnet, [2] metrics open to everyone (shadows [3]), [5] udp instead of tcp
    # delete from the highest number down (without --force ufw shows the rule and asks y/n)
    srv ufw --force delete 5
    srv ufw --force delete 2
    srv ufw --force delete 1
    srv ufw insert 1 allow from 10.18.0.16/28 to any port 22 proto tcp comment 'admin SSH'
    srv ufw insert 2 allow 443/tcp comment 'HTTPS'
    srv ufw status numbered
    diff <("$LAB/bin/matrix.sh") "$LAB/logs/matrix-after.txt" && echo "matrix matches the approved policy"

    # ---------- Task 5: blocked-packet log ----------
    sysctl -w net.netfilter.nf_log_all_netns=1
    srv ufw logging low
    for p in 5432 22 3306 9100; do from guest nc -z -w 1 10.18.0.10 "$p"; done
    dmesg | grep '\[UFW BLOCK\]' | grep 'SRC=10.18.0.100' | tail -n 4 | tee "$LAB/logs/ufw-block.txt"
    sed -E 's/.*SRC=([0-9.]+).*DPT=([0-9]+).*/\1 \2/' "$LAB/logs/ufw-block.txt" | sort | uniq -c
    sysctl -w net.netfilter.nf_log_all_netns=0

    # ---------- Task 6: the same policy in nftables ----------
    srv ufw disable
    cat > "$LAB/lab18.nft" <<'NFT'
    #!/usr/sbin/nft -f
    # Lab 18: least-privilege inbound policy for app01 (10.18.0.10)
    flush ruleset

    table inet lab18 {
        set admin_nets {
            type ipv4_addr
            flags interval
            elements = { 10.18.0.16/28 }
        }

        chain input {
            type filter hook input priority filter; policy drop;

            ct state established,related accept
            ct state invalid drop
            iifname "lo" accept
            ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } accept

            tcp dport 22 ip saddr @admin_nets counter accept comment "SSH from admin subnet"
            tcp dport 443 counter accept comment "HTTPS for everyone"
            tcp dport 9100 ip saddr 10.18.0.50 counter accept comment "metrics from monitoring host"
            tcp dport 8080 counter reject with tcp reset comment "debug console: refuse loudly"

            limit rate 5/minute burst 10 packets log prefix "[NFT DROP] " level info
            counter comment "dropped by policy"
        }

        chain forward {
            type filter hook forward priority filter; policy drop;
        }

        chain output {
            type filter hook output priority filter; policy accept;
        }
    }
    NFT
    srv nft -c -f "$LAB/lab18.nft" && echo "check OK"
    srv nft list ruleset > "$LAB/backups/ruleset-before-nft.txt"
    srv bash -c "nohup sh -c 'sleep 300; nft flush ruleset' >/dev/null 2>&1 & echo \$! > $LAB/rollback.pid"
    srv nft -f "$LAB/lab18.nft" && from admin nc -z -w 2 10.18.0.10 22 &&
        kill "$(cat "$LAB/rollback.pid")" && echo "SSH still works - rollback cancelled"
    diff <("$LAB/bin/matrix.sh") "$LAB/logs/matrix-after.txt" && echo "nftables policy gives the same matrix"
    srv nft list chain inet lab18 input | grep counter | sed 's/^[[:space:]]*//'
    ```

    **Clean-up** (removes the namespaces, the services and restores the original `/etc/ufw`; evidence files stay):

    ```bash
    /srv/lab18/bin/cleanup.sh
    sudo ufw status                       # Status: inactive, as before the lab
    ```

??? success "PowerShell solution"
    Run in an **elevated** PowerShell on the Windows lab VM. Replace `10.18.0.50` with the address of the machine you test from (your "monitoring host"). Outputs are examples.

    ```powershell
    # ---------- 7.1 record and export ----------
    New-Item -ItemType Directory -Path C:\Lab18 -Force | Out-Null
    Get-NetConnectionProfile | Select-Object InterfaceAlias, NetworkCategory
    Get-NetFirewallProfile -PolicyStore ActiveStore |
        Select-Object Name, Enabled, DefaultInboundAction, LogBlocked, LogFileName |
        Export-Csv C:\Lab18\profiles-before.csv -NoTypeInformation
    $rulesBefore = (Get-NetFirewallRule).Count
    netsh advfirewall export "C:\Lab18\fw-before.wfw"

    # ---------- 7.2 test listeners (stop them in 7.6) ----------
    $listeners = foreach ($port in 9100, 8080) {
        $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
        $l.Start(); $l
    }
    Get-NetTCPConnection -State Listen -LocalPort 9100, 8080 | Select-Object LocalAddress, LocalPort, OwningProcess

    # ---------- 7.3 scoped rules in one group ----------
    $monitor = '10.18.0.50'
    New-NetFirewallRule -DisplayName 'Lab18 metrics from monitoring' -Name 'Lab18-Metrics-In' -Group 'Lab18' `
        -Direction Inbound -Protocol TCP -LocalPort 9100 -RemoteAddress $monitor -Action Allow `
        -Description 'CHG-1818: Prometheus exporter, monitoring host only' | Out-Null
    New-NetFirewallRule -DisplayName 'Lab18 debug console blocked' -Name 'Lab18-Debug-Block' -Group 'Lab18' `
        -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Block `
        -Description 'CHG-1818: debug console must not be reachable' | Out-Null
    Get-NetFirewallRule -Group 'Lab18' | ForEach-Object {
        $pf = $_ | Get-NetFirewallPortFilter
        $af = $_ | Get-NetFirewallAddressFilter
        [pscustomobject]@{ Name = $_.Name; Action = $_.Action; Enabled = $_.Enabled
                           Port = "$($pf.LocalPort)/$($pf.Protocol)"; Remote = ($af.RemoteAddress -join ',') }
    } | Format-Table -AutoSize

    # ---------- 7.4 test FROM THE SECOND MACHINE (not from this VM) ----------
    #   Windows: Test-NetConnection -ComputerName <this VM> -Port 9100   -> TcpTestSucceeded True
    #            Test-NetConnection -ComputerName <this VM> -Port 8080   -> False (blocked)
    #   Linux:   nc -zv -w 2 <this VM> 9100 ; nc -zv -w 2 <this VM> 8080   (8080: timed out = dropped)

    # ---------- 7.5 logging ----------
    Set-NetFirewallProfile -Profile Domain, Private, Public -LogBlocked True -LogMaxSizeKilobytes 16384
    # ...repeat the 8080 test from the second machine, then:
    $log = Join-Path $env:SystemRoot 'System32\LogFiles\Firewall\pfirewall.log'
    Get-Content $log -Tail 200 | Where-Object { $_ -match ' DROP ' -and $_ -match ' 8080 ' } |
        Select-Object -Last 5 | Tee-Object C:\Lab18\pfirewall-drops.txt

    # ---------- 7.6 remove, stop, restore ----------
    Remove-NetFirewallRule -Group 'Lab18' -WhatIf
    Remove-NetFirewallRule -Group 'Lab18'
    $listeners | ForEach-Object { $_.Stop() }
    netsh advfirewall import "C:\Lab18\fw-before.wfw"     # full restore: rules AND profile settings (logging)
    Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, LogBlocked   # compare with profiles-before.csv
    '{0} rules before, {1} rules after' -f $rulesBefore, (Get-NetFirewallRule).Count
    ```

    **Expected output (example, excerpts):**

    ```text
    Ok.

    Name              Action Enabled Port     Remote
    ----              ------ ------- ----     ------
    Lab18-Metrics-In   Allow    True 9100/TCP 10.18.0.50
    Lab18-Debug-Block  Block    True 8080/TCP Any

    2026-11-15 22:31:07 DROP TCP 10.18.0.100 10.18.0.60 50412 8080 52 S 1830291022 0 64240 - - - RECEIVE

    What if: Performing operation "Delete" on Target "Lab18 metrics from monitoring".
    What if: Performing operation "Delete" on Target "Lab18 debug console blocked".
    Ok.
    412 rules before, 412 rules after
    ```

    The import restores the exported profile settings as well, so `LogBlocked` returns to its value from step 7.1; compare it with `C:\Lab18\profiles-before.csv`.

??? success "Answers to questions"
    1. The database (5432) and the debug console (8080): both give data or control to anyone on the network. Binding the database to 127.0.0.1 fixes that one service, but the host firewall is the **policy** that protects against the next service someone installs, against mistakes in application configuration, and limits lateral movement — defence in depth.
    2. With default deny active and no SSH rule, every **new** connection to 22 is dropped. The existing session survives because its packets match the `ESTABLISHED,RELATED` rule in `ufw-before-input`, so it would look fine until you log out — only a **new** connection tests the rule.
    3. 8080 has a `reject` rule (TCP RST → *refused*); 5432 has no rule and falls through to the default **drop** policy (no answer → *filtered*/timeout). Reject is better for an internal service that people might try by mistake (fast, clear failure); drop is better for everything else, especially towards untrusted networks (no information, no reply traffic).
    4. Rule 3 (`9100/tcp ALLOW IN 10.18.0.50`) was shadowed by rule 2 (`9100/tcp ALLOW IN Anywhere`): rule 2 had 3 packets (one per client), rule 3 had 0 — every 9100 packet matched rule 2 first.
    5. The web service uses **TCP**; a UDP 443 rule never matches a TCP SYN, and the default policy dropped it. `ufw status` showed `443/udp` — the `/udp` suffix is the clue. (HTTP/3 does use UDP 443, but only in addition to TCP.)
    6. Deleting rule *N* renumbers every rule after it. Deleting from the highest number down keeps the lower numbers valid; and re-checking `status numbered` after each delete avoids deleting the wrong rule.
    7. It counts every **packet** that reached the end of the chain (and was then dropped by the policy). A dropped SYN gets no answer, so the client retransmits it after about one second; with `nc -w 2` each attempt sends two SYNs.
    8. Windows `Block` silently drops (the client times out — there is no reject action), and it wins over any Allow rule regardless of order, whereas ufw `reject` sends a TCP RST and its effect depends on its position in the list.
    9. `import` replaces the whole local (persistent store) policy with the file's content: rules created after the export disappear, and settings return to their exported values. Group Policy rules are not affected. Export again before every change, so the newest known-good state is the one you restore.
    10. The before/after test matrices (`matrix-before.txt`, `matrix-after.txt`) with the date and the client addresses; the rule listing (`ufw status numbered` / `ufw show added` or the nft file) with comments referring to CHG-1818; and the backups/rollback evidence (`iptables-before.rules`, `etc-ufw-*.tgz`, the cancelled rollback) — optionally the `[UFW BLOCK]` summary showing that denied traffic is logged.
