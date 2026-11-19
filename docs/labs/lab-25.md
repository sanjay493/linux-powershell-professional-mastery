---
description: "Migrate a fragile health-check crontab line to a robust scheduled job: audit every crontab, write a wrapper with absolute paths, flock -n, timeout, UTC log lines, logger -t lab25 and exit-code mapping for system-health.sh, install it in cron every 15 minutes and nightly, prove overlap protection, convert it to systemd timers verified with systemd-analyze, rotate its log with a logrotate drop-in, register System-Health.ps1 as a Windows scheduled task and handle LastTaskResult 3, and hunt down a planted persistence job (MITRE ATT&CK T1053)."
---

# Lab 25: Scheduled Health Checks

| Field | Value |
|---|---|
| **Lab ID** | LAB-25 |
| **Related lesson** | [Day 25: Task Scheduling and Automation](../course/module-5/day-25.md) |
| **Difficulty** | Intermediate → Advanced |
| **Time** | 90–150 minutes (plus waiting for scheduled runs) |
| **Risk level** | Low. Use a **lab VM or WSL2**, not a production server, and take a snapshot first. The setup scripts back up your crontab, create `~/lab25` / `C:\Lab25`, add one cron drop-in (`/etc/cron.d/lab25-sysupdate`) and one Windows task that only write a time stamp. Everything uses the `lab25` prefix and is removed by the clean-up scripts. Needs `sudo` (Linux) and an elevated PowerShell (Windows). The health check itself only reads system information. |

## Objective

The operations team inherited a health check from an old server: a single crontab line that someone copied years ago. Nobody has seen an alert from it. You are asked to:

1. **Audit** the existing schedules on the box and explain why the legacy line has never worked.
2. Replace it with a **robust job**: a wrapper `lab25-run-health.sh` around the Day 25 script `system-health.sh` with absolute paths, a lock, a time limit, one UTC log line per run, the report file kept via `-o`, exit-code mapping and an alert through `logger -t lab25` when the script exits **3**.
3. Run it **every 15 minutes** (quick check) and **nightly at 02:30 UTC** (full CSV report with report retention), first with cron, then as **systemd timers**.
4. Keep its log under control with a **logrotate** drop-in.
5. Do the same on **Windows** with `System-Health.ps1` and Task Scheduler.
6. While you are at it, the security team asks you to **list every scheduled job** on the machine — they suspect someone left a persistence mechanism behind.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS VM (or WSL2 with systemd enabled for Task 5) with `sudo`. Packages: `cron` (default), `util-linux` (`flock`), `coreutils` (`timeout`), `logrotate` (default), `at` optional. Check: `systemctl is-active cron`.
- **Windows:** Windows 11 or Windows Server 2022 with Windows PowerShell 5.1 (PowerShell 7 also works), an **elevated** session for SYSTEM tasks.
- The course repository (or at least `scripts/linux/system-health.sh` and `scripts/powershell/System-Health.ps1`) from the [scripts library](../projects/scripts.md). The setup scripts look for it in `~/linux-powershell-professional-mastery` / `$HOME\linux-powershell-professional-mastery`; pass another path as the first argument / `-HealthScript`.

## Initial Conditions

- `~/lab25` and `C:\Lab25` do not exist; your crontab has no `lab25` lines.
- Save the setup and clean-up scripts from the [Solution](#solution) ("Lab setup and clean-up scripts") to your home directory, **read them**, then run the setup:

=== "Linux"

    ```bash
    cd ~ && sudo bash lab25-setup.sh ~/linux-powershell-professional-mastery/scripts/linux/system-health.sh
    crontab -l | tail -2
    sha256sum /tmp/.lab25-update.sh
    ```

    **Expected output (captured; your user name appears instead of `student`):**

    ```text
    Lab 25 ready for student in /home/student/lab25
      crontab backup : /home/student/lab25/backup/crontab.before (0 lines)
      health script  : /home/student/lab25/bin/system-health.sh
    # lab25-legacy: health check copied from the old server
    */15 * * * * cd lab25 && ./bin/system-health.sh -o reports > /dev/null 2>&1; echo "last run $(date +%F)" > last-run.txt
    9392fdcb6ca07985fed986b3cd92d1c7836158e971d0bf36a9618d4cbfc15539  /tmp/.lab25-update.sh
    ```

    The backup line shows how many lines your crontab had before the lab; the clean-up script restores it.

=== "Windows"

    ```powershell
    # elevated PowerShell
    Set-Location $HOME
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Lab25-Setup.ps1 `
        -HealthScript "$HOME\linux-powershell-professional-mastery\scripts\powershell\System-Health.ps1"
    ```

    **Expected output (example):**

    ```text
    Lab 25 ready in C:\Lab25
      health script : C:\Lab25\bin\System-Health.ps1
      tasks         : \Lab25\Legacy-Health (legacy), plus one planted task to find in Task 8
    ```

The lab layout:

```text
~/lab25/                         C:\Lab25\
├── bin/system-health.sh         ├── bin\System-Health.ps1      the Day 25 scripts (copied)
├── bin/lab25-run-health.sh      ├── bin\Lab25-Run-Health.ps1   your wrapper (Task 2 / Task 7)
├── reports/                     ├── reports\                   one report per run
├── log/health.log               ├── log\health.log             one UTC line per run
├── run/health.lock              │                              flock lock file (Linux)
├── backup/crontab.before        ├── backup\                    crontab / task XML backups
└── evidence/                    └── evidence\                  Task 8 evidence
```

## Step-by-Step Instructions

### Task 1 — Audit the existing schedules

List your crontab, all system crontabs (`/etc/crontab`, `/etc/cron.d/`), the `cron.*` directories and the spool directory. Find the legacy health-check line and write down **every** problem with it. Prove at least one of them from the cron log (`journalctl -u cron` / `grep CRON /var/log/syslog`) after the next quarter hour, or reproduce the shell's view of the line by hand.

On Windows, list the tasks in `\Lab25\`, run `\Lab25\Legacy-Health` once and read its `LastTaskResult`.

### Task 2 — Write the wrapper `lab25-run-health.sh`

Create `~/lab25/bin/lab25-run-health.sh` (mode 750) that:

1. sets its own `PATH`, `LC_ALL=C`, `TZ=UTC` and uses only absolute paths derived from `LAB25_HOME` (default `$HOME/lab25`);
2. accepts a mode `quick` (default: `system-health.sh -q -o reports`) or `nightly` (`-q -f csv -o reports`, then deletes reports older than 14 days) and passes any further options to `system-health.sh`;
3. holds a lock with `flock -n` on `~/lab25/run/health.lock`; if the lock is busy, logs `status=SKIP` and exits 0;
4. runs the check under `timeout` (default 120 s, `LAB25_TIMEOUT`), and maps the result: 0 → `OK`, 3 → `ALERT` (also append the WARNING lines), 124 → `TIMEOUT`, anything else → `ERROR` (with the first line of the script's output);
5. writes **one line per run** to `~/lab25/log/health.log`: `UTC-timestamp host= mode= status= exit= …` including the report file name, and sends the same message with `logger -t lab25` at priority `user.info`, `user.warning` (alert) or `user.err`;
6. exits with the health script's code (124 for a timeout).

Test it from another directory (`cd /tmp`) with an OK run, a forced alert (`-m 1`), an invalid mode, an invalid option (`-c 0`) and a timeout (a stand-in script that sleeps). Check the script with `shellcheck`.

### Task 3 — Install it in cron and prove that it fired

Back up your crontab with a time stamp. Disable (comment out) the legacy line — do not delete it, the change must be reviewable. Add:

- `MAILTO=""` and a comment with the owner;
- the quick check every 15 minutes and the nightly check at 02:30, each with stderr appended to `~/lab25/log/cron-stderr.log`.

Then **prove** that cron ran it: the `CMD` line in the cron log, a new line in `health.log` and a new report file. (To avoid waiting, temporarily use `*/2` or wait for the next quarter hour.)

### Task 4 — Prove the overlap protection

Hold the lock from another terminal for longer than one interval (`flock ~/lab25/run/health.lock sleep 200`) while a scheduled (or manual) run starts. Show the `SKIP` line. Explain what would have happened without the lock if a run took 20 minutes.

### Task 5 — Convert to systemd timers

Write four units with the `lab25-` prefix in `/etc/systemd/system/` (replace `student` with your user name):

- `lab25-health.service` — `Type=oneshot`, `User=`/`Group=`, `ExecStart=… quick`, `TimeoutStartSec=5min`, `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict`, `ReadWritePaths=` your lab folder;
- `lab25-health.timer` — every 15 minutes;
- `lab25-health-nightly.service` — the same with `nightly`;
- `lab25-health-nightly.timer` — 02:30 **UTC**, `Persistent=true`, `RandomizedDelaySec=15min`.

Check them with `systemd-analyze verify` and both schedules with `systemd-analyze calendar`. On a VM with systemd: `daemon-reload`, enable both timers, comment out the two cron lines (never run both schedulers for the same job), start the quick service once by hand, and show `systemctl list-timers 'lab25*'`, `systemctl status lab25-health.service` and `journalctl -u lab25-health.service`.

(Alternative without root: user units in `~/.config/systemd/user/` without `User=`/`Group=`, `systemctl --user`, and `sudo loginctl enable-linger $USER`.)

### Task 6 — Rotate the log

Create `/etc/logrotate.d/lab25-health` for `~/lab25/log/*.log`: weekly, 8 rotations, also when larger than 5 MiB, compressed (delayed), missing or empty logs are fine, new log created with mode 0640, rotation performed **as your user** (`su`). Test with `sudo logrotate -d` — debug mode, which changes nothing — and explain the output.

### Task 7 — Windows: Task Scheduler

In an elevated PowerShell:

1. Save `Lab25-Run-Health.ps1` (Solution) as `C:\Lab25\bin\Lab25-Run-Health.ps1` and run it once by hand exactly as the task will (`powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File …`). Check `$LASTEXITCODE` and the log.
2. **Preview first:** build the action, a daily trigger with a 15-minute repetition, a SYSTEM principal and the settings (`-StartWhenAvailable`, `-ExecutionTimeLimit 10 min`, `-MultipleInstances IgnoreNew`, `-RestartCount 2`, battery options) as objects and inspect them before registering anything.
3. Register `\Lab25\Lab25-Health` (quick) and `\Lab25\Lab25-Health-Nightly` (02:30, `-Mode Nightly`).
4. Check the operational log is enabled (enable it if not — note the previous state for the clean-up).
5. `Start-ScheduledTask`, wait, read `Get-ScheduledTaskInfo`. Then force an alert by changing the action with `Set-ScheduledTask` to add `-MemoryPercent 1`, run it, show **`LastTaskResult` 3**, the log line, the Application event from `Lab25Health`, and events 100/102/201 for the run. Restore the normal action.
6. Delete the legacy task after exporting it to `C:\Lab25\backup\`.

### Task 8 — Persistence hunt and clean-up

List **every** scheduled job on the Linux machine (all users' crontabs, `/etc/crontab`, `/etc/cron.d`, the `cron.*` directories, `at` jobs, systemd timers) and on Windows (all tasks outside `\Microsoft\` with action and account). Identify the planted job, decide why it is suspicious, **record evidence** in `~/lab25/evidence/` (contents, hash, timestamps, the log lines that show it running) and then remove it. Finally run the clean-up scripts.

## Commands to Execute

Work through the tasks yourself first; complete solutions are in the [Solution](#solution). Building blocks:

| Need | Bash | PowerShell |
|---|---|---|
| Back up schedules | `crontab -l > ~/lab25/backup/crontab.$(date -u +%Y%m%dT%H%M%SZ)` | `Export-ScheduledTask -TaskPath '\Lab25\' -TaskName X` |
| All crontabs | `for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u "$u"; done` | <code>Get-ScheduledTask &#124; Where-Object TaskPath -notlike '\Microsoft\*'</code> |
| Lock | `exec 9> "$LOCK"; flock -n 9` | `[System.Threading.Mutex]` · `-MultipleInstances IgnoreNew` |
| Time limit | `timeout --kill-after=10 120 CMD` | `-ExecutionTimeLimit (New-TimeSpan -Minutes 10)` |
| UTC timestamp | `date -u +%Y-%m-%dT%H:%M:%SZ` | `[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')` |
| Log / alert | `logger -t lab25 -p user.warning -- "…"` | `eventcreate /T WARNING /ID 325 /L APPLICATION /SO Lab25Health /D "…"` |
| Did it run? | `journalctl -u cron` · `grep CRON /var/log/syslog` | `Get-ScheduledTaskInfo` · TaskScheduler Operational log |
| Test schedules | `systemd-analyze calendar '*:0/15'` · `systemd-analyze verify *.timer *.service` | inspect the trigger object |
| Test rotation | `sudo logrotate -d /etc/logrotate.d/lab25-health` | — |
| Evidence | `sha256sum`, `stat`, `cp -p` | `Get-FileHash`, `Export-ScheduledTask` |

## Expected Results

The Linux values were **captured** on 2026-11-19 by running the setup script, the solution commands and the clean-up script end to end on Ubuntu 24.04.5 (cron 3.0pl1-184ubuntu2, util-linux 2.39.3, systemd 255.4, logrotate 3.21.0) in a container in which `cron` and `atd` were started by hand and systemd was **not** PID 1; cron's syslog messages were read from `/dev/log` with a small listener instead of `/var/log/syslog`. The real `scripts/linux/system-health.sh` was used. Because one volume in the container was 93 % full, the demonstrations of an OK run pass `-d 95`. Host and user names are shown as `ubuntu-lab` and `student`. `systemctl list-timers`, `systemctl status` and all Windows results are **examples**; PowerShell was not available on the release host.

| Task | Result |
|---|---|
| 1 | The legacy line is the only job in your crontab. Problems: relative `cd lab25` and `./bin/…` (works only because cron starts in `$HOME`), unescaped `%` (the command is cut at `date +`, `/bin/sh` reports a syntax error and **nothing runs**, exit status 2), all output discarded (`> /dev/null 2>&1`, and no MTA for the rest), no lock, no time limit, no exit-code handling or alert, `last-run.txt` overwritten (no history), reports never deleted, default `PATH=/usr/bin:/bin`. Cron log: `(CRON) error (grandchild #3645 failed with exit status 2)` and `No MTA installed, discarding output`. `~/lab25/reports` was never created. Windows: `Legacy-Health` `LastTaskResult` **1** (`.\bin\System-Health.ps1` is not found in `C:\Windows\System32`) |
| 2 | From `/tmp`: `quick -d 95` → exit 0, `status=OK`; `-m 1` → exit 3, `status=ALERT` + WARNING lines; `hourly` → usage message, exit 2, no log line; `-c 0` → exit 1, `status=ERROR msg="system-health.sh: error: -c must be an integer from 1 to 1000"`; hanging stand-in with `LAB25_TIMEOUT=3` → exit 124 after 3 s, `status=TIMEOUT`. `shellcheck -S style` reports nothing |
| 3 | Cron log `(student) CMD ([5588] /home/student/lab25/bin/lab25-run-health.sh quick …)`, `health.log` line `… status=OK exit=0 duration=0s report=system-health-ubuntu-lab-20261119T165201Z.txt`, a new file in `reports/` |
| 4 | `2026-11-19T16:54:02Z host=ubuntu-lab mode=quick status=SKIP exit=0 msg="previous run still active"` |
| 5 | `systemd-analyze verify` on the four units: no messages, exit 0. `*:0/15` → `*-*-* *:00/15:00`; `*-*-* 02:30:00 UTC` → next elapse 02:30 UTC. A typo `OnCalender=` is reported as `Unknown key name` and `Timer unit lacks value setting. Refusing.` |
| 6 | `logrotate -d`: `rotating pattern: /home/student/lab25/log/*.log  weekly (8 rotations)`, `switching euid … to <your UID>`, both logs "does not need rotating (log has already been rotated)" (first time seen); nothing changed |
| 7 | (example) Manual run exit 0 or 3; after registration `LastTaskResult` 267011 (not yet run), during the run 267009, then 0; with `-MemoryPercent 1` **3**, event 201 "with return code 3", an Application event 325 from `Lab25Health`, `health.log` `status=ALERT exit=3` |
| 8 | The planted job is `/etc/cron.d/lab25-sysupdate`: `*/5 * * * * student /tmp/.lab25-update.sh >/dev/null 2>&1` — a script in `/tmp` with a hidden name, generic "system update helper" comment, output discarded. It runs every 5 minutes (`CRON[8342]: (student) CMD ([8343] /tmp/.lab25-update.sh >/dev/null 2>&1)`) and appends a time stamp to `/tmp/.lab25-beacon`. SHA-256 of the script: `9392fdcb6ca07985fed986b3cd92d1c7836158e971d0bf36a9618d4cbfc15539`. Windows (example): `\Lab25-UpdateCheck` in the root folder, at logon, `powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\Public\lab25-update.ps1"` |

## Verification Steps

=== "Bash"

    ```bash
    crontab -l | grep -c '^#DISABLED'                                  # 2 (legacy comment + line)
    crontab -l | grep -E '^\*/15|^30 2'                                # the two new lines
    grep -c 'mode=quick' ~/lab25/log/health.log                        # grows by 1 every 15 min
    tail -n 3 ~/lab25/log/health.log
    journalctl -t lab25 -n 3 --no-pager                                # or: grep lab25 /var/log/syslog | tail -3
    ls -1t ~/lab25/reports | head -3
    systemd-analyze verify /etc/systemd/system/lab25-health*.{service,timer} && echo "units OK"
    systemctl list-timers 'lab25*'                                     # VM with systemd only
    sudo logrotate -d /etc/logrotate.d/lab25-health 2>&1 | grep -E 'rotating pattern|error'
    ls /etc/cron.d/lab25-* /tmp/.lab25-update.sh 2>/dev/null; echo "planted job gone: $?"   # 2 after Task 8
    ```

=== "PowerShell"

    ```powershell
    Get-ScheduledTask -TaskPath '\Lab25\' | Select-Object TaskName, State
    Get-ScheduledTaskInfo -TaskPath '\Lab25\' -TaskName 'Lab25-Health' | Select-Object LastRunTime, LastTaskResult, NextRunTime
    (Get-ScheduledTask -TaskPath '\Lab25\' -TaskName 'Lab25-Health').Actions.Arguments   # no -MemoryPercent 1 left
    Get-Content C:\Lab25\log\health.log -Tail 3
    (Get-WinEvent -ListLog 'Microsoft-Windows-TaskScheduler/Operational').IsEnabled
    Get-ScheduledTask -TaskPath '\' -TaskName 'Lab25-UpdateCheck' -ErrorAction SilentlyContinue   # nothing after Task 8
    icacls C:\Lab25                                                          # no write rights for Users
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| No `CMD` lines for your job at all | cron not running, or you are waiting for `*/15` | `systemctl status cron`; wait for :00/:15/:30/:45 or use `*/2` while testing |
| `CMD` line, but no `health.log` line | Wrapper not executable, wrong absolute path, or it failed before logging | `ls -l ~/lab25/bin`; run the exact crontab command in `env -i HOME=$HOME PATH=/usr/bin:/bin /bin/sh -c '…'`; read `cron-stderr.log` |
| `status=ERROR exit=2 … missing or not executable` | `system-health.sh` not copied or not `chmod +x` | Re-run the setup or `chmod 750 ~/lab25/bin/system-health.sh` |
| Every run is `ALERT` | A real threshold breach (often a nearly full filesystem) | Read the WARNING lines; fix it or pass a threshold (`quick -d 95`) and document why |
| `SKIP` on every run | A stale process holds the lock (hung run) | `fuser -v ~/lab25/run/health.lock` / `pgrep -af system-health`; the `timeout` should prevent this |
| `journalctl -t lab25` shows nothing | No journal/rsyslog (containers), or wrong tag | `grep lab25 /var/log/syslog`; check `logger -t lab25 test` |
| `systemd-analyze verify`: `Command … is not executable` | Wrong `ExecStart=` path or user name | Use the absolute path of your wrapper; replace `student` |
| Timer active but service `failed` with `status=3` | The check reported an alert — expected | Read the journal; use `OnFailure=` for notifications |
| Service fails with `Permission denied` writing the log | `ReadWritePaths=` missing or wrong with `ProtectSystem=strict` | Set `ReadWritePaths=/home/<you>/lab25` |
| `logrotate: … parent directory has insecure permissions` | Log directory writable by a non-root group | Keep the `su student student` line (with your names) or `chmod 750` the directory |
| Windows `LastTaskResult` 1 | Error in the script, or `-Command` used | Use `-File`; run the action line by hand with `-NonInteractive`; add `Start-Transcript` while debugging |
| Windows `Access is denied` on `Register-ScheduledTask` | Not elevated (SYSTEM principal, `-RunLevel Highest`) | Start PowerShell as Administrator |
| No events in the operational log | Log disabled | `wevtutil sl Microsoft-Windows-TaskScheduler/Operational /e:true` (admin) |
| `eventcreate` fails in a manual run | Not elevated (creating the event source needs admin) | Run the test elevated; the task runs as SYSTEM |

## Questions

1. The legacy line contains `cd lab25` — a relative path — yet that part would work under cron. Why, and why is it still wrong?
2. Explain exactly what cron did with the unescaped `%` in the legacy line and why nobody ever saw an error.
3. Your wrapper exits 0 when the lock is busy. Argue for that choice, and name a case where a non-zero code would be better.
4. Why does the wrapper separate exit 3 (`ALERT`) from 1, 2 and 124 (`ERROR`/`TIMEOUT`), and who should be notified for each?
5. The systemd quick service ends in the `failed` state when the check finds a problem. Is that good or bad? What does `SuccessExitStatus=3` change?
6. Why is the nightly timer scheduled at `02:30:00 UTC` with `RandomizedDelaySec=15min` and `Persistent=true`, while the quick timer has neither of the latter two?
7. Why must the Windows action use `-File` rather than `-Command`, and why `-NonInteractive`?
8. Why did the Windows setup remove inherited permissions from `C:\Lab25`, and what attack does that prevent for a task that runs as SYSTEM?
9. List four indicators that made `/etc/cron.d/lab25-sysupdate` (and `\Lab25-UpdateCheck`) suspicious, and explain why you record evidence before deleting it.
10. Which MITRE ATT&CK sub-techniques cover the persistence mechanisms you looked for in Task 8?

## Solution

??? success "Lab setup and clean-up scripts (Bash: `lab25-setup.sh`, `lab25-cleanup.sh`)"
    `lab25-setup.sh` (run with `sudo bash lab25-setup.sh [path/to/system-health.sh]`):

    ```bash
    #!/usr/bin/env bash
    # lab25-setup.sh - prepare Lab 25 (Scheduled Health Checks). Run with sudo from your account:
    #     sudo bash lab25-setup.sh [PATH/TO/system-health.sh]
    # Creates ~/lab25 for the invoking user, backs up that user's crontab, appends the "legacy"
    # fragile cron line, and plants one harmless suspicious job for the persistence hunt:
    #     /etc/cron.d/lab25-sysupdate -> /tmp/.lab25-update.sh (runs as YOU, only writes a file).
    # Safe to re-run. Undo everything with lab25-cleanup.sh.
    set -o errexit -o nounset -o pipefail

    if [[ $EUID -ne 0 || -z ${SUDO_USER:-} || ${SUDO_USER:-} == root ]]; then
        echo "Run as a normal user through sudo: sudo bash $0 [system-health.sh]" >&2
        exit 1
    fi
    U=$SUDO_USER
    UHOME=$(getent passwd "$U" | cut -d: -f6)
    LAB=$UHOME/lab25
    SRC=${1:-$UHOME/linux-powershell-professional-mastery/scripts/linux/system-health.sh}
    if [[ ! -f $SRC ]]; then
        echo "system-health.sh not found at $SRC - pass its path as the first argument" >&2
        exit 1
    fi

    install -d -o "$U" -g "$U" -m 0750 "$LAB" "$LAB"/{bin,reports,log,run,backup,evidence}
    install -o "$U" -g "$U" -m 0750 "$SRC" "$LAB/bin/system-health.sh"

    # 1. Back up the user's crontab once (an empty file means "had no crontab").
    if [[ ! -e $LAB/backup/crontab.before ]]; then
        crontab -l -u "$U" > "$LAB/backup/crontab.before" 2>/dev/null || true
        chown "$U:$U" "$LAB/backup/crontab.before"
    fi

    # 2. Append the fragile legacy line (only once). The % is deliberately NOT escaped.
    if ! crontab -l -u "$U" 2>/dev/null | grep -q 'lab25-legacy'; then
        {
            crontab -l -u "$U" 2>/dev/null || true
            echo '# lab25-legacy: health check copied from the old server'
            # shellcheck disable=SC2016  # the $(...) must stay literal: it is for cron, not for us
            echo '*/15 * * * * cd lab25 && ./bin/system-health.sh -o reports > /dev/null 2>&1; echo "last run $(date +%F)" > last-run.txt'
        } | crontab -u "$U" -
    fi

    # 3. Plant the harmless "suspicious" job for Task 8 (runs as the lab user, not root).
    cat > /tmp/.lab25-update.sh <<'EOF'
    #!/bin/sh
    # harmless Lab 25 persistence simulation: only records that it ran
    date -u +%Y-%m-%dT%H:%M:%SZ >> /tmp/.lab25-beacon
    EOF
    chown "$U:$U" /tmp/.lab25-update.sh
    chmod 0755 /tmp/.lab25-update.sh
    printf '%s\n' '# system update helper' \
        "*/5 * * * * $U /tmp/.lab25-update.sh >/dev/null 2>&1" > /etc/cron.d/lab25-sysupdate
    chmod 0644 /etc/cron.d/lab25-sysupdate

    echo "Lab 25 ready for $U in $LAB"
    echo "  crontab backup : $LAB/backup/crontab.before ($(wc -l < "$LAB/backup/crontab.before") lines)"
    echo "  health script  : $LAB/bin/system-health.sh"
    if ! pgrep -x cron > /dev/null; then
        echo "  WARNING: the cron daemon is not running (sudo systemctl enable --now cron)"
    fi
    ```

    `lab25-cleanup.sh` (run with `sudo bash lab25-cleanup.sh [--purge]`):

    ```bash
    #!/usr/bin/env bash
    # lab25-cleanup.sh - undo Lab 25. Run with sudo from your account:
    #     sudo bash lab25-cleanup.sh [--purge]
    # Removes the lab25 cron entries, timers, logrotate drop-in and planted files.
    # Restores the crontab you had before the lab. --purge also deletes ~/lab25.
    set -o errexit -o nounset -o pipefail

    if [[ $EUID -ne 0 || -z ${SUDO_USER:-} || ${SUDO_USER:-} == root ]]; then
        echo "Run as a normal user through sudo: sudo bash $0 [--purge]" >&2
        exit 1
    fi
    U=$SUDO_USER
    UHOME=$(getent passwd "$U" | cut -d: -f6)
    LAB=$UHOME/lab25

    # 1. systemd units (only when systemd is really running)
    if [[ -d /run/systemd/system ]]; then
        for t in lab25-health.timer lab25-health-nightly.timer; do
            systemctl disable --now "$t" 2>/dev/null || true
        done
    fi
    rm -fv /etc/systemd/system/lab25-health*.service /etc/systemd/system/lab25-health*.timer
    rm -fv "$UHOME"/.config/systemd/user/lab25-health*
    [[ -d /run/systemd/system ]] && systemctl daemon-reload

    # 2. crontab: restore the backup, or drop every lab25 line if there is no backup
    if [[ -f $LAB/backup/crontab.before ]]; then
        if [[ -s $LAB/backup/crontab.before ]]; then
            crontab -u "$U" "$LAB/backup/crontab.before"
        else
            crontab -r -u "$U" 2>/dev/null || true
        fi
    else
        crontab -l -u "$U" 2>/dev/null | grep -v 'lab25' | crontab -u "$U" - || true
    fi
    echo "crontab for $U now has $(crontab -l -u "$U" 2>/dev/null | grep -c . || true) line(s)"

    # 3. planted files, drop-ins and at jobs
    rm -fv /etc/cron.d/lab25-* /etc/logrotate.d/lab25-* /tmp/.lab25-update.sh /tmp/.lab25-beacon
    for job in $(atq 2>/dev/null | awk '{print $1}'); do
        if at -c "$job" 2>/dev/null | grep -q 'lab25'; then atrm "$job" && echo "removed at job $job"; fi
    done

    # 4. lab folder
    if [[ ${1:-} == --purge ]]; then
        rm -rf -- "$LAB" && echo "removed $LAB"
    else
        echo "kept $LAB (re-run with --purge to delete it)"
    fi
    ```

    Both scripts were executed end to end in the release container (setup → all tasks → clean-up, and setup → clean-up `--purge` with an existing personal crontab line, which was restored) and pass `shellcheck -S style`.

??? success "Lab setup and clean-up scripts (PowerShell: `Lab25-Setup.ps1`, `Lab25-Cleanup.ps1`)"
    `Lab25-Setup.ps1` (elevated):

    ```powershell
    #Requires -RunAsAdministrator
    <#
    .SYNOPSIS
        Prepare Lab 25 on Windows (run in an elevated Windows PowerShell 5.1 or PowerShell 7 session).
    .DESCRIPTION
        Creates C:\Lab25 with a locked-down ACL (SYSTEM and Administrators: full control, Users: read and
        execute), copies System-Health.ps1 into C:\Lab25\bin, registers the fragile legacy task
        \Lab25\Legacy-Health and plants one harmless "suspicious" task for the persistence hunt:
        \Lab25-UpdateCheck (runs as you at logon, only appends a time stamp to
        C:\Users\Public\lab25-beacon.txt). Safe to re-run. Undo with Lab25-Cleanup.ps1.
    .PARAMETER HealthScript
        Path to scripts\powershell\System-Health.ps1 from the course repository.
    .EXAMPLE
        .\Lab25-Setup.ps1 -HealthScript C:\src\linux-powershell-professional-mastery\scripts\powershell\System-Health.ps1
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$HealthScript = (Join-Path $HOME 'linux-powershell-professional-mastery\scripts\powershell\System-Health.ps1'),

        [ValidateNotNullOrEmpty()]
        [string]$LabRoot = 'C:\Lab25'
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path -LiteralPath $HealthScript)) {
        throw "System-Health.ps1 not found at $HealthScript - pass -HealthScript <path>"
    }

    foreach ($dir in 'bin', 'reports', 'log', 'backup', 'evidence') {
        New-Item -ItemType Directory -Path (Join-Path $LabRoot $dir) -Force | Out-Null
    }
    # Remove inherited C:\ permissions (Authenticated Users may modify new top-level folders) and grant
    # SYSTEM (S-1-5-18) and Administrators (S-1-5-32-544) full control, Users (S-1-5-32-545) read/execute.
    & icacls.exe $LabRoot /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "icacls failed with exit code $LASTEXITCODE" }
    Copy-Item -LiteralPath $HealthScript -Destination (Join-Path $LabRoot 'bin\System-Health.ps1') -Force

    # 1. The fragile legacy task: relative paths, -Command, output thrown away, no time limit.
    $legacyAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument '-Command .\bin\System-Health.ps1 -OutputPath reports > $null'
    $legacyTrigger = New-ScheduledTaskTrigger -Daily -At '02:30'
    $legacyPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount
    Register-ScheduledTask -TaskName 'Legacy-Health' -TaskPath '\Lab25\' -Action $legacyAction `
        -Trigger $legacyTrigger -Principal $legacyPrincipal `
        -Description 'lab25-legacy: health check copied from the old server' -Force | Out-Null

    # 2. Harmless "suspicious" task for Task 8 (runs as the current user, writes only a time stamp).
    $plant = Join-Path $env:PUBLIC 'lab25-update.ps1'
    Set-Content -LiteralPath $plant -Encoding ASCII -Value @(
        '# harmless Lab 25 persistence simulation: only records that it ran'
        '[DateTime]::UtcNow.ToString(''o'') | Add-Content -Path "$env:PUBLIC\lab25-beacon.txt"'
    )
    $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $plantAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$plant`""
    $plantTrigger = New-ScheduledTaskTrigger -AtLogOn -User $me
    $plantPrincipal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive
    Register-ScheduledTask -TaskName 'Lab25-UpdateCheck' -TaskPath '\' -Action $plantAction `
        -Trigger $plantTrigger -Principal $plantPrincipal -Description 'Update helper' -Force | Out-Null
    Start-ScheduledTask -TaskPath '\' -TaskName 'Lab25-UpdateCheck'

    Write-Output "Lab 25 ready in $LabRoot"
    Write-Output ("  health script : {0}" -f (Join-Path $LabRoot 'bin\System-Health.ps1'))
    Write-Output '  tasks         : \Lab25\Legacy-Health (legacy), plus one planted task to find in Task 8'
    ```

    `Lab25-Cleanup.ps1` (elevated; `-WhatIf` previews):

    ```powershell
    #Requires -RunAsAdministrator
    <#
    .SYNOPSIS
        Undo Lab 25 on Windows: remove the \Lab25\ tasks and folder, the planted task and files,
        and the Lab25Health event source. -Purge also deletes C:\Lab25.
    .EXAMPLE
        .\Lab25-Cleanup.ps1 -WhatIf      # preview
        .\Lab25-Cleanup.ps1 -Purge
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Purge,
        [ValidateNotNullOrEmpty()]
        [string]$LabRoot = 'C:\Lab25'
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $tasks = @(Get-ScheduledTask -TaskPath '\Lab25\' -ErrorAction SilentlyContinue) +
             @(Get-ScheduledTask -TaskPath '\' -TaskName 'Lab25-UpdateCheck' -ErrorAction SilentlyContinue)
    foreach ($t in $tasks) {
        if ($PSCmdlet.ShouldProcess("$($t.TaskPath)$($t.TaskName)", 'Unregister scheduled task')) {
            Unregister-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -Confirm:$false
            Write-Output "removed task $($t.TaskPath)$($t.TaskName)"
        }
    }
    # Delete the now empty \Lab25 task folder through the Task Scheduler COM API.
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    try {
        $null = $service.GetFolder('\Lab25')
        if ($PSCmdlet.ShouldProcess('\Lab25', 'Delete task folder')) { $service.GetFolder('\').DeleteFolder('Lab25', 0) }
    } catch {
        Write-Verbose 'task folder \Lab25 not present'
    }

    foreach ($f in (Join-Path $env:PUBLIC 'lab25-update.ps1'), (Join-Path $env:PUBLIC 'lab25-beacon.txt')) {
        if ((Test-Path -LiteralPath $f) -and $PSCmdlet.ShouldProcess($f, 'Remove file')) {
            Remove-Item -LiteralPath $f -Force
            Write-Output "removed $f"
        }
    }
    if ([System.Diagnostics.EventLog]::SourceExists('Lab25Health') -and
        $PSCmdlet.ShouldProcess('Lab25Health', 'Delete event source')) {
        [System.Diagnostics.EventLog]::DeleteEventSource('Lab25Health')
        Write-Output 'removed event source Lab25Health'
    }
    if ($Purge) {
        if ((Test-Path -LiteralPath $LabRoot) -and $PSCmdlet.ShouldProcess($LabRoot, 'Remove folder')) {
            Remove-Item -LiteralPath $LabRoot -Recurse -Force
            Write-Output "removed $LabRoot"
        }
    } else {
        Write-Output "kept $LabRoot (run again with -Purge to delete it)"
    }
    ```

    If the TaskScheduler operational log was disabled before Task 7 and you want to restore that state: `wevtutil sl Microsoft-Windows-TaskScheduler/Operational /e:false`. (Reviewed statically; not executed on the release host.)

??? success "Bash solution: Task 1 (audit)"
    ```bash
    crontab -l
    sudo ls -l /var/spool/cron/crontabs/
    grep -Ev '^[[:space:]]*(#|$)' /etc/crontab /etc/cron.d/*
    ls /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly
    ls ~/lab25                                    # no reports/, no last-run.txt
    # what /bin/sh receives from cron (everything up to the first %):
    cd ~ && /bin/sh -c 'cd lab25 && ./bin/system-health.sh -o reports > /dev/null 2>&1; echo "last run $(date +'; echo "exit=$?"
    # after the next quarter hour:
    journalctl -u cron --since "-20 min" --no-pager | grep -E 'lab25|grandchild|MTA'   # or grep CRON /var/log/syslog
    ```

    **Expected output (captured, abridged; tabs shown as spaces):**

    ```text
    # lab25-legacy: health check copied from the old server
    */15 * * * * cd lab25 && ./bin/system-health.sh -o reports > /dev/null 2>&1; echo "last run $(date +%F)" > last-run.txt
    -rw------- 1 student crontab 351 Nov 19 16:49 student
    /etc/crontab:SHELL=/bin/sh
    /etc/crontab:17 *  * * *  root  cd / && run-parts --report /etc/cron.hourly
    /etc/crontab:25 6  * * *  root  test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
    …
    /etc/cron.d/e2scrub_all:10 3 * * * root test -e /run/systemd/system || SERVICE_MODE=1 /sbin/e2scrub_all -A -r
    /etc/cron.d/lab25-sysupdate:*/5 * * * * student /tmp/.lab25-update.sh >/dev/null 2>&1
    backup  bin  evidence  log  reports  run
    /bin/sh: 1: Syntax error: end of file unexpected (expecting ")")
    exit=2
    CRON[3643]: (student) CMD ([3645] cd lab25 && ./bin/system-health.sh -o reports > /dev/null 2>&1; echo "last run $(date +)
    CRON[3643]: (CRON) error (grandchild #3645 failed with exit status 2)
    CRON[3643]: (CRON) info (No MTA installed, discarding output)
    ```

    (The setup script creates the empty `reports/` directory for the new job; the legacy line itself never wrote a report or `last-run.txt`. The cron lines were captured with the same line scheduled `* * * * *`. Note the `e2scrub_all` entries: Ubuntu package jobs that step aside when systemd is running, because a timer does the work. Your system may show more package files, such as `php` or `sysstat`.) The `/etc/cron.d/lab25-sysupdate` entry is for Task 8 — note it now.

??? success "Bash solution: Task 2 (`lab25-run-health.sh`)"
    ```bash
    #!/usr/bin/env bash
    # lab25-run-health.sh - run system-health.sh safely from cron or a systemd timer.
    #
    # Usage : lab25-run-health.sh [quick|nightly] [extra system-health.sh options, e.g. -d 95]
    #           quick   (default) every 15 minutes: quiet text report, alert on problems
    #           nightly full CSV report, then delete reports older than 14 days
    # Env   : LAB25_HOME (default $HOME/lab25), LAB25_TIMEOUT seconds (default 120)
    # Files : $LAB25_HOME/bin/system-health.sh  the checked script (Day 25)
    #         $LAB25_HOME/reports/              report files (system-health.sh -o)
    #         $LAB25_HOME/log/health.log        one UTC-stamped line per run (+ problem lines)
    #         $LAB25_HOME/run/health.lock       flock lock file (prevents overlapping runs)
    # Exit  : 0 OK or skipped (previous run still active) · 3 threshold breached (alert)
    #         1 invalid system-health.sh option · 2 setup/output problem or bad mode · 124 timed out
    set -o nounset -o pipefail
    umask 027
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export PATH LC_ALL=C TZ=UTC

    LAB=${LAB25_HOME:-$HOME/lab25}
    HEALTH=$LAB/bin/system-health.sh
    REPORTS=$LAB/reports
    LOG=$LAB/log/health.log
    LOCK=$LAB/run/health.lock
    LIMIT=${LAB25_TIMEOUT:-120}
    MODE=${1:-quick}
    [[ $# -gt 0 ]] && shift
    TAG=lab25

    log() {   # log STATUS MESSAGE -> health.log and syslog/journal
        local status=$1; shift
        printf '%s host=%s mode=%s status=%s %s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname)" "$MODE" "$status" "$*" >> "$LOG"
        case $status in
            OK|SKIP) logger -t "$TAG" -p user.info -- "mode=$MODE status=$status $*" ;;
            ALERT)   logger -t "$TAG" -p user.warning -- "mode=$MODE status=$status $*" ;;
            *)       logger -t "$TAG" -p user.err -- "mode=$MODE status=$status $*" ;;
        esac
    }

    case $MODE in
        quick)   args=(-q -o "$REPORTS") ;;
        nightly) args=(-q -f csv -o "$REPORTS") ;;
        *) echo "usage: ${0##*/} [quick|nightly]" >&2; exit 2 ;;
    esac

    mkdir -p "$REPORTS" "${LOG%/*}" "${LOCK%/*}" || exit 2
    if [[ ! -x $HEALTH ]]; then
        log ERROR "exit=2 msg=\"$HEALTH missing or not executable\""
        exit 2
    fi

    # One run at a time: fd 9 holds the lock until this script exits.
    exec 9> "$LOCK"
    if ! flock -n 9; then
        log SKIP "exit=0 msg=\"previous run still active\""
        exit 0
    fi

    start=$SECONDS
    touch "$LAB/run/last-start"
    out=$(timeout --kill-after=10 "$LIMIT" "$HEALTH" "${args[@]}" "$@" 2>&1)
    rc=$?
    dur=$((SECONDS - start))
    report=$(find "$REPORTS" -maxdepth 1 -type f -name 'system-health-*' -newer "$LAB/run/last-start" -printf '%f\n' | sort | tail -n 1)

    case $rc in
        0)   log OK    "exit=0 duration=${dur}s report=${report:-none}" ;;
        3)   log ALERT "exit=3 duration=${dur}s report=${report:-none}"
             grep -E '^Status|^[a-z-]+ +WARNING ' <<< "$out" | sed 's/^/    /' >> "$LOG" ;;
        124|137) log TIMEOUT "exit=$rc limit=${LIMIT}s"; rc=124 ;;
        *)   log ERROR "exit=$rc msg=\"$(head -n 1 <<< "$out")\"" ;;
    esac

    if [[ $MODE == nightly ]]; then
        find "$REPORTS" -maxdepth 1 -type f -name 'system-health-*' -mtime +14 -delete
    fi
    exit "$rc"
    ```

    Install and test:

    ```bash
    install -m 0750 lab25-run-health.sh ~/lab25/bin/
    shellcheck -S style ~/lab25/bin/lab25-run-health.sh && echo "shellcheck clean"
    cd /tmp
    ~/lab25/bin/lab25-run-health.sh quick -d 95;      echo "exit=$?"
    ~/lab25/bin/lab25-run-health.sh quick -d 95 -m 1; echo "exit=$?"
    ~/lab25/bin/lab25-run-health.sh hourly;           echo "exit=$?"
    ~/lab25/bin/lab25-run-health.sh quick -c 0;       echo "exit=$?"
    mkdir -p /tmp/slowlab/bin && printf '#!/bin/sh\nsleep 30\n' > /tmp/slowlab/bin/system-health.sh && chmod +x /tmp/slowlab/bin/system-health.sh
    LAB25_HOME=/tmp/slowlab LAB25_TIMEOUT=3 ~/lab25/bin/lab25-run-health.sh; echo "exit=$?"
    cat /tmp/slowlab/log/health.log; rm -rf /tmp/slowlab
    cat ~/lab25/log/health.log
    ```

    **Expected output (captured):**

    ```text
    shellcheck clean
    exit=0
    exit=3
    usage: lab25-run-health.sh [quick|nightly]
    exit=2
    exit=1
    exit=124
    2026-11-19T16:50:29Z host=ubuntu-lab mode=quick status=TIMEOUT exit=124 limit=3s
    2026-11-19T16:50:09Z host=ubuntu-lab mode=quick status=OK exit=0 duration=0s report=system-health-ubuntu-lab-20261119T165009Z.txt
    2026-11-19T16:50:09Z host=ubuntu-lab mode=quick status=ALERT exit=3 duration=0s report=system-health-ubuntu-lab-20261119T165009Z.txt
        Status               : WARNING
        memory        WARNING  3.6%        >= 1%     used of 15.7 GiB (MemTotal - MemAvailable)
    2026-11-19T16:50:09Z host=ubuntu-lab mode=quick status=ERROR exit=1 msg="system-health.sh: error: -c must be an integer from 1 to 1000"
    ```

    Design notes: `exec 9> "$LOCK"; flock -n 9` keeps the lock for the whole script (released automatically on exit or crash). `touch run/last-start` + `find -newer` identifies the report written by *this* run. `umask 027` keeps reports private to the user and group. Only problem lines go into the log, so a healthy day is 96 short lines.

??? success "Bash solution: Tasks 3 and 4 (cron, overlap)"
    ```bash
    crontab -l > ~/lab25/backup/crontab.$(date -u +%Y%m%dT%H%M%SZ)
    { crontab -l | sed '/lab25-legacy/,+1 s/^/#DISABLED /'
      cat <<EOF
    # lab25: managed health checks (UTC) - owner: ops team
    MAILTO=""
    */15 * * * * $HOME/lab25/bin/lab25-run-health.sh quick >> $HOME/lab25/log/cron-stderr.log 2>&1
    30 2 * * * $HOME/lab25/bin/lab25-run-health.sh nightly >> $HOME/lab25/log/cron-stderr.log 2>&1
    EOF
    } | crontab -
    crontab -l
    # after the next quarter hour:
    journalctl -u cron --since "-20 min" --no-pager | grep lab25-run-health    # or grep CRON /var/log/syslog
    tail -n 1 ~/lab25/log/health.log; ls -1t ~/lab25/reports | head -1
    # Task 4: hold the lock across the next scheduled run (second terminal), then look at the log
    flock ~/lab25/run/health.lock sleep 960 &
    # ... after the next quarter hour:
    tail -n 1 ~/lab25/log/health.log; kill %1
    ```

    The here-document is unquoted, so `$HOME` is expanded **now** and the crontab receives absolute paths (cron would not expand `$HOME` inside `PATH=`, but it would in a command; absolute paths are clearer either way). `sed '/lab25-legacy/,+1 …'` comments out the marker comment and the line after it.

    **Expected output (captured; `* * * * *` and `-d 95` were used in the container to see results within minutes):**

    ```text
    #DISABLED # lab25-legacy: health check copied from the old server
    #DISABLED */15 * * * * cd lab25 && ./bin/system-health.sh -o reports > /dev/null 2>&1; echo "last run $(date +%F)" > last-run.txt
    # lab25: managed health checks (UTC) - owner: ops team
    MAILTO=""
    */15 * * * * /home/student/lab25/bin/lab25-run-health.sh quick >> /home/student/lab25/log/cron-stderr.log 2>&1
    30 2 * * * /home/student/lab25/bin/lab25-run-health.sh nightly >> /home/student/lab25/log/cron-stderr.log 2>&1
    CRON[5587]: (student) CMD ([5588] /home/student/lab25/bin/lab25-run-health.sh quick -d 95 >> /home/student/lab25/log/cron-stderr.log 2>&1)
    2026-11-19T16:52:01Z host=ubuntu-lab mode=quick status=OK exit=0 duration=0s report=system-health-ubuntu-lab-20261119T165201Z.txt
    system-health-ubuntu-lab-20261119T165201Z.txt
    2026-11-19T16:54:02Z host=ubuntu-lab mode=quick status=SKIP exit=0 msg="previous run still active"
    ```

    The nightly mode was also run by hand: it wrote `system-health-ubuntu-lab-20261119T165336Z.csv` and deleted a test report whose modification time had been set to 20 days ago (captured).

??? success "Bash solution: Task 5 (systemd timers)"
    ```ini
    # /etc/systemd/system/lab25-health.service
    [Unit]
    Description=Lab 25 health check (quick, every 15 minutes)

    [Service]
    Type=oneshot
    User=student
    Group=student
    Environment=LAB25_HOME=/home/student/lab25
    ExecStart=/home/student/lab25/bin/lab25-run-health.sh quick
    TimeoutStartSec=5min
    Nice=10
    # hardening: the job only needs to write inside its own lab folder
    NoNewPrivileges=yes
    PrivateTmp=yes
    ProtectSystem=strict
    ReadWritePaths=/home/student/lab25
    ```

    ```ini
    # /etc/systemd/system/lab25-health.timer
    [Unit]
    Description=Run lab25-health.service every 15 minutes

    [Timer]
    OnCalendar=*:0/15
    AccuracySec=1min
    Unit=lab25-health.service

    [Install]
    WantedBy=timers.target
    ```

    `lab25-health-nightly.service` is the same as `lab25-health.service` with `Description=Lab 25 health check (nightly CSV report)` and `ExecStart=… nightly`.

    ```ini
    # /etc/systemd/system/lab25-health-nightly.timer
    [Unit]
    Description=Run lab25-health-nightly.service at 02:30 UTC

    [Timer]
    OnCalendar=*-*-* 02:30:00 UTC
    RandomizedDelaySec=15min
    Persistent=true

    [Install]
    WantedBy=timers.target
    ```

    ```bash
    cd /etc/systemd/system
    sudo systemd-analyze verify lab25-health.service lab25-health.timer lab25-health-nightly.service lab25-health-nightly.timer; echo "rc=$?"
    systemd-analyze calendar '*:0/15' '*-*-* 02:30:00 UTC'
    # on a VM with systemd:
    sudo systemctl daemon-reload
    sudo systemctl enable --now lab25-health.timer lab25-health-nightly.timer
    crontab -l | sed -E '/lab25-run-health/ s/^([^#])/#MOVED-TO-SYSTEMD \1/' | crontab -
    sudo systemctl start lab25-health.service
    systemctl list-timers 'lab25*'
    systemctl status lab25-health.service --no-pager
    journalctl -u lab25-health.service -n 5 --no-pager
    ```

    **Expected output (captured for `verify` and `calendar`; "From now" depends on the time):**

    ```text
    rc=0
      Original form: *:0/15
    Normalized form: *-*-* *:00/15:00
        Next elapse: Thu 2026-11-19 17:30:00 UTC
           From now: 13min left

    Normalized form: *-*-* 02:30:00 UTC
        Next elapse: Fri 2026-11-20 02:30:00 UTC
           From now: 9h left
    ```

    **Expected output on a VM (example):**

    ```text
    NEXT                        LEFT LAST                        PASSED  UNIT                       ACTIVATES
    Thu 2026-11-19 17:15:00 UTC 9min Thu 2026-11-19 17:00:01 UTC 5min ago lab25-health.timer         lab25-health.service
    Fri 2026-11-20 02:38:12 UTC 9h   -                           -       lab25-health-nightly.timer lab25-health-nightly.service

    2 timers listed.
    ○ lab25-health.service - Lab 25 health check (quick, every 15 minutes)
         Loaded: loaded (/etc/systemd/system/lab25-health.service; static)
         Active: inactive (dead) since Thu 2026-11-19 17:06:12 UTC; 2s ago
    TriggeredBy: ● lab25-health.timer
        Process: 2533 ExecStart=/home/student/lab25/bin/lab25-run-health.sh quick (code=exited, status=0/SUCCESS)
       Main PID: 2533 (code=exited, status=0/SUCCESS)
    Nov 19 17:06:12 ubuntu-lab systemd[1]: Starting lab25-health.service - Lab 25 health check (quick, every 15 minutes)...
    Nov 19 17:06:12 ubuntu-lab lab25[2536]: mode=quick status=OK exit=0 duration=0s report=system-health-ubuntu-lab-20261119T170612Z.txt
    Nov 19 17:06:12 ubuntu-lab systemd[1]: lab25-health.service: Deactivated successfully.
    Nov 19 17:06:12 ubuntu-lab systemd[1]: Finished lab25-health.service - Lab 25 health check (quick, every 15 minutes).
    ```

    The `sed` command comments out the two active cron entries so the job does not run twice. Under the service, `systemctl is-active` and the failed-units check of `system-health.sh` work normally (they show `n/a` only in containers). If the service fails with `status=3`, that is an alert, not a broken unit.

??? success "Bash solution: Task 6 (logrotate)"
    ```bash
    sudo tee /etc/logrotate.d/lab25-health >/dev/null <<EOF
    # Lab 25: rotate the health-check logs of $USER
    $HOME/lab25/log/*.log {
        su $USER $(id -gn)
        weekly
        rotate 8
        maxsize 5M
        compress
        delaycompress
        missingok
        notifempty
        create 0640 $USER $(id -gn)
    }
    EOF
    cat /etc/logrotate.d/lab25-health
    sudo logrotate -d /etc/logrotate.d/lab25-health
    ```

    **Expected output (captured, from the `rotating pattern` line on):**

    ```text
    rotating pattern: /home/student/lab25/log/*.log  weekly (8 rotations)
    empty log files are not rotated, log files >= 5242880 are rotated earlier, old logs are removed
    switching euid from 0 to 30035 and egid from 0 to 30036 (pid 6731)
    considering log /home/student/lab25/log/cron-stderr.log
    Creating new state
      Now: 2026-11-19 16:54
      Last rotated at 2026-11-19 16:00
      log does not need rotating (log has already been rotated)
    considering log /home/student/lab25/log/health.log
    Creating new state
      Now: 2026-11-19 16:54
      Last rotated at 2026-11-19 16:00
      log does not need rotating (log has already been rotated)
    switching euid from 30035 to 0 and egid from 30036 to 0 (pid 6731)
    ```

    Debug mode read the configuration, switched to your user (`su`), and only **reported** what it would do. A log seen for the first time counts as just rotated; `sudo logrotate -d -f …` shows a forced rotation plan (`renaming …/health.log to …/health.log.1`, `creating new …/health.log mode = 0640`). The daily `logrotate.timer` (or `/etc/cron.daily/logrotate` without systemd) picks up the drop-in automatically.

??? success "Bash solution: Task 8 (persistence hunt)"
    ```bash
    for u in $(cut -d: -f1 /etc/passwd); do
        sudo crontab -l -u "$u" 2>/dev/null | grep -Ev '^[[:space:]]*(#|$)' | sed "s/^/$u: /"
    done
    grep -Ev '^[[:space:]]*(#|$)' /etc/crontab /etc/cron.d/*
    ls -la /etc/cron.d/ /etc/cron.hourly/ /etc/cron.daily/ /etc/cron.weekly/ /etc/cron.monthly/
    sudo atq
    systemctl list-timers --all --no-pager          # VM with systemd
    find /etc/cron* /var/spool/cron /etc/systemd/system -newermt '-1 day' -type f 2>/dev/null
    # evidence first
    E=~/lab25/evidence
    { echo "# collected $(date -u +%FT%TZ) by $(id -un)"
      ls -l --time-style=+%FT%T /etc/cron.d/lab25-sysupdate /tmp/.lab25-update.sh /tmp/.lab25-beacon
      sha256sum /etc/cron.d/lab25-sysupdate /tmp/.lab25-update.sh
      echo '--- cron.d entry'; cat /etc/cron.d/lab25-sysupdate
      echo '--- script'; cat /tmp/.lab25-update.sh
      echo '--- beacon'; cat /tmp/.lab25-beacon
      echo '--- cron log'; journalctl -u cron --no-pager | grep lab25-update | tail -5
    } > "$E/lab25-sysupdate.txt"
    cp -p /etc/cron.d/lab25-sysupdate /tmp/.lab25-update.sh "$E/"
    # then remove (containment)
    sudo rm -v /etc/cron.d/lab25-sysupdate /tmp/.lab25-update.sh /tmp/.lab25-beacon
    ```

    **Expected output (captured, abridged; hunt run after Task 3):**

    ```text
    student: MAILTO=""
    student: */15 * * * * /home/student/lab25/bin/lab25-run-health.sh quick >> /home/student/lab25/log/cron-stderr.log 2>&1
    student: 30 2 * * * /home/student/lab25/bin/lab25-run-health.sh nightly >> /home/student/lab25/log/cron-stderr.log 2>&1
    /etc/crontab:SHELL=/bin/sh
    …
    /etc/cron.d/lab25-sysupdate:*/5 * * * * student /tmp/.lab25-update.sh >/dev/null 2>&1
    …
    # collected 2026-11-19T16:54:45Z by root
    -rw-r--r-- 1 root    root     81 2026-11-19T16:49:41 /etc/cron.d/lab25-sysupdate
    -rw-rw-r-- 1 student student  21 2026-11-19T16:50:01 /tmp/.lab25-beacon
    -rwxr-xr-x 1 student student 127 2026-11-19T16:49:41 /tmp/.lab25-update.sh
    9392fdcb6ca07985fed986b3cd92d1c7836158e971d0bf36a9618d4cbfc15539  /tmp/.lab25-update.sh
    --- cron.d entry
    # system update helper
    */5 * * * * student /tmp/.lab25-update.sh >/dev/null 2>&1
    --- script
    #!/bin/sh
    # harmless Lab 25 persistence simulation: only records that it ran
    date -u +%Y-%m-%dT%H:%M:%SZ >> /tmp/.lab25-beacon
    --- beacon
    2026-11-19T16:50:01Z
    ```

    The cron log lines for the planted job (captured from syslog in the container; on a VM they are what the `--- cron log` section collects):

    ```text
    CRON[4738]: (student) CMD ([4739] /tmp/.lab25-update.sh >/dev/null 2>&1)
    CRON[4738]: (student) END ([4739] /tmp/.lab25-update.sh >/dev/null 2>&1)
    ```

    (The evidence was collected as root in the container; yours shows your user name. The hash of the `cron.d` file depends on your user name and is therefore not listed.) Finally run `sudo bash ~/lab25-cleanup.sh` (keeps `~/lab25`) or `sudo bash ~/lab25-cleanup.sh --purge`. Captured clean-up output:

    ```text
    crontab for student now has 0 line(s)
    removed '/etc/cron.d/lab25-sysupdate'
    removed '/etc/logrotate.d/lab25-health'
    removed '/tmp/.lab25-update.sh'
    removed '/tmp/.lab25-beacon'
    removed at job 4
    kept /home/student/lab25 (re-run with --purge to delete it)
    ```

    On a VM the script also disables the two timers and removes the unit files (`removed '/etc/systemd/system/lab25-health.service'` …). If you completed Task 8 first, the planted files are already gone and only the remaining items are listed.

??? success "PowerShell solution: Task 7 wrapper (`Lab25-Run-Health.ps1`)"
    ```powershell
    <#
    .SYNOPSIS
        Run System-Health.ps1 from Task Scheduler with locking, one UTC log line per run,
        an Application-log alert on exit 3 and report retention.
    .PARAMETER Mode
        Quick (default, every 15 minutes: text report) or Nightly (CSV report, then delete
        reports older than 14 days).
    .PARAMETER MemoryPercent
        Passed to System-Health.ps1 (default 90). Use 1 to force an alert while testing.
    .PARAMETER DiskPercent
        Passed to System-Health.ps1 (default 90).
    .PARAMETER LabRoot
        Lab folder (default C:\Lab25) with bin\System-Health.ps1, reports\ and log\.
    .NOTES
        Exit codes: 0 OK or skipped (previous run still active) · 2 setup/output problem
        3 threshold breached (alert) · other: passed through from System-Health.ps1.
        Time limit: set -ExecutionTimeLimit on the task (Task Scheduler stops the run).
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Quick', 'Nightly')]
        [string]$Mode = 'Quick',

        [ValidateRange(1, 100)]
        [int]$MemoryPercent = 90,

        [ValidateRange(1, 100)]
        [int]$DiskPercent = 90,

        [ValidateNotNullOrEmpty()]
        [string]$LabRoot = 'C:\Lab25'
    )
    Set-StrictMode -Version Latest

    $health = Join-Path $LabRoot 'bin\System-Health.ps1'
    $reports = Join-Path $LabRoot 'reports'
    $log = Join-Path $LabRoot 'log\health.log'
    $inv = [System.Globalization.CultureInfo]::InvariantCulture

    function Write-RunLog {
        param([string]$Status, [string]$Message)
        $stamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', $inv)
        $line = '{0} host={1} mode={2} status={3} {4}' -f $stamp, $env:COMPUTERNAME, $Mode.ToLowerInvariant(), $Status, $Message
        Add-Content -LiteralPath $log -Value $line -Encoding UTF8
    }

    function Send-Alert {
        param([string]$Type, [int]$Id, [string]$Text)
        # eventcreate creates the Application-log source Lab25Health on first use (needs admin/SYSTEM).
        & eventcreate.exe /T $Type /ID $Id /L APPLICATION /SO Lab25Health /D $Text | Out-Null
    }

    try {
        New-Item -ItemType Directory -Path $reports, (Split-Path $log) -Force -ErrorAction Stop | Out-Null
    } catch {
        exit 2
    }
    if (-not (Test-Path -LiteralPath $health)) {
        Write-RunLog -Status 'ERROR' -Message ('exit=2 msg="{0} missing"' -f $health)
        exit 2
    }

    # One run at a time, machine-wide. The mutex is released when this process ends.
    $mutex = New-Object System.Threading.Mutex($false, 'Global\Lab25Health')
    $locked = $false
    try { $locked = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) {
        Write-RunLog -Status 'SKIP' -Message 'exit=0 msg="previous run still active"'
        $mutex.Dispose()
        exit 0
    }

    $rc = 2
    try {
        $start = Get-Date
        $params = @{ Quiet = $true; OutputPath = $reports; MemoryPercent = $MemoryPercent; DiskPercent = $DiskPercent }
        if ($Mode -eq 'Nightly') { $params.Format = 'Csv' }
        $global:LASTEXITCODE = -1
        $out = & $health @params 2>&1 | Out-String
        $rc = $global:LASTEXITCODE
        $seconds = [int]((Get-Date) - $start).TotalSeconds
        $report = Get-ChildItem -LiteralPath $reports -Filter 'System-Health-*' -File |
            Where-Object LastWriteTime -ge $start.AddSeconds(-1) |
            Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty Name
        if (-not $report) { $report = 'none' }

        switch ($rc) {
            0 { Write-RunLog -Status 'OK' -Message "exit=0 duration=${seconds}s report=$report" }
            3 {
                Write-RunLog -Status 'ALERT' -Message "exit=3 duration=${seconds}s report=$report"
                $warnings = ($out -split "`r?`n") | Where-Object { $_ -match 'WARNING' } | Select-Object -First 10
                $warnings | ForEach-Object { Add-Content -LiteralPath $log -Value "    $_" -Encoding UTF8 }
                Send-Alert -Type 'WARNING' -Id 325 -Text ("Lab25 health ALERT on {0}: {1}" -f $env:COMPUTERNAME, ($warnings -join '; '))
            }
            default {
                $first = (($out -split "`r?`n") | Where-Object { $_ } | Select-Object -First 1)
                Write-RunLog -Status 'ERROR' -Message ('exit={0} msg="{1}"' -f $rc, $first)
                Send-Alert -Type 'ERROR' -Id 326 -Text ("Lab25 health check FAILED on {0} with exit {1}" -f $env:COMPUTERNAME, $rc)
            }
        }
        if ($Mode -eq 'Nightly') {
            Get-ChildItem -LiteralPath $reports -Filter 'System-Health-*' -File |
                Where-Object LastWriteTime -lt (Get-Date).AddDays(-14) | Remove-Item -Force
        }
    } catch {
        Write-RunLog -Status 'ERROR' -Message ('exit=2 msg="{0}"' -f $_.Exception.Message)
        $rc = 2
    } finally {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
    exit $rc
    ```

    The task's `-ExecutionTimeLimit` provides the time limit (Task Scheduler stops the process); the mutex prevents overlap even when someone runs the script by hand while the task runs. `eventcreate` writes to the Application log with source `Lab25Health` (event 325 alert, 326 failure) — the Windows counterpart of `logger -t lab25`. (Reviewed statically; not executed on the release host.)

??? success "PowerShell solution: Tasks 1, 7 and 8"
    ```powershell
    # ---- Task 1: audit ----
    Get-ScheduledTask -TaskPath '\Lab25\' | Select-Object TaskName, State, @{N = 'Run'; E = { "$($_.Actions.Execute) $($_.Actions.Arguments)" }}
    Start-ScheduledTask -TaskPath '\Lab25\' -TaskName 'Legacy-Health'; Start-Sleep -Seconds 10
    Get-ScheduledTaskInfo -TaskPath '\Lab25\' -TaskName 'Legacy-Health' | Select-Object LastRunTime, LastTaskResult
    # Problems: -Command (exit codes lost), relative paths (SYSTEM starts in C:\Windows\System32),
    # output to $null, no -NoProfile/-NonInteractive, no time limit, no log, no alert.

    # ---- Task 7.1: manual run, exactly like the task ----
    Copy-Item .\Lab25-Run-Health.ps1 C:\Lab25\bin\ -Force
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Lab25\bin\Lab25-Run-Health.ps1 -Mode Quick
    "exit=$LASTEXITCODE"; Get-Content C:\Lab25\log\health.log -Tail 2

    # ---- Task 7.2: build and preview the objects ----
    $exe = 'powershell.exe'          # or "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    $argQuick = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Lab25\bin\Lab25-Run-Health.ps1" -Mode Quick'
    $quickAction = New-ScheduledTaskAction -Execute $exe -Argument $argQuick -WorkingDirectory 'C:\Lab25'
    $nightlyAction = New-ScheduledTaskAction -Execute $exe -WorkingDirectory 'C:\Lab25' `
        -Argument '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Lab25\bin\Lab25-Run-Health.ps1" -Mode Nightly'
    $quickTrigger = New-ScheduledTaskTrigger -Daily -At '00:00'
    $quickTrigger.Repetition = (New-ScheduledTaskTrigger -Once -At '00:00' -RepetitionInterval (New-TimeSpan -Minutes 15) `
        -RepetitionDuration (New-TimeSpan -Days 1)).Repetition
    $nightlyTrigger = New-ScheduledTaskTrigger -Daily -At '02:30' -RandomDelay (New-TimeSpan -Minutes 15)
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 1) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $quickAction | Format-List Execute, Arguments, WorkingDirectory
    $quickTrigger | Format-List StartBoundary, @{N = 'Interval'; E = { $_.Repetition.Interval }}, @{N = 'Duration'; E = { $_.Repetition.Duration }}
    $principal | Format-List UserId, LogonType, RunLevel
    $settings | Format-List StartWhenAvailable, MultipleInstances, ExecutionTimeLimit, RestartCount, DisallowStartIfOnBatteries

    # ---- Task 7.3: register ----
    Register-ScheduledTask -TaskName 'Lab25-Health' -TaskPath '\Lab25\' -Action $quickAction -Trigger $quickTrigger `
        -Principal $principal -Settings $settings -Description 'Lab 25 quick health check every 15 minutes'
    Register-ScheduledTask -TaskName 'Lab25-Health-Nightly' -TaskPath '\Lab25\' -Action $nightlyAction -Trigger $nightlyTrigger `
        -Principal $principal -Settings $settings -Description 'Lab 25 nightly CSV health report'

    # ---- Task 7.4: operational log ----
    $opLog = 'Microsoft-Windows-TaskScheduler/Operational'
    $wasEnabled = (Get-WinEvent -ListLog $opLog).IsEnabled; "Operational log enabled before: $wasEnabled"
    if (-not $wasEnabled) { wevtutil sl $opLog /e:true }

    # ---- Task 7.5: run, then force an alert ----
    function Wait-Lab25Task { param([string]$Name)
        Start-Sleep -Seconds 2
        while ((Get-ScheduledTask -TaskPath '\Lab25\' -TaskName $Name).State -eq 'Running') { Start-Sleep -Seconds 2 }
        Get-ScheduledTaskInfo -TaskPath '\Lab25\' -TaskName $Name |
            Select-Object LastRunTime, LastTaskResult, @{N = 'Hex'; E = { '0x{0:X}' -f $_.LastTaskResult }}, NextRunTime }
    (Get-ScheduledTaskInfo -TaskPath '\Lab25\' -TaskName 'Lab25-Health').LastTaskResult      # 267011 = not yet run
    Start-ScheduledTask -TaskPath '\Lab25\' -TaskName 'Lab25-Health'; Wait-Lab25Task 'Lab25-Health'
    $alertAction = New-ScheduledTaskAction -Execute $exe -Argument "$argQuick -MemoryPercent 1" -WorkingDirectory 'C:\Lab25'
    Set-ScheduledTask -TaskPath '\Lab25\' -TaskName 'Lab25-Health' -Action $alertAction | Out-Null
    $since = Get-Date
    Start-ScheduledTask -TaskPath '\Lab25\' -TaskName 'Lab25-Health'; Wait-Lab25Task 'Lab25-Health'
    Get-Content C:\Lab25\log\health.log -Tail 3
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Lab25Health'; StartTime = $since } |
        Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-List
    Get-WinEvent -FilterHashtable @{ LogName = $opLog; Id = 100, 102, 201; StartTime = $since } |
        Where-Object Message -like '*\Lab25\Lab25-Health*' | Sort-Object TimeCreated |
        Select-Object TimeCreated, Id, @{N = 'Message'; E = { ($_.Message -split "`n")[0] }} | Format-List
    Set-ScheduledTask -TaskPath '\Lab25\' -TaskName 'Lab25-Health' -Action $quickAction | Out-Null   # restore

    # ---- Task 7.6: retire the legacy task ----
    Export-ScheduledTask -TaskPath '\Lab25\' -TaskName 'Legacy-Health' | Set-Content C:\Lab25\backup\Legacy-Health.xml
    Unregister-ScheduledTask -TaskPath '\Lab25\' -TaskName 'Legacy-Health' -Confirm:$false

    # ---- Task 8: hunt, evidence, removal ----
    $all = Get-ScheduledTask | Where-Object TaskPath -notlike '\Microsoft\*' |
        Select-Object TaskPath, TaskName, State, @{N = 'RunAs'; E = { $_.Principal.UserId }},
            @{N = 'Triggers'; E = { ($_.Triggers | ForEach-Object { $_.CimClass.CimClassName -replace '^MSFT_Task|Trigger$' }) -join ',' }},
            @{N = 'Action'; E = { ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' ; ' }}
    $all | Format-List
    $all | Export-Csv C:\Lab25\evidence\tasks-$(Get-Date -Format yyyyMMddTHHmmss).csv -NoTypeInformation -Encoding UTF8
    Export-ScheduledTask -TaskPath '\' -TaskName 'Lab25-UpdateCheck' | Set-Content C:\Lab25\evidence\Lab25-UpdateCheck.xml
    Get-FileHash "$env:PUBLIC\lab25-update.ps1" | Format-List Algorithm, Hash, Path
    Get-Item "$env:PUBLIC\lab25-update.ps1", "$env:PUBLIC\lab25-beacon.txt" | Select-Object FullName, CreationTimeUtc, LastWriteTimeUtc
    Copy-Item "$env:PUBLIC\lab25-update.ps1", "$env:PUBLIC\lab25-beacon.txt" C:\Lab25\evidence\
    Get-WinEvent -FilterHashtable @{ LogName = $opLog; Id = 106 } -MaxEvents 20 -ErrorAction SilentlyContinue |
        Where-Object Message -like '*Lab25-UpdateCheck*' | Select-Object TimeCreated, Message
    Unregister-ScheduledTask -TaskPath '\' -TaskName 'Lab25-UpdateCheck' -Confirm:$false
    Remove-Item "$env:PUBLIC\lab25-update.ps1", "$env:PUBLIC\lab25-beacon.txt"
    # clean-up when you are done:  .\Lab25-Cleanup.ps1 -WhatIf ; .\Lab25-Cleanup.ps1 [-Purge]
    ```

    **Expected output (example, abridged):**

    ```text
    TaskName      State Run
    --------      ----- ---
    Legacy-Health Ready powershell.exe -Command .\bin\System-Health.ps1 -OutputPath reports > $null

    LastRunTime          LastTaskResult
    -----------          --------------
    11/19/2026 4:40:12 PM              1

    exit=0
    2026-11-19T16:41:03Z host=WIN11-LAB mode=quick status=OK exit=0 duration=2s report=System-Health-WIN11-LAB-20261119T164101Z.txt

    Execute          : powershell.exe
    Arguments        : -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Lab25\bin\Lab25-Run-Health.ps1" -Mode Quick
    WorkingDirectory : C:\Lab25

    StartBoundary : 2026-11-19T00:00:00+05:30
    Interval      : PT15M
    Duration      : P1D

    UserId    : SYSTEM
    LogonType : ServiceAccount
    RunLevel  : Highest

    StartWhenAvailable         : True
    MultipleInstances          : IgnoreNew
    ExecutionTimeLimit         : PT10M
    RestartCount               : 2
    DisallowStartIfOnBatteries : False

    Operational log enabled before: False
    267011

    LastRunTime    : 11/19/2026 4:43:20 PM
    LastTaskResult : 0
    Hex            : 0x0
    NextRunTime    : 11/19/2026 4:45:00 PM

    LastRunTime    : 11/19/2026 4:44:05 PM
    LastTaskResult : 3
    Hex            : 0x3
    NextRunTime    : 11/19/2026 4:45:00 PM

    2026-11-19T11:13:22Z host=WIN11-LAB mode=quick status=OK exit=0 duration=2s report=System-Health-WIN11-LAB-20261119T111320Z.txt
    2026-11-19T11:14:07Z host=WIN11-LAB mode=quick status=ALERT exit=3 duration=2s report=System-Health-WIN11-LAB-20261119T111405Z.txt
        memory      WARNING  41.7%      >= 1%   used of 15.8 GiB

    TimeCreated      : 11/19/2026 4:44:07 PM
    Id               : 325
    LevelDisplayName : Warning
    Message          : Lab25 health ALERT on WIN11-LAB: memory      WARNING  41.7%      >= 1%   used of 15.8 GiB

    TimeCreated : 11/19/2026 4:44:05 PM
    Id          : 100
    Message     : Task Scheduler started "{6b1e…}" instance of the "\Lab25\Lab25-Health" task for user "NT AUTHORITY\SYSTEM".

    TimeCreated : 11/19/2026 4:44:07 PM
    Id          : 201
    Message     : Task Scheduler successfully completed task "\Lab25\Lab25-Health" , instance "{6b1e…}" , action "powershell.exe" with return code 3.

    TimeCreated : 11/19/2026 4:44:07 PM
    Id          : 102
    Message     : Task Scheduler successfully finished "{6b1e…}" instance of the "\Lab25\Lab25-Health" task for user "NT AUTHORITY\SYSTEM".

    TaskPath : \
    TaskName : Lab25-UpdateCheck
    State    : Ready
    RunAs    : WIN11-LAB\student
    Triggers : Logon
    Action   : powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\Public\lab25-update.ps1"
    ```

    The log times are UTC (the PC is at UTC+05:30); `LastRunTime` and event times are local. Red flags of the planted task: root folder `\` with a vague name and description ("Update helper"), a **hidden** PowerShell window, `-ExecutionPolicy Bypass`, a script in the world-writable `C:\Users\Public`, and a logon trigger (runs every time the user logs on).

??? success "Answers to questions"
    1. cron starts every job in the crontab owner's **home directory**, so `cd lab25` happens to work for this user. It is still wrong because the job depends on an implicit working directory: run the line from another user, from `/etc/cron.d`, or from a script with `cd` elsewhere and it breaks; absolute paths make the job independent of where it starts and readable for reviewers.
    2. cron treats the first unescaped `%` as the end of the command: it changed it into a newline, executed only `cd lab25 && … ; echo "last run $(date +` with `/bin/sh`, and would have fed the rest (`F)" > last-run.txt`) to the command as standard input. The shell saw an unterminated `$(` and quote and failed with a syntax error (exit status 2) **before** running anything. The error message went to standard error, which cron mails to the owner — but there was no mail transfer agent, so cron logged "No MTA installed, discarding output" and dropped it. The only trace was a syslog line nobody read.
    3. A busy lock is normal when a run is slow; it is not a failure of this run, so exit 0 avoids false "failed" alerts every 15 minutes while still logging `SKIP` for anyone who looks. A non-zero code (for example 75, "temporary failure", via `flock -E 75`) is better when the monitoring must notice that runs are being skipped repeatedly — for example if a hung run holds the lock for hours — or for jobs where a skipped run means missing data (a backup).
    4. Exit 3 means "the check worked and found a problem in the system" — notify the team that owns the server (disk full, service down). 1, 2 and 124 mean "the check itself is broken" (bad arguments, output directory, hang) — notify whoever maintains the monitoring. Mixing them either hides broken monitoring behind "alerts" or sends system owners messages about a script bug.
    5. It is useful: `systemctl --failed`, `systemctl status` and any `OnFailure=` handler immediately show that the last check found a problem, and the unit becomes active/inactive again at the next successful run. The downside is that "failed" also appears in generic health dashboards, which may be confusing. `SuccessExitStatus=3` would make systemd treat 3 as success — the unit would look green while the server has a problem, so only use it if alerting comes from the log/journal instead.
    6. The nightly report must run once per day even if the server was off at 02:30 (`Persistent=true` catches up at boot), in UTC so DST never skips or doubles it, and with a random delay so that hundreds of servers do not start reporting at the same second. A missed quick check is irrelevant — the next one is 15 minutes away — and a 15-minute check must run close to its time, so neither catch-up nor a 15-minute random delay makes sense there.
    7. With `-File`, the exit code of the script (`exit 3`) becomes the exit code of `powershell.exe`, which Task Scheduler stores as `LastTaskResult` and in event 201; with `-Command` the script's exit code is not reliably passed through (errors become 1, success 0). `-NonInteractive` makes any prompt (`Read-Host`, a confirmation, a credential request) fail immediately instead of waiting forever for input in a session nobody can see.
    8. New folders directly under `C:\` inherit permissions that let Authenticated Users create and modify files. A task running as **SYSTEM** that executes `C:\Lab25\bin\Lab25-Run-Health.ps1` would then run whatever any local user wrote into that file — a privilege escalation to SYSTEM. Removing inheritance and granting only read/execute to Users closes that path.
    9. Any four: it runs from `/tmp` (world-writable, wiped at reboot), uses a **hidden** file name (`.lab25-update.sh`), has a vague "system update helper" comment that matches no installed package, discards all output, runs frequently (every 5 minutes), was created recently (time stamps) and writes a "beacon" file; on Windows: root task folder, hidden window, `-ExecutionPolicy Bypass`, script in `C:\Users\Public`, logon trigger. Evidence first because deleting the job destroys the contents, hashes and time stamps needed to understand what happened, find other affected systems (search for the same hash) and support an incident report; removal comes after recording, as part of containment.
    10. T1053.003 (Cron), T1053.002 (At), T1053.006 (Systemd Timers) and T1053.005 (Scheduled Task) — all sub-techniques of T1053 Scheduled Task/Job (used for persistence, privilege escalation and execution).

??? success "Clean-up"
    ```bash
    sudo bash ~/lab25-cleanup.sh            # keeps ~/lab25; add --purge to delete it
    crontab -l                              # your original crontab (or "no crontab for …")
    systemctl list-timers 'lab25*'          # 0 timers listed
    ls /etc/cron.d/ /etc/logrotate.d/ | grep lab25    # nothing
    ```

    ```powershell
    .\Lab25-Cleanup.ps1 -WhatIf             # preview (elevated)
    .\Lab25-Cleanup.ps1 -Purge
    Get-ScheduledTask | Where-Object TaskName -like 'Lab25*'          # nothing
    ```

    Delete your snapshot only after you have checked that the clean-up left the system as before.
