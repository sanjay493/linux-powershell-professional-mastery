---
description: "Triage a 'slow server' incident on Ubuntu 24.04 with the USE method and the 60-second checklist: a setup script starts five bounded, self-expiring faults (a CPU hog with a harmless name, a 2 GiB memory hog, a synchronous small-write disk hog, a file-descriptor leak and a stuck backup agent); find each culprit with vmstat, mpstat, pidstat, iostat, PSI, /proc, lsof, wchan, /proc/PID/stack and strace, stop them safely, verify recovery and write a blameless RCA; then triage bounded PowerShell jobs on Windows with Get-Counter and CIM."
---

# Lab 28: The Slow Server

| Field | Value |
|---|---|
| **Lab ID** | LAB-28 |
| **Related lesson** | [Day 28: Advanced System Troubleshooting](../course/module-6/day-28.md) |
| **Difficulty** | Advanced |
| **Time** | 90–120 minutes (Linux 70–80 min, Windows 20–30 min, RCA 15 min) |
| **Risk level** | Low–Medium. Use a **disposable Ubuntu 24.04 VM** (take a snapshot first) and a Windows lab VM. The fault scripts only create files under `/srv/lab28` (Linux) and `%TEMP%\Lab28` (Windows), and every fault **stops by itself** after 30 minutes (Linux) / 15 minutes (Windows). The memory hog takes 40 % of the *available* memory (at most 2 GiB). Never run the fault scripts on a shared or production machine. Always **preview** what you will stop before you `kill`. |

## Objective

Monday, 09:10. The ticket says: *"app01 has been very slow since about nine. Also, last night's backup never finished, and the session service keeps logging errors."* You have `sudo` on app01 (your Ubuntu VM). Reproduce a professional investigation:

1. **Define** the problem and run the **60-second checklist**, writing one finding per command.
2. Use the **USE method** to identify every saturated or failing resource, then the **process** behind each one, with its full command line.
3. Explain the **mechanism** of each fault (what exactly is it doing, waiting on, or leaking?) with evidence.
4. **Stop** the culprits safely, **verify recovery** against your first measurements, and **clean up**.
5. Write a short **blameless RCA** with a UTC timeline, 5 whys and corrective actions.
6. On Windows, triage four bounded PowerShell jobs with `Get-Counter` and CIM.

The rule of the lab: **triage from symptoms**. Do not read `/srv/lab28/bin` until Task 6.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS VM, 2+ vCPU, 2+ GB RAM, 1 GB free disk, a user with `sudo`. Packages: `sudo apt install sysstat strace lsof python3` (`python3` is installed by default).
- **Windows:** Windows 11 / Server 2022 VM, Windows PowerShell 5.1 or PowerShell 7, a **normal (non-elevated)** session. 1+ GB free RAM.
- About 30 minutes of uninterrupted time per platform (the faults expire on their own).

## Initial Conditions

- `/srv/lab28` does not exist: `ls -d /srv/lab28` reports *No such file or directory*. If it exists, run the clean-up script first.
- On Windows, `Get-Job -Name 'Lab28-*'` returns nothing.
- Take a VM snapshot. Close other heavy applications so your measurements show the lab faults.
- Start a transcript of your work for the RCA: `script -a ~/lab28-notes.log` (end with `exit`) on Linux, `Start-Transcript -Path $HOME\lab28-notes.txt` on Windows.

## Setup script (Linux)

Save as `lab28-setup.sh` and run `sudo bash lab28-setup.sh`. **Read it first** (it is shown here for that reason) — but in the investigation itself, pretend you have never seen it. `LAB28_MINUTES=10 sudo -E bash lab28-setup.sh` shortens the lifetime.

```bash
#!/usr/bin/env bash
# lab28-setup.sh - start five BOUNDED, self-expiring faults for Lab 28 ("the slow server").
# Everything lives in /srv/lab28; every fault stops by itself after LAB28_MINUTES (default 30).
set -o errexit -o nounset -o pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
LAB=/srv/lab28
[ -e "$LAB/setup.done" ] && { echo "Already running. Run lab28-cleanup.sh first." >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }
MINUTES=${LAB28_MINUTES:-30}
case $MINUTES in ''|*[!0-9]*) echo "LAB28_MINUTES must be a number." >&2; exit 1;; esac
LIMIT="$((MINUTES * 60))s"

# memory hog size: 40% of MemAvailable, capped at 2048 MiB
avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
MEM_MB=$(( avail_kb * 40 / 100 / 1024 )); [ "$MEM_MB" -gt 2048 ] && MEM_MB=2048

mkdir -p "$LAB/bin" "$LAB/spool" "$LAB/sessions" "$LAB/logs"
chmod 0755 "$LAB"

# 1. CPU: a busy loop that looks like a harmless image job
cat > "$LAB/bin/thumbnailer" <<'PY'
#!/usr/bin/env python3
while True:
    sum(i * i for i in range(10000))
PY
# 2. Memory: allocates and touches MEM_MB, then holds it
cat > "$LAB/bin/cache-warmer" <<'PY'
#!/usr/bin/env python3
import sys, time
blob = bytearray(int(sys.argv[1]) * 1024 * 1024)
for i in range(0, len(blob), 4096):
    blob[i] = 1
while True:
    time.sleep(60)
PY
# 3. Disk: small synchronous (O_DSYNC) writes, overwriting one 64 MiB file
cat > "$LAB/bin/log-shipper" <<'SH'
#!/bin/sh
while true; do
    dd if=/dev/zero of=/srv/lab28/spool/outbox.dat bs=4k count=16384 oflag=dsync conv=notrunc status=none
done
SH
# 4. File descriptors: opens a file every 0.2 s and never closes it
cat > "$LAB/bin/session-cache" <<'PY'
#!/usr/bin/env python3
import resource, time, datetime
resource.setrlimit(resource.RLIMIT_NOFILE, (256, 256))   # like a service with LimitNOFILE=256
log = open("/srv/lab28/logs/session-cache.log", "a", buffering=1)
held, n = [], 0
while True:
    n += 1
    try:
        held.append(open(f"/srv/lab28/sessions/s{n % 50}.tmp", "a"))
    except OSError as e:
        log.write(f"{datetime.datetime.now().isoformat(timespec='seconds')} ERROR accept session: {e}\n")
        time.sleep(5)
    time.sleep(0.2)
PY
# 5. Stuck: waits forever to open a FIFO that nobody writes to
mkfifo "$LAB/spool/backup.fifo"
cat > "$LAB/bin/backup-agent" <<'SH'
#!/bin/sh
exec 3< /srv/lab28/spool/backup.fifo
SH
chmod 0755 "$LAB"/bin/*

start() {   # start NAME ARGS... under timeout, record its PID
    local name=$1; shift
    nohup timeout "$LIMIT" "$LAB/bin/$name" "$@" >/dev/null 2>&1 &
    local tpid=$!
    sleep 0.3
    pgrep -P "$tpid" > "$LAB/$name.pid" || echo "$tpid" > "$LAB/$name.pid"
    echo "$tpid" > "$LAB/$name.timeout.pid"
}
start thumbnailer
start cache-warmer "$MEM_MB"
start log-shipper
start session-cache
start backup-agent

date -u +%FT%TZ > "$LAB/setup.done"
echo "Lab 28 faults started at $(cat "$LAB/setup.done"); they stop by themselves after $MINUTES min."
echo "Memory hog size: ${MEM_MB} MiB. Do NOT read $LAB/bin until Task 6: triage from symptoms first."
```

## Clean-up script (Linux)

Save as `lab28-cleanup.sh`. It lists what it will stop, signals only processes whose program lives in `/srv/lab28/bin`, and removes the lab. Run it with `sudo bash lab28-cleanup.sh` at the end (or at any time to abort). It is safe to run twice.

```bash
#!/usr/bin/env bash
# lab28-cleanup.sh - stop every Lab 28 fault (only processes whose binary lives in /srv/lab28) and remove the lab.
set -o nounset -o pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
LAB=/srv/lab28
[ -d "$LAB" ] || { echo "Nothing to clean up."; exit 0; }
echo "Processes that will be stopped:"
pgrep -af "$LAB/bin/" || echo "  (none running)"
for f in "$LAB"/*.timeout.pid; do
    [ -e "$f" ] || continue
    pid=$(cat "$f")
    # only signal a timeout process that is still ours
    if tr '\0' ' ' 2>/dev/null < "/proc/$pid/cmdline" | grep -q "$LAB/bin/"; then kill "$pid" 2>/dev/null; fi
done
sleep 1
pkill -f "$LAB/bin/" 2>/dev/null
pkill -f "of=$LAB/" 2>/dev/null     # a dd started by log-shipper
sleep 1
pgrep -af "$LAB/bin/" && { echo "Some processes survived; check them by hand." >&2; exit 1; }
rm -rf -- "${LAB:?}"
echo "Lab 28 removed."
```

## Step-by-Step Instructions

### Task 1 — Define the problem and run the 60-second checklist

1. Write the problem statement in your notes: what is slow, since when (UTC), who is affected, how you will measure it, what changed.
2. Wait at least one minute after setup, then run the checklist (Day 28 Demo 1): `uptime`, `sudo dmesg -T | tail`, `vmstat -w 1 5`, `mpstat -P ALL 1 3`, `pidstat 1 3`, `iostat -xz 1 3`, `free -m`, `cat /proc/pressure/{cpu,memory,io}`, `sar -n DEV 1 3`, `top -b -n 1 -o %CPU | head -20`.
3. For each command write **one line**: which resource, utilisation/saturation/errors, normal or not. List your hypotheses.

### Task 2 — CPU: which process, and is it saturation?

1. Identify the top CPU consumer with `pidstat` and get its **full command line, parent, owner, start time and binary** (`ps -o pid,ppid,user,lstart,etime,args -p PID`, `ls -l /proc/PID/exe`).
2. Decide from `mpstat -P ALL` and `pidstat -u` `%wait` whether the CPU is **utilised** or **saturated**.
3. Note why the `Command` column alone (`python3`) would have misled you.

### Task 3 — Disk: who is writing, and how?

1. Use `iostat -xz 1 3` to characterise the I/O: writes per second, average request size (`wareq-sz`), flushes per second (`f/s`), `w_await`, `aqu-sz`, PSI io.
2. Find the writing process with `pidstat -d 1 3`. It is short-lived: find its **parent** and the parent's command line.
3. Summarise the parent's system calls for 5 seconds with `strace -c -f -p PARENT` and explain the pattern.

### Task 4 — Memory: the biggest consumer

1. Find the largest resident process (`ps -eo pid,rss,vsz,args --sort=-rss | head`).
2. Compare its RSS with `MemTotal` and `MemAvailable`. Is memory a bottleneck **now** on your VM? What would happen on a VM with half the RAM and no swap? With swap?

### Task 5 — Software limits: the session errors and the backup

1. The session service "keeps logging errors". Find the process with the most open file descriptors, compare the count with its limit (`/proc/PID/limits`), see what is open (`lsof -p`), check again a minute later, and read its log in `/srv/lab28/logs`.
2. The backup "never finished". Find the backup agent (`pgrep -af backup-agent`), its state and wait channel, its kernel stack and the system call it is blocked in (`strace -p`, stop after a few seconds).
3. **Prove** your explanation of the backup agent: give it what it is waiting for (as root: `: > PATH` on the object it waits on) and confirm it exits.

### Task 6 — Stop, verify, clean up

1. **Preview** the CPU and disk culprits with `pgrep -af` using the exact pattern you will use to signal them, then stop them with `SIGTERM` (`kill -TERM`), not `SIGKILL`.
2. Re-run `vmstat`, `iostat -xz` and PSI io and compare with Task 1. Wait a minute: watch PSI `avg10` fall.
3. Now read the fault scripts in `/srv/lab28/bin` and check your findings against them.
4. Run `sudo bash lab28-cleanup.sh`, then confirm nothing remains (`pgrep -af /srv/lab28`, `ls -d /srv/lab28`).

### Task 7 — Write the RCA

Write `~/lab28-rca.md` with: summary, impact, detection, UTC timeline, root cause per fault (5 whys for at least one), contributing factors, what went well, corrective actions (owner, date). Use blameless language.

### Task 8 — Windows triage

1. Save the two scripts below, read them, and start the faults from a normal PowerShell window:

    ```powershell
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Lab28-Faults.ps1 -Minutes 15 -MemoryMB 1024
    ```

2. **Without** using `Get-Job`, find the four culprits: top CPU (normalised by CPU count), top private memory, fastest-growing handle count over 60 seconds, top write rate and the disk write latency.
3. Map each PID back to its job: background jobs are child `powershell.exe`/`pwsh.exe` processes; get their command lines and parent with `Win32_Process`.
4. Clean up with `.\Lab28-Cleanup.ps1 -WhatIf`, then `.\Lab28-Cleanup.ps1`.

`Lab28-Faults.ps1`:

```powershell
<#
.SYNOPSIS
    Lab28-Faults.ps1 - start three BOUNDED background jobs (CPU, memory, handle leak) plus a write-through
    disk writer for Lab 28. Every job stops by itself after -Minutes. Runs without elevation.
.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Lab28-Faults.ps1 -Minutes 15 -MemoryMB 1024
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 60)]  [int]$Minutes  = 15,
    [ValidateRange(64, 4096)] [int]$MemoryMB = 1024
)
Set-StrictMode -Version Latest
$lab = Join-Path $env:TEMP 'Lab28'
if (Get-Job -Name 'Lab28-*' -ErrorAction SilentlyContinue) { throw 'Lab 28 jobs already exist. Run Lab28-Cleanup.ps1 first.' }
New-Item -ItemType Directory -Path $lab -Force | Out-Null
$deadline = (Get-Date).AddMinutes($Minutes)

Start-Job -Name 'Lab28-Cpu' -ArgumentList $deadline -ScriptBlock {
    param($d) while ((Get-Date) -lt $d) { $x = 0; for ($i = 0; $i -lt 200000; $i++) { $x += $i * $i } }
} | Out-Null

Start-Job -Name 'Lab28-Mem' -ArgumentList $deadline, $MemoryMB -ScriptBlock {
    param($d, $mb)
    $blob = New-Object byte[] ($mb * 1MB)
    for ($i = 0; $i -lt $blob.Length; $i += 4096) { $blob[$i] = 1 }      # touch every page
    while ((Get-Date) -lt $d) { Start-Sleep -Seconds 5 }
} | Out-Null

Start-Job -Name 'Lab28-Handles' -ArgumentList $deadline, $lab -ScriptBlock {
    param($d, $dir)
    $held = New-Object System.Collections.ArrayList
    $n = 0
    while ((Get-Date) -lt $d) {
        $n++
        $f = Join-Path $dir ('s{0}.tmp' -f ($n % 50))
        [void]$held.Add([System.IO.File]::Open($f, 'OpenOrCreate', 'ReadWrite', 'ReadWrite'))   # never closed
        Start-Sleep -Milliseconds 200
    }
} | Out-Null

Start-Job -Name 'Lab28-Disk' -ArgumentList $deadline, $lab -ScriptBlock {
    param($d, $dir)
    $path = Join-Path $dir 'outbox.dat'
    $fs = New-Object System.IO.FileStream($path, 'OpenOrCreate', 'Write', 'None', 4096, 'WriteThrough')
    $buf = New-Object byte[] 4096
    try {
        while ((Get-Date) -lt $d) {
            if ($fs.Position -ge 64MB) { [void]$fs.Seek(0, 'Begin') }
            $fs.Write($buf, 0, $buf.Length); $fs.Flush($true)
        }
    } finally { $fs.Dispose() }
} | Out-Null

Get-Job -Name 'Lab28-*' | Format-Table Id, Name, State -AutoSize
Write-Output ("Lab 28 jobs started; they stop by themselves at {0:HH:mm:ss}. Triage with Get-Counter and CIM, not Get-Job." -f $deadline)
```

`Lab28-Cleanup.ps1`:

```powershell
# Lab28-Cleanup.ps1 - stop and remove the Lab 28 jobs (preview first), then delete the lab folder.
[CmdletBinding(SupportsShouldProcess)]
param()
Set-StrictMode -Version Latest
$jobs = @(Get-Job -Name 'Lab28-*' -ErrorAction SilentlyContinue)
$jobs | Format-Table Id, Name, State -AutoSize
foreach ($j in $jobs) {
    if ($PSCmdlet.ShouldProcess($j.Name, 'Stop and remove job')) { $j | Stop-Job; $j | Remove-Job -Force }
}
$lab = Join-Path $env:TEMP 'Lab28'
if ((Test-Path -LiteralPath $lab) -and $PSCmdlet.ShouldProcess($lab, 'Remove folder')) {
    Remove-Item -LiteralPath $lab -Recurse -Force
}
Write-Output 'Lab 28 (Windows) cleaned up.'
```

## Commands to Execute

Try each task yourself first; complete commands are in the [Solution](#solution). The core toolset is: `uptime`, `dmesg -T`, `vmstat -w 1`, `mpstat -P ALL 1`, `pidstat -u/-d/-r 1`, `iostat -xz 1`, `free -m`, `/proc/pressure/*`, `ps -o ...`, `/proc/PID/{fd,limits,stack,exe,cmdline}`, `lsof -p`, `strace -p`/`-c`, `kill -TERM`; and on Windows `Get-Counter`, `Get-CimInstance Win32_PerfFormattedData_PerfProc_Process`, `Get-Process`, `Get-CimInstance Win32_Process`.

## Expected Results

The values below were **captured** on 2026-11-20 in the course's Ubuntu 24.04.5 test container (4 vCPU, 16 GB RAM, no swap, virtio disk `vda`; container management processes removed), where the setup → triage → clean-up sequence was run end to end three times. Your PIDs, rates and percentages will differ; the **pattern** should be the same. Windows results are **examples** (not executed).

| Task | Expected finding |
|---|---|
| 1 | Load rising (1-min ≫ 15-min); `vmstat` `b`≈1 permanently, `wa` ≈ 15–20 %, `us` ≈ one CPU's worth; `mpstat` one CPU at ~0 % idle; `iostat` thousands of ~2–4 KiB writes/s with thousands of flushes/s; PSI io `full` > 10 %; `dmesg` clean. Hypotheses: a CPU-bound process, a synchronous small-write workload |
| 2 | `python3 /srv/lab28/bin/thumbnailer`, ~98 % of **one** CPU, `%wait` ≈ 0 → utilisation of one core, not machine-wide saturation. `/proc/PID/exe` is the Python interpreter (`/usr/bin/python3.12` on stock 24.04; `python3.11` in the test container) — the script path is only in the arguments |
| 3 | Writer: a series of short-lived `dd ... oflag=dsync` processes in `D` state (`submit_bio_wait`), all children of `/bin/sh /srv/lab28/bin/log-shipper` (`pidstat -d` may also list `log-shipper` itself with exactly 65,536 kB in one second: when the shell reaps a finished `dd`, the kernel adds the child's I/O to the parent's counters); `strace -c` shows ~16,000–20,000 `write` calls in 5 s. Pattern: 4 KiB **synchronous** writes, each forced to disk |
| 4 | `python3 /srv/lab28/bin/cache-warmer 2048` with RSS ≈ 2 GiB (40 % of available memory, capped at 2 GiB). On a 4 GB VM, `available` would fall sharply; without swap the next allocation burst risks the OOM killer, with swap `si`/`so` and PSI memory would rise |
| 5a | `python3 /srv/lab28/bin/session-cache`: **256** descriptors open = its limit `Max open files 256 256`; the same 50 files opened many times; the log shows `[Errno 24] Too many open files` every 5 s once the limit is hit (about 50 s after start) |
| 5b | `/bin/sh /srv/lab28/bin/backup-agent`: state `S`, wchan `wait_for_partner`, stack `fifo_open` → `do_sys_openat2`; `strace` shows an unfinished `openat(..., "/srv/lab28/spool/backup.fifo", O_RDONLY`. After `: > /srv/lab28/spool/backup.fifo` it exits immediately |
| 6 | After `kill -TERM` of thumbnailer and log-shipper: no `dd` running, `iostat` `w/s` 0, `f/s` 0, `vmstat` `b` 0 and `wa` 0, PSI io `avg10` falling within seconds and `avg60` over the next minute; clean-up removes the two remaining faults and `/srv/lab28` |
| 8 | One `powershell`/`pwsh` child at ~1 CPU (`CPU%` ≈ 100/cores), one with ~1 GB private memory, one gaining ~300 handles per minute, one with hundreds of write operations/s and elevated `Avg. Disk sec/Write` |

## Verification Steps

=== "Bash"

    ```bash
    # during the investigation: each culprit identified by full command line
    for p in $(pgrep -f /srv/lab28/bin/); do ps -o pid=,stat=,args= -p "$p"; done
    # after Task 6 and clean-up: nothing left
    pgrep -af /srv/lab28 || echo "no lab28 processes"
    ls -d /srv/lab28 2>/dev/null || echo "/srv/lab28 removed"
    vmstat -w 1 3 | tail -2        # b = 0, wa ~ 0
    cat /proc/pressure/io          # avg10 back near 0
    test -s ~/lab28-rca.md && echo "RCA written"
    ```

=== "PowerShell"

    ```powershell
    Get-Job -Name 'Lab28-*' -ErrorAction SilentlyContinue     # nothing after clean-up
    Test-Path (Join-Path $env:TEMP 'Lab28')                    # False
    Get-Counter '\Processor(_Total)\% Processor Time' -MaxSamples 3   # back to the baseline
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Already running. Run lab28-cleanup.sh first.` | A previous run left `/srv/lab28/setup.done` | `sudo bash lab28-cleanup.sh`, then set up again |
| `mpstat`/`pidstat`/`iostat`: command not found | sysstat missing | `sudo apt install sysstat` |
| The I/O fault barely shows (`w/s` low) | Very slow or very fast storage, or the VM's disk cache ignores flushes | Look at `f/s` and `w_await` rather than `%util`; the pattern (small synchronous writes) is what matters |
| No `Too many open files` in the session log yet | Less than ~55 s since setup | Wait a minute and check <code>ls /proc/PID/fd &#124; wc -l</code> again |
| `strace: attach: ptrace(PTRACE_SEIZE...): Operation not permitted` | Not root (Yama `ptrace_scope=1`) | `sudo strace ...` — do not change the Yama setting |
| `cat: /proc/N/stack: Permission denied` | Needs root | `sudo cat /proc/N/stack` |
| All faults disappeared on their own | The 30-minute lifetime expired | Run the clean-up script, then the setup again (optionally with `LAB28_MINUTES=45`) |
| The VM becomes unresponsive | Very small VM (memory hog + others) | Revert the snapshot; use a VM with 2+ GB RAM |
| Windows: `Lab28 jobs already exist` | Previous run not cleaned up | `.\Lab28-Cleanup.ps1` |
| Windows: `Get-Counter : The specified object was not found` | Non-English Windows (localised counter names) | `Get-Counter -ListSet *disk*` and use the local names, or the CIM classes |

## Questions

1. Which command first showed each of the five faults, and which USE category (utilisation, saturation, errors) did it belong to?
2. Why was the `dd` process the wrong answer to "who is writing", and how did you find the right one?
3. The CPU hog used 98 % of one core on a 4-CPU machine. Is the machine CPU-saturated? Which numbers prove your answer?
4. What was the I/O pattern of the log shipper, and why is it so expensive even though the throughput (MB/s) is small?
5. Why did no CPU, memory or disk graph show the session-service problem? Which two numbers proved it?
6. What exactly was the backup agent waiting for, and how did you prove it?
7. Why did you stop the culprits with `SIGTERM` rather than `SIGKILL`, and why did you preview with `pgrep -af` first?
8. Write the 5 whys for the log-shipper fault, ending in a systemic root cause.
9. On Windows, why must `PercentProcessorTime` be divided by the number of logical CPUs?
10. Which of today's faults would `sar` history (if enabled) have recorded, and which not?

## Solution

??? success "Bash solution"
    ```bash
    # ---- Task 1: checklist (wait >= 60 s after setup) ----
    uptime ; nproc
    sudo dmesg -T | tail -5
    vmstat -w 1 5
    mpstat -P ALL 1 3
    pidstat 1 3
    iostat -xz 1 3
    free -m
    for r in cpu memory io; do echo "== $r"; cat /proc/pressure/$r; done
    sar -n DEV 1 3
    top -b -n 1 -o %CPU | head -20

    # ---- Task 2: CPU ----
    pidstat -u 2 1
    C=$(pgrep -f 'bin/thumbnailer$' | tail -1)     # or simply the PID from pidstat
    ps -o pid,ppid,user,lstart,etime,args -p "$C"
    ls -l /proc/"$C"/exe
    mpstat -P ALL 1 1                            # one CPU at ~0 % idle, the others mostly idle

    # ---- Task 3: disk ----
    iostat -xz 1 3                               # w/s, wareq-sz, f/s, w_await, aqu-sz
    pidstat -d 1 3                               # writer: dd (new PID every few seconds)
    for i in 1 2 3; do pgrep -x dd | while read -r p; do ps -o pid=,ppid=,stat=,etime=,args= -p "$p"; done; sleep 1; done
    PP=$(ps -o ppid= -p "$(pgrep -xn dd)" | tr -d ' ')
    ps -o pid,ppid,etime,args -p "$PP"           # /bin/sh /srv/lab28/bin/log-shipper
    sudo timeout -s INT 5 strace -c -f -p "$PP"  # thousands of write() calls

    # ---- Task 4: memory ----
    ps -eo pid,rss,vsz,args --sort=-rss | head -4
    grep -E '^(MemTotal|MemAvailable):' /proc/meminfo

    # ---- Task 5a: file descriptors ----
    for d in /proc/[0-9]*; do
        n=$(sudo ls "$d/fd" 2>/dev/null | wc -l)
        echo "$n ${d#/proc/} $(tr '\0' ' ' 2>/dev/null < "$d/cmdline")"
    done | sort -rn | head -4
    S=$(pgrep -f 'bin/session-cache$' | tail -1)
    grep 'open files' /proc/"$S"/limits
    sudo lsof -p "$S" | awk '{print $NF}' | sort | uniq -c | sort -rn | head -3
    tail -3 /srv/lab28/logs/session-cache.log

    # ---- Task 5b: the stuck backup agent ----
    B=$(pgrep -f 'bin/backup-agent$' | tail -1)
    ps -o pid,stat,etime,wchan:20,args -p "$B"
    sudo cat /proc/"$B"/stack
    sudo timeout 3 strace -p "$B"
    sudo ls -l /proc/"$B"/fd
    sudo sh -c ': > /srv/lab28/spool/backup.fifo'   # open the FIFO for writing: the reader's open() returns
    sleep 1; ps -p "$B" >/dev/null || echo "backup-agent $B has exited"

    # ---- Task 6: preview, stop, verify, clean up ----
    pgrep -af '/srv/lab28/bin/(thumbnailer|log-shipper)$'          # preview with the SAME pattern
    sudo kill -TERM $(pgrep -f '/srv/lab28/bin/(thumbnailer|log-shipper)$')
    sleep 3; pgrep -x dd || echo "no dd running"
    vmstat -w 1 4 ; iostat -xz 1 2 ; sleep 30 ; cat /proc/pressure/io
    ls -l /srv/lab28/bin ; cat /srv/lab28/bin/*                     # now compare with your findings
    sudo bash lab28-cleanup.sh
    pgrep -af /srv/lab28 || echo "no lab28 processes" ; ls -d /srv/lab28 2>/dev/null || echo "removed"
    ```

    **Expected output (captured, Tasks 2, 3, 5b, 6; shortened):**

    ```text
    16:58:48      UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
    16:58:50        0      3702   90.00    7.50    0.00    0.00   97.50     0  python3
    16:58:50        0      3793    0.50    7.50    0.00    0.00    8.00     3  dd
      PID  PPID USER                      STARTED     ELAPSED COMMAND
     3702  3700 root     Fri Nov 20 16:57:46 2026       01:03 python3 /srv/lab28/bin/thumbnailer
    lrwxrwxrwx 1 root root 0 Nov 20 16:58 /proc/3702/exe -> /usr/bin/python3.11

     3793  3710 D          00:01 dd if=/dev/zero of=/srv/lab28/spool/outbox.dat bs=4k count=16384 oflag=dsync conv=notrunc status=none
     3878  3710 R          00:00 dd if=/dev/zero of=/srv/lab28/spool/outbox.dat bs=4k count=16384 oflag=dsync conv=notrunc status=none
      PID  PPID     ELAPSED COMMAND
     3710  3708       01:06 /bin/sh /srv/lab28/bin/log-shipper
    % time     seconds  usecs/call     calls    errors syscall
    ------ ----------- ----------- --------- --------- ----------------
     66.45    1.319475      329868         4         2 wait4
     25.71    0.510519          30     16690           write
      7.82    0.155320           9     16693           read
      0.01    0.000150          75         2           vfork

      PID STAT     ELAPSED WCHAN                COMMAND
     3719 S          01:18 wait_for_partner     /bin/sh /srv/lab28/bin/backup-agent
    backup-agent 3719 has exited

    no dd running
    Device   r/s ...    w/s     wkB/s ...     f/s f_await  aqu-sz  %util
    vda    24.00 ...   0.00      0.00 ...    0.00    0.00    0.08   2.80
    some avg10=4.24 avg60=11.19 avg300=5.83 total=83149578
    full avg10=3.72 avg60=9.71 avg300=5.03 total=71943890
    ```

    (The `strace -c` table counts the shell and its `dd` children together, because of `-f`; `wait4` is the shell waiting for each `dd`. The `read`/`write` pairs are `dd` copying `/dev/zero` to the file in 4 KiB blocks, each write forced to stable storage by `oflag=dsync`.)

    **RCA template (`~/lab28-rca.md`):**

    ```text
    # RCA: app01 slowness and failed backup, 2026-11-20
    Summary: Between 16:57 and 17:12 UTC app01 was slow because a log-shipping agent forced every 4 KiB
      write to disk (O_DSYNC), saturating storage (PSI io full 17 %), while an image job used a full CPU.
      Separately, the session service exhausted its 256 file descriptors and the backup agent was blocked
      waiting for a FIFO writer.
    Impact: <who, how long, measured how: e.g. page load p95, failed sessions, no backup for 1 night>
    Detection: user ticket at 09:10 local; no alert fired (gap).
    Timeline (UTC): 16:57:48 faults start · 16:58 load 1.5 · 16:59 session-cache hits EMFILE ·
      17:05 triage complete · 17:07 log-shipper and thumbnailer stopped · 17:08 PSI io back to 0.
    Root causes and 5 whys (log-shipper): slow app → disk latency/flush storm → agent writes synchronously
      → configured with dsync for "no lost lines" → change not load-tested and no I/O alerting
      → ROOT: change process has no performance test for agents on shared hosts.
    Contributing factors: no sysstat history; no fd-usage alert; backup has no timeout.
    What went well: checklist identified all faults in < 10 minutes; evidence preserved.
    Corrective actions: batch/async writes in the agent (owner, date) · alert PSI io full > 5 % (owner, date)
      · LimitNOFILE + fix the leak in session-cache (owner, date) · `timeout` and a writer check for
      backup-agent (owner, date) · enable sysstat on all servers (owner, date).
    ```

??? success "PowerShell solution"
    ```powershell
    # ---- find the culprits without Get-Job (5.1 and 7, Windows) ----
    $cpus = [Environment]::ProcessorCount
    # 1. CPU, normalised
    Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -Filter "Name<>'_Total' AND Name<>'Idle'" |
        Sort-Object PercentProcessorTime -Descending | Select-Object -First 5 Name, IDProcess,
            @{n='CPU%';e={[math]::Round($_.PercentProcessorTime / $cpus, 1)}}, IOWriteOperationsPersec, HandleCount

    # 2. memory (private bytes)
    Get-Process | Sort-Object PagedMemorySize64 -Descending | Select-Object -First 5 Id, ProcessName,
        @{n='PrivateMB';e={[math]::Round($_.PagedMemorySize64 / 1MB)}}

    # 3. handle growth over 60 s
    $before = @{}; Get-Process | ForEach-Object { $before[$_.Id] = $_.HandleCount }
    Start-Sleep -Seconds 60
    Get-Process | Where-Object { $before.ContainsKey($_.Id) } | ForEach-Object {
        [pscustomobject]@{ Id = $_.Id; Name = $_.ProcessName; Growth = $_.HandleCount - $before[$_.Id] }
    } | Sort-Object Growth -Descending | Select-Object -First 3

    # 4. disk: write rate per process and latency per disk
    Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -Filter "Name<>'_Total'" |
        Sort-Object IOWriteOperationsPersec -Descending | Select-Object -First 3 Name, IDProcess, IOWriteOperationsPersec
    Get-Counter '\PhysicalDisk(*)\Avg. Disk sec/Write', '\PhysicalDisk(*)\Current Disk Queue Length' -SampleInterval 2 -MaxSamples 3

    # 5. map PIDs to the jobs: child powershell/pwsh processes of your session
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$PID" |
        Select-Object ProcessId, Name, CreationDate, @{n='Cmd';e={$_.CommandLine.Substring(0, [math]::Min(80, $_.CommandLine.Length))}}

    # 6. clean up (preview first)
    .\Lab28-Cleanup.ps1 -WhatIf
    .\Lab28-Cleanup.ps1
    ```

    **Expected output (example, step 1 on a 4-CPU VM):**

    ```text
    Name          IDProcess  CPU% IOWriteOperationsPersec HandleCount
    ----          ---------  ---- ----------------------- -----------
    powershell#2       7340  24.8                       0         601
    powershell#4       7388  14.2                     498         588
    powershell#3       7364   0.3                       0        1012
    powershell#1       7312   0.1                       0         580
    ```

    In Windows PowerShell 5.1 and PowerShell 7, `Start-Job` runs each job in a **separate child process** (`powershell.exe` or `pwsh.exe`), which is why the culprits appear as additional PowerShell processes whose parent is your session (`$PID`). The memory job shows ~1,024 MB in `PrivateMB`, and the handle job gains about 300 handles per minute (5 per second).

??? success "Answers to questions"
    1. **thumbnailer** — `mpstat -P ALL`/`pidstat` (utilisation of one CPU); **log-shipper** — `vmstat` `b`/`wa` and `iostat` `w/s`/`f/s`, PSI io (saturation of the disk); **cache-warmer** — `ps --sort=-rss`/`free` (utilisation of memory; saturation only on a smaller VM); **session-cache** — `/proc/PID/fd` count = limit and `EMFILE` in its log (errors on a software resource); **backup-agent** — `ps` wchan/`strace -p` (no resource usage at all; a blocked process, found from the ticket, not from the USE metrics).
    2. Each `dd` lives only seconds and is just the tool doing the writing; killing it would only make the shell start the next one. Its **parent** (`ps -o ppid=`), `/bin/sh /srv/lab28/bin/log-shipper`, is the loop that keeps starting them.
    3. No. `mpstat` shows one CPU at ~0 % idle and the others largely idle; `vmstat` `r` stays around 1–2 (below 4 CPUs); `pidstat -u` shows `%wait` ≈ 0 for the hog and PSI cpu `some` stays low. It is full utilisation of one core, which would matter only if other work needed that core (or if the service were single-threaded and slow).
    4. Thousands of 4 KiB writes per second, each with `O_DSYNC` (`f/s` ≈ thousands): every write waits for stable storage, so the device does many tiny operations and flushes; latency and queue grow and every other process's I/O waits behind them (PSI io `full` > 10 %), even though throughput is only tens of MB/s.
    5. It used almost no CPU, memory or disk; it simply reached its descriptor limit. The proof: `ls /proc/PID/fd | wc -l` = **256** and `Max open files 256` in `/proc/PID/limits`, plus `Errno 24 Too many open files` in its log.
    6. It was blocked in `openat()` on the FIFO `/srv/lab28/spool/backup.fifo` (wchan `wait_for_partner`, stack `fifo_open`): opening a FIFO for reading blocks until a writer opens it. Opening the FIFO for writing (`: > /srv/lab28/spool/backup.fifo`) let the `open()` complete and the agent exited at once.
    7. `SIGTERM` lets a process clean up (flush, remove locks/temporary files); `SIGKILL` cannot be caught and can leave corrupt state — use it only if `SIGTERM` fails. Previewing with exactly the same pattern prevents signalling the wrong processes (for example, a regex that also matches your editor or a production service).
    8. Example: the application was slow → storage latency/flush storm → log-shipper did 4 KiB synchronous writes → it was configured with `dsync` to never lose a line → the change was made without load testing and nothing alerted on I/O pressure → **root cause:** the change process has no performance-test step for agents on shared hosts, and there is no saturation alerting.
    9. The counter is per logical processor: 100 = one full CPU. On 4 CPUs, a value of 100 is 25 % of the machine; dividing by `[Environment]::ProcessorCount` gives the Task Manager-style percentage.
    10. `sar` (every 10 minutes) would record CPU, run queue/load, memory, disk activity (`-d`) and I/O wait — i.e. the CPU, memory and disk faults — but not which process caused them, nor descriptor exhaustion or a blocked process. Those need application logs, `/proc` checks or process-level monitoring.
