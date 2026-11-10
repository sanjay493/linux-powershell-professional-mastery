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
| 2 | `process-monitor.sh` | `Process-Monitor.ps1` | Top CPU/memory processes, thresholds | **Day 08 (available)** |
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

---

## process-monitor.sh / Process-Monitor.ps1

**Purpose:** a read-only, thresholded snapshot of the busiest processes. It samples CPU usage over a short interval (so it shows **current** usage, unlike the lifetime average in `ps %CPU` or the cumulative seconds in `Get-Process CPU`), lists the top *N* processes by CPU and by memory, and exits with code **3** when any process is at or above the CPU or memory threshold — ready for cron, Task Scheduler or a monitoring agent. Taught in [Day 08](../course/module-2/day-08.md) and used in [Lab 08](../labs/lab-08.md).

CPU is reported as a percentage of **one** logical processor (the Linux `top` convention): a process using two full cores shows 200%. Task Manager divides by all processors instead.

### Prerequisites

| Linux | Windows |
|---|---|
| Any Linux with `/proc` (Ubuntu 24.04 tested), Bash 4+, procps (`ps`), coreutils, `awk`. No root: other users' processes are included unless `/proc` is mounted with `hidepid`. | Windows 11, Windows PowerShell 5.1 or PowerShell 7. No admin: user names come from CIM `Win32_Process.GetOwner()`; protected processes show `n/a`. Also runs in PowerShell 7 on Linux (without user names). |

### Options

| Bash | PowerShell | Default | Meaning |
|---|---|---|---|
| `-n COUNT` | `-Top` | 10 | Processes per list (1–100) |
| `-c CPU_PCT` | `-CpuThreshold` | 90 | CPU warning threshold, % of one core (1–10000) |
| `-m MEM_PCT` | `-MemoryThreshold` | 50 | Memory warning threshold, % of RAM (1–100) |
| `-i SECONDS` | `-SampleSeconds` | 1 | Sampling interval (0–60); 0 = average since process start |
| <code>-f text&#124;csv</code> | <code>-Format Text&#124;Csv&#124;Json</code> | text | Output format |
| `-o DIR` | `-OutputPath DIR` | — | Also save a timestamped report file |
| `-h` | `Get-Help .\Process-Monitor.ps1 -Full` | — | Help |

Exit codes: `0` OK · `1` invalid arguments · `2` output folder problem · `3` threshold breached.

### How to run

```bash
cd scripts/linux
bash process-monitor.sh                          # top 10 by CPU and memory
bash process-monitor.sh -n 5 -c 50 -m 20         # stricter thresholds
bash process-monitor.sh -f csv -o ~/lpm-lab/reports
bash process-monitor.sh -n 3 > /dev/null; echo "exit: $?"   # 0 = OK, 3 = WARNING
```

```powershell
Set-Location scripts\powershell
.\Process-Monitor.ps1
.\Process-Monitor.ps1 -Top 5 -CpuThreshold 50 -Format Json
.\Process-Monitor.ps1 -Format Csv -OutputPath $HOME\lpm-lab\reports
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Process-Monitor.ps1 -Top 3; "exit: $LASTEXITCODE"
```

### Sample output (Bash; captured on 2026-11-10 in an Ubuntu 24.04.5 container with a lab busy loop running; host renamed, the two container-management processes replaced by generic names)

```text
==============================================
 Process Monitor Report
==============================================
Report time (UTC)        : 2026-11-10T16:59:03Z
Host name                : ubuntu-lab
Processes                : 79
Zombie processes         : 0
CPU cores                : 4
Load average (1/5/15)    : 0.22 0.11 0.09
CPU method               : 1s sample of /proc/PID/stat
Thresholds               : CPU >= 90% of one core, MEM >= 50% of RAM
Status                   : WARNING

--- Top 2 by CPU ---
    PID USER           %CPU  %MEM  RSS(MiB) STAT      ELAPSED COMMAND
   3860 root           99.0   0.0       3.3 R           00:02 lab08-report -c while :; do :; done
    175 root            1.0   1.8     305.5 Sl          20:33 /opt/agent/bin/agent --serve

--- Top 2 by memory ---
    PID USER           %CPU  %MEM  RSS(MiB) STAT      ELAPSED COMMAND
    175 root            1.0   1.8     305.5 Sl          20:33 /opt/agent/bin/agent --serve
    150 root            0.0   0.2      40.7 Sl          20:35 /usr/local/bin/env-manager

--- Threshold breaches ---
CPU 99.0% >= 90%  PID 3860 (root) lab08-report -c while :; do :; done
```

The exit code of that run was `3`. With no busy process the same command reported `Status : OK`, `Threshold breaches: none` and exit code `0`.

### Sample output (PowerShell; **example** of the layout on Windows — illustrative values, not captured on Windows; the memory list is omitted)

```text
==============================================
 Process Monitor Report
==============================================
Report time (UTC)    : 2026-11-10T16:47:32Z
Computer name        : WIN11-LAB
Processes            : 212
Logical CPUs         : 8
Total memory (MB)    : 16086
CPU method           : 1s sample of TotalProcessorTime
Thresholds           : CPU >= 90% of one CPU, memory >= 50% of RAM
Status               : WARNING
PowerShell           : 5.1.26100.9168 (Desktop)

--- Top 3 by CPU ---
     Id Name                  CPU%    WS(MB)   Mem% User                 CommandLine
   8744 powershell              96      62.1    0.4 WIN11-LAB\student    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
   3828 MsMpEng                3.1     312.4    1.9 NT AUTHORITY\SYSTEM  n/a
   9124 explorer               1.5      44.3    0.3 WIN11-LAB\student    C:\Windows\Explorer.EXE

--- Threshold breaches ---
PID 8744 powershell: CPU 96%, memory 0.4%
```

`n/a` in the *CommandLine* or *User* column means Windows did not allow a non-elevated session to read that protected process.

### Troubleshooting

| Problem | Fix |
|---|---|
| A busy process shows less than expected | It was busy only part of the interval; use `-i 5` / `-SampleSeconds 5` |
| CPU above 100% | Normal for multi-threaded processes: the value is % of **one** core |
| `-i 0` shows a low CPU value for a process that is busy now | Interval 0 reports the lifetime average (like `ps`); use the default sampling |
| `User` / `CommandLine` is `n/a` (Windows) | Protected or other users' processes in a non-elevated session; run elevated if you need them |
| `Total memory (MB): n/a` and no memory breaches | The memory query failed (CIM or `/proc/meminfo` unavailable); run with `-Verbose` |
| Script exits 3 in a scheduler and the job is marked as failed | Expected: 3 means *threshold breached*; configure the scheduler to treat 3 as a warning |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or the one-off `-ExecutionPolicy Bypass -File` form |

### Validation status

| Check | Linux script | PowerShell script |
|---|---|---|
| Executed | 2026-11-10 in an Ubuntu 24.04.5 container (Bash 5.2.21, procps-ng 4.0.4): no arguments, `-o`, `-f csv`, `-n/-c/-m/-i` values, a non-root run, invalid options/values (exit 1), unwritable `-o` (exit 2) and a busy loop above the threshold (exit 3). CI: GitHub `ubuntu-24.04` runner, every release | Executed 2026-11-10 with **PowerShell 7.4.6 on Linux** (Text/Csv/Json, `-OutputPath`, invalid values → exit 1, unwritable path → exit 2, busy loop → exit 3). **Not executed on Windows or in Windows PowerShell 5.1 before release**; CI runs it on `windows-latest` with 5.1 and 7 |
| Static analysis | `bash -n` and ShellCheck 0.9.0 (no findings at any severity) | PSScriptAnalyzer 1.23.0: no Error/Warning/Information findings; CI re-runs it |
