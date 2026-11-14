---
description: "Module 3 test (Days 11–15): 25 questions on IP configuration, layered connectivity troubleshooting, DNS, ports and sockets, network interfaces, neighbour caches and packet capture in Bash and PowerShell, with a collapsible answer key and a practical task."
---

# Module 3 Test: Networking & Troubleshooting

| | |
|---|---|
| **Covers** | [Day 11](../course/module-3/day-11.md) – [Day 15](../course/module-3/day-15.md) |
| **Questions** | 25: 15 multiple choice (1 mark each), 7 command-writing (2 marks each), 3 short-answer and practical (3 marks each) |
| **Total** | 38 marks · pass mark 23 (60%) |
| **Time** | 75 minutes, closed book except for built-in help (`man`, `--help`, `Get-Help`) |
| **Environment** | For Part C you need an Ubuntu 24.04 **VM** (or WSL2) with `sudo` where you can create network namespaces, and/or a Windows 11 lab VM. Take a snapshot first, work only with the names given in the task (`m3test…`), and test or capture only on systems you own or are authorised to use (localhost, your lab, `scanme.nmap.org`). |

Answer every question before opening the answers. Each answer explains *why*, so use the key to learn, not only to mark. Grade with the table on the [Assessments](index.md#grading-guidance) page.

## Part A — Multiple choice (1 mark each)

**1.** A Windows laptop shows `169.254.23.7` with mask `255.255.0.0` in `ipconfig /all`. What does that mean?

- A. It has a valid private address from the office DHCP server
- B. It asked for a DHCP lease, got no answer and assigned itself a link-local (APIPA) address
- C. It is connected to a CGNAT network
- D. It has a static address configured by the administrator

??? question "Answer and explanation"
    **B.** `169.254.0.0/16` is link-local IPv4 (APIPA). Windows uses it when no DHCP server answered, so it is almost always a fault: check the cable/Wi-Fi, VLAN and DHCP server. `Get-NetIPAddress` shows `PrefixOrigin WellKnown` for it. CGNAT is `100.64.0.0/10`. (Day 11)

**2.** A host has `192.168.10.25/26`. Which address is in the **same subnet**?

- A. `192.168.10.70`
- B. `192.168.10.1`
- C. `192.168.10.64`
- D. `192.168.10.130`

??? question "Answer and explanation"
    **B.** A `/26` has blocks of 64 addresses: `.0–.63`, `.64–.127`, `.128–.191`, `.192–.255`. `.25` is in `.0–.63`, so `.1` is in the same subnet; `.64` and `.70` are in the next block and `.130` in the third. (Day 11)

**3.** Which command applies a Netplan change on a remote Ubuntu server **with automatic rollback** if you lose the connection?

- A. `sudo netplan apply`
- B. `sudo netplan generate`
- C. `sudo netplan try`
- D. `sudo systemctl restart networking`

??? question "Answer and explanation"
    **C.** `netplan try` applies the configuration and reverts it after 120 seconds (`--timeout`) unless you confirm with ++enter++. `apply` has no safety net, `generate` only writes backend files, and Ubuntu 24.04 does not use the `networking` service. (Day 11)

**4.** `ping 10.20.0.20` from a client prints `From 192.168.50.1 icmp_seq=1 Destination Host Unreachable`. What does this tell you?

- A. The destination answered but is overloaded
- B. The router `192.168.50.1` could not deliver the packet to the destination (for example, no ARP reply on the final network)
- C. DNS resolution failed
- D. A firewall on the destination dropped the packet silently

??? question "Answer and explanation"
    **B.** An ICMP *unreachable* comes from the device reporting the problem — here the router. A silent drop would produce **no** reply (timeout), and DNS is not involved when you ping an IP address. (Day 12)

**5.** Which statement about `Test-Connection` is correct?

- A. `-TcpPort` and `-Traceroute` work in both Windows PowerShell 5.1 and PowerShell 7
- B. In Windows PowerShell 5.1 it returns `Win32_PingStatus` objects; `-TcpPort`, `-Traceroute` and `-MtuSize` exist only in PowerShell 7
- C. It is Windows-only in every version
- D. It only supports TCP, not ICMP

??? question "Answer and explanation"
    **B.** PowerShell 7 rewrote `Test-Connection` on .NET (`-TargetName`, `-TcpPort`, `-Traceroute`, `-MtuSize`, cross-platform). Scripts that must run on both versions use only `-Count` and `-Quiet`, or `Test-NetConnection` on Windows. (Day 12)

**6.** `nc -zv -w 3 10.20.0.20 8080` fails after 3 seconds with *timed out*, while port 22 on the same host reports *Connection refused*. What is the most likely difference?

- A. Port 8080 is filtered (packets dropped by a firewall); on port 22 the host answered with a TCP RST because nothing listens
- B. Both ports are filtered
- C. Port 8080 is open but slow
- D. DNS fails for port 8080 only

??? question "Answer and explanation"
    **A.** *Refused* means the host is reachable and actively said "nothing here" (RST, or an ICMP port-unreachable from a REJECT rule). *Timed out* means no answer at all — typically a DROP rule or a routing problem. (Day 12)

**7.** `dig app.corp.example A` returns `status: NOERROR` with `ANSWER: 0` and an SOA record in the AUTHORITY section. What does that mean?

- A. The name does not exist (NXDOMAIN)
- B. The name exists but has no A record (NODATA)
- C. The resolver failed (SERVFAIL)
- D. The resolver refused the query

??? question "Answer and explanation"
    **B.** NODATA is NOERROR with an empty answer: the name exists (perhaps with only AAAA or MX records), but not the type you asked for. NXDOMAIN would show `status: NXDOMAIN`. The SOA in the authority section is used for **negative caching**. (Day 13)

**8.** You add a missing DNS record, but clients still get NXDOMAIN for several minutes. Why?

- A. DNS changes always take 48 hours
- B. The resolver cached the negative answer for the time given by the zone's SOA (minimum/negative TTL)
- C. The clients' `/etc/hosts` overrides DNS
- D. The new record has a TTL of 0

??? question "Answer and explanation"
    **B.** Negative answers are cached too (RFC 2308), for the smaller of the SOA TTL and its minimum field. Flush the resolver's cache for that name (`rndc flushname`/`flushtree`, `resolvectl flush-caches`, `Clear-DnsClientCache` on the client) or wait for it to expire. (Day 13)

**9.** On Ubuntu, `getent hosts intranet` returns `10.0.0.9`, but `dig intranet.corp.example +short` returns `10.0.0.50`. What is the most likely explanation?

- A. `dig` is broken
- B. `getent` follows `/etc/nsswitch.conf` and found a stale entry in `/etc/hosts`; `dig` queries DNS only
- C. The DNS server returns random answers
- D. `getent` uses IPv6 only

??? question "Answer and explanation"
    **B.** Applications resolve names through the C library and `nsswitch.conf` (`files` before `dns`), exactly like `getent`. `dig`, `host` and `nslookup` bypass `/etc/hosts`. When the two disagree, check `/etc/hosts` first. (Day 13)

**10.** `sudo ss -ltn` shows `127.0.0.1:5432`. Users on other hosts get *Connection refused* on port 5432. Why?

- A. A firewall drops their packets
- B. PostgreSQL listens on the loopback address only
- C. Port 5432 is privileged
- D. PostgreSQL is not running

??? question "Answer and explanation"
    **B.** A loopback-only listener accepts connections that originate on the host itself. A firewall drop would cause a timeout; a stopped service would not appear in `ss -ltn`; only ports below 1024 are privileged on Linux. (Day 14)

**11.** An application server holds 2,000 sockets in `CLOSE-WAIT`, all to the database. Where is the problem?

- A. In the database server
- B. In the network between them
- C. In the application on the server that shows CLOSE-WAIT, which never closes its side
- D. In the kernel; lower the TIME-WAIT timer

??? question "Answer and explanation"
    **C.** CLOSE-WAIT means the peer sent FIN and the **local application** has not called `close()`. Only fixing the application (or its connection pool) clears it. TIME-WAIT is a different state, held by the side that closed first. (Day 14)

**12.** A program on Windows fails to start with socket error **10048**. What does that mean?

- A. Connection refused
- B. Connection timed out
- C. The address and port are already in use by another socket
- D. Access denied because of an excluded port range

??? question "Answer and explanation"
    **C.** 10048 is `WSAEADDRINUSE`, the Windows equivalent of Linux `EADDRINUSE` (errno 98). Find the owner with `Get-NetTCPConnection -LocalPort PORT` and `Get-Process -Id OwningProcess`. 10061 is refused, 10060 timed out, 10013 access denied. (Day 14)

**13.** `ip link show eth0` prints `<NO-CARRIER,BROADCAST,MULTICAST,UP>` and `state DOWN`. What is the correct reading?

- A. The interface is administratively down; run `ip link set eth0 up`
- B. The interface is administratively up, but there is no physical link (cable, switch port, or virtual NIC disconnected)
- C. The interface is working normally
- D. The interface has no IP address, so it reports DOWN

??? question "Answer and explanation"
    **B.** `UP` in the flags is the **administrative** state (someone set it up); `LOWER_UP` would mean the physical/lower layer has carrier. `NO-CARRIER` with `state DOWN` means the link layer is down: check the cable, switch port, Wi-Fi association or the VM's virtual network connection. IP addresses do not affect the link state. (Day 15)

**14.** In `ip neigh show`, an entry is listed as `10.15.0.1 dev eth0 FAILED`. What does that mean?

- A. The neighbour was reachable recently and is still trusted
- B. Address resolution for `10.15.0.1` failed: no ARP reply was received
- C. The entry was configured manually and never expires
- D. The neighbour's MAC address changed

??? question "Answer and explanation"
    **B.** `FAILED` (and `INCOMPLETE` while resolution is in progress) means no ARP (IPv4) or Neighbor Discovery (IPv6) reply arrived. `REACHABLE` = recently confirmed, `STALE` = known but not recently confirmed (it is re-checked on the next use), `PERMANENT` = static entry. On Windows, `Get-NetNeighbor` reports `Unreachable`, `Reachable`, `Stale` and `Permanent`. A gateway in FAILED state explains "no connectivity beyond the LAN". (Days 11, 15)

**15.** Which pair is correct?

- A. tcpdump capture filter `tcp.port == 443`; Wireshark display filter `tcp port 443`
- B. tcpdump capture filter (BPF) `host 10.15.0.5 and tcp port 443`; Wireshark display filter `ip.addr == 10.15.0.5 && tcp.port == 443`
- C. Both tools use the same syntax for capture and display filters
- D. Display filters reduce what is written to the capture file

??? question "Answer and explanation"
    **B.** Capture filters use **BPF** syntax (`host`, `net`, `port`, `tcp`, `udp`, `icmp`, `arp`, `and`/`or`/`not`) and decide what is captured at all — tcpdump and Wireshark's capture-filter field use them. **Display filters** (`ip.addr == x`, `tcp.port == 443`, `dns`, `tcp.flags.syn == 1 && tcp.flags.ack == 0`) only hide packets that are already captured. (Day 15)

## Part B — Write the command (2 marks each)

Write the command for **both** shells unless the question names one. One mark for a working command, one for using the safe or precise form described in the lessons.

**16.** Show the IPv4 addresses, the default gateway and the DNS servers of the machine in one compact view (one command per shell), and show which route and source address would be used to reach `8.8.8.8`.

??? question "Answer and explanation"
    - Bash: `ip -br -4 addr` (or `ip -4 addr show`), `ip route show default`, `resolvectl dns` (systemd-resolved) — and `ip route get 8.8.8.8` for the route, interface and source address.
    - PowerShell: `Get-NetIPConfiguration` (addresses, gateway and DNS servers per interface) and `Find-NetRoute -RemoteIPAddress 8.8.8.8` (route and source address). `ipconfig /all` is accepted for the first part.

    (Day 11)

**17.** Test whether TCP port 443 on your lab server `10.20.0.20` accepts connections, with a 3-second timeout (Bash), and the same test returning only `$true`/`$false` in PowerShell 7 and in Windows PowerShell 5.1.

??? question "Answer and explanation"
    - Bash: `nc -zv -w 3 10.20.0.20 443` (or `curl -v --connect-timeout 3 https://10.20.0.20/`).
    - PowerShell 7: `Test-Connection -TargetName 10.20.0.20 -TcpPort 443 -Quiet`
    - Windows PowerShell 5.1 (and 7 on Windows): `(Test-NetConnection -ComputerName 10.20.0.20 -Port 443).TcpTestSucceeded` or `Test-NetConnection 10.20.0.20 -Port 443 -InformationLevel Quiet`.

    Note: test ports only on systems you are authorised to test. (Day 12)

**18.** Query the **MX** records of `example.com` showing only the answer data (Bash), and the same with `Resolve-DnsName`, sending the query to the DNS server `1.1.1.1` in both shells.

??? question "Answer and explanation"
    - Bash: `dig @1.1.1.1 example.com MX +short`
    - PowerShell (Windows): `Resolve-DnsName -Name example.com -Type MX -Server 1.1.1.1`

    `@server` and `-Server` bypass the system resolver, which is how you compare resolvers. (Day 13)

**19.** List every TCP and UDP listener with its owning process (Linux, complete for all users), and every TCP listener with its process name on Windows.

??? question "Answer and explanation"
    - Bash: `sudo ss -tulnp`
    - PowerShell: <code>Get-NetTCPConnection -State Listen &#124; Select-Object LocalAddress, LocalPort, OwningProcess, @{ n = 'Process'; e = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName } }</code>

    Without `sudo`, `ss -p` shows the process only for your own sockets. (Day 14)

**20.** Show the established TCP connections to remote port 443 (Bash), and count all TCP connections by state (PowerShell).

??? question "Answer and explanation"
    - Bash: `ss -tn state established '( dport = :443 )'` (add `-p` with `sudo` for owners).
    - PowerShell: <code>Get-NetTCPConnection &#124; Group-Object State &#124; Sort-Object Count -Descending &#124; Select-Object Count, Name</code>

    With a state filter, `ss` omits the State column. (Day 14)

**21.** Show the link speed, duplex and link status of `eth0`, and its RX/TX packet, error and drop counters (Bash). Show the status and link speed of every adapter and the received/sent byte counters of the adapter `Ethernet` (PowerShell).

??? question "Answer and explanation"
    - Bash: `sudo ethtool eth0` (look at `Speed:`, `Duplex:`, `Link detected:`) and `ip -s link show eth0` (RX/TX `packets`, `errors`, `dropped`; `ip -s -s link` adds error details).
    - PowerShell (Windows): `Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress` and `Get-NetAdapterStatistics -Name Ethernet` (`ReceivedBytes`, `SentBytes`, and more counters in `Format-List *`).

    Counters are cumulative since the interface came up: compare two readings over time. Virtual NICs may report no speed or a nominal one. (Day 15)

**22.** Capture 50 packets of DNS traffic on `eth0` without name resolution into `/tmp/m3test-dns.pcap`, then read the file back showing only queries to `10.15.0.53` (Bash). On Windows, start and stop a native packet capture and convert it to a format Wireshark can open.

??? question "Answer and explanation"
    - Bash: `sudo tcpdump -i eth0 -n -c 50 -w /tmp/m3test-dns.pcap port 53`, then `tcpdump -n -r /tmp/m3test-dns.pcap dst host 10.15.0.53`
    - PowerShell / Windows (elevated): `pktmon start --capture` … reproduce the problem … `pktmon stop`, then `pktmon etl2pcap PktMon.etl --out m3test.pcapng` (in older Windows 10 builds the subcommand is `pktmon pcapng`).

    One mark for capturing with a filter and `-n`/`-c`, one for writing to a file and reading it back (or the `pktmon` start/stop/convert sequence). Capture only on networks you are authorised to monitor; capture files can contain passwords and personal data — protect and delete them. (Day 15)

## Part C — Short answer and practical (3 marks each)

**23.** Users report "the intranet site `http://intranet.corp.example` is down". It loads by IP address. Describe your layered investigation, with commands, from the client side, and name two likely causes.

??? question "Answer and explanation"
    Marking: 1 mark for the layered order, 1 for correct commands, 1 for plausible causes tied to evidence.

    1. **Link and IP:** `ip -br addr`, `ip route show default` / `Get-NetIPConfiguration` — fine, because the site works by IP.
    2. **Name resolution through the system path:** `getent hosts intranet.corp.example` / `Resolve-DnsName intranet.corp.example`; compare with DNS only: `dig intranet.corp.example`, and with another resolver `dig @10.15.0.53 intranet.corp.example`. Check `/etc/hosts` / `C:\Windows\System32\drivers\etc\hosts`, `resolvectl status` / `Get-DnsClientServerAddress`.
    3. **Read the response code:** NXDOMAIN (missing record, or negative cache after a recent fix), SERVFAIL (broken zone or forwarder), timeout (resolver unreachable or firewalled), REFUSED (resolver not allowing recursion for you).
    4. **Port and application:** once the name resolves to the right address, `curl -v http://intranet.corp.example/` / `Test-NetConnection intranet.corp.example -Port 80`.

    Likely causes: wrong DNS server on the client, a stale hosts entry, a missing or mistyped record, a cached negative answer, or a broken zone on the DNS server. (Days 12–13)

**24.** A server on a switched LAN suddenly loses connectivity for a few seconds several times an hour. Another host was recently added. Explain how you would test for a **duplicate IP address** and an ARP problem on Linux and on Windows, and what evidence would confirm it.

??? question "Answer and explanation"
    Marking: 1 mark for the neighbour-cache evidence, 1 for an active duplicate test, 1 for capture evidence and a safe next step.

    - **Neighbour cache:** on another host, run `ip neigh show 10.15.0.10` (or `Get-NetNeighbor -IPAddress 10.15.0.10`) repeatedly: a MAC address that **changes** between two values for the same IP is the classic sign.
    - **Active test:** `sudo arping -D -I eth0 -c 3 10.15.0.10` sends duplicate-address-detection probes (run it from a host that does **not** own the address, or on the server itself before assigning the address); a reply means another device uses the address. On Windows, `Get-NetIPAddress` shows `AddressState Duplicate` and the System log records a TCP/IP duplicate-address warning.
    - **Capture:** `sudo tcpdump -i eth0 -n -e arp` shows ARP replies for the same IP from two different MAC addresses (`-e` prints the MAC addresses); in Wireshark the display filter `arp.duplicate-address-detected` highlights them.
    - **Next step:** identify the second device from its MAC (switch MAC table, DHCP leases, OUI vendor), remove the conflict through the change process, and fix the DHCP scope / IP plan so it cannot recur. Do not flush or change neighbour entries on production hosts as a "fix".

    (Days 11, 15)

**25.** **Practical task.** On your lab VM (snapshot first), using only the names `m3test-a`, `m3test-b` and the subnet `10.33.0.0/24`: (a) create two network namespaces joined by a veth pair, with `10.33.0.1/24` in `m3test-a` and `10.33.0.2/24` in `m3test-b`, and bring the links up; (b) prove connectivity with three pings and show the neighbour entry that was created; (c) start a TCP listener on port 8080 in `m3test-b` and prove with `ss` which process owns it; (d) capture the TCP handshake of one connection from `m3test-a` to that port into a file and show the SYN, SYN-ACK and ACK; (e) show the interface counters of the veth in `m3test-a`; (f) clean up everything you created. (Windows alternative for (b)–(e): `Test-Connection -Count 3` to your gateway, `Get-NetNeighbor` for its entry, a `[System.Net.Sockets.TcpListener]` on `127.0.0.1:8080` found with `Get-NetTCPConnection -LocalPort 8080`, a `pktmon` capture of a connection to it, and `Get-NetAdapterStatistics`.)

??? question "Answer and explanation"
    Marking: 0.5 mark per step (a)–(f).

    ```bash
    # (a) namespaces and a veth pair
    sudo ip netns add m3test-a ; sudo ip netns add m3test-b
    sudo ip link add m3test-va type veth peer name m3test-vb
    sudo ip link set m3test-va netns m3test-a ; sudo ip link set m3test-vb netns m3test-b
    sudo ip -n m3test-a addr add 10.33.0.1/24 dev m3test-va
    sudo ip -n m3test-b addr add 10.33.0.2/24 dev m3test-vb
    for ns in m3test-a m3test-b; do sudo ip -n "$ns" link set lo up; done
    sudo ip -n m3test-a link set m3test-va up ; sudo ip -n m3test-b link set m3test-vb up
    # (b) connectivity and the neighbour entry
    sudo ip netns exec m3test-a ping -c 3 10.33.0.2
    sudo ip -n m3test-a neigh show             # 10.33.0.2 dev m3test-va lladdr ... REACHABLE
    # (c) listener and owner
    sudo ip netns exec m3test-b nc -lk 10.33.0.2 8080 & echo $! > /tmp/m3test-nc.pid
    sudo ip netns exec m3test-b ss -ltnp 'sport = :8080'
    # (d) capture one handshake
    sudo ip netns exec m3test-a timeout 15 tcpdump -i m3test-va -n -c 3 -w /tmp/m3test.pcap 'tcp port 8080' &
    sleep 1 ; sudo ip netns exec m3test-a nc -z -w 2 10.33.0.2 8080 ; wait
    tcpdump -n -r /tmp/m3test.pcap             # Flags [S], [S.], [.]
    # (e) counters
    sudo ip -n m3test-a -s link show m3test-va
    # (f) clean up (stop the saved PID only, after checking it)
    ps -p "$(cat /tmp/m3test-nc.pid)" -o pid,args && sudo kill "$(cat /tmp/m3test-nc.pid)"
    sudo ip netns del m3test-a ; sudo ip netns del m3test-b   # deletes the veth pair too
    rm -f /tmp/m3test.pcap /tmp/m3test-nc.pid
    ip netns list | grep m3test || echo "cleaned up"
    ```

    In (d), tcpdump prints `Flags [S]` (SYN), `Flags [S.]` (SYN-ACK) and `Flags [.]` (ACK). The PID saved in (c) is that of `sudo`; `kill` on it ends `nc` as well (or use `sudo ip netns pids m3test-b` to see the processes inside the namespace — deleting a namespace does **not** kill processes still running in it).

    ```powershell
    Test-Connection -TargetName 192.168.1.1 -Count 3                     # (b) PS 7; 5.1: -ComputerName
    Get-NetNeighbor -IPAddress 192.168.1.1
    $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 8080)   # (c)
    $l.Start()
    Get-NetTCPConnection -LocalPort 8080 -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess
    $PID                                                                 # same as OwningProcess
    pktmon start --capture                                               # (d) elevated window
    Test-NetConnection -ComputerName 127.0.0.1 -Port 8080 | Out-Null
    pktmon stop ; pktmon etl2pcap PktMon.etl --out m3test.pcapng
    Get-NetAdapterStatistics | Select-Object Name, ReceivedBytes, SentBytes   # (e)
    $l.Stop() ; Remove-Item .\PktMon.etl, .\m3test.pcapng -WhatIf         # (f) then without -WhatIf
    ```

    Loopback traffic may not appear in a `pktmon` capture on every Windows build; capturing a connection to another lab host shows the handshake reliably. (Days 11–15)

## After the test

| Score (of 38) | What to do next |
|---|---|
| 34–38 | Distinction. Move on to [Module 4](../course/module-4/index.md). |
| 29–33 | Merit. Re-read the lessons for any questions you missed. |
| 23–28 | Pass. Repeat the labs for the days you lost marks on. |
| < 23 | Repeat Labs 11–15 before starting Module 4. |
