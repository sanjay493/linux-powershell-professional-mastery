---
description: "Twenty production-style Bash and PowerShell scripts with prerequisites, usage, sample output, troubleshooting and validation status."
---

# Script Library

Scripts live in the repository under `scripts/linux/` and `scripts/powershell/`. Each one is **read-only by default**, validates its input, handles errors, and documents its prerequisites and exit codes in its header.

## Conventions

| Convention | Linux (Bash) | PowerShell |
|---|---|---|
| Help | `./script.sh -h` | `Get-Help .\Script.ps1 -Full` |
| Save a report | `-o DIR` | `-OutputPath DIR` |
| Output format | <code>-f text&#124;csv</code> (where relevant) | <code>-Format Text&#124;Csv&#124;Json</code> |
| Exit codes | `0` OK · `1` usage error · `2` output/IO error · `3` threshold breached | same |
| Privileges | Runs as a normal user; reports clearly when a check needs `sudo` | Runs non-elevated; reports when a check needs Administrator |

**Run a script you have not written only after reading it.**

## Release plan

| # | Linux | PowerShell | Purpose | Released with |
|---|---|---|---|---|
| 1 | `system-info.sh` | `System-Info.ps1` | Identity and inventory report | **Day 01 (available)** |
| 2 | `process-monitor.sh` | `Process-Monitor.ps1` | Top CPU/memory processes, thresholds | Day 08 |
| 3 | `disk-monitor.sh` | `Disk-Monitor.ps1` | Filesystem usage with warning/critical thresholds | Day 09 |
| 4 | `dns-check.sh` | `DNS-Check.ps1` | Forward/reverse lookups across resolvers | Day 13 |
| 5 | `port-monitor.sh` | `Port-Monitor.ps1` | Listening ports and owning processes, baseline diff | Day 14 |
| 6 | `network-diagnostic.sh` | `Network-Diagnostic.ps1` | Layered connectivity diagnosis | Day 15 |
| 7 | `log-analyser.sh` | `Log-Analyser.ps1` | Error/warning summaries from system logs | Day 16 |
| 8 | `failed-login-report.sh` | `Failed-Login-Report.ps1` | Failed authentication summary by account and source | Day 17 |
| 9 | `system-health.sh` | `System-Health.ps1` | Thresholded health check for scheduling | Day 25 |
| 10 | `daily-report.sh` | `Daily-Report.ps1` | Combined daily text and CSV report | Day 29 |

---

## system-info.sh / System-Info.ps1

**Purpose:** a read-only snapshot of who/what/where: host, user, OS, kernel/build, CPU, memory, system disk, IPv4 addresses, gateway, DNS, uptime and shell version.

### Prerequisites

| Linux | Windows |
|---|---|
| Ubuntu 24.04 (any systemd distro), Bash 4+, coreutils, procps (`free`), iproute2 (`ip`). No root. | Windows 11, Windows PowerShell 5.1 or PowerShell 7. CIM access (default). No admin. |

### How to run

```bash
cd scripts/linux
bash system-info.sh                 # text report to the terminal
bash system-info.sh -f csv          # CSV (Property,Value)
bash system-info.sh -o ~/lpm-lab/reports   # also save a timestamped file
```

```powershell
Set-Location scripts\powershell
.\System-Info.ps1                                   # requires RemoteSigned for CurrentUser
.\System-Info.ps1 -Format Json
.\System-Info.ps1 -Format Csv -OutputPath $HOME\lpm-lab\reports
# Without changing execution policy (this process only):
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\System-Info.ps1
```

### Sample output (PowerShell 5.1, Windows 11; captured by running the script; identifying values replaced)

```text
==============================================
 System Information Report
==============================================
Report time (UTC)    : 2026-11-08T10:31:47Z
Computer name        : WIN11-LAB
Current user         : WIN11-LAB\student
Operating system     : Microsoft Windows 11 Home Single Language
OS version/build     : 10.0.26200 (build 26200)
Architecture         : AMD64
Manufacturer/model   : Contoso Laptop X509
CPU model            : AMD Ryzen 5 3500U with Radeon Vega Mobile Gfx
Logical CPUs         : 8
Memory total (MB)    : 10188
Memory used (MB)     : 7646
Memory free (MB)     : 2542
System drive         : C: 96.8 GB used of 500.3 GB (19%), 403.5 GB free
IPv4 addresses       : WiFi=192.168.1.3/24
Default gateway      : 192.168.1.1 via WiFi
DNS servers          : 192.168.1.1
Uptime               : 3d 10h 34m
Boot time            : 2026-11-05 05:27:40
PowerShell           : 5.1.26100.9168 (Desktop)
```

### Sample output (Bash, format)

```text
==============================================
 System Information Report
==============================================
Report time (UTC)        : 2026-11-08T10:32:13Z
Host name                : ubuntu-lab
Current user             : student
Operating system         : Ubuntu 24.04.1 LTS
Kernel release           : 6.8.0-48-generic
Architecture             : x86_64
CPU model                : Intel(R) Xeon(R) CPU E5-2673 v4 @ 2.30GHz
CPU cores                : 4
Load average (1/5/15)    : 0.12 0.08 0.03
Memory total             : 15990MiB
Memory used              : 1203MiB
Memory available         : 14420MiB
Root filesystem          : 31G used of 73G (43%), 42G free
IPv4 addresses           : eth0=10.1.0.4/16
Default gateway          : 10.1.0.1 via eth0
DNS servers              : 127.0.0.53
Uptime                   : up 12 minutes
Boot time                : 2026-11-08 10:20:01
Shell                    : 5.2.21(1)-release
```

The CI pipeline runs the script on every release on a GitHub-hosted Ubuntu 24.04 runner, and the real report is attached to each workflow run as the `linux-script-reports` artefact.

### Troubleshooting

| Problem | Fix |
|---|---|
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or use the one-off `-ExecutionPolicy Bypass -File` form |
| `File ... cannot be loaded. The file is not digitally signed` (downloaded zip) | `Unblock-File .\System-Info.ps1` after reading it |
| A field shows `n/a` | The underlying tool or query failed or is missing (for example no `ip` command in a minimal container). Run with `-Verbose` (PowerShell) to see why |
| `bash: ./system-info.sh: Permission denied` | Run `bash system-info.sh`, or `chmod +x system-info.sh` once |
| `$'\r': command not found` | The file has Windows line endings: `sed -i 's/\r$//' system-info.sh` (the repository enforces LF via `.gitattributes`) |

### Validation status

| Check | Linux script | PowerShell script |
|---|---|---|
| Executed | CI: GitHub `ubuntu-24.04` runner, every release | Executed locally on Windows 11 / Windows PowerShell 5.1 (2026-11-08); CI: `windows-latest` with 5.1 and 7 |
| Static analysis | `bash -n` and ShellCheck in CI | PowerShell parser and PSScriptAnalyzer in CI |
