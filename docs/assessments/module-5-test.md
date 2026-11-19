---
description: "Module 5 test (Days 21–25): 25 questions on variables and input, conditions and loops, functions and reusable scripts, text and data processing, and task scheduling with cron, systemd timers and Task Scheduler in Bash and PowerShell, with a collapsible answer key and a practical scripting-and-scheduling task."
---

# Module 5 Test: Scripting & Automation

| | |
|---|---|
| **Covers** | [Day 21](../course/module-5/day-21.md) – [Day 25](../course/module-5/day-25.md) |
| **Questions** | 25: 15 multiple choice (1 mark each), 7 command-writing (2 marks each), 3 short-answer and practical (3 marks each) |
| **Total** | 38 marks · pass mark 23 (60%) |
| **Time** | 75 minutes, closed book except for built-in help (`man`, `--help`, `Get-Help`) |
| **Environment** | For Part C you need an Ubuntu 24.04 **VM** (or WSL2) where you may edit your own crontab, and/or a Windows 11 lab VM where you may create a scheduled task. Take a snapshot first, back up your crontab before changing it (`crontab -l > ~/crontab.bak`), work only with the names given in the task (`m5test…`) and remove every job and file you create at the end. |

Answer every question before opening the answers. Each answer explains *why*, so use the key to learn, not only to mark. Grade with the table on the [Assessments](index.md#grading-guidance) page.

## Part A — Multiple choice (1 mark each)

**1.** `path=/var/log/nginx/access.log` — which expansion prints `access.log`?

- A. `${path#*/}`
- B. `${path##*/}`
- C. `${path%/*}`
- D. `${path%%/*}`

??? question "Answer and explanation"
    **B.** `##*/` removes the **longest** prefix that ends in `/`, leaving the file name (like `basename`). `#*/` removes only the first `/` (`var/log/nginx/access.log`), `%/*` removes the shortest suffix and leaves the directory (`/var/log/nginx`, like `dirname`), and `%%/*` removes everything from the first `/` (an empty string). (Day 21)

**2.** A wrapper script must pass **all** of its arguments, unchanged, to another command — including arguments that contain spaces, such as `"Shared Docs"`. Which form does that?

- A. `other-cmd $*`
- B. `other-cmd "$*"`
- C. `other-cmd "$@"`
- D. `other-cmd $@`

??? question "Answer and explanation"
    **C.** `"$@"` expands to every positional parameter as a **separate, intact word**. `"$*"` joins them into one word; unquoted `$*` and `$@` are word-split and glob-expanded, so `Shared Docs` becomes two arguments. (Day 21)

**3.** A PowerShell script starts with `Set-StrictMode -Version Latest`. Later it runs `$total = $totl + 1` (a typo). What happens?

- A. `$total` becomes `1`, silently
- B. An error: the variable `$totl` cannot be retrieved because it has not been set
- C. `$total` becomes `$null`
- D. PowerShell corrects the name automatically

??? question "Answer and explanation"
    **B.** Without strict mode an undefined variable is `$null` and the typo silently produces `1`. Strict mode makes reading an unset variable (and, from version 2.0, a non-existent property) an error, so mistakes fail fast instead of producing wrong reports. It is the PowerShell counterpart of Bash `set -o nounset`. (Day 21)

**4.** Which Bash test is a correct **numeric** "greater than 10" check for `$n`?

- A. `[ "$n" > 10 ]`
- B. `[[ $n > 10 ]]`
- C. `[ "$n" -gt 10 ]`
- D. `[ "$n" -gt 10 ] ]`

??? question "Answer and explanation"
    **C.** `-gt` compares integers (so does `(( n > 10 ))`). In `[ ]`, `>` is a **redirection** that creates a file named `10`; in `[[ ]]`, `>` is a **string** comparison, so `9` sorts after `10`. D is a syntax error. (Day 22)

**5.** Why does PowerShell style put `$null` on the **left**: `if ($null -eq $result)`?

- A. It is faster
- B. If `$result` is a collection, `$result -eq $null` filters the collection instead of returning `$true`/`$false`
- C. `$null` on the right is a syntax error
- D. It makes the comparison case-sensitive

??? question "Answer and explanation"
    **B.** With a collection on the left, comparison operators act as filters and return the matching elements, so `@(1, $null, 2) -eq $null` returns an array, not a Boolean, and `if` may take the wrong branch. With `$null` on the left you always get a single Boolean. (Day 22)

**6.** What do `IFS=` and `-r` do in `while IFS= read -r line; do …; done < hosts.txt`?

- A. They make the loop run in a subshell
- B. `IFS=` keeps leading and trailing whitespace; `-r` keeps backslashes literally instead of treating them as escapes
- C. They skip empty lines
- D. They read the file in reverse order

??? question "Answer and explanation"
    **B.** By default `read` trims whitespace (using `IFS`) and interprets backslashes as escapes and line continuations. `IFS= read -r` reads each line exactly as it is in the file — the safe default for processing data. Redirecting the file into the loop (instead of `cat file |`) also keeps the loop in the current shell. (Day 22)

**7.** `/var/log/app/` contains no `.log` files. What does `for f in /var/log/app/*.log; do echo "$f"; done` print in Bash with default options?

- A. Nothing
- B. The literal pattern `/var/log/app/*.log`, once
- C. An error and exit status 2
- D. Every file in `/var/log/app/`

??? question "Answer and explanation"
    **B.** An unmatched glob is left as the literal word, so the loop runs once with a "file" that does not exist. Guard with `[[ -e $f ]] || continue`, or enable `shopt -s nullglob` so the pattern expands to nothing. (Day 22)

**8.** A script uses `while getopts ":c:m:qh" opt; do …`. Which statement is correct?

- A. `-q` and `-h` require arguments
- B. `-c` and `-m` require an argument; the leading `:` selects silent error reporting, so the script handles `:` (missing argument) and `\?` (unknown option) itself
- C. The leading `:` means every option is optional
- D. `getopts` also accepts long options such as `--quiet`

??? question "Answer and explanation"
    **B.** A colon **after** a letter means "takes an argument" (available in `$OPTARG`). A colon at the **start** of the optstring switches `getopts` to silent mode: it prints nothing and sets `opt` to `:` or `?` so your `case` can print a helpful message and exit 1. `getopts` is POSIX and supports only short options. (Day 23)

**9.** What does `$x` contain after this PowerShell code?

```powershell
function Get-Thing { 'a'; Write-Verbose 'b'; return 'c' }
$x = Get-Thing
```

- A. `'c'` only
- B. `'a'` and `'c'`
- C. `'a'`, `'b'` and `'c'`
- D. `'b'` only

??? question "Answer and explanation"
    **B.** Everything a function emits to the **output** stream is returned — the bare `'a'` *and* the `return 'c'`. `Write-Verbose` writes to the verbose stream (stream 4), which is never captured in `$x` and is shown only with `-Verbose`. `return` just ends the function after emitting its value. (Day 23)

**10.** A script declares `param([ValidateRange(1, 100)][int]$Percent = 90)`. What happens with `.\Check.ps1 -Percent 150`?

- A. `$Percent` is silently clamped to 100
- B. Parameter binding fails with a validation error and the script body never runs
- C. The script runs with the default 90
- D. The value is accepted and a warning is printed

??? question "Answer and explanation"
    **B.** Validation attributes run while the parameter is **bound**, before any line of the body executes, so bad input never reaches your logic. That is why the course scripts can rely on `ValidateRange`/`ValidateSet` instead of hand-written checks; called with `powershell.exe -File`, the failure exits with a non-zero code. (Days 21, 23)

**11.** Why must the input be sorted before `uniq -c` when you count IP addresses?

- A. `uniq` only works on numbers
- B. `uniq` collapses only **adjacent** identical lines, so unsorted input gives several partial counts for the same address
- C. `uniq -c` sorts by itself but needs the input to be unique
- D. Sorting is optional; it only changes the order

??? question "Answer and explanation"
    **B.** `uniq` compares each line with the previous one only. `sort | uniq -c | sort -rn` groups identical lines, counts them, then ranks by count. Use `LC_ALL=C sort` when you need byte-order results that are the same on every system. (Day 24)

**12.** `servers.csv` has a header line and the columns `name,os,disk_pct`. What does `awk -F, 'NR > 1 { sum += $3; n++ } END { if (n) printf "%.1f\n", sum / n }' servers.csv` print?

- A. The total of all disk percentages
- B. The average disk percentage of the data rows, with one decimal
- C. The number of servers
- D. The header line followed by the average

??? question "Answer and explanation"
    **B.** `NR > 1` skips the header, `sum += $3; n++` accumulates column 3 and counts rows, and the `END` block prints `sum / n` once all lines are read (`if (n)` avoids dividing by zero on an empty file). This works only while no field contains a quoted comma — for real CSV use `Import-Csv` or a CSV-aware tool. (Day 24)

**13.** What does the crontab entry `30 2 * * 1 /opt/lpm/backup.sh` do?

- A. Runs at 01:30 on the 2nd of every month
- B. Runs at 02:30 every Monday
- C. Runs every 30 minutes on Mondays and Tuesdays
- D. Runs at 02:30 on the 1st of every month

??? question "Answer and explanation"
    **B.** The five fields are **minute, hour, day of month, month, day of week** — minute first. `30 2` is 02:30, and day of week `1` is Monday (0 and 7 are Sunday). Check an expression before you trust it; for systemd timers, `systemd-analyze calendar 'Mon *-*-* 02:30:00'` prints the next elapse time. (Day 25)

**14.** A script works when you run it by hand but fails in cron with `command not found`. What is the most likely cause?

- A. cron runs jobs as root, which cannot find user programs
- B. cron starts jobs with a minimal environment — a short `PATH` (`/usr/bin:/bin`), no login profile, no aliases — so programs in other directories are not found
- C. cron does not support Bash scripts
- D. The script needs `chmod 777`

??? question "Answer and explanation"
    **B.** cron does not read your `.bashrc` or `.profile`. Use absolute paths for commands and files, or set `PATH=` at the top of the crontab (or the script), and capture output while testing (`>> ~/job.log 2>&1`) so you can read the error. Running a user crontab job as root (A) is false: it runs as the crontab's owner. (Day 25)

**15.** A systemd timer has `OnCalendar=*-*-* 06:00:00` and `Persistent=true`. The laptop was switched off at 06:00 and is powered on at 09:10. What happens?

- A. Nothing until 06:00 tomorrow
- B. The service is started soon after boot because a run was missed while the machine was off
- C. The service runs three times to catch up
- D. The timer is disabled because it missed a run

??? question "Answer and explanation"
    **B.** `Persistent=true` stores the last trigger time on disk; at boot, if an elapse was missed, the unit is triggered once immediately. Plain cron has no such catch-up (anacron does it at day granularity). `systemctl list-timers` shows the `LAST` and `NEXT` run of every timer. (Day 25)

## Part B — Command writing (2 marks each)

**16.** Write a Bash function `pct_used` that takes a mount point, prints its space use as a bare number (for `/` with 24% used it prints `24`), and returns status `1` without output when the argument is not an existing directory. Show how a caller stores the value.

??? question "Answer and explanation"
    ```bash
    pct_used() {
        local mp="$1"
        [[ -d "$mp" ]] || return 1
        df --output=pcent -- "$mp" | awk 'NR == 2 { gsub(/[ %]/, ""); print }'
    }
    if used="$(pct_used /)"; then echo "root is ${used}% full"; fi
    ```
    The **data** goes to stdout and the caller captures it with `$( )`; the **verdict** is the return status, tested by `if`. `local` keeps `mp` out of the caller's scope, and `df --output=pcent` avoids guessing columns. 1 mark for the function with `local` and the status, 1 for the text processing and the caller. (Days 23, 24)

**17.** Write a Bash loop that tries `curl -fsS http://127.0.0.1:8080/health` up to 5 times, waiting 2 seconds between attempts, prints `healthy` and stops at the first success, and exits with status 1 after the last failed attempt.

??? question "Answer and explanation"
    ```bash
    for attempt in 1 2 3 4 5; do
        if curl -fsS --max-time 3 http://127.0.0.1:8080/health > /dev/null; then
            echo healthy; exit 0
        fi
        echo "attempt $attempt failed" >&2
        (( attempt < 5 )) && sleep 2
    done
    exit 1
    ```
    `curl -f` turns HTTP errors (4xx/5xx) into a non-zero status, so the command itself is the condition. The loop is **bounded** (never retry forever in an unattended job), errors go to stderr, and `--max-time` stops one attempt from hanging. A `until`/counter loop or exponential back-off (`sleep $((2 ** attempt))`) is equally correct. (Day 22)

**18.** In a combined-format web access log the HTTP status code is field 9. Write one pipeline that prints the five most frequent status codes with their counts, most frequent first.

??? question "Answer and explanation"
    ```bash
    awk '{ print $9 }' access.log | sort | uniq -c | sort -rn | head -n 5
    ```
    `awk` extracts the field (whitespace-separated), `sort | uniq -c` counts identical values, `sort -rn` ranks the counts numerically in descending order, and `head -n 5` keeps the top five. `awk '{ n[$9]++ } END { for (s in n) print n[s], s }' access.log | sort -rn | head -n 5` is an accepted one-`awk` alternative. (Day 24)

**19.** `servers.csv` has the columns `Name,Os,DiskPct`. Write PowerShell that lists the servers with **more than 90%** disk use, highest first, and saves them to `full.csv` without the type-information line in Windows PowerShell 5.1.

??? question "Answer and explanation"
    ```powershell
    Import-Csv .\servers.csv |
        Where-Object { [int]$_.DiskPct -gt 90 } |
        Sort-Object -Property { [int]$_.DiskPct } -Descending |
        Export-Csv -Path .\full.csv -NoTypeInformation -Encoding UTF8
    ```
    `Import-Csv` returns every field as a **string**, so cast with `[int]` — otherwise `'100' -gt 90` and the sort compare text. `-NoTypeInformation` suppresses the `#TYPE` line that 5.1 writes by default (PowerShell 7 omits it already). 1 mark for the numeric filter and sort, 1 for the export. (Day 24)

**20.** Write a PowerShell advanced function `Test-Threshold` with a mandatory `[int]$Value` validated to 0–100 and an optional `[int]$Limit` (default 90, validated 1–100). It writes a verbose message and returns `$true` when `Value` is at or above `Limit`, otherwise `$false`.

??? question "Answer and explanation"
    ```powershell
    function Test-Threshold {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateRange(0, 100)]
            [int]$Value,

            [ValidateRange(1, 100)]
            [int]$Limit = 90
        )
        Write-Verbose "Comparing $Value with limit $Limit"
        $Value -ge $Limit
    }
    Test-Threshold -Value 93 -Verbose     # VERBOSE: Comparing 93 with limit 90 / True
    ```
    `[CmdletBinding()]` makes it an advanced function, so `-Verbose` (and the other common parameters) work. Validation attributes reject bad input before the body runs, and the comparison's Boolean is the only thing written to the output stream. `Test` is an approved verb. (Day 23)

**21.** Write a crontab line that runs `/opt/lpm/system-health.sh -q` every 15 minutes from 08:00 to 17:45 on weekdays, never lets two copies run at once, and appends all output to a daily log file named `/var/log/lpm/health-YYYY-MM-DD.log`. Say what you do before editing the crontab.

??? question "Answer and explanation"
    ```bash
    crontab -l > ~/crontab.bak 2>/dev/null     # back up first (crontab -r has no undo)
    crontab -e
    # m h dom mon dow  command
    */15 8-17 * * 1-5 /usr/bin/flock -n /tmp/lpm-health.lock /opt/lpm/system-health.sh -q >> /var/log/lpm/health-$(date +\%F).log 2>&1
    ```
    `*/15 8-17 * * 1-5` = minutes 0, 15, 30, 45 of hours 8–17, Monday–Friday. `flock -n` exits at once if the previous run still holds the lock. In a crontab `%` is special (it means "newline / standard input"), so it must be written `\%`. Absolute paths avoid cron's minimal `PATH`. The systemd timer equivalent is `OnCalendar=Mon..Fri *-*-* 08..17:00/15:00` — check it with `systemd-analyze calendar`. 1 mark for the schedule fields, 1 for `flock`, `\%` and the backup. (Day 25)

**22.** Write the PowerShell that registers a scheduled task `LPM-Health` running `C:\lpm\System-Health.ps1 -Quiet -OutputPath C:\lpm\health` with `powershell.exe` every day at 06:00, and then shows the result code of its last run.

??? question "Answer and explanation"
    ```powershell
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\lpm\System-Health.ps1 -Quiet -OutputPath C:\lpm\health'
    $trigger = New-ScheduledTaskTrigger -Daily -At '06:00'
    Register-ScheduledTask -TaskName 'LPM-Health' -Action $action -Trigger $trigger
    Start-ScheduledTask -TaskName 'LPM-Health'                      # optional: test it now
    (Get-ScheduledTaskInfo -TaskName 'LPM-Health').LastTaskResult   # 0 = OK, 3 = threshold breached
    ```
    `New-ScheduledTaskAction` and `New-ScheduledTaskTrigger` build the objects and `Register-ScheduledTask` saves the task (in the current user's context unless you pass `-User`/`-Principal`). `-File` makes the script's `exit` code the task's **Last Run Result**, which `Get-ScheduledTaskInfo` reports as `LastTaskResult`: `3` is the script's "alert" code, not a crash; `267011` (0x41303) means the task has not run yet. 1 mark for action and trigger, 1 for registration and the result check. (Day 25)

## Part C — Short answer and practical (3 marks each)

**23.** The course scripts all use the exit codes `0` OK, `1` invalid arguments, `2` output/IO problem and `3` threshold breached, write the report to **stdout** and errors to **stderr**. Explain why this design matters for a script that runs unattended, and how a scheduler or monitoring system should treat each exit code. (1 mark for stdout/stderr separation, 1 for the meaning of the codes, 1 for the scheduler/monitor behaviour.)

??? question "Answer and explanation"
    **Streams:** the report on stdout can be redirected, piped or saved (`-o`) without being mixed with error messages; stderr carries diagnostics that a log or cron mail captures separately, so a broken run is visible even when the report is discarded. **Exit codes:** the status is the machine-readable verdict — no one has to parse text. `0` = ran and everything is fine; `1` = the job is misconfigured (fix the command line, it will never succeed as written); `2` = it ran but could not write its output (permissions, full disk); `3` = it ran correctly and **found a problem** — the alert you scheduled it for. **Treatment:** the scheduler or monitor should alert on `3` as a warning/notification, page or ticket on `1`/`2` as a job failure, and never mark `3` simply as "task failed" and ignore it; in Task Scheduler it appears as Last Run Result `0x3`, in systemd as `status=3` in `systemctl status`/the journal, in cron via mail or your log. With `-q` the scripts stay silent on `0`, so mail arrives only when there is something to do. (Days 23, 25)

**24.** Compare **cron** with **systemd timers** for running a nightly health check. Cover at least: missed runs, logging, overlapping runs and how you verify the schedule. (1 mark per two correct points, up to 3.)

??? question "Answer and explanation"
    | Topic | cron | systemd timer |
    |---|---|---|
    | Missed runs (machine off) | Lost; `anacron` catches up daily/weekly jobs | `Persistent=true` runs a missed elapse once at boot |
    | Logging | Output is mailed (`MAILTO`) or lost unless you redirect `>> log 2>&1`; cron logs only the start | stdout/stderr go to the journal: `journalctl -u name.service`, with the exit status |
    | Overlap | Nothing stops a second copy; wrap with `flock -n` | A timer does not start a service that is still running, so the same unit never overlaps |
    | Environment | Minimal `PATH`, no profile; `%` must be escaped | Defined by the unit (`Environment=`, `User=`); resource limits and sandboxing (`ProtectSystem=`) available |
    | Verify schedule | Read the five fields carefully, `crontab -l`, test with a near-future time | `systemd-analyze calendar 'EXPR'`, `systemctl list-timers`, `systemd-analyze verify` |
    | Setup effort | One line (`crontab -e`) | Two unit files (`.service` + `.timer`), `systemctl daemon-reload`, `systemctl enable --now name.timer` |

    Either is acceptable for a nightly check; timers win where catch-up, journal logging and no-overlap matter, cron where simplicity and portability matter. (Day 25)

**25.** **Practical task.** On your lab VM (snapshot first), using only names beginning `m5test`:

- (a) Create `~/m5test/m5test-app.log` with the seven lines below.
- (b) Write `~/m5test/m5test-errors.sh` that takes `-l LOGFILE` (required) and `-t THRESHOLD` (integer 1–1000, default 3) with `getopts`, prints `-h` help, uses a **function** to count `ERROR` lines per program (text processing), **loops** over the results, prints `ALERT` for every program at or above the threshold and `ok` otherwise, and exits `3` if any program alerted, `1` for invalid input, `0` otherwise.
- (c) Run it with `-t 3` and `-t 5` and with an invalid `-t`, and record the exit codes.
- (d) Schedule it every weekday at 06:00 with `cron` (with `flock` and a log), show the entry, then remove it. Windows: write the PowerShell equivalent `m5test-errors.ps1` and schedule it with `Register-ScheduledTask`, then unregister it.

```text
2026-11-19T06:00:01Z ubuntu-lab nginx[812]: INFO started
2026-11-19T06:01:12Z ubuntu-lab backup[901]: ERROR target /srv/backup not mounted
2026-11-19T06:01:13Z ubuntu-lab backup[901]: ERROR retry 1 failed
2026-11-19T06:01:14Z ubuntu-lab backup[901]: ERROR retry 2 failed
2026-11-19T06:02:00Z ubuntu-lab nginx[812]: ERROR upstream timed out
2026-11-19T06:03:30Z ubuntu-lab cron[640]: INFO job finished
2026-11-19T06:04:45Z ubuntu-lab sshd[1203]: WARNING invalid user admin
```

??? question "Answer and explanation"
    Marking: 1 mark for argument parsing and validation with correct exit codes, 1 for the function, text processing and loop producing the right counts, 1 for a correct, safe schedule (absolute paths, `flock`, backup and removal).

    **Bash solution** (`~/m5test/m5test-errors.sh`):

    ```bash
    #!/usr/bin/env bash
    # m5test-errors.sh - count ERROR lines per program in a log; exit 3 when a program reaches the threshold.
    # Usage: m5test-errors.sh -l LOGFILE [-t THRESHOLD] [-h]
    set -o nounset -o pipefail

    LOGFILE=""
    THRESHOLD=3

    usage() { printf 'Usage: %s -l LOGFILE [-t THRESHOLD 1-1000] [-h]\n' "${0##*/}"; }
    die()   { printf '%s: error: %s\n' "${0##*/}" "$1" >&2; exit "${2:-1}"; }

    # count_errors FILE -> prints "COUNT PROGRAM" lines, highest count first
    count_errors() {
        awk '$4 == "ERROR" { prog = $3; sub(/\[[0-9]+\]:$/, "", prog); sub(/:$/, "", prog); n[prog]++ }
             END { for (p in n) print n[p], p }' "$1" | sort -k1,1nr -k2,2
    }

    while getopts ":l:t:h" opt; do
        case "$opt" in
            l) LOGFILE="$OPTARG" ;;
            t) THRESHOLD="$OPTARG" ;;
            h) usage; exit 0 ;;
            :) die "option -$OPTARG requires an argument" ;;
            \?) die "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ -n "$LOGFILE" ]] || { usage >&2; exit 1; }
    [[ -r "$LOGFILE" ]] || die "cannot read '$LOGFILE'"
    if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || (( 10#$THRESHOLD < 1 || 10#$THRESHOLD > 1000 )); then
        die "-t must be an integer from 1 to 1000"
    fi
    THRESHOLD=$((10#$THRESHOLD))

    status=0
    while read -r count prog; do
        [[ -n "$count" ]] || continue
        if (( count >= THRESHOLD )); then
            printf 'ALERT %-10s %3d errors (threshold %d)\n' "$prog" "$count" "$THRESHOLD"
            status=3
        else
            printf 'ok    %-10s %3d errors\n' "$prog" "$count"
        fi
    done < <(count_errors "$LOGFILE")
    exit "$status"
    ```

    **Expected output (captured):** run on 2026-11-19 in an Ubuntu 24.04.5 container with the script above (which also passes `shellcheck -S style` with no findings); home directory shown as `~`.

    ```text
    $ ./m5test-errors.sh -l ~/m5test/m5test-app.log; echo "exit: $?"
    ALERT backup       3 errors (threshold 3)
    ok    nginx        1 errors
    exit: 3
    $ ./m5test-errors.sh -l ~/m5test/m5test-app.log -t 5; echo "exit: $?"
    ok    backup       3 errors
    ok    nginx        1 errors
    exit: 0
    $ ./m5test-errors.sh -l ~/m5test/m5test-app.log -t abc; echo "exit: $?"
    m5test-errors.sh: error: -t must be an integer from 1 to 1000
    exit: 1
    ```

    Points to notice: the `while … done < <(…)` form keeps `status` in the current shell (a pipe into `while` would lose it — Day 22); the function returns **data** on stdout; `10#` stops `08` being read as octal; `sshd`'s `WARNING` line is not counted.

    **Scheduling (cron)** — back up, add, verify, remove:

    ```bash
    crontab -l > ~/m5test/crontab.bak 2>/dev/null || true
    ( crontab -l 2>/dev/null
      echo "0 6 * * 1-5 /usr/bin/flock -n /tmp/m5test.lock $HOME/m5test/m5test-errors.sh -l $HOME/m5test/m5test-app.log >> $HOME/m5test/m5test-cron.log 2>&1"
    ) | crontab -
    crontab -l | grep m5test            # 0 6 * * 1-5 /usr/bin/flock -n /tmp/m5test.lock /home/student/m5test/...
    # clean up: restore the backup (or crontab -r if you had no crontab before)
    if [ -s ~/m5test/crontab.bak ]; then crontab ~/m5test/crontab.bak; else crontab -r; fi
    rm -rf ~/m5test /tmp/m5test.lock
    ```

    `$HOME` is expanded by your shell when the line is written, so the crontab contains absolute paths. A systemd user timer with `OnCalendar=Mon..Fri *-*-* 06:00:00` and `Persistent=true` is an accepted alternative (`systemd-analyze calendar 'Mon..Fri 06:00'` shows the next run; remove it with `systemctl --user disable --now m5test-errors.timer`).

    **PowerShell solution** (`$HOME\m5test\m5test-errors.ps1`):

    ```powershell
    <#
    .SYNOPSIS
        Counts ERROR lines per program in a log; exits 3 when a program reaches the threshold.
    .EXAMPLE
        .\m5test-errors.ps1 -LogFile $HOME\m5test\m5test-app.log -Threshold 3
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string]$LogFile,

        [ValidateRange(1, 1000)]
        [int]$Threshold = 3
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function Get-ErrorCount {
        param([Parameter(Mandatory)][string]$Path)
        Get-Content -LiteralPath $Path |
            Where-Object { $_ -match '^\S+\s+\S+\s+(?<prog>[^\[\s:]+)(\[\d+\])?:\s+ERROR\b' } |
            ForEach-Object { $Matches['prog'] } |
            Group-Object -NoElement |
            Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false }
    }

    $status = 0
    foreach ($group in Get-ErrorCount -Path $LogFile) {
        if ($group.Count -ge $Threshold) {
            Write-Output ('ALERT {0,-10} {1,3} errors (threshold {2})' -f $group.Name, $group.Count, $Threshold)
            $status = 3
        }
        else {
            Write-Output ('ok    {0,-10} {1,3} errors' -f $group.Name, $group.Count)
        }
    }
    exit $status
    ```

    ```powershell
    # schedule weekdays at 06:00, check, then remove
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$HOME\m5test\m5test-errors.ps1`" -LogFile `"$HOME\m5test\m5test-app.log`""
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday, Tuesday, Wednesday, Thursday, Friday -At '06:00'
    Register-ScheduledTask -TaskName 'm5test-errors' -Action $action -Trigger $trigger
    Start-ScheduledTask -TaskName 'm5test-errors'; Start-Sleep -Seconds 5
    (Get-ScheduledTaskInfo -TaskName 'm5test-errors').LastTaskResult     # 3 with the sample log
    Unregister-ScheduledTask -TaskName 'm5test-errors' -Confirm:$false
    Remove-Item -Recurse -Force $HOME\m5test
    ```

    The PowerShell version was reviewed, not executed (no PowerShell on the release host); its expected output is the same two lines as Bash. Invalid input such as `-Threshold 0` or a missing `-LogFile` file fails parameter validation before the body runs (non-zero exit under `-File`). (Days 21–25)

## After the test

| Score (of 38) | What to do next |
|---|---|
| 34–38 | Distinction. Move on to [Module 6](../course/module-6/index.md). |
| 29–33 | Merit. Re-read the lessons for any questions you missed. |
| 23–28 | Pass. Repeat the labs for the days you lost marks on. |
| < 23 | Repeat Labs 21–25 before starting Module 6. |
