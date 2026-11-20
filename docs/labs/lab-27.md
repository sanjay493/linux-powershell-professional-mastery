---
description: "Work five realistic network tickets on an isolated four-namespace lab network: prove packet loss and congestion with curl phase timings, ss -ti, a two-point capture and TShark statistics; find a stale hosts entry that overrides correct DNS; prove a missing return route; diagnose a TLS name mismatch; locate a forgotten firewall drop; fix the faults with backups, verify, package the evidence with hashes and write findings. A Windows part classifies failures with Test-NetConnection, curl.exe, Resolve-DnsName and pktmon."
---

# Lab 27: Five Tickets, One Network

| Field | Value |
|---|---|
| **Lab ID** | LAB-27 |
| **Related lesson** | [Day 27: Network Investigation](../course/module-6/day-27.md) |
| **Difficulty** | Advanced |
| **Time** | 2–2.5 hours (Linux 100–120 min, Windows 20–30 min) |
| **Risk level** | Low. Everything runs inside **isolated network namespaces** on a disposable Ubuntu 24.04 VM: no real interface, host or network is touched, scanned or captured. The setup script changes nothing outside the namespaces except creating `/srv/lab27` and `/etc/netns/lab27-cli/`; the clean-up script removes both. The Windows part only uses `127.0.0.1`, a reserved documentation address (`192.0.2.1`) and, optionally, a capture of your own traffic to your own lab VM. |

## Objective

You are the on-call network analyst for a small company network. Five tickets are waiting:

| Ticket | Reported by | Text |
|---|---|---|
| **T1** | Staff | "The intranet `www.corp.lab` is slow. Downloads crawl and pages sometimes hang for a second." |
| **T2** | One user (cli01) | "`api.corp.lab:8080` is down for me. The API team says it's up." |
| **T3** | Backup team | "We can't reach `bak01` (10.27.3.30) from the office network, but the server is running." |
| **T4** | Staff | "`https://secure.corp.lab` gives a certificate error since the migration." |
| **T5** | Monitoring | "Can't scrape `metrics.corp.lab:9100` since last night." |

For each ticket: classify the failure by its signature, find the root cause, prove it with evidence, fix it in the lab (with backups), verify the fix from the client, and write a short finding. You are authorised to investigate and change every device in this lab network — and nothing else.

## Required Environment

- **Linux:** a disposable **Ubuntu 24.04 LTS VM** (or WSL2 with root) with `sudo`. Network namespaces need root; do not use a production machine.
- Packages: `sudo apt install iproute2 nftables ethtool dnsmasq-base python3 openssl tcpdump tshark nmap dnsutils traceroute curl netcat-openbsd`. When `tshark` asks whether non-superusers may capture, answer **No** (you will capture with `tcpdump` as root and analyse files as yourself).
- About 50 MB of disk space in `/srv`.
- **Windows (part 2):** Windows 11 or Windows Server 2022, Windows PowerShell 5.1 and/or PowerShell 7, `curl.exe` (built in since Windows 10 1803). An elevated session only for the optional `pktmon` task.

## Initial Conditions

- No `lab27-*` namespaces exist: `ip netns list | grep lab27` prints nothing.
- `/srv/lab27` and `/etc/netns/lab27-cli` do not exist.
- No other process on the VM listens on the lab addresses (they are private to the namespaces, so conflicts are unlikely).
- You run every lab command with `sudo ip netns exec lab27-<host> <command>`. To save typing, define these helpers in your shell first:

    ```bash
    cli() { sudo ip netns exec lab27-cli "$@"; }
    rtr() { sudo ip netns exec lab27-rtr "$@"; }
    srv() { sudo ip netns exec lab27-srv "$@"; }
    bak() { sudo ip netns exec lab27-bak "$@"; }
    ```

!!! note "Proxy variables"
    If your VM has `http_proxy`/`https_proxy` set, `curl` inside the namespaces may try to use a proxy it cannot reach. Run `cli env | grep -i proxy`; if anything is set, use `cli env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY curl ...` or `curl --noproxy '*'`.

## Setup script (Linux)

Save as `lab27-setup.sh` and run `sudo bash lab27-setup.sh`. **Read it first** — but try not to memorise the fault list: the lab is more useful if you find each fault from the evidence.

```bash
#!/usr/bin/env bash
# lab27-setup.sh - build an ISOLATED four-namespace network with five injected faults.
# Nothing here touches a real interface: the namespaces have no uplink.
set -o errexit -o nounset -o pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
for t in ip tc nft ethtool dnsmasq python3 openssl; do
    command -v "$t" >/dev/null || { echo "Missing: $t (see Required Environment)" >&2; exit 1; }
done
ip netns list | grep -q '^lab27-' && { echo "Already set up. Run lab27-cleanup.sh first." >&2; exit 1; }
LAB=/srv/lab27 ; mkdir -p "$LAB/www" "$LAB/tls" "$LAB/pids"

# --- namespaces and links ---------------------------------------------------
for ns in cli rtr srv bak; do ip netns add "lab27-$ns"; ip -n "lab27-$ns" link set lo up; done
ip link add c0 netns lab27-cli type veth peer name r1 netns lab27-rtr
ip link add s0 netns lab27-srv type veth peer name r2 netns lab27-rtr
ip link add b0 netns lab27-bak type veth peer name r3 netns lab27-rtr
ip -n lab27-cli addr add 10.27.1.10/24 dev c0
ip -n lab27-rtr addr add 10.27.1.1/24  dev r1
ip -n lab27-rtr addr add 10.27.2.1/24  dev r2
ip -n lab27-rtr addr add 10.27.3.1/24  dev r3
ip -n lab27-srv addr add 10.27.2.20/24 dev s0
ip -n lab27-srv addr add 10.27.2.53/24 dev s0
ip -n lab27-bak addr add 10.27.3.30/24 dev b0
for pair in cli:c0 rtr:r1 rtr:r2 rtr:r3 srv:s0 bak:b0; do
    ip -n "lab27-${pair%:*}" link set "${pair#*:}" up
done
ip netns exec lab27-rtr sysctl -qw net.ipv4.ip_forward=1
ip -n lab27-cli route add default via 10.27.1.1
ip -n lab27-srv route add default via 10.27.2.1
# FAULT 3 (routing): bak01 gets NO default route - the return path is missing.

# --- name resolution for the client ------------------------------------------
# ip netns exec bind-mounts /etc/netns/<ns>/* over /etc/* for commands it runs.
mkdir -p /etc/netns/lab27-cli
printf 'nameserver 10.27.2.53\nsearch corp.lab\n' > /etc/netns/lab27-cli/resolv.conf
# FAULT 2 (name resolution): a stale hosts entry left over from a migration.
printf '127.0.0.1 localhost\n10.27.1.10 cli01.corp.lab cli01\n10.27.2.21 api.corp.lab api   # old API server (migrated 2026-10)\n' \
    > /etc/netns/lab27-cli/hosts
ip netns exec lab27-srv dnsmasq --no-resolv --no-hosts --bind-interfaces \
    --listen-address=10.27.2.53 --except-interface=lo --local=/corp.lab/ --local-ttl=300 \
    --host-record=www.corp.lab,10.27.2.20 --host-record=api.corp.lab,10.27.2.20 \
    --host-record=secure.corp.lab,10.27.2.20 --host-record=metrics.corp.lab,10.27.2.20 \
    --host-record=bak01.corp.lab,10.27.3.30 --host-record=cli01.corp.lab,10.27.1.10 \
    --log-queries --log-facility="$LAB/dnsmasq.log" --pid-file="$LAB/pids/dnsmasq.pid"

# --- services on srv01 (10.27.2.20) and bak01 (10.27.3.30) -------------------
printf '<html><body><h1>Corp intranet</h1></body></html>\n' > "$LAB/www/index.html"
head -c 2000000 /dev/zero | tr '\0' 'x' > "$LAB/www/report.bin"   # 2 MB download
start() {  # start <ns> <pidname> <command...>
    local ns=$1 name=$2 ; shift 2
    ip netns exec "lab27-$ns" nohup "$@" >"$LAB/$name.log" 2>&1 &
    echo $! > "$LAB/pids/$name.pid"
}
start srv www     python3 -m http.server 80   --bind 10.27.2.20 --directory "$LAB/www"
start srv api     python3 -m http.server 8080 --bind 10.27.2.20 --directory "$LAB/www"
start srv metrics python3 -m http.server 9100 --bind 10.27.2.20 --directory "$LAB/www"
start bak backup  python3 -m http.server 8000 --bind 10.27.3.30 --directory "$LAB/www"
# port 9200 on srv01 is deliberately CLOSED (nothing listens).

# FAULT 4 (TLS): a lab CA, and a server certificate issued for the OLD name only.
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=Lab27 Root CA" \
    -keyout "$LAB/tls/ca.key" -out "$LAB/tls/ca.crt" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj "/CN=legacy.corp.lab" \
    -keyout "$LAB/tls/srv.key" -out "$LAB/tls/srv.csr" 2>/dev/null
printf 'subjectAltName=DNS:legacy.corp.lab\n' > "$LAB/tls/san.ext"
openssl x509 -req -in "$LAB/tls/srv.csr" -CA "$LAB/tls/ca.crt" -CAkey "$LAB/tls/ca.key" \
    -CAcreateserial -days 30 -extfile "$LAB/tls/san.ext" -out "$LAB/tls/srv.crt" 2>/dev/null
cat > "$LAB/tls/https.py" <<'PY'
import http.server, ssl, sys
d = sys.argv[1]
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(d + "/tls/srv.crt", d + "/tls/srv.key")
h = lambda *a, **k: http.server.SimpleHTTPRequestHandler(*a, directory=d + "/www", **k)
s = http.server.HTTPServer(("10.27.2.20", 443), h)
s.socket = ctx.wrap_socket(s.socket, server_side=True)
s.serve_forever()
PY
start srv https python3 "$LAB/tls/https.py" "$LAB"

# FAULT 5 (firewall): the router silently DROPS new connections to srv01:9100.
ip netns exec lab27-rtr nft -f - <<'NFT'
table inet lab27 {
    chain forward {
        type filter hook forward priority filter; policy accept;
        ip daddr 10.27.2.20 tcp dport 9100 counter drop comment "CHG-4471 temp block"
    }
}
NFT

# FAULT 1 (performance): the router link towards cli01 is congested (4 Mbit/s for web
# replies) and drops 8 % of srv01's port-80 packets - a stand-in for a faulty link.
ip netns exec lab27-rtr ethtool -K r2 gro off >/dev/null      # one decision per real packet
ip netns exec lab27-rtr ethtool -K r1 tso off gso off >/dev/null
ip netns exec lab27-rtr nft add rule inet lab27 forward ip saddr 10.27.2.20 tcp sport 80 \
    numgen random mod 100 '<' 8 counter drop comment '"simulated faulty link"'
ip netns exec lab27-rtr tc qdisc add dev r1 root handle 1: htb default 10 2>/dev/null
ip netns exec lab27-rtr tc class add dev r1 parent 1: classid 1:10 htb rate 1gbit quantum 1514
ip netns exec lab27-rtr tc class add dev r1 parent 1: classid 1:30 htb rate 4mbit ceil 4mbit
ip netns exec lab27-rtr tc filter add dev r1 parent 1: protocol ip prio 1 u32 \
    match ip sport 80 0xffff flowid 1:30

# --- helpers for the investigation ----------------------------------------------
cat > "$LAB/curl-format.txt" <<'FMT'
dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total} code=%{http_code} size=%{size_download} speed=%{speed_download}\n
FMT
cat > "$LAB/lab27-triage.sh" <<'TRIAGE'
#!/usr/bin/env bash
# lab27-triage.sh - one line per service: name, resolved address, TCP connect, HTTP result, timings.
# Run inside the client namespace: sudo ip netns exec lab27-cli bash /srv/lab27/lab27-triage.sh
set -o nounset -o pipefail
ca=/srv/lab27/tls/ca.crt          # the corp CA, as deployed to company clients
printf '%-26s %-12s %-10s %s\n' TARGET ADDRESS TCP RESULT
while read -r name port scheme; do
    addr=$(getent ahostsv4 "$name" | awk 'NR==1 {print $1}')
    if timeout 3 bash -c "exec 3<>/dev/tcp/$addr/$port" 2>/dev/null; then tcp=open
    else rc=$?; [ "$rc" -eq 124 ] && tcp=timeout || tcp=refused/unreach; fi
    result=$(curl -s -o /dev/null -m 6 --cacert "$ca" -w '%{http_code} connect=%{time_connect}s total=%{time_total}s' \
             "$scheme://$name:$port/" 2>&1); rc=$?
    printf '%-26s %-12s %-10s %s (curl exit %s)\n' "$name:$port" "${addr:-NXDOMAIN}" "$tcp" "$result" "$rc"
done <<'LIST'
www.corp.lab 80 http
api.corp.lab 8080 http
secure.corp.lab 443 https
metrics.corp.lab 9100 http
bak01.corp.lab 8000 http
LIST
TRIAGE
mkdir -p "$LAB/evidence" "$LAB/backup"

# wait (max 10 s) until srv01's five TCP listeners (53, 80, 443, 8080, 9100) are up
for _ in $(seq 1 20); do
    [ "$(ip netns exec lab27-srv ss -Hltn | wc -l)" -ge 5 ] && break
    sleep 0.5
done
echo "Lab 27 ready: cli01 10.27.1.10 | rtr01 10.27.1.1/10.27.2.1/10.27.3.1 | srv01 10.27.2.20 (+DNS .53) | bak01 10.27.3.30"
echo "Work from the client:  sudo ip netns exec lab27-cli <command>"
```

Expected output:

```text
Lab 27 ready: cli01 10.27.1.10 | rtr01 10.27.1.1/10.27.2.1/10.27.3.1 | srv01 10.27.2.20 (+DNS .53) | bak01 10.27.3.30
Work from the client:  sudo ip netns exec lab27-cli <command>
```

## Clean-up script (Linux)

Save as `lab27-cleanup.sh` and run `sudo bash lab27-cleanup.sh` when you have finished (or to start again).

```bash
#!/usr/bin/env bash
# lab27-cleanup.sh - remove everything lab27-setup.sh created.
set -o nounset -o pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
for f in /srv/lab27/pids/*.pid; do
    [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null
done
for ns in cli rtr srv bak; do ip netns del "lab27-$ns" 2>/dev/null; done
rm -rf /etc/netns/lab27-cli /srv/lab27
ip netns list | grep '^lab27-' || echo "Lab 27 removed."
```

## Step-by-Step Instructions

### Task 1 — First look (10 min)

1. Confirm the four namespaces exist and look at the client's view of the network: `ip netns list`, `cli ip -br addr`, `cli ip route`, `cli cat /etc/resolv.conf`.
2. Run the triage script from the client: `cli bash /srv/lab27/lab27-triage.sh`. Save the output as `/srv/lab27/evidence/triage-before.txt`.
3. For every line, write the **signature** (open/works, refused, no route to host, timed out, TLS error) and your first hypothesis, using the table in the lesson. Do not change anything yet.

### Task 2 — T1: "the intranet is slow" (25 min)

1. Run `curl` with the phase format (`-w @/srv/lab27/curl-format.txt`) ten times for `http://www.corp.lab/` and three times for `http://www.corp.lab/report.bin`. Which phase is slow, and how often?
2. Download the same file from the same server on port **8080**. What does the comparison rule out?
3. While a port-80 download runs, read `ss -tin 'sport = :80'` **on srv01**. Record `rtt`, `minrtt`, `retrans`, `bytes_retrans` and `bytes_sent`.
4. Take a **two-point capture** of SYN/SYN-ACK packets (client `c0`, server `s0`) while you repeat small requests until one connect takes about 1 s. Show, for that connection, where the missing packet was last seen.
5. Capture one full download at the client with `-s 128` and summarise it with TShark: `-z io,stat,1` for retransmissions and duplicate ACKs, `-z expert,warn`, and the number of *Previous segment not captured* events.
6. Look at the device between the two capture points: rtr01's nftables counters and `tc -s class show dev r1`. Name the root cause.

### Task 3 — T2: "the API is down for me" (15 min)

1. Run `curl -sv` against `http://api.corp.lab:8080/`. Which address does curl try, and what error comes back?
2. Compare `dig api.corp.lab` with `getent hosts api.corp.lab`. Explain the difference using `/etc/nsswitch.conf`.
3. Prove the real API works with `curl --resolve`.
4. Optional: read `/srv/lab27/dnsmasq.log` — did the DNS server ever receive a query for `api.corp.lab` from your failing tests?
5. Capture the failing connection at the client and explain the ICMP message you see, and check rtr01's neighbour table for `10.27.2.21`.

### Task 4 — T3: "bak01 is unreachable" (15 min)

1. Ping and traceroute bak01 from the client. Where does the traceroute stop?
2. Capture ICMP on **bak01** (`bak tcpdump -ni b0 icmp`) while the client pings. What arrives, and what leaves?
3. On bak01, run `ip route` and `ip route get 10.27.1.10`, and read `nstat -az IpOutNoRoutes`.
4. Explain why rtr01 can ping bak01 even though the client cannot.

### Task 5 — T4: "certificate error since the migration" (15 min)

1. Run `curl` against `https://secure.corp.lab/` without and with `--cacert /srv/lab27/tls/ca.crt`. Record both errors.
2. Read the certificate the server presents with `openssl s_client … | openssl x509 -noout -subject -issuer -dates -ext subjectAltName` and with `nmap --script ssl-cert`.
3. Capture one handshake and list what TShark can see in clear text (SNI, versions) and what it cannot.
4. State the correct fix, and why `curl -k` is not one.

### Task 6 — T5: "can't scrape metrics:9100" (15 min)

1. From the client run `nmap -sT -Pn -n --reason -p 80,443,8080,9100,9200 10.27.2.20`. Compare 9100 with 9200.
2. Compare `traceroute -T -p 9100` with `traceroute -T -p 80`.
3. Prove the service on srv01 is healthy from srv01 itself.
4. Capture on rtr01 (`-i any`) while the client retries. On which interface do the SYNs appear, and on which do they not?
5. Read rtr01's firewall with counters. Run one more test and show the counter increase. What does the rule's comment tell you?

### Task 7 — Fix and verify (15 min)

The change owners have approved the following in the lab (in production each would go through change control):

1. **T2:** back up the client's hosts file to `/srv/lab27/backup/`, preview the stale line, delete it, show the `diff`, and verify with `getent`.
2. **T3:** add the missing default route on bak01 (runtime only in the lab; in production the fix belongs in the persistent network configuration — netplan on Ubuntu).
3. **T5:** save rtr01's ruleset to `/srv/lab27/backup/`, find the rule's handle with `nft -a`, and delete only that rule.
4. **T1:** the "faulty link" has been replaced: delete the loss rule and the shaper on rtr01.
5. **T4 (stretch):** issue a new certificate from the lab CA whose SANs include `secure.corp.lab` and `legacy.corp.lab`, and restart the HTTPS service.
6. Re-run the triage script, save it as `evidence/triage-after.txt`, and re-run the phase timings for T1.

### Task 8 — Evidence and findings (10 min)

1. Put your captures in `/srv/lab27/evidence/`, run `capinfos` and `sha256sum` on them and save the hashes as `evidence/SHA256SUMS`.
2. Write one paragraph per ticket in `/srv/lab27/evidence/findings.md`: symptom in numbers, root cause, evidence (with file names), fix, verification.
3. Copy anything you want to keep out of `/srv/lab27`, then run the clean-up script.

### Windows part — classify failures without a capture first (20–30 min)

1. Start a tiny local HTTP responder on `127.0.0.1:18080` as a background job (see the solution), then test `127.0.0.1:18080` (open), `127.0.0.1:18081` (nothing listening) and `192.0.2.1:80` (a reserved documentation address that nobody answers) with `Test-NetConnection` inside `Measure-Command`. Which results can you tell apart by `TcpTestSucceeded` alone, and which only by time?
2. Repeat with `curl.exe -s -o NUL -m 5 -w "%{http_code} connect=%{time_connect}\n"` and record the curl exit code (`$LASTEXITCODE`) for each.
3. Compare `Resolve-DnsName localhost`, `Resolve-DnsName localhost -NoHostsFile` and `[System.Net.Dns]::GetHostAddresses('localhost')`, and read (do not edit) your hosts file with `Get-Content`.
4. Show your TCP template values with `Get-NetTCPSetting` and note `InitialRtoMs`.
5. **Optional, elevated:** capture your own `curl.exe` request to a service on **your** lab VM with `pktmon` (filter on that port), convert it with `pktmon etl2pcap`, and hash it with `Get-FileHash`.
6. Stop and remove the background job.

## Commands to Execute

Try each task yourself first; the full command sequence and the fixes are in the [Solution](#solution). The lesson's [Demonstrations](../course/module-6/day-27.md#practical-demonstrations) show the same techniques with captured output from this network.

## Expected Results

- **Task 1:** www `open` and `200`; api resolves to **10.27.2.21** and fails with curl exit 7; secure `open` but curl exit 60; metrics and bak01 time out (exit 28) after the 6-second limit.
- **Task 2:** some small-page requests show `connect=` of about **1.0 s** (sometimes 3.0 s); `report.bin` takes about **4 s** (≈ 0.5 MB/s) on port 80 and a few milliseconds on port 8080; `ss -ti` on srv01 shows `rtt` in the hundreds of ms against a `minrtt` near 0.02 ms, non-zero `retrans` and `bytes_retrans` of several percent of `bytes_sent`; the two-point capture shows a SYN-ACK in the server file that never appears in the client file; TShark shows dozens of retransmissions and *Previous segment not captured* events; rtr01's `simulated faulty link` counter and the `1:30` class's `overlimits` increase.
- **Task 3:** curl tries `10.27.2.21` and reports *No route to host* (or fails fast if rtr01 still remembers the failed neighbour); `dig` returns 10.27.2.20 (TTL 300); `getent` returns 10.27.2.21 from the hosts file; `--resolve … 10.27.2.20` returns `200`; the capture shows SYNs and ICMP *Host unreachable* from 10.27.1.1; `ip neigh` on rtr01 shows `10.27.2.21 … INCOMPLETE` or `FAILED`.
- **Task 4:** ping 100 % loss; traceroute shows `10.27.1.1` then `*`; bak01's capture shows echo **requests** only; `ip route get 10.27.1.10` on bak01 prints `RTNETLINK answers: Network is unreachable`; `IpOutNoRoutes` is non-zero and grows.
- **Task 5:** exit 60 *unable to get local issuer certificate* without the CA; exit 60 *no alternative certificate subject name matches target host name 'secure.corp.lab'* with it; the certificate names only `legacy.corp.lab`, issued by `Lab27 Root CA`, valid 30 days; the capture shows `Client Hello (SNI=secure.corp.lab)` and TLS 1.3 records, but no readable certificate.
- **Task 6:** `9100/tcp filtered … no-response`, `9200/tcp closed … conn-refused`; the TCP traceroute to 9100 stops after hop 1, to 80 it reaches 10.27.2.20; srv01 returns `200` locally; SYNs appear `In` on `r1` and never on `r2`; the `CHG-4471 temp block` counter increases with each test.
- **Task 7:** after the fixes every triage line shows `open` and `200`, small-page connects stay well under 10 ms and `report.bin` downloads in milliseconds on port 80.
- **Windows part:** 18080 `True` in milliseconds; 18081 `False` quickly; 192.0.2.1 `False` after many seconds; curl exit codes 0, 7 and 28 respectively.

## Verification Steps

=== "Linux"

    ```bash
    cli bash /srv/lab27/lab27-triage.sh | tee /srv/lab27/evidence/triage-after.txt
    # every service: open + 200
    test "$(grep -c ' 200 ' /srv/lab27/evidence/triage-after.txt)" -eq 5 && echo "T1-T5 fixed"
    cli getent hosts api.corp.lab                      # 10.27.2.20
    bak ip route get 10.27.1.10                        # via 10.27.3.1
    rtr nft list table inet lab27                      # no CHG-4471 rule, no loss rule
    for i in 1 2 3; do cli curl -s -o /dev/null -w @/srv/lab27/curl-format.txt http://www.corp.lab/report.bin; done
    ls /srv/lab27/backup/                              # hosts and ruleset backups exist
    cat /srv/lab27/evidence/SHA256SUMS
    ```

=== "Windows"

    ```powershell
    Get-Job -Name lab27-http -ErrorAction SilentlyContinue      # nothing after clean-up
    (Get-NetTCPConnection -LocalPort 18080 -State Listen -ErrorAction SilentlyContinue) -eq $null   # True
    Get-Content $HOME\lab27\windows-results.csv
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Already set up. Run lab27-cleanup.sh first.` | Namespaces from an earlier run | `sudo bash lab27-cleanup.sh`, then run the setup again |
| `Missing: ethtool` (or another tool) | Package not installed | Install the packages from Required Environment |
| `Error: Specified qdisc kind is unknown.` | Kernel without the `sch_htb` module (rare on Ubuntu) | `sudo modprobe sch_htb`; T1 still has the loss rule if shaping is unavailable |
| Every triage line fails right after setup | Services still starting | Wait a few seconds; `srv ss -ltn` should list 53, 80, 443, 8080 and 9100 |
| `Bind /etc/netns/lab27-cli/<file> -> /etc/<file> failed` | Extra files (for example a backup) placed in `/etc/netns/lab27-cli/` — `ip netns exec` bind-mounts every file there | Keep backups in `/srv/lab27/backup/`, not in `/etc/netns/…` |
| `curl` inside the namespace tries a proxy | Proxy environment variables | See the note in Initial Conditions |
| You never see a 1-second connect in Task 2 | Random loss: 8 % per packet | Repeat 20–30 times; check that the `faulty link` counter grows |
| T1 looks fixed but downloads are still slow | Only one of the two T1 faults removed | Remove both the loss rule and the `tc` qdisc on `r1` |
| `nft delete rule` fails with *Could not process rule* | Wrong handle | List with `rtr nft -a list chain inet lab27 forward` and copy the handle number |
| HTTPS service not listening after the T4 fix | Restarted too quickly, or wrong path | `cat /srv/lab27/https.log`; wait until `srv ss -ltn 'sport = :443'` shows LISTEN |
| Windows: `Start-Job` responder never answers | Port in use or job failed | `Receive-Job -Name lab27-http`; choose another port in both places |

## Questions

1. Which two pieces of evidence together prove that the T1 problem is on the path and not on srv01's application?
2. Why did the two-point capture locate the loss more precisely than the client capture alone?
3. In T2, why did the DNS server's log show no query for `api.corp.lab` from the failing tests?
4. What did *No route to host* mean in T2, and why was it not a routing-table problem on the client?
5. In T3, why does the traceroute make it *look* as if rtr01 is the problem?
6. List both T4 problems in the order a client meets them, and the fix for each.
7. What is the difference between the nmap results for 9100 and 9200, and which device produced each result?
8. Why should the CHG-4471 rule be removed by (or with) its change owner rather than by the analyst who found it?
9. Which Windows results in the Windows part could not be told apart by `TcpTestSucceeded`, and how did you separate them?
10. Name three things you did during this lab that make your findings verifiable by someone else.

## Solution

??? success "Bash solution"
    Run these after the setup script and the helper functions from Initial Conditions. Output values (timings, ports, counters) differ on every run; the lesson's [Demonstrations](../course/module-6/day-27.md#practical-demonstrations) show captured examples from this network.

    **Task 1 — first look**

    ```bash
    ip netns list
    cli ip -br addr ; cli ip route ; cli cat /etc/resolv.conf
    cli bash /srv/lab27/lab27-triage.sh | sudo tee /srv/lab27/evidence/triage-before.txt
    ```

    **Task 2 — T1 slow intranet**

    ```bash
    F=@/srv/lab27/curl-format.txt
    for i in $(seq 1 10); do cli curl -s -m 10 -o /dev/null -w "$F" http://www.corp.lab/; done
    for i in 1 2 3; do cli curl -s -o /dev/null -w "$F" http://www.corp.lab/report.bin; done
    cli curl -s -o /dev/null -w "$F" http://www.corp.lab:8080/report.bin       # same server, other port

    # sender-side TCP state during a port-80 download
    cli curl -s -o /dev/null http://www.corp.lab/report.bin &
    sleep 2 ; srv ss -tin 'sport = :80' ; wait
    srv nstat -az TcpRetransSegs TcpExtTCPSynRetrans

    # two-point capture of handshakes; repeat requests until one connect takes ~1 s
    E=/srv/lab27/evidence
    cli tcpdump -ni c0 -w $E/t1-syn-cli.pcap 'tcp port 80 and tcp[tcpflags] & tcp-syn != 0' 2>/dev/null &
    srv tcpdump -ni s0 -w $E/t1-syn-srv.pcap 'tcp port 80 and tcp[tcpflags] & tcp-syn != 0' 2>/dev/null &
    sleep 1
    for i in $(seq 1 40); do
        o=$(cli curl -s -o /dev/null -w '%{local_port} %{time_connect}' http://www.corp.lab/)
        case ${o#* } in 1.*|3.*) echo "slow connect: $o"; break ;; esac
    done
    sleep 1 ; sudo pkill -INT -f 'tcpdump -ni (c0|s0) -w /srv/lab27/evidence/t1-syn' ; wait
    P=${o% *}
    tshark -n -r $E/t1-syn-cli.pcap -Y "tcp.port==$P"
    tshark -n -r $E/t1-syn-srv.pcap -Y "tcp.port==$P"

    # one full download, header-only capture at the client
    cli tcpdump -ni c0 -s 128 -w $E/t1-download.pcap 'tcp port 80' 2>/dev/null &
    sleep 1 ; cli curl -s -o /dev/null http://www.corp.lab/report.bin ; sleep 1
    sudo pkill -INT -f 'tcpdump -ni c0 -s 128' ; wait
    T="tshark -n -r $E/t1-download.pcap"
    $T -q -z 'io,stat,1,COUNT(tcp.analysis.retransmission)tcp.analysis.retransmission,COUNT(tcp.analysis.duplicate_ack)tcp.analysis.duplicate_ack'
    $T -q -z expert,warn
    $T -Y tcp.analysis.lost_segment | wc -l

    # the device between the capture points
    rtr nft list table inet lab27
    rtr tc -s class show dev r1
    ```

    Root cause: rtr01 drops about 8 % of srv01's port-80 packets (`simulated faulty link`) and shapes web replies to 4 Mbit/s (class `1:30`), so the queue adds hundreds of milliseconds and lost SYN-ACKs cost a full second. Port 8080 bypasses both.

    **Task 3 — T2 API "down"**

    ```bash
    cli curl -sv -m 6 http://api.corp.lab:8080/ 2>&1 | head -6
    cli dig api.corp.lab +noall +answer
    cli getent hosts api.corp.lab
    grep ^hosts /etc/nsswitch.conf
    cli cat /etc/hosts
    cli curl -sS -m 4 --resolve api.corp.lab:8080:10.27.2.20 -o /dev/null -w '%{http_code} %{remote_ip}\n' http://api.corp.lab:8080/
    sudo grep 'query\[A\]' /srv/lab27/dnsmasq.log | awk '{print $6}' | sort | uniq -c
    cli timeout 6 tcpdump -ni c0 'host 10.27.2.21 or icmp' 2>/dev/null &
    sleep 1 ; cli curl -s -m 5 -o /dev/null http://api.corp.lab:8080/ ; wait
    rtr ip neigh show 10.27.2.21
    ```

    Root cause: `/etc/hosts` (bind-mounted from `/etc/netns/lab27-cli/hosts`) still maps `api.corp.lab` to the old server 10.27.2.21; NSS reads `files` before `dns`. The address is unused, so rtr01's ARP fails and it returns ICMP *Host unreachable*.

    **Task 4 — T3 bak01 unreachable**

    ```bash
    cli ping -c 2 -W 1 10.27.3.30
    cli traceroute -n -w 1 -q 1 -m 4 10.27.3.30
    bak timeout 5 tcpdump -ni b0 -c 6 icmp &
    sleep 1 ; cli ping -c 3 -W 1 10.27.3.30 >/dev/null ; wait
    bak ip route
    bak ip route get 10.27.1.10
    bak nstat -az IpOutNoRoutes
    rtr ping -c 2 -W 1 10.27.3.30
    ```

    Root cause: bak01 has only its connected route; it cannot reply to anything outside 10.27.3.0/24. rtr01 succeeds because it is on that subnet.

    **Task 5 — T4 certificate error**

    ```bash
    cli curl -sS -m 5 -o /dev/null https://secure.corp.lab/ ; echo "exit=$?"
    cli curl -sS -m 5 -o /dev/null --cacert /srv/lab27/tls/ca.crt https://secure.corp.lab/ ; echo "exit=$?"
    echo | cli openssl s_client -connect 10.27.2.20:443 -servername secure.corp.lab 2>/dev/null |
        openssl x509 -noout -subject -issuer -dates -ext subjectAltName
    cli nmap -Pn -n -p 443 --script ssl-cert 10.27.2.20
    cli tcpdump -ni c0 -w /srv/lab27/evidence/t4-tls.pcap 'tcp port 443' 2>/dev/null &
    sleep 1 ; cli curl -s -m 3 --cacert /srv/lab27/tls/ca.crt -o /dev/null https://secure.corp.lab/ ; sleep 1
    sudo pkill -INT -f 'tcpdump -ni c0 -w /srv/lab27/evidence/t4-tls' ; wait
    tshark -n -r /srv/lab27/evidence/t4-tls.pcap -Y tls
    ```

    Root cause: (1) clients that do not trust the corp CA reject the issuer; (2) clients that do trust it reject the **name** — the certificate's only SAN is `legacy.corp.lab`. Fix: issue a certificate with SANs `secure.corp.lab` (and `legacy.corp.lab` while it is still used) and deploy the corp CA to clients. `curl -k` would accept any certificate, including an attacker's.

    **Task 6 — T5 metrics port**

    ```bash
    cli nmap -sT -Pn -n --reason -p 80,443,8080,9100,9200 10.27.2.20
    cli traceroute -n -T -p 9100 -q 1 -w 1 -m 4 10.27.2.20
    cli traceroute -n -T -p 80   -q 1 -w 1 -m 4 10.27.2.20
    srv ss -ltnp 'sport = :9100'
    srv curl -s -o /dev/null -w '%{http_code}\n' http://10.27.2.20:9100/
    rtr timeout 6 tcpdump -ni any -c 10 'tcp port 9100' &
    sleep 1 ; cli curl -s -m 3 -o /dev/null http://10.27.2.20:9100/ ; wait
    rtr nft list table inet lab27 | grep CHG-4471
    cli nc -zv -w 2 10.27.2.20 9100
    rtr nft list table inet lab27 | grep CHG-4471      # counter increased
    ```

    Root cause: rtr01's forward chain has `ip daddr 10.27.2.20 tcp dport 9100 counter drop comment "CHG-4471 temp block"`, a temporary rule that was never removed.

    **Task 7 — fixes (with backups) and verification**

    ```bash
    B=/srv/lab27/backup ; D=$(date +%F)
    # T2: hosts file - back up, preview, delete, compare, verify
    sudo cp -a /etc/netns/lab27-cli/hosts "$B/cli-hosts.$D"
    sudo grep -n '^10\.27\.2\.21[[:space:]]' /etc/netns/lab27-cli/hosts
    sudo sed -i '/^10\.27\.2\.21[[:space:]]/d' /etc/netns/lab27-cli/hosts
    sudo diff "$B/cli-hosts.$D" /etc/netns/lab27-cli/hosts
    cli getent hosts api.corp.lab

    # T3: return route on bak01 (runtime; persistent config would be netplan)
    sudo ip -n lab27-bak route add default via 10.27.3.1
    bak ip route get 10.27.1.10

    # T5 and T1: save the ruleset, then delete the two rules by handle, and remove the shaper
    rtr nft list ruleset | sudo tee "$B/rtr-ruleset.$D.nft" >/dev/null
    rtr nft -a list chain inet lab27 forward
    for pattern in 'CHG-4471' 'faulty link'; do
        h=$(rtr nft -a list chain inet lab27 forward | awk -v p="$pattern" 'index($0, p) {print $NF}')
        [ -n "$h" ] && rtr nft delete rule inet lab27 forward handle "$h"
    done
    rtr tc qdisc del dev r1 root
    rtr nft list table inet lab27

    # T4 (stretch): new certificate with the right SANs from the lab CA, then restart HTTPS
    cd /srv/lab27/tls || exit 1
    printf 'subjectAltName=DNS:secure.corp.lab,DNS:legacy.corp.lab\n' | sudo tee san2.ext >/dev/null
    sudo openssl req -newkey rsa:2048 -nodes -subj "/CN=secure.corp.lab" -keyout srv.key -out srv.csr 2>/dev/null
    sudo openssl x509 -req -in srv.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 30 \
        -extfile san2.ext -out srv.crt 2>/dev/null
    openssl x509 -in srv.crt -noout -subject -ext subjectAltName
    sudo kill "$(cat /srv/lab27/pids/https.pid)"
    sudo ip netns exec lab27-srv sh -c 'nohup python3 /srv/lab27/tls/https.py /srv/lab27 >/srv/lab27/https.log 2>&1 & echo $! > /srv/lab27/pids/https.pid'
    for _ in $(seq 1 10); do srv ss -Hltn 'sport = :443' | grep -q LISTEN && break; sleep 0.5; done
    cd - >/dev/null || exit 1

    # verify from the client
    cli bash /srv/lab27/lab27-triage.sh | sudo tee /srv/lab27/evidence/triage-after.txt
    for i in 1 2 3; do cli curl -s -o /dev/null -w "$F" http://www.corp.lab/report.bin; done
    ```

    **Task 8 — evidence**

    ```bash
    cd /srv/lab27/evidence || exit 1
    for f in *.pcap; do capinfos "$f" | grep -E 'File name|Number of packets|First packet|Last packet'; done
    sha256sum ./*.pcap ./*.txt | sudo tee SHA256SUMS
    sha256sum -c SHA256SUMS
    cd - >/dev/null || exit 1
    ```

    A finding for T5, for example:

    ```text
    T5 metrics.corp.lab:9100 unreachable — ROOT CAUSE: rtr01 forward-chain rule
    "ip daddr 10.27.2.20 tcp dport 9100 counter drop" (comment CHG-4471 temp block).
    Evidence: nmap --reason from cli01: 9100 filtered/no-response, 9200 closed/conn-refused, 80/443/8080 open;
    traceroute -T -p 9100 stops after 10.27.1.1, -p 80 reaches 10.27.2.20; srv01 serves 9100 locally (200);
    rtr01 capture: SYNs In on r1, none on r2; rule counter +1 per test. FIX: rule removed by handle after
    approval from the CHG-4471 owner (ruleset backup in backup/). VERIFIED: triage-after.txt line 4 = 200.
    ```

    Finally: `sudo bash lab27-cleanup.sh`.

??? success "PowerShell solution"
    Works in Windows PowerShell 5.1 and PowerShell 7 on Windows. No elevation needed except for the optional `pktmon` step.

    ```powershell
    New-Item -ItemType Directory -Path $HOME\lab27 -Force | Out-Null

    # 1. A tiny HTTP responder on 127.0.0.1:18080 as a background job
    $null = Start-Job -Name lab27-http -ScriptBlock {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 18080)
        $listener.Start()
        try {
            while ($true) {
                $client = $listener.AcceptTcpClient()
                $stream = $client.GetStream()
                $buffer = New-Object byte[] 4096
                [void]$stream.Read($buffer, 0, $buffer.Length)
                $body = 'lab27 ok'
                $resp = "HTTP/1.0 200 OK`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n$body"
                $bytes = [System.Text.Encoding]::ASCII.GetBytes($resp)
                $stream.Write($bytes, 0, $bytes.Length)
                $client.Close()
            }
        } finally { $listener.Stop() }
    }
    Start-Sleep -Seconds 2

    # 1-2. Classify open / refused / silent, with timing and curl exit codes
    $tests = @(
        @{ Case = 'open';     Target = '127.0.0.1'; Port = 18080 },
        @{ Case = 'refused';  Target = '127.0.0.1'; Port = 18081 },
        @{ Case = 'filtered'; Target = '192.0.2.1'; Port = 80 }     # TEST-NET-1: reserved, nobody answers
    )
    $results = foreach ($t in $tests) {
        $sw  = [System.Diagnostics.Stopwatch]::StartNew()
        $tnc = Test-NetConnection -ComputerName $t.Target -Port $t.Port -WarningAction SilentlyContinue
        $sw.Stop()
        $curl = curl.exe -s -o NUL -m 5 -w '%{http_code} connect=%{time_connect}' ('http://{0}:{1}/' -f $t.Target, $t.Port)
        [pscustomobject]@{
            Case             = $t.Case
            Target           = '{0}:{1}' -f $t.Target, $t.Port
            TcpTestSucceeded = $tnc.TcpTestSucceeded
            TncMs            = [int]$sw.Elapsed.TotalMilliseconds
            Curl             = $curl
            CurlExit         = $LASTEXITCODE
        }
    }
    $results | Format-Table -AutoSize
    $results | Export-Csv -Path $HOME\lab27\windows-results.csv -NoTypeInformation

    # 3. Name sources (read-only)
    Resolve-DnsName localhost -ErrorAction SilentlyContinue | Select-Object Name, Type, IPAddress
    Resolve-DnsName localhost -NoHostsFile -ErrorAction SilentlyContinue | Select-Object Name, Type, IPAddress
    [System.Net.Dns]::GetHostAddresses('localhost').IPAddressToString
    Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" | Where-Object { $_ -notmatch '^\s*(#|$)' }

    # 4. TCP template values
    Get-NetTCPSetting | Select-Object SettingName, InitialRtoMs, MaxSynRetransmissions

    # 5. OPTIONAL, elevated: capture your own request to YOUR lab VM (replace address and port)
    # pktmon filter remove ; pktmon filter add -i 192.168.56.10 -p 22
    # pktmon start --capture --pkt-size 0 --file-name $HOME\lab27\vm.etl
    # curl.exe -s -m 3 telnet://192.168.56.10:22 ; pktmon stop
    # pktmon etl2pcap $HOME\lab27\vm.etl --out $HOME\lab27\vm.pcapng ; pktmon filter remove
    # Get-FileHash $HOME\lab27\vm.* -Algorithm SHA256

    # 6. Clean up the responder
    Stop-Job -Name lab27-http ; Remove-Job -Name lab27-http
    ```

    **Expected output (example):**

    ```text
    Case     Target        TcpTestSucceeded TncMs Curl                    CurlExit
    ----     ------        ---------------- ----- ----                    --------
    open     127.0.0.1:18080           True    41 200 connect=0.000412           0
    refused  127.0.0.1:18081          False  2077 000 connect=0.000000           7
    filtered 192.0.2.1:80             False 21402 000 connect=0.000000          28
    ```

    `Test-NetConnection` reports `False` for both the refused and the silent case; the time (seconds versus a couple of seconds) and curl's exit code (7 versus 28) separate them. Exact times depend on Windows' retry settings and on whether `Test-NetConnection`'s ping step also times out.

??? success "Answers to questions"
    1. Phase timings show DNS fast, the server answering within ~1 ms after connect, and delays concentrated in the TCP connect (≈ 1 s) and transfer; the same file from the **same server** on port 8080 is fast. Together with `ss -ti` (rtt ≫ minrtt, retransmissions), this rules out the application, disk and CPU and points at the path for port-80 traffic.
    2. The client capture shows only that a packet is missing. The server capture shows that the SYN-ACK **left** srv01 within microseconds; since it never reached `c0`, it was lost between the two points — on rtr01 or its links.
    3. `getent`/curl found an answer in `/etc/hosts` first (`hosts: files dns`), so the resolver never sent a DNS query. Only `dig`, which bypasses NSS, queried the server.
    4. rtr01 could not resolve 10.27.2.21 with ARP on its srv01 segment (the old server is gone), so it sent ICMP *Host unreachable*, which curl reports as "No route to host". The client's own routing table was fine.
    5. The probes reach bak01, but its replies (and the ICMP time-exceeded messages that traceroute relies on from the last hop) cannot be routed back, so every hop after rtr01 shows `*`. It looks like rtr01 stops forwarding, but the capture on bak01 shows the packets arriving.
    6. First the issuer: clients without the corp CA reject it as untrusted (deploy the CA to clients through policy). Then the name: clients that trust the CA reject the certificate because no SAN matches `secure.corp.lab` (issue a new certificate with the right SANs). Never disable verification.
    7. 9100 is **filtered** (no response): rtr01 dropped the SYNs. 9200 is **closed** (conn-refused): srv01 itself answered with a RST because nothing listens there.
    8. The rule belongs to a change that may still be needed (it could be part of incident containment), and the owner must update the change record. The analyst provides the evidence and the request; removing controls unilaterally breaks change control and can reopen a security hole.
    9. The refused (18081) and silent (192.0.2.1) cases both returned `False`. Timing (fast vs slow) and curl's exit code (7 vs 28) separated them.
    10. For example: saved captures with tight filters and `capinfos` summaries; SHA-256 hashes in `SHA256SUMS` (verified with `sha256sum -c`); before/after triage outputs; backups of every file and ruleset changed; firewall counters shown before and after a test; findings that state symptom in numbers, evidence file names, fix and verification.
