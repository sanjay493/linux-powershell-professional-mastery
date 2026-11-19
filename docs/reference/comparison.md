---
description: "Task-oriented Bash and PowerShell equivalents, updated with each lesson."
---

# Bash ↔ PowerShell Side-by-Side

Rows are added as each day is released. ⚠ marks behaviour that differs in an important way.

## Identity & system

| Task | Bash (Ubuntu) | PowerShell | Notes |
|---|---|---|---|
| Current user | `whoami` | `whoami` · `$env:USERNAME` | |
| Host name | `hostname` | `hostname` · `$env:COMPUTERNAME` | |
| OS version | `cat /etc/os-release` | `Get-ComputerInfo -Property OsName,OsVersion` | Windows-only cmdlet |
| Kernel / build | `uname -r` | `[Environment]::OSVersion.Version` | |
| Architecture | `uname -m` | `$env:PROCESSOR_ARCHITECTURE` | |
| Shell version | `echo $BASH_VERSION` | `$PSVersionTable.PSVersion` | |
| Date / UTC | `date` · `date -u` | `Get-Date` · `(Get-Date).ToUniversalTime()` | |
| ISO timestamp | `date -Iseconds` | `Get-Date -Format o` | |

## Help

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| Full help | `man cmd` | `Get-Help cmd -Full` | `Update-Help` first |
| Examples | `man cmd` (EXAMPLES section) | `Get-Help cmd -Examples` | |
| Find commands | `apropos word` | `Get-Command *word*` | |
| What runs? | `type -a name` | `Get-Command name -All` | |

## Navigation & files

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| Where am I | `pwd` | `Get-Location` | |
| List (incl. hidden) | `ls -la` | `Get-ChildItem -Force` | ⚠ `ls -la` fails in PowerShell |
| Recursive list | `ls -R` | `Get-ChildItem -Recurse` | |
| Change dir | `cd dir` | `Set-Location dir` | |
| Previous dir | `cd -` | `Set-Location -` | 6.2+ only |
| Make dirs | `mkdir -p a/b` | `New-Item a\b -ItemType Directory -Force` | |
| New empty file | `touch f` | `New-Item f -ItemType File` | ⚠ `-Force` overwrites |
| Copy | `cp a b` | `Copy-Item a b` | |
| Copy tree | `cp -r a b` | `Copy-Item a b -Recurse` | Same nesting rule |
| Move / rename | `mv a b` | `Move-Item a b` · `Rename-Item a -NewName b` | |
| Delete | `rm f` | `Remove-Item f` | No recycle bin |
| Delete tree | `rm -r d` | `Remove-Item d -Recurse` | |
| Force | `rm -rf d` | `Remove-Item d -Recurse -Force` | ⚠ `-rf` is not a PS parameter |
| Simulate | *(preview with ls)* | `-WhatIf` | |
| Exists? | `[ -e p ]` | `Test-Path p` | |
| Literal name | `'a[1].txt'` | `-LiteralPath 'a[1].txt'` | |

## Reading files & redirection

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| Show file | `cat f` | `Get-Content f` | `cat` is an alias only on Windows |
| Invisible characters | `cat -A f` | `Format-Hex f` | |
| Page | `less f` | <code>Get-Content f &#124; Out-Host -Paging</code> | No search in PowerShell |
| First N lines | `head -n N f` | `Get-Content f -TotalCount N` | |
| Last N lines | `tail -n N f` | `Get-Content f -Tail N` | |
| Skip header | `tail -n +2 f` | <code>Get-Content f &#124; Select-Object -Skip 1</code> | |
| Line range | `sed -n '10,20p' f` | <code>Get-Content f &#124; Select-Object -Skip 9 -First 11</code> | ⚠ arrays are zero-based |
| Follow | `tail -F f` | `Get-Content f -Tail 0 -Wait` | `-F` survives rotation |
| Count lines | `wc -l f` | `(Get-Content f).Count` | |
| Words / characters | `wc -w f` · `wc -m f` | <code>Get-Content f &#124; Measure-Object -Word -Character</code> | |
| Overwrite / append | `>` / `>>` | `>` / `>>` · `Out-File [-Append]` | ⚠ 5.1 writes UTF-16 LE |
| Errors to file | `2> f` | `2> f` | |
| All output to file | `&> f` · `> f 2>&1` | `*> f` | |
| Discard | `> /dev/null` · `2>/dev/null` | <code>&#124; Out-Null</code> · `2>$null` | |
| Save and show | <code>&#124; tee [-a] f</code> | <code>&#124; Tee-Object [-Append] f</code> | |
| Refuse overwrite | `set -o noclobber` | `Out-File -NoClobber` | |
| Input from file | `cmd < f` | <code>Get-Content f &#124; cmd</code> | ⚠ no `<` in PowerShell |
| Privileged append | <code>echo x &#124; sudo tee -a f</code> | Elevated session + `Add-Content` | |

## Searching

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| Find by name | `find . -name '*.log'` | `Get-ChildItem -Recurse -Filter *.log` | Quote Bash patterns |
| Files / folders only | `-type f` / `-type d` | `-File` / `-Directory` | |
| Depth limit | `-maxdepth N` | `-Depth N` | 5.0+ |
| Size | `-size +100M` | `Where-Object Length -gt 100MB` | |
| Age | `-mtime -1` · `-mmin -30` | `Where-Object LastWriteTime -gt (Get-Date).AddDays(-1)` | |
| Hidden | `-name '.*'` | `-Force` / `-Hidden` | |
| Act on results | `-exec cmd {} +` | <code>&#124; ForEach-Object { }</code> | |
| Delete results | `-delete` (last, after preview) | <code>&#124; Remove-Item -WhatIf</code> | |
| Search text | `grep 'x' f` | `Select-String -Pattern 'x' -Path f` | ⚠ opposite case defaults |
| Ignore case / match case | `-i` | default / `-CaseSensitive` | |
| Invert | `-v` | `-NotMatch` | |
| Count | `-c` | `(Select-String ...).Count` | |
| Matching file names | `-l` | <code>-List &#124; Select-Object -ExpandProperty Path</code> | |
| Recursive | `grep -r` | <code>Get-ChildItem -Recurse &#124; Select-String</code> | |
| Context | `-C N` | `-Context N` | |
| Literal | `-F` | `-SimpleMatch` | |
| Only the match | `-o` | `-AllMatches` + `.Matches.Value` | |
| Quiet test | `-q` | `-Quiet` | |
| Indexed name search | `locate` | — | |
| Which program runs | `command -v` · `type -a` · `which -a` | `Get-Command [-All]` · `where.exe` | ⚠ `where` = `Where-Object` |

## Help, history & pipelines

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| What is this name? | `type -a name` | `Get-Command name -All` | |
| Dependency check | `command -v name` | `Get-Command name -ErrorAction SilentlyContinue` | |
| Reverse alias lookup | `alias` | `Get-Alias -Definition Get-ChildItem` | |
| Search help by keyword | `man -k word` · `apropos word` | `Get-Command *word*` · `Get-Help word` | |
| One option / parameter | `/` search in `man` | `Get-Help cmd -Parameter Name` | |
| Object members | — | <code>... &#124; Get-Member</code> | ⚠ text has no members |
| Session history | `history` | `Get-History` | ⚠ PS: current session only |
| Persistent history | `~/.bash_history` | `(Get-PSReadLineOption).HistorySavePath` | |
| Re-run entry N | `!N` | `Invoke-History N` · `r N` | |
| Reverse search | ++ctrl+r++ | ++ctrl+r++ | PSReadLine |
| Count and rank | <code>sort &#124; uniq -c &#124; sort -rn</code> | <code>Group-Object X &#124; Sort-Object Count -Descending</code> | |
| Sum a column | `awk '{ s += $10 } END { print s }'` | <code>(... &#124; Measure-Object Bytes -Sum).Sum</code> | |
| On success / failure | `a && b` · <code>a &#124;&#124; b</code> | 7+: `a && b` · <code>a &#124;&#124; b</code> · 5.1: `a; if ($?) { b }` | ⚠ 5.1 parser error |
| Last status | `$?` (0–255) | `$?` (Boolean) · `$LASTEXITCODE` | ⚠ |
| Every pipe stage | `${PIPESTATUS[@]}` | — | |
| Fail on any stage | `set -o pipefail` | `$ErrorActionPreference = 'Stop'` | Not identical |
| Catch an error | `if ! cmd; then …; fi` | `try { cmd -ErrorAction Stop } catch { … }` | |

## Users & groups

| Task | Bash (Ubuntu) | PowerShell (Windows only) | Notes |
|---|---|---|---|
| Who am I / my groups | `id` · `groups` | `whoami /user /groups` | |
| List local users | `getent passwd` | `Get-LocalUser` | |
| One user's details | `getent passwd NAME` · `chage -l NAME` | <code>Get-LocalUser NAME &#124; Select-Object &#42;</code> · `net user NAME` | |
| Create a user | `sudo useradd -m -s /bin/bash NAME` · `sudo adduser NAME` | `New-LocalUser -Name NAME -Password (Read-Host -AsSecureString)` | `adduser` is Debian/Ubuntu |
| Set a password | `sudo passwd NAME` | `Set-LocalUser -Name NAME -Password (Read-Host -AsSecureString)` | Never on the command line |
| Lock / disable | `sudo usermod -L -e 1 NAME` | `Disable-LocalUser -Name NAME` | `passwd -l` alone does not stop SSH keys |
| Unlock / enable | `sudo usermod -U -e '' NAME` | `Enable-LocalUser -Name NAME` | |
| Account expiry | `sudo chage -E 2026-12-31 NAME` | `Set-LocalUser -Name NAME -AccountExpires (Get-Date '2026-12-31')` | |
| Delete a user | `sudo userdel NAME` (home kept) | `Remove-LocalUser -Name NAME` (profile kept) | Archive data first |
| Create a group | `sudo groupadd NAME` | `New-LocalGroup -Name NAME` | |
| Add to group | `sudo usermod -aG GROUP NAME` · `sudo gpasswd -a NAME GROUP` | `Add-LocalGroupMember -Group GROUP -Member NAME` | ⚠ `-G` without `-a` replaces groups |
| Remove from group | `sudo gpasswd -d NAME GROUP` | `Remove-LocalGroupMember -Group GROUP -Member NAME` | |
| List group members | `getent group GROUP` | `Get-LocalGroupMember -Group GROUP` | |
| Admin group | `sudo` (Ubuntu) · `wheel` (RHEL family) | `Administrators` | |
| Extra UID 0 accounts | `awk -F: '$3 == 0' /etc/passwd` | <code>Get-LocalUser &#124; Where-Object SID -like '&#42;-500'</code> (built-in Administrator) | |

## Permissions

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Show permissions | `ls -l FILE` · `stat -c '%a %U:%G %n' FILE` | `Get-Acl FILE` · `icacls FILE` | `Get-Acl` is Windows-only |
| Full access list | `getfacl FILE` | `(Get-Acl FILE).Access` · `(Get-Acl FILE).AccessToString` | |
| Text baseline | `getfacl -R DIR` | `(Get-Acl DIR).Sddl` | |
| Permissions along a path | `namei -l /path/file` | `icacls` on each folder | |
| Set exact rights | `chmod 640 FILE` | `icacls FILE /inheritance:r /grant:r "User:(M)" "Group:(R)"` | |
| Targeted change | `chmod u+x,o= FILE` | `icacls FILE /grant "NAME:(RX)"` · `/remove:g NAME` | |
| Safe recursive change | `chmod -R u=rwX,go=rX DIR` | `icacls DIR /grant "Group:(OI)(CI)RX" /t` | |
| Extra user or group | `setfacl -m u:NAME:rX FILE` | `icacls FILE /grant "NAME:(RX)"` · `AddAccessRule()` + `Set-Acl` | |
| Remove one principal | `setfacl -x u:NAME FILE` | `icacls FILE /remove NAME` · `RemoveAccessRuleAll()` | |
| Change owner | `sudo chown USER FILE` | `icacls FILE /setowner USER` · `takeown /f FILE` | |
| Change group | `chgrp GROUP FILE` | — | NTFS primary group is rarely used |
| Defaults for new files | `umask 027` · `setfacl -d -m g:team:rwX DIR` | Inheritable ACEs `(OI)(CI)` on the parent | |
| Team folder | `chgrp team DIR && chmod 2770 DIR` | `icacls DIR /grant "Team:(OI)(CI)M"` | |
| Shared drop folder | `chmod 1777 DIR` | CREATOR OWNER inheritable ACE | No sticky bit on Windows |
| Disable inheritance | — | `icacls DIR /inheritance:d` (copy) or `:r` (remove) · `SetAccessRuleProtection()` | |
| Reset to inherited defaults | — | `icacls DIR\* /reset /t /c` | |
| Back up permissions | `getfacl -R DIR > perms.acl` | `icacls DIR /save perms.txt /t /c` | Always before a change |
| Restore permissions | `setfacl --restore=perms.acl` | `icacls PARENT /restore perms.txt` | Same working dir / parent folder |
| Simulate | `setfacl --test -m ...` | `Set-Acl ... -WhatIf` | `icacls` has no dry run |
| Setuid/setgid audit | `sudo find / -xdev -type f -perm /6000` | — | No setuid on Windows |
| World-writable audit | `sudo find / -xdev -type f -perm -o+w` | `Get-Acl` filter for `Everyone`/`Users` with Write/Modify/FullControl | |
| Immutable file | `sudo chattr +i FILE` | — (closest: Deny Delete ACE) | |

## Processes & services

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| List processes | `ps -ef` · `ps aux` | `Get-Process` · `tasklist` | |
| Custom columns, sorted | `ps -eo pid,ppid,user,%cpu,%mem,cmd --sort=-%cpu` | <code>Get-Process &#124; Sort-Object CPU -Descending &#124; Select-Object Name, Id, CPU, WS</code> | `CPU` = seconds, `%cpu` = lifetime average |
| Current CPU | `top -b -n 2 -d 1` · `process-monitor.sh` | two `Get-Process` samples · `Process-Monitor.ps1` | |
| Find by name / command line | `pgrep -af PATTERN` | `Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%x%'"` | |
| Parent process | `ps -o ppid= -p PID` · `pstree -p` | `Win32_Process.ParentProcessId` · `(Get-Process -Id n).Parent` (7.x) | |
| Owner | `ps -o user= -p PID` | `Get-Process -IncludeUserName` (elevated) · `GetOwner()` | |
| Graceful stop | `kill PID` | `taskkill /PID n` · `.CloseMainWindow()` | No signals on Windows |
| Force stop | `kill -KILL PID` | `Stop-Process -Id n` · `taskkill /F /PID n` | |
| Preview | `pgrep -a PATTERN` | `Stop-Process -Id n -WhatIf` | |
| Priority | `nice -n 19 cmd` · `renice -n 19 -p PID` | `(Get-Process -Id n).PriorityClass = 'Idle'` | |
| Background job | `cmd &` · `jobs` · `fg` · `bg` | `Start-Job` · `Get-Job` · `Receive-Job` | |
| Time limit | `timeout 30 cmd` | `Wait-Process -Id n -Timeout 30` | |
| Service status | `systemctl status NAME` | `Get-Service NAME` · `sc.exe query NAME` | |
| Start / stop / restart | <code>sudo systemctl start&#124;stop&#124;restart NAME</code> | `Start-Service` · `Stop-Service` · `Restart-Service` (elevated) | |
| Start at boot | `sudo systemctl enable --now NAME` | `Set-Service NAME -StartupType Automatic` | |
| Disable | `sudo systemctl disable --now NAME` · `mask` | `Set-Service NAME -StartupType Disabled` | |
| Failed services | `systemctl --failed` | <code>Get-Service &#124; Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }</code> | Not identical concepts |
| Service config | `systemctl cat NAME` · `systemctl show NAME` | `sc.exe qc NAME` · `Get-CimInstance Win32_Service -Filter "Name='NAME'"` | |
| Service logs | `journalctl -u NAME -n 50` | `Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'}` | |
| Dependencies | `systemctl list-dependencies [--reverse] NAME` | `Get-Service NAME -RequiredServices` / `-DependentServices` | |

## Storage

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Free space per filesystem | `df -hT -x tmpfs -x squashfs` | `Get-Volume` · `Get-PSDrive -PSProvider FileSystem` | `Get-PSDrive` also works on Linux |
| Filesystem holding a path | `df -h PATH` · `findmnt -T PATH` | `Get-Volume -FilePath PATH` | |
| Inodes | `df -i` | — | NTFS MFT grows dynamically |
| Folder size | `du -sh DIR` | <code>Get-ChildItem DIR -Recurse -File -Force &#124; Measure-Object Length -Sum</code> | Blocks vs logical length |
| Biggest sub-folders | <code>sudo du -xh -d 1 DIR &#124; sort -rh &#124; head</code> | `Get-ChildItem -Directory` + `Measure-Object` per folder | |
| Biggest files | `find DIR -xdev -type f -size +100M -exec ls -lh {} +` | <code>Get-ChildItem -Recurse -File &#124; Sort-Object Length -Descending &#124; Select-Object -First 10</code> | |
| Disks / partitions | `lsblk` · `sudo fdisk -l` | `Get-Disk` · `Get-Partition` · `Get-PhysicalDisk` | |
| UUID / label / type | `lsblk -f` · `sudo blkid` | `Get-Volume` (`FileSystemType`, `FileSystemLabel`, `UniqueId`) | |
| Mount / attach | `sudo mount DEV DIR` · `sudo losetup -f --show FILE` | `Set-Partition -NewDriveLetter` · `Mount-DiskImage` | |
| Unmount / detach | `sudo umount DIR` | `Dismount-DiskImage` · `Remove-PartitionAccessPath` | |
| Persistent mounts | `/etc/fstab` (UUID, `nofail`) + `sudo findmnt --verify` | Mount Manager remembers letters | |
| Who keeps it busy? | `sudo fuser -vm DIR` · `sudo lsof +L1` | Resource Monitor handles · Sysinternals `handle.exe` | |
| Create filesystem | `sudo mkfs.ext4 -L LABEL DEV` | `Format-Volume -FileSystem NTFS -NewFileSystemLabel LABEL` | Destructive |
| Grow | `sudo lvextend -r -l +100%FREE VG/LV` · `growpart` + `resize2fs` | `Resize-Partition -Size (Get-PartitionSupportedSize …).SizeMax` | |
| Check | `sudo e2fsck -n DEV` (unmounted) | `Repair-Volume -Scan` · `chkdsk C: /scan` | |
| Swap / page file | `swapon --show` · `free -h` | `Get-CimInstance Win32_PageFileUsage` | |
| Thresholded report | `disk-monitor.sh -m PATH -p PATH` | `Disk-Monitor.ps1 -DriveName X -FolderPath X:\` | Exit 3 on breach |

## Packages

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Refresh catalogue | `sudo apt update` | `winget source update` | |
| List upgrades | `apt list --upgradable` | `winget upgrade` | |
| Security updates | <code>apt list --upgradable &#124; grep -- -security</code> | Windows Update history · `Get-HotFix` | |
| Upgrade all | `sudo apt upgrade` · `sudo apt full-upgrade` | `winget upgrade --all` | |
| Search / details | `apt search` · `apt show` · `apt policy` | `winget search` · `winget show --id ID -e` | |
| Simulate | `apt-get -s install PKG` | `winget show` · `-WhatIf` (cmdlets) | |
| Install | `sudo apt install PKG` · `sudo apt install ./file.deb` | `winget install --id ID -e --source winget` · `msiexec /i file.msi` | |
| Hold / pin | `sudo apt-mark hold PKG` | `winget pin add --id ID` | |
| Remove | `sudo apt remove PKG` | `winget uninstall --id ID -e` | |
| Remove with config | `sudo apt purge PKG` | — | |
| Unneeded dependencies | `sudo apt autoremove` | — | |
| Inventory | `dpkg -l` · `dpkg-query -W` | Uninstall registry keys · `winget list` · `Get-Package` (5.1) | Never `Win32_Product` |
| Owner of a file | `dpkg -S PATH` | — (`InstallLocation`, signature) | |
| Files of a package | `dpkg -L PKG` | — | |
| Verify | `dpkg --verify PKG` | `Get-AuthenticodeSignature` · `sfc /verifyonly` | |
| History | `/var/log/apt/history.log` · `/var/log/dpkg.log` | `MsiInstaller` events 1033/1034 | |
| Reboot required | `/var/run/reboot-required` | `RebootRequired` / `RebootPending` registry keys | |
| Baseline export | `apt-mark showmanual` | `winget export -o apps.json` | |
| OS components | `apt install` | `Get-WindowsOptionalFeature` · `Get-WindowsCapability` | Elevated |
| Shell modules | — | `Install-PSResource -Scope CurrentUser` · `Install-Module -Scope CurrentUser` | PSResourceGet built into 7.4+ |
| RHEL family | `dnf check-update` (exit 100) · `rpm -qf` · `dnf history undo` | — | |

## Networking: IP configuration

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Overview | `ip -br addr` · `ip -br link` | `Get-NetIPConfiguration` · `ipconfig` | `Net*` cmdlets are Windows-only |
| Full detail | `ip addr` · `ip -d link` | `ipconfig /all` · `Get-NetIPConfiguration -Detailed` | |
| Address origin / lease | `dynamic`, `valid_lft` in `ip addr` | `Get-NetIPAddress` (`PrefixOrigin`, `ValidLifetime`) | |
| APIPA / duplicates | No IPv4 address shown | `Get-NetIPAddress -PrefixOrigin WellKnown` · `-AddressState Duplicate` | |
| MAC, link speed | `ip link` · `ethtool IFACE` | `Get-NetAdapter` | |
| Counters | `ip -s link` | `Get-NetAdapterStatistics` | |
| MTU / metric / DHCP flag | `ip link` · `ip route` metrics | `Get-NetIPInterface` (`NlMtu`, `InterfaceMetric`, `Dhcp`) | |
| Routing table | `ip route` · `ip -6 route` | `Get-NetRoute` · `route print` | |
| Route for a destination | `ip route get ADDR` | `Find-NetRoute -RemoteIPAddress ADDR` | |
| ARP / neighbours | `ip neigh` | `Get-NetNeighbor` · `arp -a` | |
| Temporary address | `sudo ip addr add A/P dev IFACE` | `New-NetIPAddress … -PolicyStore ActiveStore` | Elevated |
| Persistent static address | Netplan YAML + `sudo netplan try` | `New-NetIPAddress … -DefaultGateway GW` | |
| Validate before applying | `sudo netplan generate` | `-WhatIf` | |
| Back to DHCP | YAML `dhcp4: true` | `Set-NetIPInterface -Dhcp Enabled` | Remove static address/route first on Windows |
| Renew DHCP | `sudo networkctl renew IFACE` · `nmcli con up ID` | `ipconfig /renew` | |
| JSON / CSV export | `ip -j addr` | <code>Get-NetIPAddress &#124; Export-Csv</code> · `ConvertTo-Json` | |
| Subnet maths | `ipcalc A/P` | .NET `IPAddress` + bit operations | |
| Cross-platform | `ip` | `[System.Net.NetworkInformation.NetworkInterface]` | |

## Networking: connectivity

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Ping N times | `ping -c 4 HOST` | `Test-Connection HOST -Count 4` · `ping -n 4 HOST` | Linux ping runs forever without `-c` |
| Boolean check | `ping -c1 -W1 -q HOST >/dev/null` | `Test-Connection HOST -Count 1 -Quiet` | Exit codes 0/1/2 on Linux |
| Timeout units | `-W` seconds | `ping -w` milliseconds · `-TimeoutSeconds` (7) | ⚠ |
| TTL option | `ping -t N` | `ping -i N` · `-TimeToLive` (5.1) | ⚠ letters swapped |
| Path MTU | `ping -M do -s 1472` · `tracepath -n` | `ping -f -l 1472` · `Test-Connection -MtuSize` (7) | Payload = MTU − 28 |
| Trace | `traceroute -n` (UDP) · `sudo traceroute -n -I` | `tracert -d` (ICMP) · `Test-Connection -Traceroute` (7) | |
| TCP trace | `sudo traceroute -T -p PORT` · `mtr -T -P PORT` | — | |
| Per-hop loss | `mtr -rn -c 100` | `pathping -n` | Intermediate-hop loss alone is usually rate limiting |
| TCP port | `nc -zv -w2 HOST PORT` | `Test-NetConnection HOST -Port PORT` · `Test-Connection HOST -TcpPort PORT` (7) | |
| Exact socket error | `nc -zv` message | `TcpClient` + `GetBaseException().SocketErrorCode` | refused vs timed out |
| HTTP test | `curl -v URL` · `curl -w` timings | `Invoke-WebRequest URL` · `curl.exe -v URL` | `curl` = `Invoke-WebRequest` alias in 5.1 ⚠ |
| Is it routing? | `sysctl net.ipv4.ip_forward` | <code>Get-NetIPInterface &#124; Select-Object InterfaceAlias, Forwarding</code> | |

## Networking: DNS

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Real DNS servers | `resolvectl status` · `resolvectl dns` | `Get-DnsClientServerAddress` · `ipconfig /all` | Ubuntu's `/etc/resolv.conf` shows the `127.0.0.53` stub |
| Search domains | `resolvectl domain` | `Get-DnsClientGlobalSetting` · `Get-DnsClient` | |
| Resolve like an application | `getent ahosts NAME` · `resolvectl query NAME` | `Resolve-DnsName NAME` · `[System.Net.Dns]::GetHostAddresses()` | Hosts file included |
| Pure DNS query | `dig NAME` | `Resolve-DnsName NAME -DnsOnly -NoHostsFile` · `nslookup NAME` | `dig`/`nslookup` ignore hosts files ⚠ |
| Ask one server | `dig @SERVER NAME` | `Resolve-DnsName NAME -Server SERVER` | |
| Record type | `dig NAME MX` · `host -t MX NAME` | `Resolve-DnsName NAME -Type MX` | No CAA in `Resolve-DnsName`; use `nslookup -type=CAA` |
| Data only | `dig +short NAME` | `(Resolve-DnsName NAME -Type A).IPAddress` | `+short` hides the status |
| Reverse (PTR) | `dig -x ADDR` · `host ADDR` | `Resolve-DnsName ADDR -Type PTR` | |
| Authoritative / cache test | `dig @SERVER NAME +norecurse` | `Resolve-DnsName NAME -Server SERVER -NoRecursion` | `aa` flag = authoritative |
| TCP | `dig +tcp NAME` | `Resolve-DnsName NAME -TcpOnly` | |
| Delegation trace | `dig +trace NAME` | — | |
| Status of a failure | `status:` in the header (exit 0 even for NXDOMAIN; 9 = no reply) | `FullyQualifiedErrorId`: `DNS_ERROR_RCODE_NAME_ERROR`, `…SERVER_FAILURE`, `…REFUSED`, `ERROR_TIMEOUT` | ⚠ |
| Show / flush local cache | `sudo resolvectl show-cache` · `sudo resolvectl flush-caches` | `Get-DnsClientCache` · `Clear-DnsClientCache` (elevated) | Resolver caches are separate |
| Hosts file | `/etc/hosts` | `C:\Windows\System32\drivers\etc\hosts` | Checked before DNS |
| Set DNS servers | Netplan `nameservers:` + `netplan try` | `Set-DnsClientServerAddress … -WhatIf` (elevated) | |
| Multi-resolver check | `dns-check.sh -n NAMES -s system,IP1,IP2 -r` | `DNS-Check.ps1 -Name … -Server System, IP1 -Reverse` | Exit 3 on failure or disagreement |

## Networking: ports and sockets

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| All listeners with owners | `sudo ss -tulnp` | `Get-NetTCPConnection -State Listen` · `Get-NetUDPEndpoint` | `sudo` needed for other users' processes on Linux |
| Who listens on a port? | `sudo ss -ltnp 'sport = :443'` · `sudo lsof -nP -iTCP:443 -sTCP:LISTEN` · `sudo fuser -v -n tcp 443` | `Get-NetTCPConnection -LocalPort 443 -State Listen` → `Get-Process -Id OWNER` | |
| PID → services | `systemctl status PID` | `Get-CimInstance Win32_Service -Filter "ProcessId = PID"` · `tasklist /svc /fi "PID eq PID"` | One svchost can host many services |
| Sockets of one process | `sudo lsof -nP -a -p PID -i` | `Get-NetTCPConnection -OwningProcess PID` | |
| Established connections | `ss -tn state established` | `Get-NetTCPConnection -State Established` | Ephemeral local port = outbound |
| Filter by remote host / port | `ss -tn 'dst 10.0.0.5'` · `ss -tn 'dport = :443'` | `-RemoteAddress 10.0.0.5` · `-RemotePort 443` | |
| Count by state | <code>ss -tan &#124; awk 'NR>1{print $1}' &#124; sort &#124; uniq -c</code> | <code>Get-NetTCPConnection &#124; Group-Object State</code> | |
| Leaks / waits | `sudo ss -tnp state close-wait` · `ss -tno state time-wait` | `Get-NetTCPConnection -State CloseWait, TimeWait` | TIME-WAIT: no owner / PID 0 |
| TIME-WAIT duration | 60 s (fixed) | 120 s default (`TcpTimedWaitDelay`) | ⚠ |
| Ephemeral range | `sysctl net.ipv4.ip_local_port_range` (32768–60999) | `netsh int ipv4 show dynamicport tcp` (49152–65535) | ⚠ |
| Accept-queue drops | `ss -ltn` (`Recv-Q` vs `Send-Q`) · `nstat -az TcpExtListenOverflows` | `netstat -s` | |
| TCP internals | `ss -ti` | `Get-NetTCPConnection` + `Get-NetTCPSetting` | No per-connection RTT cmdlet |
| Native legacy tool | `netstat -tulnp` (net-tools, not default) | `netstat -ano` (`-b` elevated) | Different options |
| Port names | `getent services 443/tcp` | `C:\Windows\System32\drivers\etc\services` | Convention only |
| Address in use | `EADDRINUSE` (errno 98) | 10048 `WSAEADDRINUSE` | Also TIME-WAIT without `SO_REUSEADDR` |
| Cross-platform API | — | `IPGlobalProperties.GetActiveTcpListeners()` | No PIDs |
| Baseline + diff | `ss -Hltun` → file · `diff`/`comm` · `port-monitor.sh -s FILE` / `-b FILE` | `Export-Csv` + `Compare-Object` · `Port-Monitor.ps1 -SaveBaselinePath` / `-BaselinePath` | Same baseline file format |

## Networking: interfaces and packet capture

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| List interfaces | `ip -br link` | `Get-NetAdapter` (`-Physical`, `-IncludeHidden`) | |
| Admin state vs carrier | `UP` vs `LOWER_UP` / `NO-CARRIER` | `Disabled` vs `Disconnected` (`MediaConnectionState`) | Two different "up"s |
| Interface details | `ip -d link show IF` | <code>Get-NetAdapter -Name IF &#124; Format-List *</code> | |
| Speed / duplex / driver | `ethtool IF` · `ethtool -i IF` | `LinkSpeed`, `FullDuplex`, `DriverVersion` | Virtual NICs report arbitrary speeds |
| Error / drop counters | `ip -s -s link show IF` · `/sys/class/net/IF/statistics/*` · `ethtool -S IF` | `Get-NetAdapterStatistics` | Two readings, compare the delta |
| Link flaps | `cat /sys/class/net/IF/carrier_changes` · `ip -timestamp monitor link` | System log driver events · poll `Get-NetAdapter` | |
| Driver settings / offloads | `ethtool -k IF` · `ethtool -K` (root) | `Get-NetAdapterAdvancedProperty` · `Set-…` (admin) | Changes reset the link |
| IP MTU | `ip link show IF` (`mtu`) | `Get-NetIPInterface` (`NlMtu`) | |
| MTU test | `ping -M do -s 1472 HOST` · `tracepath -n HOST` | `ping -f -l 1472 HOST` | Payload + 28 = IP size |
| Neighbour cache | `ip neigh show` (`nud STATE`) | `Get-NetNeighbor` (`-State`) · `arp -a` | |
| Static entries | `ip neigh show nud permanent` | `Get-NetNeighbor -State Permanent` | Multicast/broadcast entries are normal |
| Delete one entry | `sudo ip neigh del IP dev IF` | `Remove-NetNeighbor -IPAddress IP -InterfaceAlias IF -WhatIf` | `flush` keeps PERMANENT entries |
| Duplicate IP | `sudo arping -D -I IF IP` (exit 1) · `arping` shows two MACs | `Get-NetIPAddress` `AddressState Duplicate` · Tcpip event 4199 | |
| Announce address | `sudo arping -U -I IF IP` | (automatic) | After fail-over |
| Bounce adapter | `sudo ip link set dev IF down && sudo ip link set dev IF up` | `Restart-NetAdapter -Name IF -WhatIf` (admin) | Never over the same link |
| Capture | `sudo tcpdump -i IF -n -s 128 -w f.pcap 'FILTER'` | `pktmon start --capture` · `netsh trace start capture=yes` | Authorised systems only |
| Analyse | `tcpdump -n -e -r f.pcap` · `tshark -n -r f.pcap -Y '…'` | Wireshark after `pktmon etl2pcap` | Capture vs display filters |
| Cross-platform API | — | `[System.Net.NetworkInformation.NetworkInterface]` | Works in PS 7 on Linux |
| Course script | `network-diagnostic.sh -t HOST -p PORT` | `Network-Diagnostic.ps1 -Target HOST -Port PORT` | Exit 3 = a check failed |

## Logs

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Recent messages | `journalctl -n 50 --no-pager` | `Get-WinEvent -LogName System -MaxEvents 50` | |
| Errors and worse | `journalctl -p err` (0–3) | `Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2}` | `Level=2` alone excludes Critical |
| Time window | `journalctl --since "2026-11-13 03:00" --until "03:30"` | `-FilterHashtable @{…; StartTime=…; EndTime=…}` | Convert to UTC before comparing sources |
| By program / source | `journalctl -t sudo` · `journalctl -u ssh` | `-FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'}` | |
| Previous boot / unexpected restart | `journalctl -b -1` · `--list-boots` | Events 41, 6008 (unexpected), 1074 + 6006 (planned), 6005 (start) | `-b -1` needs a persistent journal |
| Kernel messages | `sudo dmesg -T` · `journalctl -k` | System log, `Microsoft-Windows-Kernel-*` providers | `dmesg -T` times approximate |
| Structured output | `journalctl -o json` / `-o verbose` | Objects · `([xml]$e.ToXml()).Event.EventData.Data` | |
| Real writer of a message | `_PID`, `_COMM`, `_UID` (trusted fields) | `ProcessId`, `UserId`; Security log written only by LSA | Tags and sources can be faked |
| Write a test message | `logger -t TAG -p local0.err "…"` · `systemd-cat -t TAG` | `eventcreate /T ERROR /ID 900 /L APPLICATION /SO Lab16 /D "…"` (elevated) · `Write-EventLog` (5.1 only) | |
| List sources / logs | `journalctl -F SYSLOG_IDENTIFIER` · `ls /var/log` | `Get-WinEvent -ListLog *` · `-ListProvider *` | |
| Search rotated text logs | `zgrep -h PATTERN /var/log/auth.log*` | `Select-String` (plain files; decompress `.gz` first) | |
| Timeline from several files | <code>cat auth.log syslog &#124; sort &#124; awk '$1 &gt;= "…"'</code> | <code>Get-Content a, b &#124; Sort-Object &#124; Where-Object { $_ -ge '…' }</code> | RFC 3339 timestamps sort as text |
| Size and retention | `journalctl --disk-usage` · `SystemMaxUse=` · logrotate | `Get-WinEvent -ListLog X` (`MaximumSizeInBytes`, `LogMode`) · `wevtutil gl` · `Limit-EventLog` (5.1) | |
| Rotate text logs | `logrotate -d` (dry run) · `logrotate -f -s STATE CONF` | No built-in (application or scheduled script) | |
| Export evidence | `journalctl -o export > f` · `cp -p` + `sha256sum` | `wevtutil epl LOG FILE.evtx` + `Get-FileHash` | Analyse copies |
| Read an export | `journalctl --file FILE` | `Get-WinEvent -Path FILE.evtx` | |
| Clear / vacuum (destructive) | `journalctl --vacuum-time=…` | `wevtutil cl LOG /bu:FILE` · `Clear-EventLog` (5.1) | Logged as 104 / 1102 on Windows |
| Legacy cmdlet | — | `Get-EventLog` (**5.1 only**) | Port to `Get-WinEvent` |
| PowerShell 7 on Linux | <code>journalctl -o json &#124; ForEach-Object { $_ &#124; ConvertFrom-Json }</code> | — | No `Get-WinEvent` on Linux |
| Daily summary script | `log-analyser.sh -s 24 -n 10 -c 50` | `Log-Analyser.ps1 -Hours 24 -Top 10 -MaxErrors 50` | Exit 3 = too many errors |

## Authentication

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Who is logged in now | `who` · `w` | `quser` · `query user` | utmp vs session manager |
| Login history | `last -F` | `Get-WinEvent -FilterHashtable @{LogName='Security';Id=4624}` | wtmp vs Security log |
| Failed logins | `sudo lastb` · `auth.log` | `Get-WinEvent … Id=4625` | btmp vs Security log |
| Most recent login / account | `lastlog` · `lastlog -b 90` | <code>Get-LocalUser &#124; Select Name,LastLogon</code> | `lastlog`→`lastlog2` on newer distros |
| Why a login failed | `Failed password` vs `invalid user` | SubStatus `0xC000006A` vs `0xC0000064` | wrong password vs no such user |
| Account locked out | `faillock --user U` | SubStatus `0xC0000234` · event 4740 | not default on Ubuntu |
| Account disabled | `/etc/shadow` `!`/expiry | SubStatus `0xC0000072` | |
| How a login happened | `Accepted password`/`publickey` | 4624 LogonType 2/3/10 | type = access path |
| Privileged-action trail | `journalctl -t sudo` (`COMMAND=`) | event 4672 + audited actions | |
| Failed escalation | `FAILED SU` · `NOT in sudoers` | elevated 4625 / 4673 | |
| Current privileges | `id` · `sudo -l` | `whoami /groups /priv` | |
| Effective auth config | `sudo sshd -T` | `auditpol /get /category:*` | service vs audit layer |
| Lockout policy | `faillock.conf` (`deny`,`unlock_time`) | `net accounts` | |
| Reset a lockout | `sudo faillock --user U --reset` | `net user U` (local) · `Unlock-ADAccount` (AD) | |
| Enable lockout | add `pam_faillock.so` to PAM | Group Policy account lockout | |
| Rank attacker IPs | <code>grep … &#124; awk &#124; sort &#124; uniq -c</code> | `Group-Object` on EventData IpAddress | |
| Count failures reliably | <code>journalctl _COMM=sshd -g 'Failed password' &#124; wc -l</code> | `Get-WinEvent … Id=4625` count | journal avoids repeat-folding |
| Bound the time window | `journalctl --since "…"` | `-FilterHashtable @{…;StartTime=…}` | always bound |
| Export for evidence | `cp -p auth.log` + `sha256sum` | `wevtutil epl Security f.evtx` + `Get-FileHash` | Day 16 |
| Daily report | `failed-login-report.sh` | `Failed-Login-Report.ps1` | exit 3 = alert |
| Harden auth | `PasswordAuthentication no` (keys) | enforce MFA / smart card | removes password guessing |

## Firewall

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Is the firewall on? | `sudo ufw status verbose` | `Get-NetFirewallProfile -PolicyStore ActiveStore` | Windows: per profile |
| Which network "trust level"? | Interface / zone (firewalld) | `Get-NetConnectionProfile` (category → profile) | |
| List rules | `sudo ufw status numbered` · `sudo nft list ruleset` · `sudo iptables -S` | `Get-NetFirewallRule -Enabled True -Direction Inbound` | |
| Ports and addresses of a rule | Part of the rule text | <code>Get-NetFirewallRule … &#124; Get-NetFirewallPortFilter</code> / `Get-NetFirewallAddressFilter` | |
| Which rule opens port 3389 / 22? | `sudo ufw show listening` | <code>Get-NetFirewallPortFilter &#124; Where-Object LocalPort -eq 3389 &#124; Get-NetFirewallRule</code> | |
| Default deny inbound | `sudo ufw default deny incoming` · nft `policy drop;` | `Set-NetFirewallProfile -DefaultInboundAction Block` (default) | |
| Allow a port from one subnet | `sudo ufw allow from 10.18.0.16/28 to any port 22 proto tcp` | `New-NetFirewallRule -Direction Inbound -Protocol TCP -LocalPort 22 -RemoteAddress 10.18.0.16/28 -Action Allow` | |
| Allow one program | — (no program match for inbound) | `New-NetFirewallRule -Program C:\App\app.exe` | |
| Block one address | `sudo ufw insert 1 deny from ADDR` | `New-NetFirewallRule -RemoteAddress ADDR -Action Block` | |
| Rule order | First match wins | Block > Allow > default | |
| Refuse quickly instead of drop | `sudo ufw reject 8080/tcp` · nft `reject with tcp reset` | — (Block always drops) | |
| Rate-limit new connections | `sudo ufw limit OpenSSH` · nft `limit rate` | — | |
| Switch a rule off | Delete it (or comment it out in the nft file) | `Disable-NetFirewallRule` | |
| Delete a rule | `sudo ufw delete N` (prompts) · `nft delete rule … handle N` | `Remove-NetFirewallRule -DisplayName X -WhatIf` | Preview first |
| Preview / check | `sudo ufw --dry-run …` · `sudo nft -c -f FILE` · `iptables-restore --test` | `-WhatIf` | |
| Back up | `sudo tar -C /etc -czf ufw.tgz ufw` · `sudo nft list ruleset > f` · `sudo iptables-save > f` | `netsh advfirewall export f.wfw` | |
| Restore | `tar -xzf … && ufw reload` · `nft -f f` (with `flush ruleset`) · `iptables-restore < f` | `netsh advfirewall import f.wfw` | Full replace |
| Timed rollback | `sudo systemd-run --on-active=5m --unit=fw-rollback …` | Scheduled task running `netsh advfirewall import` | Cancel after a new session works |
| Log dropped packets | `sudo ufw logging low` → `journalctl -k`, `/var/log/ufw.log` | `Set-NetFirewallProfile -LogBlocked True` → `pfirewall.log` | |
| Security events | `journalctl -k -g 'UFW BLOCK'` | Security 5152 / 5157 (audit policy) | |
| Rule hit counters | `iptables -L -n -v` · nft `counter` | — | Use logs on Windows |
| Connection state table | `sudo conntrack -L` | — (internal to WFP) | |
| Test a port from a client | `nc -zv -w 2 HOST PORT` · `nmap -sT -Pn -p P HOST` | `Test-NetConnection HOST -Port P` | Own/authorised hosts only |
| RHEL family | `firewall-cmd --add-service=https --permanent && firewall-cmd --reload` | — | |

## Security auditing

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| UID 0 / admin accounts | `awk -F: '$3==0' /etc/passwd` · `getent group sudo` | `Get-LocalGroupMember Administrators` | Compare to approved list |
| Empty / non-expiring passwords | `sudo awk -F: '$2==""' /etc/shadow` · `chage -l` | <code>Get-LocalUser &#124; Select PasswordExpires</code> | Shadow needs root |
| My privileges | `id` · `sudo -l` | `whoami /priv` · `whoami /groups` | |
| Dangerous privilege grant | `NOPASSWD` + shell-capable cmd (GTFOBins) | ⚠ execution policy is **not** a control | `find`/`vi`/`less` = root |
| Validate policy file | `visudo -c` | — | Read-only check |
| SUID / SGID files | `find / -xdev -perm -4000` | — (no SUID model) | Baseline + diff |
| File capabilities | `getcap -r /` | — | `cap_net_raw` etc. |
| File integrity | `sha256sum` · `dpkg -V` | `Get-FileHash` | Reputation / tamper |
| Code signature | `gpg --verify` · `dpkg-sig` | `Get-AuthenticodeSignature` | Signed vs tampered |
| Downloaded-file mark | — | `Unblock-File` (Mark-of-the-Web) | |
| World-writable files | `find / -perm -0002` | `icacls` / `Get-Acl` on key paths | |
| Orphaned files | `find / \( -nouser -o -nogroup \)` | — | Deleted-account files |
| Disk encryption | `cryptsetup status` (LUKS) | `Get-BitLockerVolume` | |
| Secure Boot | `mokutil --sb-state` | `Confirm-SecureBootUEFI` | UEFI + elevated |
| Antivirus state | `systemctl status clamav-*` | `Get-MpComputerStatus` | Defender built in |
| Legacy protocol off | n/a | `Get-SmbServerConfiguration` (SMB1) | Want `False` |
| Kernel hardening | `sysctl fs.protected_* kernel.*_restrict` | Security Baselines (registry) | CIS Benchmark |
| Script/command logging | `auditd` · shell history | event 4104 (script block), 4688 | |

## Network security investigation

| Task | Bash (Ubuntu) | PowerShell (Windows) | Notes |
|---|---|---|---|
| Host discovery | `nmap -sn NET` | `Test-Connection -Count 1` | Authorised nets only |
| Port scan | `nmap -sS -sV TARGET` | `Test-NetConnection -Port` (per port) | No built-in Windows scanner |
| Open vs closed vs filtered | `nmap --reason` | `TcpTestSucceeded` true/false | filtered = timeout |
| Listening sockets | `ss -tulpn` | `Get-NetTCPConnection -State Listen` | Day 14 baseline |
| Established connections | `ss -tanp state established` | `Get-NetTCPConnection -State Established` | |
| Socket → process | `lsof -i` · `/proc/PID/exe` | `OwningProcess` → `Get-Process -Id` | core skill |
| Socket → executable | `ls -l /proc/PID/exe` | `netstat -anob` | `(deleted)` = IoC |
| Capture packets | `tcpdump -n -w f 'host X'` | `pktmon start/stop` + `etl2pcap` | Tight filter |
| Read a capture | `tshark -r f -Y FILTER` · Wireshark | Wireshark (pcapng) | Display filters |
| Reverse-lookup an IP | `dig -x IP` · `host IP` | `Resolve-DnsName IP` | Day 13 |
| Firewall drop log | `journalctl -k -g UFW` | `pfirewall.log`, Security 5157 | Day 18 |
| Correlate logins | `journalctl _COMM=sshd` | `Get-WinEvent` 4624/4625 | Day 17 |

## Scripting: variables and input

| Task | Bash (Ubuntu) | PowerShell | Notes |
|---|---|---|---|
| Assign / read | `name=web-01` · `"$name"` | `$name = 'web-01'` · `$name` | ⚠ No spaces around `=` in Bash |
| Typed variable | `declare -i n=5` | `[int]$n = 5` | ⚠ Bash does not validate; PS rejects bad values |
| Constant | `readonly MAX=3` | `New-Variable MAX 3 -Option ReadOnly` | |
| Default value | `${v:-default}` | `$v ?? 'default'` (7.0+) · `if (-not $v) { … }` | `??` tests only `$null` |
| Required value | `: "${v:?message}"` | `[Parameter(Mandatory)]` · `throw` | |
| Basename / dirname | `${p##*/}` · `${p%/*}` | `Split-Path -Leaf` · `Split-Path -Parent` | |
| Replace / case | `${v//a/b}` · `${v^^}` · `${v,,}` | `.Replace('a','b')` · `.ToUpper()` · `.ToLower()` | |
| Command output | `x=$(cmd)` | `$x = cmd` | PS keeps objects |
| Arithmetic | `$(( a * 100 / b ))` (integers) | `$a * 100 / $b` (decimals) | ⚠ Leading zero = octal in Bash |
| Formatted text | `printf '%-10s %5.1f\n' a 3.14` | `'{0,-10} {1,5:N1}' -f 'a', 3.14` | |
| Environment variable | `export X=1` · `"$X"` | `$env:X = '1'` · `$env:X` | ⚠ Case-sensitive on Linux |
| One-command environment | `TZ=UTC date` | (set `$env:`, run, restore) | |
| Persistent environment | `~/.profile`, `/etc/environment` | `[Environment]::SetEnvironmentVariable(n, v, 'User')` | Windows only for User/Machine |
| Arguments | `$1` · `$#` · `"$@"` · `shift` | `param()` · `$args` · `$PSBoundParameters` | |
| Prompt | `read -r -p 'Host: ' h` | `$h = Read-Host 'Host'` | Terminal only / interactive only |
| Secret prompt | `read -r -s -p 'PIN: ' p` | `Read-Host -AsSecureString` · `Get-Credential` | Never pass secrets as arguments |
| Arrays / maps | `a=(x "y z")` · `declare -A m=([k]=v)` | `@('x','y z')` · `@{ k = 'v' }` | |
| Load settings file | `source ./site.env` | `. .\settings.ps1` · `Import-PowerShellDataFile` | `.psd1` cannot run code |
| Undefined-variable errors | `set -o nounset` | `Set-StrictMode -Version Latest` | |

## Scripting: conditions and loops

| Task | Bash (Ubuntu) | PowerShell | Notes |
|---|---|---|---|
| If / else if / else | `if …; then …; elif …; then …; else …; fi` | `if () {} elseif () {} else {}` | Bash tests exit status |
| Numeric compare | `(( a >= 90 ))` · `[[ $a -ge 90 ]]` | `$a -ge 90` | ⚠ `>` is redirection in both shells |
| String equal | `[[ $a == "$b" ]]` | `$a -eq $b` | ⚠ PS is case-insensitive; `-ceq` |
| Empty test | `[[ -z $s ]]` · `[[ -n $s ]]` | `-not $s` · `[string]::IsNullOrEmpty($s)` | |
| Wildcard match | `[[ $f == *.log ]]` | `$f -like '*.log'` | |
| Regex match + groups | `[[ $s =~ ^(re)$ ]]` · `${BASH_REMATCH[1]}` | `$s -match '^(re)$'` · `$Matches[1]` | Regex unquoted in Bash |
| Membership | loop over the array | `$list -contains $x` · `$x -in $list` | ⚠ `@(…) -eq $x` filters |
| File tests | `[[ -f $p ]]` `[[ -d $p ]]` `[[ -s $p ]]` `[[ -r $p ]]` | `Test-Path $p -PathType Leaf/Container` | |
| Multi-way branch | <code>case $x in a&#124;b) …;; *) …;; esac</code> | `switch -Wildcard ($x) { 'a' { …; break } default { } }` | ⚠ `switch` runs all matches without `break` |
| Ternary | <code>[[ c ]] &amp;&amp; x=a &#124;&#124; x=b</code> | `$c ? 'a' : 'b'` (7.0+) | Bash form is not a true if/else |
| Loop over a list | `for h in "${hosts[@]}"; do …; done` | `foreach ($h in $hosts) { }` | |
| Numeric loop | `for (( i=1; i<=n; i++ ))` · `seq 1 "$n"` | `for ($i=1; $i -le $n; $i++) {}` · `1..$n` | ⚠ `{1..$n}` does not work |
| Loop over files | `shopt -s nullglob; for f in dir/*.log` | `foreach ($f in Get-ChildItem dir -Filter *.log)` | |
| Lines of a file | <code>while IFS= read -r l &#124;&#124; [[ -n $l ]]; do …; done &lt; f</code> | `switch -File f {}` · `foreach ($l in Get-Content f)` | |
| Lines of command output | `while read -r l; do …; done < <(cmd)` | <code>cmd &#124; ForEach-Object { }</code> | ⚠ <code>cmd &#124; while</code> loses variables |
| Condition loops | `while cmd` · `until cmd` | `while ()` · `do {} while ()` · `do {} until ()` | `do` runs at least once |
| Skip / stop | `continue` · `break` · `break 2` | `continue` · `break` · `break label` | ⚠ use `return` in `ForEach-Object` |
| Parallel loop | `cmd &` … `wait` · `xargs -P` | `ForEach-Object -Parallel -ThrottleLimit N` (7.0+) | |
| Time limit | `timeout 30 cmd` (exit 124) | `Wait-Job -Timeout 30` | |
| Pause | `sleep 2` | `Start-Sleep -Seconds 2` | |

## Scripting: functions and reusable scripts

| Task | Bash (Ubuntu) | PowerShell | Notes |
|---|---|---|---|
| Define a function | `f() { …; }` | `function Verb-Noun { param() … }` | Approved verbs (`Get-Verb`) |
| Arguments | `$1` · `"$@"` · `$#` | named parameters · `$PSBoundParameters` | ⚠ no `$1` in PS |
| Private variables | `local x` | default (local) · `$script:x` to share | ⚠ opposite defaults |
| Return data | print on stdout; `v=$(f)` | output objects; `$v = f` | stray output pollutes both |
| Success / failure | `return 0..255` | errors (`throw`, `Write-Error`) | `return 300` → 44 in Bash |
| Diagnostics | `printf … >&2` | `Write-Verbose` · `Write-Warning` · `Write-Information` | |
| Options | `while getopts ':hf:' o` | `param([Parameter(Mandatory)] …)` | PS validates and completes |
| Validation | `[[ $v =~ ^[0-9]+$ ]]` · `(( v >= 1 ))` | `[ValidateRange()]` · `[ValidatePattern()]` · `[ValidateSet()]` | |
| Help | `usage()` for `-h` | comment-based help → `Get-Help` | |
| Dry run | custom `-n` option | `SupportsShouldProcess` → `-WhatIf` / `-Confirm` | |
| Cleanup | `trap cleanup EXIT` | `try {} finally {}` · `clean {}` (7.3+) | ⚠ nothing survives `kill -9` |
| Temp file | `mktemp` · `mktemp -d` | `New-TemporaryFile` · `[IO.Path]::GetTempPath()` | |
| Catch an error | <code>cmd &#124;&#124; die "…"</code> · `trap … ERR` | `try { … -ErrorAction Stop } catch { }` | ⚠ `catch` ignores non-terminating errors |
| Shared code | `source lib.sh` (+ load guard) | `Import-Module .\Mod` (`.psm1` + `.psd1`) | |
| Testable script | `[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"` | functions in a module; Pester tests | |
| Pipeline input | `while read -r l; do …; done` | `process { }` + `ValueFromPipeline*` | |
| One instance only | `flock -n 9` | named mutex / scheduled-task setting | Day 25 |

## Text and data processing

| Task | Bash (Ubuntu) | PowerShell | Notes |
|---|---|---|---|
| Field of a line | `awk '{print $1}'` · `cut -d: -f1` | `($l -split '\s+')[0]` | ⚠ PS index from 0 |
| Count per value | <code>sort &#124; uniq -c &#124; sort -rn</code> | <code>Group-Object -NoElement &#124; Sort-Object Count -Descending</code> | |
| Numeric sort by column | `sort -t, -k5,5nr` | `Sort-Object { [int]$_.disk_pct } -Descending` | ⚠ text sort: `10 100 9` |
| Sum / average | `awk '{s += $10} END {print s, s/NR}'` | `Measure-Object Bytes -Sum -Average` | |
| Per-key sum | `awk '{b[$1] += $10} END {…}'` | `Group-Object IP` + `Measure-Object -Sum` | |
| Replace | `sed -E 's/re/\1x/g'` | `-replace 're', '${1}x'` | ⚠ PS case-insensitive |
| Print / delete lines | `sed -n '10,20p'` · `sed '/^#/d'` | `(Get-Content f)[9..19]` · `Where-Object { $_ -notmatch '^#' }` | |
| Safe in-place edit | `sed … f` preview with `diff`, then `sed -i.bak` | `Copy-Item f f.bak`; `(Get-Content f) -replace …` then `Set-Content` | read fully before writing |
| Strip CR | `tr -d '\r'` | <code>-replace "&#96;r", ''</code> | `Import-Csv` copes with CRLF |
| CSV with quotes | Python `csv` / `gawk --csv` | `Import-Csv` | ⚠ `cut`/`awk -F,` split quoted commas |
| CSV out | `printf '%s,%s\n'` | `Export-Csv -NoTypeInformation -Encoding UTF8` | ⚠ 5.1 defaults: `#TYPE`, ASCII |
| JSON filter | <code>jq '.[] &#124; select(.v &gt;= 90)'</code> | <code>(… -Raw &#124; ConvertFrom-Json) &#124; Where-Object v -ge 90</code> | ⚠ 5.1 arrays: parentheses |
| JSON out | `jq -n --arg h "$h" '{host: $h}'` | `ConvertTo-Json -Depth 5` | ⚠ default depth 2 |
| Join two data sets | `join -t,` (sorted inputs) | hashtable lookup + calculated property | |
| Lines → one line | `paste -sd,` | `-join ','` · `Join-String` (7.0+) | |
| HTML report | — | `ConvertTo-Html` | |

## Scheduling and automation

| Task | Bash (Ubuntu) | PowerShell | Notes |
|---|---|---|---|
| Recurring job | `crontab -e` → `*/15 * * * * /path/job` | `Register-ScheduledTask` + repeating trigger | ⚠ cron: absolute paths, `\%` |
| Nightly 02:30 | `30 2 * * *` · `OnCalendar=*-*-* 02:30:00` | `New-ScheduledTaskTrigger -Daily -At 02:30` | prefer UTC servers |
| At boot / logon | `@reboot` · `OnBootSec=` | `-AtStartup` · `-AtLogOn` | `@reboot` = cron start |
| Run once later | `at 22:00` · `systemd-run --on-calendar=` | `-Once -At` · `schtasks /sc once` | |
| Catch up missed runs | `anacron` · `Persistent=true` | `-StartWhenAvailable` | cron skips them |
| No overlap | `flock -n LOCK CMD` | `-MultipleInstances IgnoreNew` | |
| Time limit | `timeout 120 CMD` (exit 124) | `-ExecutionTimeLimit` | |
| List jobs | `crontab -l` · `ls /etc/cron.d` · `systemctl list-timers --all` | `Get-ScheduledTask` | |
| Last result | `journalctl -u cron` · `systemctl status NAME` | `Get-ScheduledTaskInfo` (`LastTaskResult`) | 0x41301 running, 0x41303 not run |
| Run now | `systemctl start NAME.service` | `Start-ScheduledTask` · `schtasks /run` | |
| Remove | delete the line · `crontab -i -r` | `Unregister-ScheduledTask -Confirm:$false` | ⚠ `crontab -r` = all |
| Job history | `/var/log/syslog`, journal | TaskScheduler Operational log | enable it first |
| Log from a job | `logger -t TAG -p user.warning` | `eventcreate` · `Write-EventLog` (5.1) | |
| Rotate job logs | `logrotate` drop-in | script / clean-up task | |
| Test a schedule | `systemd-analyze calendar 'EXPR'` | inspect the trigger object | |
| Persistence hunt | <code>for u in $(cut -d: -f1 /etc/passwd); do crontab -l -u "$u"; done</code> | <code>Get-ScheduledTask &#124; Where-Object TaskPath -notlike '\Microsoft\*'</code> | T1053.003/.005/.006 |

## Remote administration

| Task | Bash (Ubuntu) | PowerShell | Notes |
|---|---|---|---|
| Interactive remote shell | `ssh user@host` | `Enter-PSSession -ComputerName host` · `-HostName host` (7.x) | |
| Command on one host | `ssh host 'cmd'` | `Invoke-Command -ComputerName host { cmd }` | ⚠ Bash double quotes expand locally |
| Many hosts | `while read -r h; do ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$h" 'cmd'; done < hosts` | `Invoke-Command -ComputerName $list -ThrottleLimit 32 -ErrorVariable bad` | ⚠ `-n` in loops; 255 = ssh error |
| Pass a local value | `printf %q` / `ssh host 'bash -s' < script.sh` | `$using:var` · `-ArgumentList` | |
| Persistent connection | `ControlMaster auto` + `ControlPersist` | `New-PSSession` + `-Session` | |
| Copy a file | `scp -P 2222 f host:/tmp/` · `sftp -b batch host` | `Copy-Item f -Destination C:\Temp\ -ToSession $s` | ⚠ `scp -P` capital |
| Sync a directory | `rsync -avzi --dry-run src/ host:dst/` | `robocopy src dst /MIR /L` | ⚠ `--delete` / `/MIR` delete files |
| Tunnel to an internal port | `ssh -N -L 127.0.0.1:8443:192.0.2.20:443 bastion` | `ssh.exe -N -L …` | no WinRM equivalent |
| Jump host | `ssh -J bastion target` · `ProxyJump` | SSH transport + `~/.ssh/config` | avoid agent forwarding |
| Verify the server | known_hosts fingerprint · `ssh-keyscan` + `ssh-keygen -lf` | Kerberos · HTTPS certificate | ⚠ TrustedHosts is not authentication |
| Create / install a key | `ssh-keygen -t ed25519 -a 100` · `ssh-copy-id` | `ssh-keygen.exe` · `administrators_authorized_keys` + `icacls` | |
| Restrict a login | `authorized_keys` `from=`, `command=`, `restrict` | JEA (`RestrictedRemoteServer`, role capabilities) | |
| Enable the server | `apt install openssh-server` | `Enable-PSRemoting` · `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0` | |
| Validate server config | `sudo sshd -t` · `sudo sshd -T` | `winrm get winrm/config` · `sshd.exe -t` | Ubuntu 24.04 Port: `ssh.socket` |
| Who logged in (which key) | `journalctl _COMM=sshd -g 'Accepted publickey'` + `ssh-keygen -lf authorized_keys` | Security 4624 type 3 · WinRM/Operational 91 · PowerShell 4104 | |
| Record a session | `script -q -a log -c 'ssh host'` | `Start-Transcript` | |
