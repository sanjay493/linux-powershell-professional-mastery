---
description: "System administrator / general IT pathway: users, files, storage, services, software, backups, logs, maintenance, remote admin, automation and the System Health Monitoring Toolkit project."
---

# Path C — System Administrator / General IT Professional

System administrators keep servers and endpoints healthy, secure and up to date, and they automate everything they do twice.

## Competencies and where they are taught

| Competency | Linux | Windows | Days |
|---|---|---|---|
| User administration | `useradd`, `usermod`, `passwd`, `chage` | `New-LocalUser`, `Add-LocalGroupMember`, `Disable-LocalUser` | 6 |
| File management | `cp -a`, `rsync`, `find` | `Copy-Item`, `robocopy` | 2–4 |
| Permissions | `chmod`, `chown`, `umask`, ACLs (`setfacl`) | `Get-Acl`, `Set-Acl`, `icacls` | 7 |
| Storage monitoring | `df -h`, `du -sh`, `lsblk`, `findmnt` | `Get-Volume`, `Get-PSDrive`, `Get-Disk` | 9 |
| Service management | `systemctl status/restart/enable`, `journalctl -u` | `Get-Service`, `Restart-Service`, `Set-Service -StartupType` | 8 |
| Software installation | `apt`, `dpkg`, `snap` | `winget`, `Install-PSResource` | 10 |
| Backup checks | `tar`, `rsync --dry-run`, checksums | `robocopy /L`, `Get-FileHash`, `wbadmin get versions` | 2, 9, 25 |
| Log monitoring | `journalctl -p err`, `/var/log/syslog` | `Get-WinEvent -FilterHashtable @{LogName='System';Level=2}` | 16 |
| System maintenance | Updates, log rotation, cleanup | Windows Update status, temp cleanup | 9, 10, 25 |
| Remote administration | `ssh`, keys, `scp`, `sftp` | `Enter-PSSession`, `Invoke-Command`, SSH remoting | 26 |
| Automation | Bash scripts, cron, systemd timers | Advanced functions, Task Scheduler | 21–25, 29 |

## Daily, weekly and monthly routine (built during the course)

| Frequency | Task | Tooling |
|---|---|---|
| Daily | Health report: CPU, memory, disk, failed services, errors in the last 24h | `system-health`, `daily-report` scripts (Days 25, 29) |
| Daily | Backup job success check | Exit codes + log parsing (Days 5, 16) |
| Weekly | Patch status, pending reboots | `apt list --upgradable`, `winget upgrade` (Day 10) |
| Weekly | Disk growth trend | `disk-monitor` script (Day 9) |
| Monthly | Account review: inactive users, admin group membership | Day 6 + Day 19 audits |
| Monthly | Restore test from backup | Lab practice |

## Final project: System Health Monitoring Toolkit

Build `health-toolkit.sh` and `Health-Toolkit.ps1` that:

- Collect CPU load, memory usage, disk usage per volume (with warning/critical thresholds as parameters), uptime and pending updates.
- List failed/stopped-but-automatic services and the top 5 processes by CPU and memory.
- Summarise errors from the system log in the last 24 hours.
- Check that the last backup file or log is newer than *N* hours.
- Write a dated text and CSV report, keep 14 days of reports, and exit with a non-zero code when any check is critical, so a scheduler or monitoring system can alert.
- Include installation instructions for cron/systemd timers and Task Scheduler.

Building blocks: `system-info` (Day 1), `process-monitor` (Day 8), `disk-monitor` (Day 9), `system-health` (Day 25) and `daily-report` (Day 29).

## Recommended next steps

- Certifications: CompTIA Linux+ / A+, LPIC-1, Red Hat RHCSA, Microsoft AZ-800/AZ-104.
- Practice: build a home lab with two Ubuntu VMs and one Windows VM, and automate their patching and health reporting.
