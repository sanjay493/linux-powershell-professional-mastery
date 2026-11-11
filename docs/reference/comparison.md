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
