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
| 3 | `disk-monitor.sh` | `Disk-Monitor.ps1` | Filesystem usage with warning/critical thresholds | **Day 09 (available)** |
| 4 | `dns-check.sh` | `DNS-Check.ps1` | Forward/reverse lookups across resolvers | **Day 13 (available)** |
| 5 | `port-monitor.sh` | `Port-Monitor.ps1` | Listening ports and owning processes, baseline diff | **Day 14 (available)** |
| 6 | `network-diagnostic.sh` | `Network-Diagnostic.ps1` | Layered connectivity diagnosis | **Day 15 (available)** |
| 7 | `log-analyser.sh` | `Log-Analyser.ps1` | Error/warning summaries from system logs | **Day 16 (available)** |
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

## disk-monitor.sh / Disk-Monitor.ps1

**Purpose:** a read-only, thresholded report of filesystem (volume) usage. It lists every real filesystem with size, used, available and use%, flags those at or above the **warning** (default 80%) or **critical** (default 90%) threshold — and, on Linux, those whose **inode** usage is at or above 90% — and exits with code **3** when anything is breached. Optionally it lists the largest directories directly under a path. Taught in [Day 09](../course/module-2/day-09.md) and used in [Lab 09](../labs/lab-09.md).

Both scripts calculate use% the way `df` does: used ÷ (used + available), so blocks reserved for root on ext4 count as unavailable. Pseudo filesystems (`tmpfs`, `devtmpfs`, `squashfs` snaps, `overlay` and kernel interfaces) are excluded by default on Linux; on Windows only **Fixed** drives are included by default.

### Prerequisites

| Linux | Windows |
|---|---|
| Any Linux with GNU coreutils 8.21+ (`df --output`, `du`) — Ubuntu 24.04 tested — Bash 4+, `awk`, `sort`. No root needed; with `-p`, directories you cannot read are skipped and counted. | Windows 11, Windows PowerShell 5.1 or PowerShell 7. No admin: volume data comes from .NET `System.IO.DriveInfo`; folders you cannot read are skipped and counted. Also runs in PowerShell 7 on Linux (each mount point is a "drive"). |

### Options

| Bash | PowerShell | Default | Meaning |
|---|---|---|---|
| `-w WARN_PCT` | `-WarningPercent` | 80 | Warning threshold, % used (1–100) |
| `-c CRIT_PCT` | `-CriticalPercent` | 90 | Critical threshold, % used (1–100, ≥ warning) |
| `-i INODE_PCT` | — | 90 | Inode warning threshold (Linux only) |
| `-a` | <code>-DriveType Fixed,Removable,Network,Ram,CDRom,Unknown</code> | real filesystems / `Fixed` | Include pseudo filesystems / other drive types |
| `-m PATH` | `-DriveName NAME` | all | Only the filesystem holding PATH / drives whose name matches (`C`, `R:\`, `/srv/lab09`) |
| `-p PATH` | `-FolderPath PATH` | — | Also list the largest directories directly under PATH |
| `-n COUNT` | `-Top` | 10 | Number of directories to list (1–50) |
| <code>-f text&#124;csv</code> | <code>-Format Text&#124;Csv&#124;Json</code> | text | Output format |
| `-o DIR` | `-OutputPath DIR` | — | Also save a timestamped report file |
| `-h` | `Get-Help .\Disk-Monitor.ps1 -Full` | — | Help |

Exit codes: `0` OK · `1` invalid arguments · `2` output folder problem · `3` threshold breached. Levels: `OK`, `WARNING`, `CRITICAL`, and on Linux `INODES` (or `WARNING+INODES` / `CRITICAL+INODES`).

### How to run

```bash
cd scripts/linux
bash disk-monitor.sh                                   # all real filesystems
bash disk-monitor.sh -w 70 -c 85                       # stricter thresholds
bash disk-monitor.sh -m /var -p /var -n 5              # only /var's filesystem + its top 5 directories
sudo bash disk-monitor.sh -p / -n 10                   # top directories of / (sudo reads everything)
bash disk-monitor.sh -f csv -o ~/lpm-lab/reports
bash disk-monitor.sh > /dev/null; echo "exit: $?"      # 0 = OK, 3 = WARNING/CRITICAL/INODES
```

```powershell
Set-Location scripts\powershell
.\Disk-Monitor.ps1
.\Disk-Monitor.ps1 -WarningPercent 70 -CriticalPercent 85
.\Disk-Monitor.ps1 -DriveName C -FolderPath C:\Users -Top 5
.\Disk-Monitor.ps1 -Format Json -OutputPath $HOME\lpm-lab\reports
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Disk-Monitor.ps1 -DriveName C; "exit: $LASTEXITCODE"
```

When you call the script with `powershell.exe -File` or `pwsh -File`, pass a single drive type or name; lists such as `-DriveType Fixed,Network` are bound reliably only when you run the script from inside PowerShell (`.\Disk-Monitor.ps1 -DriveType Fixed, Network`).

### Sample output (Bash; captured on 2026-11-11 in an Ubuntu 24.04.5 container during the Lab 09 scenario; host renamed)

```text
==============================================
 Disk Monitor Report
==============================================
Report time (UTC)    : 2026-11-11T17:00:40Z
Host name            : ubuntu-lab
Filesystems          : 1 (only the one holding /srv/lab09)
Thresholds           : space WARN >= 80%, CRIT >= 90%; inodes >= 90%
Pseudo filesystems   : included
Status               : CRITICAL

--- Filesystems ---
FILESYSTEM             TYPE         SIZE     USED    AVAIL  USE%  IUSE% LEVEL           MOUNTED_ON
/dev/loop0             ext4       223.7M   195.0M    10.8M    95      1 CRITICAL        /srv/lab09

--- Threshold breaches ---
CRITICAL        /srv/lab09 used 95%, inodes 1% (/dev/loop0, ext4)

--- Largest directories under /srv/lab09 (du -x, one level) ---
    165.0M  /srv/lab09 (total)
    120.0M  /srv/lab09/app
     45.0M  /srv/lab09/backups
       16K  /srv/lab09/lost+found
        8K  /srv/lab09/reports
Unreadable entries skipped: 0
```

The exit code was `3`. `Pseudo filesystems: included` appears because `-m` checks the requested filesystem whatever its type. The `du` total (165M) is 30M smaller than `USED` (195M) because of a deleted-but-open file — exactly the situation Lab 09 investigates. After the lab clean-up the same command reported `Status : OK` (8% used) and exit code `0`. A spool filesystem with all inodes used was reported as `INODES … used 32%, inodes 100%` (exit 3).

### Sample output (PowerShell; **example** of the layout on Windows — illustrative values, not captured on Windows)

```text
==============================================
 Disk Monitor Report
==============================================
Report time (UTC)    : 2026-11-11T17:05:12Z
Computer name        : WIN11-LAB
Volumes              : 2
Drive types          : Fixed
Thresholds           : WARNING >= 80%, CRITICAL >= 90% used
Status               : WARNING
PowerShell           : 5.1.26100.9168 (Desktop)

--- Volumes ---
Name                   FS       Type        Size(GB)   Used(GB)   Free(GB)   Use% Level     Label
C:\                    NTFS     Fixed         236.53     162.41      74.12   68.7 OK        Windows
R:\                    NTFS     Fixed           0.23       0.19       0.04   83.0 WARNING   LAB09

--- Threshold breaches ---
WARNING   R:\ used 83% (0.04 GB free of 0.23 GB)
```

### Troubleshooting

| Problem | Fix |
|---|---|
| `df --output failed (GNU coreutils 8.21 or later is required)` | You are on macOS/BSD or BusyBox `df`; run on a GNU/Linux system |
| A `/snap/...` or `tmpfs` filesystem is missing from the report | Pseudo filesystems are excluded by design; add `-a`, or `-m PATH` for one specific mount |
| `Unreadable entries skipped` is greater than 0 | Some directories under `-p` are not readable by your user; run with `sudo` for a complete total |
| `-p` is slow | `du` walks every file; point it at a smaller directory or run it outside business hours |
| `IUSE%` shows `n/a` | The filesystem does not report inodes (vfat, Btrfs reports dynamic values); inode checks are skipped |
| A network share is missing (Windows) | Only `Fixed` drives are included by default; add `-DriveType Fixed, Network` from inside PowerShell |
| `Label` is `n/a` (Windows) | The volume has no label, or (Linux) `DriveInfo` does not provide one |
| Script exits 3 in a scheduler and the job is marked as failed | Expected: 3 means *threshold breached*; configure the scheduler to treat 3 as a warning |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or the one-off `-ExecutionPolicy Bypass -File` form |

### Validation status

| Check | Linux script | PowerShell script |
|---|---|---|
| Executed | 2026-11-11 in an Ubuntu 24.04.5 container (Bash 5.2.21, GNU coreutils 9.4): no arguments, `-p`, `-m`, `-n`, `-f csv`, `-a`, `-o`, a non-root run with an unreadable directory (counted), invalid options and values and `-c` below `-w` (exit 1), unwritable `-o` (exit 2), a 95% loop-device filesystem and an inode-exhausted one (exit 3), and the cleaned filesystem (exit 0). CI: GitHub `ubuntu-24.04` runner, every release | **Not executed before release** (no PowerShell available on the release host). Reviewed against the .NET `DriveInfo` and PowerShell documentation; CI parses it and runs it on `windows-latest` with Windows PowerShell 5.1 and PowerShell 7 (no arguments and `-OutputPath`) and runs PSScriptAnalyzer |
| Static analysis | `bash -n` and ShellCheck 0.10.0 (no findings at any severity) | PSScriptAnalyzer in CI (Error and Warning severities) |

## dns-check.sh / DNS-Check.ps1

**Purpose:** read-only forward and reverse DNS checks across several resolvers. For each name and record type the scripts ask every selected resolver — including the **system** resolver, which also reads the hosts file — and report the status (`OK`, `NODATA`, `NXDOMAIN`, `SERVFAIL`, `REFUSED`, `TIMEOUT`, `CONN-REFUSED`, `NOTFOUND`…), the TTL, the query time and the answers. They flag resolvers that return **different answers** and, with `-r` / `-Reverse`, check that every address has a PTR record that resolves back to the same address (forward-confirmed reverse DNS). Any failed lookup, disagreement or PTR problem gives exit code **3**. Taught in [Day 13](../course/module-3/day-13.md) and used in [Lab 13](../labs/lab-13.md).

### Prerequisites

| Linux | Windows |
|---|---|
| Any Linux with Bash 4+, glibc `getent`, `awk`, `sort` (Ubuntu 24.04 tested). Recommended: `dig` (`sudo apt install bind9-dnsutils`); without it `host` is used, and without both only the system resolver is checked (per-server rows show `n/a`). `resolvectl`, when present, adds the upstream servers to the default list. No root needed. | Windows 11, Windows PowerShell 5.1 or PowerShell 7. No admin. Uses `Resolve-DnsName` and `Get-DnsClientServerAddress` (DnsClient module). In PowerShell 7 on Linux/macOS only the system resolver is available through `System.Net.Dns` (A, AAAA, PTR); per-server lookups show `n/a`. |

### Options

| Bash | PowerShell | Default | Meaning |
|---|---|---|---|
| `-n NAME[,NAME…]` | `-Name` | `example.com` on all resolvers + own host name on the system resolver | Names to check (max 50) |
| `-s SERVER[,SERVER…]` | `-Server` | system + resolv.conf servers + resolvectl upstreams / System + adapter DNS servers | IPv4/IPv6 addresses or `system` / `System` |
| `-t TYPE[,TYPE…]` | `-Type` | A, AAAA | A AAAA CNAME MX NS TXT SOA SRV PTR (+ CAA in Bash only) |
| `-r` | `-Reverse` | off | PTR + forward-confirmation for every address found |
| `-w SECONDS` | `-TimeoutSeconds` (system lookups on Linux/macOS) · `-NoQuickTimeout` (Windows) | 2 / 5 / quick timeout | Timeouts; Bash tries each query once |
| <code>-f text&#124;csv</code> | <code>-Format Text&#124;Csv&#124;Json</code> | text | Output format |
| `-o DIR` | `-OutputPath DIR` | — | Also save `dns-check-<host>-<UTC>.<ext>` / `DNS-Check-<COMPUTER>-<UTC>.<ext>` |
| `-h` | `Get-Help .\DNS-Check.ps1 -Full` | — | Help |

Exit codes: `0` OK · `1` invalid arguments · `2` output folder problem · `3` a lookup failed, resolvers disagree or a PTR is missing/mismatched. `NODATA` (the name exists but has no record of that type) is reported but is not a failure; a `NOTFOUND` from the system resolver counts only when it found no address of any requested type for that name. The system resolver takes part in the answer comparison for A records only (it may omit AAAA on IPv4-only hosts).

### How to run

```bash
cd scripts/linux
bash dns-check.sh                                             # defaults
bash dns-check.sh -n www.corp.example,intranet.corp.example -r
bash dns-check.sh -n app.corp.example -t A -s system,192.168.13.53,192.168.13.54
bash dns-check.sh -n corp.example -t MX,TXT,NS,SOA,CAA -s 192.168.13.53
bash dns-check.sh -f csv -o ~/lpm-lab/reports
bash dns-check.sh > /dev/null; echo "exit: $?"                # 0 = OK, 3 = problem found
```

```powershell
Set-Location scripts\powershell
.\DNS-Check.ps1
.\DNS-Check.ps1 -Name www.corp.example, intranet.corp.example -Server System, 192.168.13.53 -Reverse
.\DNS-Check.ps1 -Name corp.example -Type MX, TXT, NS, SOA -Format Csv -OutputPath $HOME\lpm-lab\reports
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DNS-Check.ps1 -Name corp.example; "exit: $LASTEXITCODE"
```

With `powershell.exe -File` / `pwsh -File`, pass a single value per list parameter; lists such as `-Name a, b` bind reliably only when you run the script from inside PowerShell.

### Sample output (Bash; captured on 2026-11-13 on the Lab 13 client namespace, Ubuntu 24.04.5 container, round 2 — stale `/etc/hosts` entry; host name `vm`)

```text
==============================================
 DNS Check Report
==============================================
Report time (UTC)    : 2026-11-13T16:55:16Z
Host name            : vm
Lookup tool          : dig (9.18.39-0ubuntu0.24.04.9-Ubuntu)
Resolvers            : system 192.168.13.53 192.168.13.54
Record types         : A
Timeout              : 2s per query, 1 try
Reverse check        : yes
Status               : PROBLEMS FOUND

--- Lookups ---
NAME                         TYPE  SERVER           STATUS          TTL     MS  ANSWERS
app.corp.example             A     system           OK              n/a      4  192.168.13.99
app.corp.example             A     192.168.13.53    OK              300      0  192.168.13.80
app.corp.example             A     192.168.13.54    OK              300      0  192.168.13.80

--- Resolver consistency ---
DIFFER  app.corp.example             A     192.168.13.53=192.168.13.80; 192.168.13.54=192.168.13.80; system=192.168.13.99

--- Reverse (PTR) check ---
ADDRESS                                  PTR                                STATUS     CONFIRMED VIA
192.168.13.99                            -                                  NXDOMAIN   n/a       192.168.13.53
192.168.13.80                            www.corp.example.                  OK         yes       192.168.13.53

--- Problems ---
DIFFER    app.corp.example A: resolvers return different answers (192.168.13.53=192.168.13.80; 192.168.13.54=192.168.13.80; system=192.168.13.99)
PTR       192.168.13.99 has no PTR record (NXDOMAIN via 192.168.13.53)
```

The exit code was `3`. The Lookups, consistency, reverse and Problems lines are as captured; the header block shows the same run's settings, with the report time approximate (the header of that run was not kept). After the hosts line was removed the same command reported `Status : OK`, `SAME … 3 resolvers agree` and exit code `0`. Other captured rounds: a broken zone gave `SERVFAIL` via both servers, a firewalled resolver `TIMEOUT`, a resolver address with no DNS service `CONN-REFUSED`. CSV output (captured):

```text
section,name,type,server,status,ttl,ms,answers
lookup,app.corp.example,A,192.168.13.53,OK,300,0,"192.168.13.80"
lookup,app.corp.example,MX,192.168.13.53,NODATA,n/a,0,"-"
lookup,mail.corp.example,A,192.168.13.53,OK,300,0,"192.168.13.25"
lookup,mail.corp.example,MX,192.168.13.53,NODATA,n/a,4,"-"
```

### Sample output (PowerShell; **example** of the layout on Windows — illustrative values, not captured)

```text
==============================================
 DNS Check Report
==============================================
Report time (UTC)    : 2026-11-13T17:10:02Z
Computer name        : WIN11-LAB
Lookup method        : Resolve-DnsName (DnsClient module)
Resolvers            : System 192.168.1.1
Record types         : A AAAA
Reverse check        : no
Status               : OK
PowerShell           : 5.1.26100.9168 (Desktop)

--- Lookups ---
NAME                         TYPE  SERVER           STATUS        TTL     MS  ANSWERS
example.com                  A     System           OK           1800     21  96.7.128.175 96.7.128.198 ...
example.com                  A     192.168.1.1      OK           1800      9  96.7.128.175 96.7.128.198 ...
example.com                  AAAA  System           OK           1800      3  2600:1406:3a00:21::173e:2e65 ...
example.com                  AAAA  192.168.1.1      OK           1800      8  2600:1406:3a00:21::173e:2e65 ...
WIN11-LAB                    A     System           OK           1200      2  192.168.1.23

--- Resolver consistency ---
SAME    example.com                  A     2 resolvers agree
SAME    example.com                  AAAA  2 resolvers agree

--- Problems ---
None.
```

### Troubleshooting

| Problem | Fix |
|---|---|
| Every row for a server shows `n/a` (Bash) | Neither `dig` nor `host` is installed: `sudo apt install bind9-dnsutils` |
| `system … NOTFOUND` for AAAA while DNS servers return an AAAA | Normal on hosts without a global IPv6 address (`getaddrinfo` `AI_ADDRCONFIG`); AAAA from `system` is not compared |
| `DIFFER` for a large public site | CDNs and geo-DNS return different addresses per resolver and over time; check only names you control, or interpret the result |
| `PTR … does not resolve back` for cloud/CDN addresses | Their PTR names belong to the provider; expected for third-party services |
| `CONN-REFUSED` | Nothing listens on port 53 at that address — wrong server address or the DNS service is stopped |
| `TIMEOUT` | No reply within `-w`: firewall, routing or server down (Day 12 tests to the resolver) |
| Default run reports your own host name as not found | `/etc/hosts` (Linux) or name registration (Windows) does not contain the machine's name — worth fixing, or pass `-n` |
| `Resolve-DnsName` missing (PowerShell on Linux) | The script falls back to `System.Net.Dns` (system resolver only) automatically |
| Script exits 3 in a scheduler and the job is marked as failed | Expected: 3 means *problem found*; treat 3 as a warning/alert |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or the one-off `-ExecutionPolicy Bypass -File` form |

### Validation status

| Check | Linux script | PowerShell script |
|---|---|---|
| Executed | 2026-11-13 in an Ubuntu 24.04.5 container (Bash 5.2.21, dig 9.18.39) inside the Lab 13 namespaces: healthy lab (exit 0), each fault round 1–6 (exit 3 with `CONN-REFUSED`/`NOTFOUND`, `DIFFER`, `NXDOMAIN`, `SERVFAIL`, `TIMEOUT`, missing PTR), `-r`, `-t` with MX/TXT/NS/SOA/CAA/SRV/CNAME, `-f csv`, `-o`, the `host` fallback and getent-only mode (restricted `PATH`), a run as `nobody`, invalid `-w`/`-t`/`-s`/`-n`/`-f`/unknown option/missing argument (exit 1), unwritable `-o` (exit 2); and in the container's own network with no arguments and with `-o` (exit 3, because the sandbox DNS answers NXDOMAIN for every public name). CI: GitHub `ubuntu-24.04` runner, every release | **Not executed before release** (no PowerShell available on the release host). Written against the DnsClient and .NET `System.Net.Dns` documentation for StrictMode, 5.1 and 7; CI parses it and runs it on `windows-latest` with Windows PowerShell 5.1 and PowerShell 7 (no arguments and `-OutputPath`) and runs PSScriptAnalyzer |
| Static analysis | `bash -n` and ShellCheck 0.9.0 (no findings at any severity) | PSScriptAnalyzer in CI (Error and Warning severities) |

## port-monitor.sh / Port-Monitor.ps1

**Purpose:** a read-only report of every listening TCP socket and UDP endpoint with its local address, port, owning process and — with options — an **exposure check** (listeners bound to all addresses on ports that are not explicitly allowed), a **baseline comparison** (NEW / GONE listeners) and a **summary of TCP connections by state**. It exits with code **3** when a NEW listener or an exposed port is found, so it can drive cron, Task Scheduler or a monitoring agent. Taught in [Day 14](../course/module-3/day-14.md) and used in [Lab 14](../labs/lab-14.md).

Both scripts write and read the **same baseline format** — one `proto address port` line per listener, `#` comments allowed — so a baseline saved by one can be compared by the other. Process names and PIDs are deliberately **not** part of the baseline key, because they change on every restart and are `n/a` for non-root runs.

### Prerequisites

| Linux | Windows |
|---|---|
| Any Linux with iproute2 `ss` (Ubuntu 24.04 tested); falls back to net-tools `netstat`, then to `/proc/net/{tcp,tcp6,udp,udp6}` (no process information). Bash 4+, `awk`, `sort`, `comm`, `ps`. No root needed: without root, owners of other users' sockets are shown as `n/a` and the report says so; run with `sudo` for a complete list. `/etc/services` (netbase) for service names. | Windows 11, Windows PowerShell 5.1 or PowerShell 7. No admin: listeners come from `Get-NetTCPConnection` / `Get-NetUDPEndpoint` (NetTCPIP), process names from `Get-Process`, service names from `Win32_Service` (CIM, best effort). In PowerShell 7 on Linux/macOS the script uses .NET `IPGlobalProperties` and reports process information as `n/a`. |

### Options

| Bash | PowerShell | Default | Meaning |
|---|---|---|---|
| `-t` / `-u` | <code>-Protocol Tcp&#124;Udp</code> | both | TCP listeners only / UDP endpoints only |
| `-e` | `-CheckExposure` | off | Flag listeners on `0.0.0.0`, `::` or `*` whose port is not allowed |
| `-a PORTS` | `-AllowedPort` | 22 | Ports allowed on all addresses (comma-separated in Bash) |
| `-c` | `-ConnectionSummary` | off | Count TCP connections by state (listeners excluded) |
| `-b FILE` | `-BaselinePath` | — | Compare with a saved baseline: NEW and GONE |
| `-s FILE` | `-SaveBaselinePath` | — | Save the current listeners as a baseline |
| <code>-f text&#124;csv</code> | <code>-Format Text&#124;Csv&#124;Json</code> | text | Output format |
| `-o DIR` | `-OutputPath DIR` | — | Also save a timestamped report file |
| `-h` | `Get-Help .\Port-Monitor.ps1 -Full` | — | Help |

Exit codes: `0` OK · `1` invalid arguments (including a missing `-b` file) · `2` output folder or baseline file cannot be written/read · `3` NEW listener or exposed port. Columns: `BOUND_TO` is `ALL`, `LOOPBACK` or `SPECIFIC`; `FLAG` is `EXPOSED` or `-`.

### How to run

```bash
cd scripts/linux
bash port-monitor.sh                                  # listeners (own processes only)
sudo bash port-monitor.sh -c                          # all owners + connection states
sudo bash port-monitor.sh -t -e -a 22,443             # exposure audit, TCP only
sudo bash port-monitor.sh -s ~/lpm-lab/ports-baseline.txt          # save a baseline
sudo bash port-monitor.sh -b ~/lpm-lab/ports-baseline.txt; echo "exit: $?"   # 3 = NEW listener
bash port-monitor.sh -f csv -o ~/lpm-lab/reports
```

```powershell
Set-Location scripts\powershell
.\Port-Monitor.ps1
.\Port-Monitor.ps1 -Protocol Tcp -CheckExposure -AllowedPort 135, 445, 3389
.\Port-Monitor.ps1 -SaveBaselinePath $HOME\lpm-lab\ports-baseline.txt
.\Port-Monitor.ps1 -BaselinePath $HOME\lpm-lab\ports-baseline.txt -ConnectionSummary
.\Port-Monitor.ps1 -Format Json -OutputPath $HOME\lpm-lab\reports
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Port-Monitor.ps1 -Protocol Tcp; "exit: $LASTEXITCODE"
```

On a Windows workstation, dozens of listeners on all addresses are normal (RPC 135, SMB 445, dynamic RPC ports 49664–49669 …); build a per-host baseline first and use `-CheckExposure` with a realistic `-AllowedPort` list, or the report will flag them all.

### Sample output (Bash; captured on 2026-11-13 in an Ubuntu 24.04.5 container during the Lab 14 incident, inside the `lab14-app` namespace; host renamed)

```text
==============================================
 Port Monitor Report
==============================================
Report time (UTC)    : 2026-11-13T16:56:48Z
Host name            : ubuntu-lab
Protocols            : TCP UDP
Data source          : ss
Listeners            : 5
Exposed listeners    : 2 (allowed on all addresses: 443)
Baseline             : /root/lab14/ports-baseline.txt (NEW 2, GONE 0)
Status               : ALERT

--- Listening sockets ---
PROTO ADDRESS                      PORT   SERVICE        PROCESS          PID      USER       BOUND_TO  FLAG
tcp   0.0.0.0                      443    https          python3          5489     nobody     ALL       -
tcp   0.0.0.0                      4444   n/a            nc               5534     nobody     ALL       EXPOSED
tcp   127.0.0.1                    6379   redis          python3          5457     nobody     LOOPBACK  -
tcp   127.0.0.1                    8443   n/a            python3          5490     nobody     LOOPBACK  -
tcp   0.0.0.0                      9090   n/a            python3          5536     nobody     ALL       EXPOSED

--- Compared with baseline ---
NEW   tcp 0.0.0.0 4444
NEW   tcp 0.0.0.0 9090

--- TCP connections by state (listeners excluded) ---
      3  TIME-WAIT
      1  ESTAB
```

The command was `port-monitor.sh -e -a 443 -b ~/lab14/ports-baseline.txt -c` and the exit code was `3`. A run as the `nobody` user on the container host printed `Process info : own processes only (3 shown as n/a; run with sudo for all)` and `n/a` in the PROCESS/PID/USER columns. The `SERVICE` column is the `/etc/services` name for the port, not proof of the program (6379 is registered for Redis; here it was a Python test server).

### Sample output (PowerShell; **example** of the layout on Windows — illustrative values, not captured on Windows)

```text
==============================================
 Port Monitor Report
==============================================
Report time (UTC)    : 2026-11-13T17:10:05Z
Computer name        : WIN11-LAB
Protocols            : Tcp
Data source          : Get-NetTCPConnection / Get-NetUDPEndpoint
Listeners            : 13
Status               : ALERT
PowerShell           : 5.1.26100.9168 (Desktop)
Baseline             : C:\Users\student\lpm-lab\ports-baseline.txt (NEW 1, GONE 0)

--- Listening sockets ---
PROTO ADDRESS                      PORT   PID      PROCESS              BOUND_TO  FLAG     SERVICES
tcp   0.0.0.0                      135    1172     svchost              ALL       -        RpcEptMapper,RpcSs
tcp   ::                           135    1172     svchost              ALL       -        RpcEptMapper,RpcSs
tcp   ::                           445    4        System               ALL       -        n/a
tcp   127.0.0.1                    44444  7316     powershell           LOOPBACK  -        n/a
...

--- Compared with baseline ---
NEW   tcp 127.0.0.1 44444
```

### Troubleshooting

| Problem | Fix |
|---|---|
| `Process info : own processes only (N shown as n/a …)` | Normal for a non-root run; use `sudo` for the owners of other users' sockets |
| `Data source : /proc/net` and every process is `n/a` | Neither `ss` nor `netstat` is installed (minimal container); install `iproute2` |
| Hundreds of NEW/GONE lines after a reboot | The baseline contains dynamic RPC ports (Windows) or ports of services started on demand; rebuild it after a clean start and review it |
| Every Windows system port is `EXPOSED` | Add the ports you accept to `-AllowedPort` (for example `135, 445, 5040`) after reviewing them |
| `-b '…' is not a readable file` (exit 1) | The baseline path is wrong; create one with `-s` / `-SaveBaselinePath` first |
| `cannot write baseline file` (exit 2) | The directory does not exist or is not writable; create it first |
| `SERVICES` is `n/a` (Windows) | The process hosts no service, or `Win32_Service` could not be queried |
| `Data source : .NET IPGlobalProperties (no process information)` on Windows | `Get-NetTCPConnection` is unavailable (very old or stripped system); owners cannot be shown |
| Script exits 3 in a scheduler and the job is marked as failed | Expected: 3 means *new listener or exposure found*; configure the scheduler to treat 3 as an alert |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or the one-off `-ExecutionPolicy Bypass -File` form |

### Validation status

| Check | Linux script | PowerShell script |
|---|---|---|
| Executed | 2026-11-13 in an Ubuntu 24.04.5 container (Bash 5.2.21, iproute2 6.1.0 `ss`), on the container host and inside the Lab 14 namespaces: no arguments, `-o`, `-f csv`, `-t`, `-u`, `-e -a`, `-c`, `-s` + `-b` with a new listener (exit 3) and with a removed listener (GONE, exit 0), non-root run as `nobody` (owners `n/a`), the `netstat` and `/proc/net` fallbacks (PATH without `ss`/`netstat`), invalid options/format/ports/`-b` path/extra argument (exit 1), unwritable `-o` and `-s` (exit 2). CI: GitHub `ubuntu-24.04` runner, every release | **Not executed before release** (PowerShell could not be installed on the release host). Cmdlet syntax and `-State` values checked against the MicrosoftDocs/windows-powershell-docs source (NetTCPIP); .NET `IPGlobalProperties` usage reviewed from the .NET API documentation. CI parses it, runs it on `windows-latest` with Windows PowerShell 5.1 and PowerShell 7 (no arguments and `-OutputPath`) and runs PSScriptAnalyzer |
| Static analysis | `bash -n` and ShellCheck 0.9.0 (no findings at any severity, `-S style`) | PSScriptAnalyzer in CI (Error and Warning severities) |

## network-diagnostic.sh / Network-Diagnostic.ps1

**Purpose:** a read-only, **layered** diagnosis of one network interface, bottom-up — link state and carrier, MTU/MAC, speed/duplex, addresses, error and drop counters, default route, gateway neighbour (ARP) state and ping, DNS configuration, an optional DNS lookup and an optional TCP port test. Every check prints one line with `OK`, `WARN`, `FAIL` or `n/a` and a short explanation; the first `FAIL` from the top is usually the layer to fix. The scripts exit with code **3** when any check fails, so they can drive cron, Task Scheduler or a monitoring agent. Taught in [Day 15](../course/module-3/day-15.md) and used in [Lab 15](../labs/lab-15.md).

The two scripts run the same checks with the same names, so their reports can be compared line by line. A gateway that does not answer ping while its ARP entry is `REACHABLE`/`STALE` is reported as `WARN`, not `FAIL`: many routers and cloud gateways drop ICMP on purpose.

### Prerequisites

| Linux | Windows |
|---|---|
| Any Linux with iproute2 `ip` and `/sys/class/net` (Ubuntu 24.04 tested). Bash 4+, `awk`, coreutils `timeout`. Optional: `ethtool` (speed/duplex when `/sys` does not report it), `ping` (iputils-ping), `getent`. No root needed; checks whose tool or permission is missing are `n/a`. The TCP test uses Bash's `/dev/tcp` with a 5-second timeout. | Windows 11, Windows PowerShell 5.1 or PowerShell 7. No admin: NetAdapter (`Get-NetAdapter`, `Get-NetAdapterStatistics`), NetTCPIP (`Get-NetIPAddress`, `Get-NetRoute`, `Get-NetNeighbor`) and DnsClient (`Get-DnsClientServerAddress`). Ping, DNS lookup and the TCP test use .NET (`Ping`, `Dns.GetHostAddresses`, `TcpClient`) on every OS. In PowerShell 7 on Linux/macOS the script uses `System.Net.NetworkInformation.NetworkInterface`; ARP state and carrier are then `n/a`. |

### Options

| Bash | PowerShell | Default | Meaning |
|---|---|---|---|
| `-i IFACE` | `-InterfaceAlias NAME` | default-route interface | Interface to check; without a default route, the first non-loopback interface that is up |
| `-t HOST` | `-Target HOST` | — | Also test a TCP connection to HOST |
| `-p PORT` | `-Port PORT` | 443 | TCP port for `-t` / `-Target` (requires it) |
| `-n NAME` | `-DnsName NAME` | — | Also resolve NAME with the system resolver (hosts file + DNS) |
| `-e MAXERR` | `-MaxErrors N` | 0 | Errors + drops allowed: errors above the limit = `FAIL`, drops alone = `WARN` |
| <code>-f text&#124;csv</code> | <code>-Format Text&#124;Csv&#124;Json</code> | text | Output format |
| `-o DIR` | `-OutputPath DIR` | — | Also save a timestamped report file |
| `-h` | `Get-Help .\Network-Diagnostic.ps1 -Full` | — | Help |

Exit codes: `0` OK (warnings allowed) · `1` invalid arguments (unknown interface, bad port, `-p` without `-t`) · `2` output folder cannot be created or written · `3` at least one check failed. Checks, in order: `link-state`, `carrier`, `mtu-mac`, `speed-duplex`, `addresses`, `counters`, `default-route`, `gateway-neighbour`, `gateway-ping`, `dns-config`, `dns-lookup` (with `-n`), `tcp-connect` (with `-t`).

Drops are not errors: Linux counts frames for protocols nobody listens to in `rx_dropped`, and Windows counts filtered packets as discards, so a healthy host can show a few. Interface counters are totals **since the interface came up**; compare two runs a few minutes apart (or `ip -s link`) to see whether they are still growing.

### How to run

```bash
cd scripts/linux
bash network-diagnostic.sh                                   # default-route interface
bash network-diagnostic.sh -i enp0s3 -n www.example.com -t www.example.com -p 443
bash network-diagnostic.sh -e 100; echo "exit: $?"           # tolerate up to 100 errors+drops
bash network-diagnostic.sh -f csv -o ~/lpm-lab/reports
```

```powershell
Set-Location scripts\powershell
.\Network-Diagnostic.ps1
.\Network-Diagnostic.ps1 -InterfaceAlias 'Ethernet' -DnsName www.example.com -Target www.example.com -Port 443
.\Network-Diagnostic.ps1 -MaxErrors 100 -Format Json -OutputPath $HOME\lpm-lab\reports
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Network-Diagnostic.ps1; "exit: $LASTEXITCODE"
```

### Sample output (Bash; captured on 2026-11-14 in an Ubuntu 24.04.5 container inside a test network namespace whose default route points to a gateway address that does not exist; host renamed)

```text
==============================================
 Network Diagnostic Report
==============================================
Report time (UTC)    : 2026-11-14T16:45:19Z
Host name            : ubuntu-lab
Interface            : ndt-c (default route)
Error limit (-e)     : 0
Status               : FAIL (2 failed, 1 warnings)

--- Checks (bottom-up: link -> IP -> gateway -> DNS -> port) ---
CHECK              STATUS DETAIL
link-state         OK    admin up, operstate up
carrier            OK    carrier detected
mtu-mac            OK    MTU 1500, MAC 2e:56:6a:20:53:64
speed-duplex       OK    10000 Mb/s, duplex full
addresses          OK    IPv4 10.15.9.10/24; IPv6 global none
counters           WARN  rx_errors 0, tx_errors 0, rx_dropped 0, tx_dropped 2 (since the interface came up; limit 0)
default-route      OK    via 10.15.9.254 dev ndt-c
gateway-neighbour  FAIL  10.15.9.254 is INCOMPLETE: no ARP/ND reply (wrong gateway, VLAN or link problem)
gateway-ping       FAIL  no reply from 10.15.9.254
dns-config         OK    nameserver(s) in /etc/resolv.conf: 8.8.8.8 8.8.4.4
dns-lookup         OK    localhost -> 127.0.0.1
tcp-connect        OK    10.15.9.1:8443 open (4 ms)
```

The command was `network-diagnostic.sh -t 10.15.9.1 -p 8443 -n localhost` and the exit code was `3`. The host could still reach its own subnet (the TCP test to `10.15.9.1` succeeded), but the gateway `10.15.9.254` never answered ARP: the classic *wrong default gateway* fault. The veth test interface reports a nominal 10000 Mb/s; real NICs report their negotiated speed. Other captured results in the same namespaces: peer interface down → `link-state FAIL … operstate down` and `carrier FAIL`; interface administratively down → `link-state FAIL admin down … (fix: sudo ip link set ndt-c up)`; no default route → `default-route FAIL`; closed port → `tcp-connect FAIL … connection refused`; port dropped by a firewall rule → `tcp-connect FAIL … timed out after 5 s`; absent host on the local subnet → `tcp-connect FAIL … no route to host`.

### Sample output (PowerShell; **example** of the layout on Windows — illustrative values, not captured on Windows)

```text
==============================================
 Network Diagnostic Report
==============================================
Report time (UTC)    : 2026-11-14T17:05:41Z
Computer name        : WIN11-LAB
Interface            : Ethernet (default route)
Data source          : NetAdapter / NetTCPIP / DnsClient cmdlets
Error limit          : 0
Status               : OK (0 failed, 0 warnings)
PowerShell           : 5.1.26100.9168 (Desktop)

--- Checks (bottom-up: link -> IP -> gateway -> DNS -> port) ---
CHECK              STATUS DETAIL
link-state         OK    admin Up, status Up
carrier            OK    media connected
mtu-mac            OK    MTU 1500, MAC 00-15-5D-01-0A-23
speed-duplex       OK    1 Gbps, full duplex
addresses          OK    IPv4 192.168.1.50/24; IPv6 global none
counters           OK    rx_errors 0, tx_errors 0, rx_discards 0, tx_discards 0 (since the adapter started; limit 0)
default-route      OK    via 192.168.1.1 on 'Ethernet'
gateway-neighbour  OK    192.168.1.1 is Reachable (MAC 00-11-22-33-44-55)
gateway-ping       OK    2 of 2 replies, avg rtt 1 ms
dns-config         OK    DNS server(s) on 'Ethernet': 192.168.1.1
dns-lookup         OK    www.example.com -> 93.184.215.14
tcp-connect        OK    www.example.com:443 open (38 ms)
```

### Troubleshooting

| Problem | Fix |
|---|---|
| `interface FAIL no default route and no non-loopback interface is UP` | Every interface is down or unconfigured; check `ip -br link` / `Get-NetAdapter` and bring the right one up |
| `interface 'X' does not exist` (exit 1) | Use the exact name from `ip -br link` (`enp0s3`, `ens33`, `eth0`) or `Get-NetAdapter` (`Ethernet`, `Wi-Fi`) |
| `counters WARN` on a healthy host | Drops include harmless discards; compare two runs or raise `-e` / `-MaxErrors`; investigate if **errors** (CRC, frame) grow |
| `speed-duplex n/a` | Virtual NICs, Wi-Fi and some drivers do not report speed; on Linux install `ethtool` for a second opinion |
| `gateway-ping WARN … ICMP may be filtered` | The gateway answers ARP but drops ping: normal for many routers and clouds; test a TCP port instead (`-t`) |
| `gateway-ping n/a ICMP not permitted` | The user may not send ICMP (unusual on Ubuntu, which allows unprivileged ICMP sockets); run as root or check `net.ipv4.ping_group_range` |
| `gateway-neighbour n/a` (PowerShell on Linux) | .NET does not expose the ARP table; run `ip neigh show` |
| `tcp-connect FAIL … timed out` vs `… refused` | Timed out = filtered or no route; refused = the host answered and nothing listens (Day 12) |
| `-p needs -t HOST` (exit 1) | Give the target too: `-t HOST -p PORT` / `-Target HOST -Port PORT` |
| Script exits 3 in a scheduler and the job is marked as failed | Expected: 3 means *a check failed*; configure the scheduler to treat 3 as an alert |

### Validation status

| Check | Linux script | PowerShell script |
|---|---|---|
| Executed | 2026-11-14 in an Ubuntu 24.04.5 container (Bash 5.2.21, iproute2, iputils-ping, ethtool), on the container host (no arguments: exit 0 with a `counters WARN`) and in two test network namespaces joined by a veth pair with a Python listener: healthy run with `-t`/`-p`/`-n` (exit 0), `-f csv`, `-o`, `-e 5`, wrong gateway, no default route (with and without `-i`), peer link down, interface admin down, closed port, port dropped by an iptables rule (timeout) and absent host (all exit 3), run as `nobody` (exit 0), invalid options, port, `-p` without `-t`, `-e`, interface, format, host and extra argument (exit 1), `-o` pointing below a file and an unwritable `-o` as `nobody` (exit 2). CI: GitHub `ubuntu-24.04` runner, every release | **Not executed before release** (PowerShell could not be installed on the release host). NetAdapter/NetTCPIP/DnsClient property names and .NET `NetworkInterface`, `Ping` and `TcpClient` usage reviewed from the official documentation. CI parses it, runs it on `windows-latest` with Windows PowerShell 5.1 and PowerShell 7 (no arguments and `-OutputPath`) and runs PSScriptAnalyzer |
| Static analysis | `bash -n` and ShellCheck 0.11.0 (no findings at any severity, `-S style`) | PSScriptAnalyzer in CI (Error and Warning severities) |

## log-analyser.sh / Log-Analyser.ps1

**Purpose:** a read-only summary of the system log for the last *N* hours — entries by severity, the noisiest programs or event sources, the most frequent error and warning messages (numbers replaced by `N` and long hex values by `X`, so that *"connect() failed … upstream 10.0.0.5:8080"* and *"… 10.0.0.6:8080"* are counted together), kernel/driver errors and a first look at failed authentications (covered fully on Day 17). It exits with code **3** when the number of error-level entries is above a threshold. Taught in [Day 16](../course/module-4/day-16.md) and used in [Lab 16](../labs/lab-16.md).

**Severity differs by source — the report always says which one it used.** The systemd journal stores a real `PRIORITY` (0 `emerg` … 3 `err`, 4 `warning`, 5 `notice`, 6 `info`, 7 `debug`) and Windows events a real `Level` (1 Critical, 2 Error, 3 Warning). Syslog **text files** do not store the priority in the line, so for them the scripts **infer** it from keywords: `error`, `fail`, `critical`, `panic`, `fatal`, `segfault` → error; `warn` → warning; everything else → info. Inferred counts are a triage aid, not an exact measure: *"0 failed"* counts as an error line.

### Prerequisites

| Linux | Windows |
|---|---|
| Ubuntu 24.04 (any Linux with `journalctl` or a syslog text file). Bash 4+, GNU `date`, `awk`, `sort`; `zcat` for `.gz` files. Source order: `-l FILE`, else the **systemd journal** if `journalctl` returns entries, else `/var/log/syslog`, else `/var/log/messages`. Without root, the journal shows only your own entries unless you are in the `adm` or `systemd-journal` group, and `/var/log/syslog` and `/var/log/auth.log` are readable only by root and `adm`; the report notes a non-root run. With no readable source it reports `n/a` and exits 0. | Windows 11, Windows PowerShell 5.1 or PowerShell 7. `Get-WinEvent -FilterHashtable` for levels 1–3 in each `-LogName` (default `System`, `Application`), at most 20,000 events per log (the report notes when the limit is hit). No admin for System and Application; the **Security** log (failed logons, event 4625) needs an elevated session and is otherwise `n/a`. `-Path` reads an exported `.evtx` file or a Linux syslog-format text file. In PowerShell 7 on Linux the journal is read with `journalctl -o json -p warning`. |

### Options

| Bash | PowerShell | Default | Meaning |
|---|---|---|---|
| `-l FILE` | `-Path FILE` | journal / syslog (Linux), event logs (Windows) | Analyse a saved file: syslog text or `.gz` (both), `.evtx` (PowerShell on Windows) |
| — | `-LogName LOG[,LOG]` | `System, Application` | Windows event logs to query |
| `-s HOURS` | `-Hours N` | 24 | Time window; `0` = the whole file or log |
| `-n TOP` | `-Top N` | 10 | Length of the "top" lists (1–100) |
| `-c MAXERR` | `-MaxErrors N` | 50 | Error-level entries allowed before exit code 3 |
| <code>-f text&#124;csv</code> | <code>-Format Text&#124;Csv&#124;Json</code> | text | Output format |
| `-o DIR` | `-OutputPath DIR` | — | Also save a timestamped report file |
| `-h` | `Get-Help .\Log-Analyser.ps1 -Full` | — | Help |

Exit codes: `0` OK (also when no log is readable: `n/a`) · `1` invalid arguments (including a missing `-l`/`-Path` file) · `2` output folder cannot be created or written · `3` more than `MAXERR` error-level entries (journal priority 0–3, inferred *error*, Windows Critical + Error).

What each script counts: the Bash script reports **every** entry in the window by severity; the PowerShell script collects only **warning and worse** (levels 1–3, or journal priority 0–4), because reading every Information event of a Windows log is slow. The *error-level* count and the exit code mean the same thing in both. Text-file timestamps are compared with this host's local time: RFC 3339 (`2026-11-14T10:00:00.123456+00:00`, the Ubuntu 24.04 rsyslog default) and classic (`Nov 14 10:00:00`, no year) formats are both understood; use `-s 0` for files copied from another time zone or an older period.

### How to run

```bash
cd scripts/linux
bash log-analyser.sh                                  # journal (or syslog), last 24 h
sudo bash log-analyser.sh -s 2 -n 5                   # everything readable, last 2 hours, top 5
bash log-analyser.sh -l /var/log/syslog.2.gz -s 0     # a rotated file, whole content (adm group or sudo)
sudo bash log-analyser.sh -c 10; echo "exit: $?"      # 3 = more than 10 error-level entries
bash log-analyser.sh -f csv -o ~/lpm-lab/reports
```

```powershell
Set-Location scripts\powershell
.\Log-Analyser.ps1
.\Log-Analyser.ps1 -LogName System -Hours 2 -Top 5
.\Log-Analyser.ps1 -LogName System, Application, Security -MaxErrors 10   # Security needs an elevated window
.\Log-Analyser.ps1 -Path $HOME\lpm-lab\System-export.evtx -Hours 0 -Format Csv -OutputPath $HOME\lpm-lab\reports
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Log-Analyser.ps1; "exit: $LASTEXITCODE"
```

### Sample output (Bash; captured on 2026-11-14 in an Ubuntu 24.04.5 container from a 10-line RFC 3339 test log, one line of which was older than the window; host and path renamed)

```text
==============================================
 Log Analyser Report
==============================================
Report time (UTC)    : 2026-11-14T16:47:58Z
Host name            : ubuntu-lab
Source               : /home/student/lab16/rfc.log
Window               : last 24 h (since 2026-11-13 16:47:58 local time)
Severity             : inferred from keywords (text file)
Entries              : 9
Error-level entries  : 6 (threshold 5)
Kernel errors        : 1
Status               : ALERT

--- Entries by severity ---
      6  err
      1  warning
      2  info

--- Top 5 programs ---
      3  sshd
      2  nginx
      1  app
      1  kernel
      1  sudo

--- Top 5 error/warning messages (digits -> N, hex -> X) ---
      2  err      nginx: N/N/N connect() failed (N: Connection refused) while connecting to upstream N.N.N.N:N
      1  warning  app: warning: cache X nearly full (N%)
      1  err      kernel: EXT4-fs error (device sda1): ext4_find_entry:N: inode #N: comm ls: reading directory lblock N
      1  err      sshd: Failed password for invalid user admin from N.N.N.N port N ssh2
      1  err      sshd: Failed password for root from N.N.N.N port N ssh2

--- Authentication (source: /home/student/lab16/rfc.log; details in Day 17) ---
SSH failed password/key      : 2
SSH invalid user             : 1
sudo authentication failures : 1
```

The command was `log-analyser.sh -l ~/lab16/rfc.log -c 5 -n 5` and the exit code was `3` (6 error-level entries > 5). Digits that follow a letter are kept (`EXT4`, `sda1`, `ext4_find_entry`), so device and file-system names stay readable. A run without `-l` on the same container read the **systemd journal** (`Severity : journal PRIORITY field`, real `crit`/`err`/`warning`/`notice`/`info`/`debug` counts); with `journalctl` removed from `PATH` it fell back to `/var/log/syslog` and took the authentication counts from `/var/log/auth.log`; as `nobody` it reported `Source : n/a` and exited 0.

### Sample output (PowerShell; **example** of the layout on Windows — illustrative values, not captured on Windows)

```text
==============================================
 Log Analyser Report
==============================================
Report time (UTC)      : 2026-11-14T17:12:09Z
Computer name          : WIN11-LAB
Source                 : Windows event logs: System, Application
Window                 : last 24 h (since 2026-11-13 22:42:09 local time)
Severity               : Windows event Level
Events (warning+)      : 41
Critical + Error       : 9 (threshold 50)
Kernel/driver errors   : 1
Failed logons          : n/a (Security log needs an elevated session)
Status                 : OK
PowerShell             : 5.1.26100.9168 (Desktop)

--- Logs ---
System                                   read
Application                              read

--- Events by level ---
      1  Critical
      8  Error
     32  Warning

--- Top 10 sources ---
     14  Microsoft-Windows-DistributedCOM
      7  Microsoft-Windows-Time-Service
      5  Application Error
...

--- Top 10 source / event ID ---
     14  Microsoft-Windows-DistributedCOM / 10016
      5  Application Error / 1000
      1  Microsoft-Windows-Kernel-Power / 41
...
```

### Troubleshooting

| Problem | Fix |
|---|---|
| `Source : n/a` / `Status : n/a (no readable log source)` | No permission: run with `sudo`, or add the user to `adm` (text logs) / `systemd-journal` (journal) |
| `Note : not root: only logs readable by …` | Counts may be incomplete; repeat with `sudo` |
| Text file shows `Entries : 0` | The window excludes it: the file is older than `-s` hours or from another time zone; use `-s 0` |
| Many "errors" that are not errors | Text files use keyword inference (`0 failed` is an error line); prefer the journal, which stores the real priority |
| `-l '…' is not a readable file` (exit 1) | Wrong path, or `/var/log/syslog` without `sudo`/`adm` |
| `Failed logons : n/a (Security log needs an elevated session)` | Run PowerShell as Administrator to include event 4625 |
| A log shows `n/a (log does not exist)` | The `-LogName` is misspelled; list logs with `Get-WinEvent -ListLog *` |
| `Note : at least one log returned 20000 events` | Shorten `-Hours`; the counts are a minimum |
| Script exits 3 in a scheduler and the job is marked as failed | Expected: 3 means *too many errors*; configure the scheduler to treat 3 as an alert |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or the one-off `-ExecutionPolicy Bypass -File` form |

### Validation status

| Check | Linux script | PowerShell script |
|---|---|---|
| Executed | 2026-11-14 in an Ubuntu 24.04.5 container (Bash 5.2.21, mawk 1.3.4, journald and rsyslog running): no arguments (journal source, exit 0), `-c 3` on the journal (exit 3), `-n`, `-f csv`, `-o`, test files in RFC 3339 and classic formats incl. a line outside the window, a `.gz` copy, `-s 0`, the `/var/log/syslog` + `/var/log/auth.log` fallback (PATH without `journalctl`), run as `nobody` (no readable source: `n/a`, exit 0; readable `-l` file above the threshold: exit 3), invalid `-s`, `-n`, `-c`, format, `-l` path, option and extra argument (exit 1), `-o` below a file and an unwritable `-o` as `nobody` (exit 2). CI: GitHub `ubuntu-24.04` runner, every release | **Not executed before release** (PowerShell could not be installed on the release host). `Get-WinEvent -FilterHashtable` keys (`LogName`, `Path`, `Level`, `Id`, `StartTime`), `-MaxEvents`, the `NoMatchingEventsFound` error and `EventLogRecord` properties reviewed from the official documentation. CI parses it, runs it on `windows-latest` with Windows PowerShell 5.1 and PowerShell 7 (no arguments and `-OutputPath`) and runs PSScriptAnalyzer |
| Static analysis | `bash -n` and ShellCheck 0.11.0 (no findings at any severity, `-S style`) | PSScriptAnalyzer in CI (Error and Warning severities) |
