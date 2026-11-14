---
description: "Release history of the course."
---

# Changelog

All notable changes are listed here, newest first. Nightly releases add two days each.

## 2026-11-14 — v0.8.0 (nightly release: Days 15–16, Module 3 complete, Module 4 begins)

- **Day 15** Network Interfaces and Diagnostics (interface types and predictable names; link flags `UP`/`LOWER_UP`/`NO-CARRIER`, operstate and carrier changes; MTU and MAC; `ip -s -s link` error, drop, overrun and carrier counters, `ip -d link`, `ip -br`/`-j`, `/sys/class/net`; `ethtool` speed/duplex/autonegotiation, `-i`, `-k`, `-S`; neighbour states REACHABLE/STALE/DELAY/PROBE/INCOMPLETE/FAILED/PERMANENT, `ip neigh del`/`flush`, `ip monitor link|neigh`, `arping` and duplicate-address detection with `-D`; MTU black holes with `ping -M do` and `tracepath`; `tcpdump` with `-i -n -c -e -v -w -r`, BPF capture filters, ring buffers and privilege dropping; `tshark`/Wireshark display filters vs capture filters; capture ethics; `Get-NetAdapter`, `Get-NetAdapterStatistics`, `Get-NetAdapterAdvancedProperty`, `Restart-NetAdapter`/`Disable-NetAdapter` with `-WhatIf`, `Get-NetNeighbor`/`Remove-NetNeighbor`, `Get-NetIPInterface` NlMtu, `ping -f -l`, `pktmon` and `netsh trace`, cross-platform .NET `NetworkInterface` statistics), with **Lab 15: Flapping Link, Silent Drops** (four layer-1/2 faults on an isolated namespace switch).
- New scripts: **`network-diagnostic.sh`** and **`Network-Diagnostic.ps1`** (read-only layered check: link state, carrier, MTU/MAC, speed/duplex, addresses, error and drop counters, default route, gateway neighbour state and ping, DNS configuration and lookup, TCP connect test; OK/WARN/FAIL per check, text/CSV(/JSON) output, exit code 3 on any failure), documented in the Script Library.
- **Day 16** System Logs (the Linux log pipeline: kernel ring buffer, systemd-journald, rsyslog and `/var/log`; Ubuntu 24.04 RFC 3339 syslog timestamps; facilities and severities 0–7; `journalctl` `-u -b -k -p --since/--until -g -o short-iso/json/cat/verbose`, trusted fields, `--disk-usage`, `--vacuum-*` and `--verify`, journal persistence and access groups; `dmesg` and `dmesg_restrict`; `logger` and `systemd-cat`; `zgrep` on rotated logs; `logrotate` incl. `-d` dry runs; `last`/`lastb`; time zones and log integrity; Windows Event Log architecture, levels and key event IDs (41, 104, 1074, 1102, 6005/6006/6008, 7036, 7045); `Get-WinEvent` `-ListLog`, `-FilterHashtable`, `-FilterXPath`, `-Path`, `ToXml()`; `Get-EventLog` (5.1 only); `wevtutil` `el/gli/qe/epl`; `eventcreate`/`New-WinEvent`; journal JSON in PowerShell 7 on Linux), with **Lab 16: What Happened at 03:12?** (rebuild an overnight intrusion and outage from current and rotated logs).
- New scripts: **`log-analyser.sh`** and **`Log-Analyser.ps1`** (read-only summary of the last N hours from the journal, syslog files or Windows Event Logs: counts by severity, top programs/providers and normalised messages, kernel errors, failed SSH/sudo authentication counts; exit code 3 above an error threshold), documented in the Script Library.
- **Module 3 test** (25 questions, 38 marks, Days 11–15) released; the **Networking & Troubleshooting Guide** PDF is now available on the Downloads page.
- Command reference: new **Interfaces & Packet Capture** and **Logs** categories for Linux and PowerShell, plus *Networking: interfaces and packet capture* and *Logs* comparison tables.
- Day 14 now links to Day 15; course, module, lab, schedule, assessment, download, reference and script-library indexes updated.

## 2026-11-13 — v0.7.0 (nightly release: Days 13–14)

- **Day 13** DNS Troubleshooting (the DNS hierarchy and resolution path; stub, recursive and authoritative servers and the `aa`/`rd`/`ra`/`ad` flags; A, AAAA, CNAME, MX, NS, SOA, PTR, TXT (SPF/DMARC), SRV and CAA records; TTL, negative caching and TTL lowering before migrations; NOERROR vs NODATA vs NXDOMAIN vs SERVFAIL vs REFUSED vs connection refused vs timeout; systemd-resolved stub/uplink/static/foreign resolv.conf modes, `resolvectl status`/`query`/`flush-caches`/`statistics`, `nsswitch.conf`, `/etc/hosts` and why `dig` disagrees with applications; `dig` (`@server`, `+short`, `+noall +answer`, `-x`, `+norecurse`, `+trace`, `+tcp`, `+dnssec`, `+search`, exit codes), `host`, `nslookup`, `getent hosts/ahosts`; `Resolve-DnsName` (`-Type`, `-Server`, `-DnsOnly`, `-NoHostsFile`, `-CacheOnly`, `-NoRecursion`, `-QuickTimeout`, `-TcpOnly`, error IDs), `Get-DnsClientServerAddress`, `Set-DnsClientServerAddress -WhatIf`, `Get-DnsClientCache`, `Clear-DnsClientCache`, NRPT, `ipconfig /displaydns /flushdns`, the Windows hosts file and `[System.Net.Dns]`; DNS tunnelling, DGA NXDOMAIN bursts, hosts-file tampering, LLMNR poisoning, DoH/DoT, split-horizon leaks, zone transfers and dangling CNAMEs), with **Lab 13: Name Resolution Failure** (client, recursive resolver, authoritative BIND server and web server in isolated namespaces; six faults: wrong nameserver, stale hosts entry, missing record with negative caching, broken zone/SERVFAIL, firewalled resolver, missing PTR).
- New scripts: **`dns-check.sh`** and **`DNS-Check.ps1`** (forward lookups of several names and record types across the system resolver and individual DNS servers, status/TTL/query time, resolver-consistency check, optional PTR and forward-confirmation check, text/CSV(/JSON) output, exit code 3 on any failure, disagreement or PTR problem), documented in the Script Library.
- **Day 14** Ports, Sockets and Connections (well-known/registered/ephemeral ports and the Linux 32768–60999 vs Windows 49152–65535 ranges, `/etc/services`, privileged ports and `ip_unprivileged_port_start`; sockets and the 5-tuple; TCP vs UDP; listening vs established and inbound vs outbound; `0.0.0.0`/`::`/`127.0.0.1` binding and dual-stack; the three-way handshake and every TCP state, who holds TIME-WAIT and who causes CLOSE-WAIT; Recv-Q/Send-Q for LISTEN (accept queue, backlog) vs ESTAB; `ss` `-tulnp`, state filters, expressions, `-H -o -e -i -s`, `-K`; legacy `netstat`; `lsof -i`; `fuser`; `/proc/net/tcp` and socket inodes; systemd socket activation; `EADDRINUSE`/10048 and the TIME-WAIT/`SO_REUSEADDR` trap; ephemeral-port exhaustion; listen-queue overflows; `Get-NetTCPConnection`, `Get-NetUDPEndpoint`, `OwningProcess` → `Get-Process`/`Win32_Service`, `netstat -ano`/`-b`, `tasklist /svc`, `Get-NetTCPSetting` and `netsh` dynamic/excluded port ranges, PID 4 and PID 0, cross-platform `IPGlobalProperties`; listening-port baselines and suspicious listeners/beacons), with **Lab 14: Who Owns Port 443?**
- New scripts: **`port-monitor.sh`** and **`Port-Monitor.ps1`** (listening TCP/UDP ports with owning process/services, exposure check for listeners on all addresses, baseline save/compare with NEW/GONE, TCP state summary, text/CSV(/JSON) output, shared baseline format, exit code 3 on a new listener or exposed port), documented in the Script Library.
- Both Linux labs run in isolated network namespaces (BIND resolver/authoritative servers for Lab 13; app and client namespaces for Lab 14), so faults can be practised without touching the real resolver configuration or services.
- Command reference: new **DNS** and **Ports & Sockets** categories for Linux and PowerShell, plus *Networking: DNS* and *Networking: ports and sockets* comparison tables.
- Day 12 now links to Day 13; course, module, lab, schedule, assessment, reference and script-library indexes updated.

## 2026-11-12 — v0.6.0 (nightly release: Days 11–12, Module 3 begins)

- **Day 11** IP Configuration (address, prefix, gateway and DNS; subnet maths and special ranges incl. RFC 1918, CGNAT, APIPA and IPv6 address types; MAC/ARP and the neighbour cache; routing tables and longest-prefix match; MTU; DHCP vs static; runtime vs persistent configuration; `ip addr`/`link`/`route`/`neigh`, `ip route get`, `-br`/`-o`/`-j`, `ipcalc`, netplan `get`/`generate`/`try`/`apply`, `nmcli`, `networkctl`; `Get-NetIPConfiguration`, `Get-NetIPAddress` (`PrefixOrigin`, `AddressState`), `Get-NetAdapter`, `Get-NetIPInterface`, `Get-NetRoute`, `Find-NetRoute`, `Get-NetNeighbor`, `New-NetIPAddress`/`Set-NetIPInterface` with `-WhatIf` and `-PolicyStore`, `ipconfig`, `route print`, the cross-platform .NET `NetworkInterface` class), with **Lab 11: Address Audit**.
- **Day 12** Connectivity Troubleshooting (layered method; ICMP messages and who sends them; TTL and RTT; `ping` options and exit codes; `traceroute` UDP/ICMP/TCP, `tracepath` and path MTU, `mtr` reports and intermediate-hop rate limiting; refused vs timed out vs unreachable; return-path problems; `nc -zv`, `curl -w` timings; `Test-Connection` in 5.1 vs 7 (`-TcpPort`, `-Traceroute`, `-MtuSize`), `Test-NetConnection -Port`/`-TraceRoute`/`-InformationLevel`, `ping.exe`, `tracert`, `pathping`, `TcpClient` port tests), with **Lab 12: Can't Reach the Server**.
- Both labs run in isolated Linux network namespaces (client/router/server), so faults can be practised without touching the real network.
- Command reference: new **Networking** category for Linux and PowerShell, plus *Networking: IP configuration* and *Networking: connectivity* comparison tables.
- Day 10 now links to Day 11; course, module, lab, schedule, assessment and reference indexes updated.

## 2026-11-11 — v0.5.0 (nightly release: Days 09–10, Module 2 complete)

- **Day 09** Disk and Storage Management (the storage stack, MBR/GPT, ext4/XFS/Btrfs/NTFS/ReFS, `df` incl. `-i` and `--output`, `du -x`/`--apparent-size`, `lsblk`, `blkid`, `findmnt -T`/`--verify`, `mount`/`umount`/remount, `/etc/fstab` with `UUID=` and `nofail`, reserved blocks, inode exhaustion, deleted-but-open files with `lsof +L1`, practice loop devices, LVM `pvs`/`vgs`/`lvs`/`lvextend -r`, swap, `e2fsck -n`; `Get-PSDrive`, `Get-Volume`, `Get-Disk`, `Get-Partition`, `Get-PhysicalDisk`, `Win32_LogicalDisk`, `DriveInfo`, folder sizes with `Measure-Object`, VHDX practice disks, `Initialize-Disk`/`New-Partition`/`Format-Volume`, `Repair-Volume`, `chkdsk /scan`, WinSxS cleanup), with **Lab 09: Disk Full**.
- **Day 10** Software and Package Management (repositories, deb822 `ubuntu.sources`, `signed-by` keyrings, `apt update`/`upgrade`/`full-upgrade`, phased and kept-back updates, `install`/`remove`/`purge`/`autoremove`, `apt-mark hold`, `dpkg -l/-L/-S/-s/--verify`, `dpkg-query`, local `.deb` packages, unattended-upgrades, `reboot-required`, history logs, snap, dnf/rpm; winget `search`/`show`/`install`/`upgrade`/`uninstall`/`list`/`export`/`import`/`pin`, the Uninstall registry keys instead of `Win32_Product`, `Get-Package` (5.1), `Get-HotFix`, pending-reboot keys, optional features and capabilities, PowerShellGet and PSResourceGet), with **Lab 10: Software Inventory**.
- New scripts: **`disk-monitor.sh`** and **`Disk-Monitor.ps1`** (filesystem/volume usage with warning/critical thresholds, inode check on Linux, largest directories, text/CSV(/JSON) output, exit code 3 on breach), documented in the Script Library.
- **Module 2 test** (25 questions, 38 marks, collapsible answer key and practical task) in Assessments.
- Command reference: new **Storage** and **Packages** categories for Linux and PowerShell, plus matching comparison tables.
- Day 08 now links to Day 09; course, module, lab, schedule and assessment indexes updated.

## 2026-11-10 — v0.4.0 (nightly release: Days 07–08)

- **Day 07** File Permissions and Access Control (`ls -l`/`stat` permission strings, `chmod` numeric and symbolic incl. `X`, `chown`, `chgrp`, `umask` (0022 vs 0002 via `pam_umask`), setuid/setgid/sticky bits, `find -perm` audits, POSIX ACLs with `getfacl`/`setfacl` and `getfacl -R` backups, `chattr`/`lsattr`; NTFS DACLs, ACEs, inheritance and deny precedence, `Get-Acl`, `Set-Acl`, `FileSystemAccessRule`, `SetAccessRuleProtection`, `icacls /save /restore /grant /remove /inheritance`, `takeown`), with **Lab 07: Lock It Down**.
- **Day 08** Processes and Services (PIDs, process states, jobs, `ps`, `top`, `htop`, `pgrep`/`pkill`, signals and `kill`, `nice`/`renice`, `/proc/PID`, `systemctl`, `journalctl -u`; `Get-Process`, `Stop-Process`, `Start-Process`, `Wait-Process`, `Win32_Process` command lines, `Get-Service`, `Start/Stop/Restart-Service`, `Set-Service`, `sc.exe`, `tasklist`/`taskkill`, Service Control Manager events), with **Lab 08: Runaway Process**.
- New scripts: **`process-monitor.sh`** and **`Process-Monitor.ps1`** (top processes by sampled CPU and memory, thresholds, text/CSV(/JSON) output, exit code 3 on breach), documented in the Script Library.
- Command reference: new **Permissions** and **Processes & Services** categories for Linux and PowerShell, plus matching comparison tables.
- Day 06 now links to Day 07; course, module, lab, schedule and assessment indexes updated.

## 2026-11-09 — v0.3.0 (nightly release: Days 05–06)

- **Day 05** Command Help, History and Pipelines (`man` sections, `man -k`/`-f`, `--help`, `help`, `type -a`, `command -v`, `history`, `fc`, history expansion, `HISTCONTROL`/`HISTTIMEFORMAT`; `Get-Help -Examples/-Parameter/-Online`, `Get-Command -All/-ParameterName`, `Get-Alias -Definition`, `Get-Member`, `Get-History`, `Invoke-History`, PSReadLine history; text vs object pipelines, `;` `&&` `||` (PowerShell 7+), `$?`, `PIPESTATUS`, `pipefail`, `$LASTEXITCODE`, `-ErrorAction`, `try`/`catch`/`finally`), with **Lab 05: Pipeline Builder**.
- **Day 06** Users and Groups (`/etc/passwd`, `/etc/shadow`, `/etc/group`, `id`, `getent`, `useradd`, `adduser` (Debian/Ubuntu), `usermod -aG`, `passwd`, `chage`, `userdel`, `groupadd`, `gpasswd`; `Get-LocalUser`, `New-LocalUser`, `Set-LocalUser`, `Disable-LocalUser`, `Remove-LocalUser`, `Add-LocalGroupMember`, `Get-LocalGroupMember`, `net user`, `whoami /groups`; onboarding, offboarding and account audits), with **Lab 06: Onboard & Offboard**.
- **Module 1 test** (25 questions, 38 marks, collapsible answer key and practical task) in Assessments.
- Command reference: new **Pipelines, History & Exit Codes** and **Users & Groups** categories for Linux and PowerShell, plus matching comparison tables.
- Day 04 now links to Day 05; course, module, lab, schedule and assessment indexes updated.

## 2026-11-08 — v0.2.0 (nightly release: Days 03–04)

- **Day 03** Reading and Managing Files (`cat`, `less`, `head`, `tail -F`, `wc`, `Get-Content -TotalCount/-Tail/-Wait`, `Measure-Object`, redirection, `Out-File`, `Tee-Object`, the six PowerShell streams, encodings and line endings), with **Lab 03: Log Reader**.
- **Day 04** Searching Files and Text (`find`, `grep`, `xargs`, `locate`/`plocate`, `which`, `type`, `command -v`, `Get-ChildItem -Recurse`, `Select-String`, `Where-Object`, `Get-Command`, wildcards vs regular expressions), with **Lab 04: Needle in the Haystack**.
- Command reference: new **Reading Files & Redirection** and **Searching** categories for Linux and PowerShell, plus matching comparison tables.
- Day 02 now links to Day 03; course, module, lab, schedule and assessment indexes updated.
- Fix: the `Move-Item / Rename-Item` reference example rendered `$_` as italics on the site; it now uses `$PSItem`.

## 2026-11-08 — v0.1.0 (launch)

- Site, navigation, search, light/dark themes and CI/CD to GitHub Pages.
- **Day 01** Introduction to Linux and PowerShell, with **Lab 01**.
- **Day 02** File and Directory Management, with **Lab 02**.
- Getting Started guides: Windows, Ubuntu, WSL2, PowerShell 7, lab safety.
- Command reference (navigation, help, files) for Linux and PowerShell, plus a comparison table.
- Career pathways: SOC Analyst, Network Analyst, System Administrator.
- Scripts: `system-info.sh`, `System-Info.ps1`.
- PDFs: complete handbook (published days), Linux and PowerShell cheat sheets, lab workbook.
