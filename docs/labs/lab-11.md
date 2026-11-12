---
description: "Audit and document IP configuration on Linux and Windows, solve subnet questions from an addressing plan, repair a broken host (link down, wrong prefix, missing default route) inside isolated network namespaces, and validate a persistent netplan file without applying it."
---

# Lab 11: Address Audit

| Field | Value |
|---|---|
| **Lab ID** | LAB-11 |
| **Related lesson** | [Day 11: IP Configuration](../course/module-3/day-11.md) |
| **Difficulty** | Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Low. The Linux repair tasks run inside **isolated network namespaces** that do not touch your real interfaces, routes or DNS. Windows tasks are read-only. Netplan is validated with `--root-dir` in a scratch folder, never applied. Use a VM or WSL2, not a production server. |

## Objective

You are the on-call administrator for a small company. A new application server, **app01**, was built yesterday and "has no network". Your job is to:

1. Produce a ticket-ready record of the IP configuration of your own Linux and Windows machines (the evidence habit).
2. Check the addressing plan and answer subnet questions about it.
3. Diagnose and repair app01 layer by layer — link, address and prefix, gateway — using only `ip` commands.
4. Write the **persistent** configuration that should have been deployed, and validate it without applying it.

**Addressing plan (from the network team):**

| Segment | Prefix | Gateway | Notes |
|---|---|---|---|
| Management | `10.20.0.0/26` | `10.20.0.1` | `mgmt01` = `10.20.0.10` |
| Servers | `10.20.0.64/26` | `10.20.0.65` | `app01` = `10.20.0.70` |
| Remote service | `198.51.100.10/32` | — | Reached through the router |

## Required Environment

- **Linux:** Ubuntu 24.04 (VM or WSL2) with `sudo`. Packages: `iproute2` and `iputils-ping` (installed by default on Ubuntu Desktop/Server), `netplan.io` (installed on Ubuntu Desktop/Server; on WSL2 install it with `sudo apt install netplan.io`; it is only used for validation here), optional `ipcalc`.
- WSL2 and most VMs support network namespaces. Containers usually do **not** allow them unless privileged.
- **Windows:** Windows 11 with Windows PowerShell 5.1 or PowerShell 7. A normal (non-elevated) window is enough.

## Initial Conditions

- No namespaces called `lab11-*` exist: `ip netns list` shows none of them. If they exist from an earlier attempt, run the clean-up at the end of this page first.
- Create the working folder: `mkdir -p ~/lab11` (Linux) and `New-Item -ItemType Directory -Path $HOME\lab11 -Force` (Windows).
- Read the setup script before running it (never run scripts you have not read). It only uses `ip netns`, `ip link`, `ip addr`, `ip route` and `sysctl` **inside** the new namespaces.

### Lab setup (Linux)

Save this as `~/lab11/setup.sh` and run it with `sudo bash ~/lab11/setup.sh`:

```bash
#!/usr/bin/env bash
# Lab 11 setup: builds three isolated namespaces (gw, mgmt, app) with a broken app01.
set -o errexit -o nounset -o pipefail
for ns in lab11-gw lab11-mgmt lab11-app; do
    ip netns add "$ns"
    ip -n "$ns" link set lo up
done
# Router (lab11-gw): eth0 = server segment, eth1 = management segment
ip link add gw-srv type veth peer name app-eth0
ip link add gw-mgmt type veth peer name mgmt-eth0
ip link set gw-srv netns lab11-gw;   ip link set app-eth0 netns lab11-app
ip link set gw-mgmt netns lab11-gw;  ip link set mgmt-eth0 netns lab11-mgmt
ip -n lab11-gw link set gw-srv name eth0
ip -n lab11-gw link set gw-mgmt name eth1
ip -n lab11-app link set app-eth0 name eth0
ip -n lab11-mgmt link set mgmt-eth0 name eth0
ip -n lab11-gw addr add 10.20.0.65/26 dev eth0
ip -n lab11-gw addr add 10.20.0.1/26 dev eth1
ip -n lab11-gw addr add 198.51.100.10/32 dev lo        # "remote service"
ip -n lab11-gw link set eth0 up
ip -n lab11-gw link set eth1 up
ip netns exec lab11-gw sysctl -qw net.ipv4.ip_forward=1
# mgmt01: correct configuration
ip -n lab11-mgmt addr add 10.20.0.10/26 dev eth0
ip -n lab11-mgmt link set eth0 up
ip -n lab11-mgmt route add default via 10.20.0.1
# app01: deliberately broken by the "build engineer"
ip -n lab11-app addr add 10.20.0.70/24 dev eth0        # wrong prefix
# (interface left down, no default route)
echo "Lab 11 ready. Open a shell on app01 with: sudo ip netns exec lab11-app bash"
```

Then open a shell **inside app01** for Tasks 3 and 5:

```bash
sudo ip netns exec lab11-app bash
# Your prompt does not change. Check where you are with:  ip -br link   (only lo and eth0 exist)
```

## Step-by-Step Instructions

### Task 1 — Evidence first: document your own machines

=== "Linux"

    1. Save a timestamped snapshot of your real configuration (read-only):

        ```bash
        { date -u -Iseconds; hostname; ip -br link; ip -br addr; ip route; ip -6 route; ip neigh; } > ~/lab11/linux-baseline.txt
        ```

    2. From the snapshot, record in `~/lab11/linux-record.txt`: interface name, MAC, IPv4 address and prefix, default gateway, MTU, and whether the address is static or dynamic (`dynamic` / `valid_lft`).
    3. Run `ip route get 1.1.1.1` and note the interface and source address.

=== "Windows"

    1. Save a timestamped snapshot:

        ```powershell
        $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
        Get-NetIPConfiguration -Detailed | Out-File "$HOME\lab11\win-baseline-$stamp.txt"
        ipconfig /all | Out-File "$HOME\lab11\win-baseline-$stamp.txt" -Append
        ```

    2. Record for the active adapter: name, MAC, IPv4 address and prefix, gateway, DNS servers, DHCP state, lease expiry, MTU and network profile (`Get-NetConnectionProfile`).
    3. Run `Find-NetRoute -RemoteIPAddress 1.1.1.1` and note the source address and the route used.

### Task 2 — Check the addressing plan

Answer without a calculator first, then verify with `ipcalc` (Linux) or the PowerShell snippet from Day 11, Demo 7:

1. Network, first host, last host and broadcast of the **Servers** segment.
2. Is `10.20.0.70` on the same subnet as `10.20.0.10`? As `10.20.0.65`?
3. How many hosts can the Servers segment hold?
4. If app01 were configured as `10.20.0.70/24`, which of `10.20.0.10`, `10.20.0.65`, `198.51.100.10` would app01 try to reach **directly** (without the gateway)?

### Task 3 — Repair app01 layer by layer (Linux, inside `lab11-app`)

Work in this order and write down what you see at each step in `~/lab11/app01-notes.txt` (run `exit` first if you need to write from your normal shell, or use `tee` with an absolute path).

1. **Link:** run `ip -br link` and `ip -br addr`. What is wrong? Fix it with one command.
2. **Address and prefix:** compare the address with the plan. Test `ping -c2 10.20.0.65` and `ping -c3 10.20.0.10` and explain both results with `ip route get` and `ip neigh`. Fix the prefix (delete the wrong address, add the right one).
3. **Gateway:** run `ip route`. Test `ping -c2 198.51.100.10`. Add the correct default route.
4. **Verify:** ping the gateway, mgmt01 and the remote service; run `ip route get` for each and save `ip -br addr; ip route; ip neigh` to `~/lab11/app01-after.txt` (from inside the namespace, absolute paths work: `/home/<you>/lab11/...`).

### Task 4 — Write and validate the persistent configuration

On a real app01 (Ubuntu Server, NIC `enp0s8`) the fix must survive a reboot. Write the netplan file and validate it **in a scratch root** so nothing is applied:

1. Create `~/lab11/netplan-root/etc/netplan/60-app01.yaml` with: no DHCP, address `10.20.0.70/26`, default route via `10.20.0.65`, DNS server `10.20.0.1`, search domain `lab.internal`. Set its permissions to `600`.
2. Validate: `sudo netplan generate --root-dir ~/lab11/netplan-root`. In a VM or WSL2 this may print `systemctl daemon-reload` or "Failed to send reload request" messages because of the scratch root; ignore those, but fix any YAML or "network definition" errors.
3. Inspect the generated file under `~/lab11/netplan-root/run/systemd/network/`.
4. Break the file on purpose (remove the `/26`) and validate again. Note the error, then restore it.

### Task 5 — Export and compare

1. Inside `lab11-app`, export the final configuration as JSON: `ip -j addr show dev eth0 > ~/lab11/app01.json` (absolute path) and confirm the prefix length with `grep -o '"prefixlen":[0-9]*'`.
2. Practise change evidence: on the router namespace, save `ip route` to a *before* file, add a test route `172.16.0.0/16 via 10.20.0.70`, save an *after* file, compare them with `diff`, then delete the test route.
3. **Windows:** export `Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin, AddressState` to `$HOME\lab11\win-ip.csv`.

### Task 6 — Windows fault finding from evidence (paper exercise)

A user sends this `ipconfig /all` excerpt (example) from their laptop. Identify **three** problems or clues and the next command you would run for each.

```text
Wireless LAN adapter Wi-Fi:

   Connection-specific DNS Suffix  . :
   Description . . . . . . . . . . . : Intel(R) Wi-Fi 6 AX201 160MHz
   Physical Address. . . . . . . . . : 7C-B2-7D-11-22-33
   DHCP Enabled. . . . . . . . . . . : Yes
   Autoconfiguration Enabled . . . . : Yes
   Link-local IPv6 Address . . . . . : fe80::1c4f:9a2e:77b0:3d11%18(Preferred)
   Autoconfiguration IPv4 Address. . : 169.254.81.177(Preferred)
   Subnet Mask . . . . . . . . . . . : 255.255.0.0
   Default Gateway . . . . . . . . . :
   DNS Servers . . . . . . . . . . . : fec0:0:0:ffff::1%1
                                       fec0:0:0:ffff::2%1
                                       fec0:0:0:ffff::3%1
```

## Commands to Execute

Try each task yourself first. Complete commands are in the [Solution](#solution). The key commands are:

| Purpose | Linux | Windows |
|---|---|---|
| Overview | `ip -br link`, `ip -br addr`, `ip route`, `ip neigh` | `Get-NetIPConfiguration -Detailed`, `ipconfig /all` |
| Path decision | `ip route get ADDR` | `Find-NetRoute -RemoteIPAddress ADDR` |
| Repair (runtime) | `ip link set eth0 up`, `ip addr del/add`, `ip route add default via` | (read-only in this lab) |
| Persistent | `netplan generate --root-dir DIR` | `New-NetIPAddress ... -WhatIf` |
| Export | `ip -j addr`, `diff` | `Export-Csv` |

## Expected Results

- **Task 1:** a baseline file per platform and a short record that matches the live configuration.
- **Task 2:** Servers = `10.20.0.64/26`: first host `.65`, last host `.126`, broadcast `.127`, 62 hosts. `.70` is **not** on the same subnet as `.10`, but **is** on the same subnet as `.65`. With a wrong `/24`, app01 would try to reach `10.20.0.10` and `10.20.0.65` directly and `198.51.100.10` through a gateway (which it does not have).
- **Task 3 (captured on Ubuntu 24.04.5):**
    - Step 1: `eth0` is `DOWN`; after `ip link set eth0 up` it shows `UP` with `10.20.0.70/24`.
    - Step 2: ping to `10.20.0.65` **succeeds** (same `/24` and same link) but ping to `10.20.0.10` fails with `Destination Host Unreachable` from `10.20.0.70`, and `ip neigh` shows `10.20.0.10 dev eth0 FAILED`: app01 is ARPing for a host that lives on another segment.
    - Step 3: `ping: connect: Network is unreachable` for `198.51.100.10` until the default route is added.
    - Step 4: all three targets reply; `ip route get 10.20.0.10` shows `via 10.20.0.65`.
- **Task 4:** `netplan generate` produces `10-netplan-enp0s8.network` containing `Address=10.20.0.70/26` and `Gateway=10.20.0.65`; without `/26` it fails with *"address '10.20.0.70' is missing /prefixlength"*.
- **Task 5:** `"prefixlen":26` in the JSON; `diff` of the before/after route snapshots shows exactly one added line (`> 172.16.0.0/16 via ...`).
- **Task 6:** APIPA address (DHCP failed), no default gateway, and `fec0::` site-local "DNS servers" (the placeholder Windows shows when no DNS server was received).

## Verification Steps

=== "Linux (inside lab11-app)"

    ```bash
    ip -br link show dev eth0                    # UP
    ip -br addr show dev eth0                    # 10.20.0.70/26
    ip route                                     # default via 10.20.0.65 + 10.20.0.64/26 connected
    ping -c1 -W1 10.20.0.65 && ping -c1 -W1 10.20.0.10 && ping -c1 -W1 198.51.100.10 && echo "ALL OK"
    ip route get 10.20.0.10                      # via 10.20.0.65
    ```

=== "Linux (netplan)"

    ```bash
    ls -l ~/lab11/netplan-root/etc/netplan/60-app01.yaml        # -rw-------
    sudo netplan generate --root-dir ~/lab11/netplan-root 2>&1 | grep -i -e error -e warning   # nothing
    grep -E 'Address|Gateway|DNS' ~/lab11/netplan-root/run/systemd/network/10-netplan-enp0s8.network
    ```

=== "Windows"

    ```powershell
    Get-ChildItem $HOME\lab11 | Select-Object Name, Length
    Import-Csv $HOME\lab11\win-ip.csv | Format-Table
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Cannot create namespace file "/run/netns/lab11-gw": File exists` | Namespaces left from an earlier attempt | Run the clean-up commands, then the setup again |
| `mount --make-shared /run/netns failed: Operation not permitted` or `Operation not permitted` | Running without `sudo`, or inside an unprivileged container | Use `sudo`; use a VM or WSL2 |
| `Error: Nexthop has invalid gateway.` when adding the default route | The prefix is still wrong, or the link is down | Fix the address first, check `ip -br addr` |
| `RTNETLINK answers: File exists` on `ip route add default` | A default route already exists | `ip route replace default via 10.20.0.65` |
| `Error: ipv4: Address already assigned.` | You tried to add the address before deleting the `/24` | `ip addr del 10.20.0.70/24 dev eth0` first |
| Pings to `10.20.0.10` still fail after the fix | mgmt01 or the router lost its configuration (setup failed half-way) | Check `sudo ip netns exec lab11-mgmt ip route` and `sudo ip netns exec lab11-gw sysctl net.ipv4.ip_forward`; re-run clean-up and setup |
| `netplan: command not found` | netplan.io missing (WSL2 minimal) | `sudo apt install netplan.io` (validation only) |
| `Invalid YAML: inconsistent indentation` | Tabs or uneven spaces | Use two spaces per level; no tabs |
| `Permissions for ... are too open` warning | YAML not mode 600 | `chmod 600 ~/lab11/netplan-root/etc/netplan/60-app01.yaml` |
| You ran a command in the wrong shell | Prompt does not change inside a namespace | `ip -br link`: inside lab11-app only `lo` and `eth0` exist; `exit` to leave |

## Questions

1. Why did ping to `10.20.0.65` work while the prefix was still wrong, but ping to `10.20.0.10` did not?
2. What does `Destination Host Unreachable` from `10.20.0.70` tell you about **where** the fault is?
3. Why could you not add the default route while the interface was down or the prefix was wrong?
4. Your runtime repair works. What happens to it at the next reboot of a real server, and what prevents that?
5. Why is `netplan try` safer than `netplan apply` on a remote server?
6. In Task 6, why are the `fec0:0:0:ffff::1` "DNS servers" a clue rather than a real configuration?
7. Which Windows cmdlets would you use to fix app01 if it were a Windows server, and which parameter lets you preview each change?

## Solution

??? success "Bash solution"
    **Task 1**

    ```bash
    mkdir -p ~/lab11
    { date -u -Iseconds; hostname; ip -br link; ip -br addr; ip route; ip -6 route; ip neigh; } > ~/lab11/linux-baseline.txt
    ip -br link                       # name + MAC
    ip -4 addr show                   # address/prefix, dynamic?, valid_lft
    ip route | grep '^default'        # gateway
    ip link show | grep -o 'mtu [0-9]*' | sort | uniq -c
    ip route get 1.1.1.1              # interface + source address
    ```

    **Task 2**

    ```bash
    ipcalc 10.20.0.70/26 | grep -E 'Network|HostMin|HostMax|Broadcast|Hosts'
    ```

    Expected output (captured):

    ```text
    Network:   10.20.0.64/26        00001010.00010100.00000000.01 000000
    HostMin:   10.20.0.65           00001010.00010100.00000000.01 000001
    HostMax:   10.20.0.126          00001010.00010100.00000000.01 111110
    Broadcast: 10.20.0.127          00001010.00010100.00000000.01 111111
    Hosts/Net: 62                    Class A, Private Internet
    ```

    **Task 3 (inside `sudo ip netns exec lab11-app bash`)**

    ```bash
    # Step 1 - link
    ip -br link ; ip -br addr
    ip link set eth0 up
    ip -br addr

    # Step 2 - address and prefix
    ping -c2 -W1 10.20.0.65            # works: on the same /24 and the same link
    ping -c3 10.20.0.10                # fails: app01 thinks .10 is local
    ip route get 10.20.0.10            # "dev eth0" with no "via": on-link
    ip neigh show 10.20.0.10           # FAILED
    ip addr del 10.20.0.70/24 dev eth0
    ip addr add 10.20.0.70/26 dev eth0

    # Step 3 - gateway
    ip route
    ping -c2 -W1 198.51.100.10         # Network is unreachable
    ip route add default via 10.20.0.65

    # Step 4 - verify
    for t in 10.20.0.65 10.20.0.10 198.51.100.10; do ping -c1 -W1 "$t" >/dev/null && echo "$t OK" || echo "$t FAIL"; done
    ip route get 10.20.0.10
    ```

    **Expected output (captured, Ubuntu 24.04.5; MAC addresses vary):**

    ```text
    lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
    eth0@if12        DOWN           b6:e0:3a:1f:e2:4c <BROADCAST,MULTICAST>
    lo               UNKNOWN        127.0.0.1/8
    eth0@if12        DOWN           10.20.0.70/24
    lo               UNKNOWN        127.0.0.1/8
    eth0@if12        UP             10.20.0.70/24
    PING 10.20.0.65 (10.20.0.65) 56(84) bytes of data.
    64 bytes from 10.20.0.65: icmp_seq=1 ttl=64 time=0.048 ms
    64 bytes from 10.20.0.65: icmp_seq=2 ttl=64 time=0.168 ms

    --- 10.20.0.65 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1021ms
    rtt min/avg/max/mdev = 0.048/0.108/0.168/0.060 ms
    PING 10.20.0.10 (10.20.0.10) 56(84) bytes of data.
    From 10.20.0.70 icmp_seq=1 Destination Host Unreachable
    From 10.20.0.70 icmp_seq=2 Destination Host Unreachable
    From 10.20.0.70 icmp_seq=3 Destination Host Unreachable

    --- 10.20.0.10 ping statistics ---
    3 packets transmitted, 0 received, +3 errors, 100% packet loss, time 2045ms
    pipe 3
    10.20.0.10 dev eth0 src 10.20.0.70 uid 0
        cache
    10.20.0.10 dev eth0 FAILED
    10.20.0.64/26 dev eth0 proto kernel scope link src 10.20.0.70
    ping: connect: Network is unreachable
    10.20.0.65 OK
    10.20.0.10 OK
    198.51.100.10 OK
    10.20.0.10 via 10.20.0.65 dev eth0 src 10.20.0.70 uid 0
        cache
    ```

    `lo` shows `UNKNOWN`, which is normal for loopback. `@if12` is the index of the veth peer in the router namespace and varies between runs.

    **Task 4**

    ```bash
    mkdir -p ~/lab11/netplan-root/etc/netplan
    cat > ~/lab11/netplan-root/etc/netplan/60-app01.yaml <<'EOF'
    network:
      version: 2
      renderer: networkd
      ethernets:
        enp0s8:
          dhcp4: false
          addresses:
            - 10.20.0.70/26
          routes:
            - to: default
              via: 10.20.0.65
          nameservers:
            addresses: [10.20.0.1]
            search: [lab.internal]
    EOF
    chmod 600 ~/lab11/netplan-root/etc/netplan/60-app01.yaml
    sudo netplan generate --root-dir ~/lab11/netplan-root
    cat ~/lab11/netplan-root/run/systemd/network/10-netplan-enp0s8.network
    # break it on purpose, validate, restore
    sed -i 's#10.20.0.70/26#10.20.0.70#' ~/lab11/netplan-root/etc/netplan/60-app01.yaml
    sudo netplan generate --root-dir ~/lab11/netplan-root
    sed -i 's#- 10.20.0.70$#- 10.20.0.70/26#' ~/lab11/netplan-root/etc/netplan/60-app01.yaml
    ```

    Expected output (captured; `systemctl`/reload messages from the scratch root omitted, path shortened):

    ```text
    [Match]
    Name=enp0s8

    [Network]
    LinkLocalAddressing=ipv6
    Address=10.20.0.70/26
    DNS=10.20.0.1
    Domains=lab.internal

    [Route]
    Destination=0.0.0.0/0
    Gateway=10.20.0.65
    .../netplan-root/etc/netplan/60-app01.yaml:8:9: Error in network definition: address '10.20.0.70' is missing /prefixlength
            - 10.20.0.70
            ^
    ```

    On a **real** server you would then copy the file to `/etc/netplan/`, keep `chmod 600`, back up the old files (`sudo cp -a /etc/netplan "/root/netplan-backup-$(date +%F)"`) and run `sudo netplan try` from the console.

    **Task 5 (inside lab11-app; replace `/home/student` with your home)**

    ```bash
    ip -j addr show dev eth0 > /home/student/lab11/app01.json
    grep -o '"prefixlen":[0-9]*' /home/student/lab11/app01.json
    ```

    To practise `diff`, take a snapshot before and after a change, for example on the router namespace: `sudo ip netns exec lab11-gw ip route > ~/lab11/gw-before.txt`, add `sudo ip netns exec lab11-gw ip route add 172.16.0.0/16 via 10.20.0.70`, snapshot `gw-after.txt`, `diff ~/lab11/gw-before.txt ~/lab11/gw-after.txt`, then delete the route again.

    Expected output (captured):

    ```text
    "prefixlen":26
    2a3
    > 172.16.0.0/16 via 10.20.0.70 dev eth0
    ```

??? success "PowerShell solution"
    **Task 1**

    ```powershell
    New-Item -ItemType Directory -Path $HOME\lab11 -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
    Get-NetIPConfiguration -Detailed | Out-File "$HOME\lab11\win-baseline-$stamp.txt"
    ipconfig /all | Out-File "$HOME\lab11\win-baseline-$stamp.txt" -Append

    $cfg  = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
    $ipif = Get-NetIPInterface -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4
    $addr = Get-NetIPAddress -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4 | Select-Object -First 1
    [pscustomobject]@{
        Adapter   = $cfg.InterfaceAlias
        MAC       = (Get-NetAdapter -InterfaceIndex $cfg.InterfaceIndex).MacAddress
        IPv4      = "$($addr.IPAddress)/$($addr.PrefixLength)"
        Origin    = $addr.PrefixOrigin
        Lifetime  = $addr.ValidLifetime
        Gateway   = $cfg.IPv4DefaultGateway.NextHop
        DNS       = ($cfg.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses -join ', '
        DHCP      = $ipif.Dhcp
        MTU       = $ipif.NlMtu
        Profile   = (Get-NetConnectionProfile -InterfaceIndex $cfg.InterfaceIndex).NetworkCategory
    } | Format-List | Tee-Object -FilePath $HOME\lab11\win-record.txt

    Find-NetRoute -RemoteIPAddress 1.1.1.1
    ```

    **Task 2**

    ```powershell
    # Same .NET maths as Day 11 Demo 7, wrapped in a function
    function Get-Subnet {
        param([Parameter(Mandatory)][string]$Address, [Parameter(Mandatory)][ValidateRange(0,32)][int]$Prefix)
        $toIp = { param($n) $b = [BitConverter]::GetBytes([uint32]$n); [array]::Reverse($b); [System.Net.IPAddress]::new($b).ToString() }
        $bytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes(); [array]::Reverse($bytes)
        $addr = [BitConverter]::ToUInt32($bytes, 0)
        $mask = [uint32]([math]::Pow(2,32) - [math]::Pow(2, 32 - $Prefix))
        $net  = $addr -band $mask; $bc = $net -bor (-bnot $mask -band [uint32]::MaxValue)
        [pscustomobject]@{ Network = & $toIp $net; FirstHost = & $toIp ($net + 1); LastHost = & $toIp ($bc - 1)
                           Broadcast = & $toIp $bc; Hosts = $bc - $net - 1 }
    }
    Get-Subnet -Address 10.20.0.70 -Prefix 26
    (Get-Subnet 10.20.0.70 26).Network -eq (Get-Subnet 10.20.0.10 26).Network   # False
    (Get-Subnet 10.20.0.70 26).Network -eq (Get-Subnet 10.20.0.65 26).Network   # True
    ```

    **Expected output (captured with PowerShell 7.4.6 on Linux; the function uses only .NET and runs in 5.1 too):**

    ```text
    Network    FirstHost  LastHost    Broadcast   Hosts
    -------    ---------  --------    ---------   -----
    10.20.0.64 10.20.0.65 10.20.0.126 10.20.0.127    62
    False
    True
    ```

    **Task 3 — the Windows equivalent of the repair (do not run on your own PC; for reference on a lab VM, elevated):**

    ```powershell
    Enable-NetAdapter -Name 'Ethernet 2' -WhatIf
    Remove-NetIPAddress -InterfaceAlias 'Ethernet 2' -IPAddress 10.20.0.70 -WhatIf
    New-NetIPAddress -InterfaceAlias 'Ethernet 2' -IPAddress 10.20.0.70 -PrefixLength 26 -DefaultGateway 10.20.0.65 -WhatIf
    Set-DnsClientServerAddress -InterfaceAlias 'Ethernet 2' -ServerAddresses 10.20.0.1 -WhatIf
    ```

    **Task 5**

    ```powershell
    Get-NetIPAddress -AddressFamily IPv4 |
        Select-Object InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin, AddressState |
        Export-Csv -Path $HOME\lab11\win-ip.csv -NoTypeInformation
    Import-Csv $HOME\lab11\win-ip.csv | Format-Table
    ```

    **Task 6 — fault finding:**

    | Clue | Meaning | Next command |
    |---|---|---|
    | `Autoconfiguration IPv4 Address 169.254.81.177`, mask `255.255.0.0` | APIPA: DHCP got no answer | `Get-NetAdapter -Name Wi-Fi` (associated?), then `ipconfig /renew "Wi-Fi"` |
    | `Default Gateway` empty | No DHCP options received, so no route off the link | `Get-NetRoute -DestinationPrefix 0.0.0.0/0` |
    | DNS `fec0:0:0:ffff::1%1` … | Windows' placeholder site-local DNS addresses when none were received (deprecated `fec0::/10`) | `Get-DnsClientServerAddress -InterfaceAlias Wi-Fi` after the renew (Day 13) |

??? success "Answers to questions"
    1. With `/24`, both `10.20.0.65` and `10.20.0.10` look local. `.65` really **is** on the same link (the router's server-side interface), so ARP succeeded. `.10` lives on the management segment behind the router; nobody on app01's link owns it, so ARP failed.
    2. The error comes from app01's **own** address, so the failure is local: app01 could not resolve the next hop's MAC address. The router, DNS and the remote side are not involved yet.
    3. A route's gateway must be reachable on a **connected** network. A downed interface has no connected routes, and with the wrong prefix the gateway may be outside the connected subnet (*Nexthop has invalid gateway*). Fix layer 1–2 and the address first.
    4. `ip` changes are runtime-only and disappear at reboot (or when the link flaps, for the default route). Persistent configuration in netplan (Task 4) — or the persistent store on Windows — prevents that.
    5. `netplan try` reverts automatically after the timeout (120 s by default) unless you confirm, so a change that cuts your SSH session undoes itself. `apply` does not.
    6. `fec0:0:0:ffff::1–3` are well-known placeholder addresses from the deprecated IPv6 site-local range. Windows shows them when it has **no** DNS server configuration, which is consistent with the failed DHCP.
    7. `Enable-NetAdapter`, `Remove-NetIPAddress`, `New-NetIPAddress -PrefixLength 26 -DefaultGateway 10.20.0.65` and `Set-DnsClientServerAddress`. All of them support `-WhatIf` (and `-Confirm`).

## Clean-up

```bash
ip netns list | grep lab11                    # preview
sudo ip netns del lab11-app
sudo ip netns del lab11-mgmt
sudo ip netns del lab11-gw
ip netns list | grep lab11 || echo "lab11 namespaces removed"
```

Deleting a namespace also deletes the veth interfaces inside it. Keep `~/lab11` (your evidence files) or remove it after reviewing: `ls -R ~/lab11 && rm -rI ~/lab11`. On Windows: `Remove-Item $HOME\lab11 -Recurse -WhatIf`, then without `-WhatIf`.
