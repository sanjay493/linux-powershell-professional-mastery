---
description: "Cybersecurity / SOC analyst pathway: authentication monitoring, Windows security events, process and network investigation, firewall auditing, reporting and the Security Investigation Toolkit project."
---

# Path A — Cybersecurity / SOC Analyst

A Security Operations Centre (SOC) analyst monitors alerts, investigates suspicious activity, and escalates or contains incidents. The command line lets you verify an alert **on the host itself** when the SIEM view is not enough.

## Competencies and where they are taught

| Competency | Linux skills | Windows skills | Days |
|---|---|---|---|
| Situational awareness on a host | `whoami`, `id`, `hostname`, `uname -a` | `whoami /all`, `Get-ComputerInfo` | 1, 6 |
| Hidden and suspicious files | `ls -la`, `find -mtime`, `file` | `Get-ChildItem -Force`, `Get-FileHash` | 2, 4, 19 |
| Log searching | `grep`, `journalctl`, `/var/log/auth.log` | `Get-WinEvent -FilterHashtable`, `Select-String` | 3, 4, 16 |
| Linux authentication monitoring | `last`, `lastb`, `who`, sshd logs | — | 17 |
| Windows security event analysis | — | Event IDs 4624, 4625, 4634, 4672, 4720, 4740 | 17 |
| Failed-login detection | `grep "Failed password"` + `awk`/`sort`/`uniq -c` | `Get-WinEvent` 4625 + `Group-Object` | 17, 24 |
| Process investigation | `ps -ef --forest`, `/proc/<pid>` | `Get-Process`, `Get-CimInstance Win32_Process` (parent PID, command line) | 8, 28 |
| Network connection investigation | `ss -tunap`, `lsof -i` | `Get-NetTCPConnection` + `OwningProcess` | 14, 20 |
| Firewall auditing | `ufw status verbose`, `nft list ruleset` | `Get-NetFirewallProfile`, `Get-NetFirewallRule` | 18 |
| Security baseline | sudoers, SUID files, world-writable files | Execution policy, Defender status, local admins | 19 |
| Suspicious activity investigation | `tcpdump`, Nmap against own hosts | `pktmon`, `Get-NetTCPConnection` | 20, 27 |
| Security reporting | Text/CSV reports | `Export-Csv`, `ConvertTo-Json` | 24, 29 |

## SOC-style case studies (released with the module)

1. **Brute force against SSH** (Day 17): hundreds of `Failed password` entries from one IP. Count, timeline, was any attempt successful?
2. **Password spraying on Windows** (Day 17): many 4625 events across many accounts from one source. Which accounts were targeted?
3. **Web shell indicator** (Days 8, 20): `www-data` spawning `bash` with an outbound connection. Parent/child processes and the socket owner.
4. **Unexpected listening port** (Days 14, 20): a new service on port 4444. Which process and file are behind it, and what is its hash?
5. **Firewall drift** (Day 18): an inbound "Allow Any" rule appeared. When, which profile, and how do you safely revert it?

## Final project: Security Investigation Toolkit

Build a pair of scripts (`soc-toolkit.sh`, `SOC-Toolkit.ps1`) that, **read-only and without changing the system**, collect:

- Host identity and time (UTC), current and logged-on users, local administrators/sudoers.
- Failed and successful logins for the last *N* hours, with the top source IPs and accounts.
- Listening ports and established connections mapped to processes.
- Recently created or modified files in temp, startup and persistence locations.
- Firewall profile and rule summary.
- A timestamped text **and** CSV report plus a SHA-256 hash of the report.

**Assessment criteria:** correctness, read-only safety, error handling, clear report layout, documentation (usage, prerequisites, sample output). The course scripts `failed-login-report`, `port-monitor` and `log-analyser` (released Days 14–17) are your building blocks.

## Recommended next steps after the course

- Free practice: TryHackMe/HackTheBox SOC-level rooms, Blue Team Labs Online, Splunk BOTS datasets.
- Certifications to consider: CompTIA Security+ / CySA+, Microsoft SC-200, Splunk Core User.
