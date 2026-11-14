---
description: "The complete 30-day curriculum: six modules from command-line fundamentals to a professional capstone."
---

# The 30-Day Course

Six modules of five days each. Each day takes about **3–4 hours**: reading, demonstrations, a hands-on lab, a quiz and homework.

!!! info "Release cadence"
    Lessons are published **two days at a time, every night at 22:00 IST (16:30 UTC)**. Unreleased days appear below without links. See the [release schedule](schedule.md) for exact dates.

## Module 1 — [Command-Line Fundamentals](module-1/index.md)

| Day | Lesson | Key commands |
|---|---|---|
| 01 | [Introduction to Linux and PowerShell](module-1/day-01.md) | `whoami` `hostname` `pwd` `ls` `uname` `date` · `Get-Location` `Get-ChildItem` `Get-ComputerInfo` `Get-Date` |
| 02 | [File and Directory Management](module-1/day-02.md) | `cd` `mkdir` `touch` `cp` `mv` `rm` · `Set-Location` `New-Item` `Copy-Item` `Move-Item` `Remove-Item` |
| 03 | [Reading and Managing Files](module-1/day-03.md) | `cat` `less` `head` `tail` `wc` · `Get-Content` `Select-Object` `Measure-Object` · redirection |
| 04 | [Searching Files and Text](module-1/day-04.md) | `find` `grep` `locate` `which` · `Get-ChildItem` `Select-String` `Where-Object` · regex |
| 05 | [Command Help, History and Pipelines](module-1/day-05.md) | `man` `history` `type` · `Get-Help` `Get-Command` `Get-History` · pipelines, exit codes |

## Module 2 — [System Administration](module-2/index.md)

| Day | Lesson | Key commands |
|---|---|---|
| 06 | [Users and Groups](module-2/day-06.md) | `useradd` `usermod` `passwd` `id` `groups` · `Get-LocalUser` `New-LocalUser` `Add-LocalGroupMember` |
| 07 | [File Permissions and Access Control](module-2/day-07.md) | `chmod` `chown` `umask` · `Get-Acl` `Set-Acl` `icacls` |
| 08 | [Processes and Services](module-2/day-08.md) | `ps` `top` `htop` `kill` `systemctl` · `Get-Process` `Stop-Process` `Get-Service` |
| 09 | [Disk and Storage Management](module-2/day-09.md) | `df` `du` `lsblk` `mount` `findmnt` · `Get-Disk` `Get-Volume` `Get-PSDrive` |
| 10 | [Software and Package Management](module-2/day-10.md) | `apt` `dpkg` `dnf` · `winget` · PowerShellGet / PSResourceGet |

## Module 3 — [Networking & Troubleshooting](module-3/index.md)

| Day | Lesson | Key commands |
|---|---|---|
| 11 | [IP Configuration](module-3/day-11.md) | `ip addr` `ip route` · `Get-NetIPConfiguration` `Get-NetIPAddress` `Get-NetRoute` |
| 12 | [Connectivity Troubleshooting](module-3/day-12.md) | `ping` `traceroute` `tracepath` `mtr` · `Test-Connection` `Test-NetConnection` `tracert` |
| 13 | [DNS Troubleshooting](module-3/day-13.md) | `dig` `nslookup` `host` · `Resolve-DnsName` |
| 14 | [Ports, Sockets and Connections](module-3/day-14.md) | `ss` `netstat` `lsof` · `Get-NetTCPConnection` `Get-NetUDPEndpoint` |
| 15 | [Network Interfaces and Diagnostics](module-3/day-15.md) | `ip link` `ip neigh` `tcpdump` · `Get-NetAdapter` `Get-NetNeighbor` `pktmon` · Wireshark |

## Module 4 — [Security, Logs & Monitoring](module-4/index.md)

| Day | Lesson | Key commands |
|---|---|---|
| 16 | [System Logs](module-4/day-16.md) | `journalctl` `dmesg` `/var/log` · `Get-WinEvent` `wevtutil` |
| 17 | Authentication and Security Monitoring | `last` `lastb` `who` · auth.log · Security log event IDs 4624/4625/4672 |
| 18 | Firewall Management | `ufw` `nft` `iptables` · `Get-NetFirewallProfile` `Get-NetFirewallRule` |
| 19 | System Security Auditing | `sudo -l` `find -perm` · `Get-ExecutionPolicy` `Get-MpComputerStatus` |
| 20 | Network Security Investigation | `nmap` `ss` `tcpdump` · `Get-NetTCPConnection` `pktmon` |

## Module 5 — [Scripting & Automation](module-5/index.md)

| Day | Lesson | Key commands |
|---|---|---|
| 21 | Variables and User Input | `read` `echo` `export` · `Read-Host` `Write-Output` · scope, types |
| 22 | Conditions and Loops | `if` `case` `for` `while` · `if` `switch` `foreach` `ForEach-Object` |
| 23 | Functions and Reusable Scripts | Bash functions · advanced functions, `param()`, `try/catch` |
| 24 | Text and Data Processing | `awk` `sed` `cut` `sort` `uniq` · `Group-Object` `Sort-Object` · CSV and JSON |
| 25 | Task Scheduling and Automation | `cron` `crontab` systemd timers · Task Scheduler, `Register-ScheduledTask` |

## Module 6 — [Professional Operations & Projects](module-6/index.md)

| Day | Lesson | Key commands |
|---|---|---|
| 26 | Remote Administration | `ssh` `ssh-keygen` `scp` `sftp` · `Enter-PSSession` `Invoke-Command` · WinRM and SSH remoting |
| 27 | Network Investigation | Case studies: TCP, routing, DNS, captures, Wireshark, Nmap |
| 28 | Advanced System Troubleshooting | CPU, memory, disk and network bottlenecks · root cause analysis |
| 29 | Integrated Diagnostic Automation | Full Linux and Windows diagnostic scripts · CSV/text reports |
| 30 | Final Capstone and Assessment | Complete investigation, final exam, certificate template |

## Suggested daily routine

1. Read the concepts (45–90 min).
2. Type every demonstration yourself rather than copy-pasting (60 min).
3. Complete the lab without looking at the solution, then compare (45–60 min).
4. Answer the practice questions and quiz (20 min).
5. Do the homework and tick the completion checklist.
