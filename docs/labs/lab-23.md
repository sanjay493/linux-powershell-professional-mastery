---
description: "Turn one-off checks into a reusable toolkit: a sourced Bash library with a load guard, a getopts-driven service checker with validation, trap-cleaned temporary files, atomic report writes and exit codes 0/1/2/3, unit tests by sourcing; and a PowerShell script module with advanced functions, pipeline input, comment-based help, try/catch and -WhatIf."
---

# Lab 23: Ops Toolkit

| Field | Value |
|---|---|
| **Lab ID** | LAB-23 |
| **Related lesson** | [Day 23: Functions and Reusable Scripts](../course/module-5/day-23.md) |
| **Difficulty** | Intermediate |
| **Time** | 90–120 minutes |
| **Risk level** | Low. Everything lives in `~/lab23` / `$HOME\lab23`. The only network activity is TCP connections to throwaway listeners on **127.0.0.1** ports 8231 and 8232 that you start and stop yourself (8239 stays closed on purpose). The only deletion (`Remove-StaleReport`) is limited to `*.csv` files inside the lab's `reports` folder and is previewed with `-WhatIf` first. No root/Administrator rights needed. |

## Objective

Your team has five slightly different copies of the same "is the service up?" check, each with its own bugs. Your task is to replace them with a small, reusable **toolkit**:

- **Bash:** a library `lib/opslib.sh` (logging, `die`, `require_cmd`, `is_int_between`, `check_tcp`) and a command-line tool `bin/svc-check.sh` that reads an inventory, checks every service, writes a CSV report and returns an exit code that cron, systemd or CI can act on (Day 25).
- **PowerShell:** a script module `OpsTools` with the advanced functions `Test-TcpPort`, `Invoke-ServiceCheck` and `Remove-StaleReport`, with help, validation, pipeline input, error handling and `-WhatIf`.

You will then **test** the toolkit like a professional: the happy path, every error path, cleanup after interruption, and individual functions in isolation.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS (VM, WSL2 or physical), Bash 5.x, coreutils (`timeout`, `mktemp`), Python 3 (for the throwaway listeners; installed by default), optionally `shellcheck` (`sudo apt install shellcheck`). Normal user.
- **Windows:** Windows 11 with Windows PowerShell 5.1 and/or PowerShell 7.4+. Normal user. The module also works in PowerShell 7 on Linux.
- Ports **8231, 8232 and 8239** on 127.0.0.1 must be free: `ss -ltn | grep -E ':82(31|32|39)\b'` (no output) / `Get-NetTCPConnection -LocalPort 8231,8232,8239 -ErrorAction SilentlyContinue` (no output).

## Initial Conditions

- `~/lab23` / `$HOME\lab23` does **not** exist. If it does, rename it (`mv ~/lab23 ~/lab23.old`).
- Create the folders and the inventory files:

=== "Linux"

    ```bash
    mkdir -p ~/lab23/{lib,bin,reports} && cd ~/lab23
    cat > inventory.txt <<'EOF'
    # name        host       port
    web-frontend  127.0.0.1  8231
    api-backend   127.0.0.1  8232
    metrics       127.0.0.1  8239
    EOF
    grep -v metrics inventory.txt > healthy.txt
    printf 'broken 127.0.0.1\nweird 127.0.0.1 99999\nweb-frontend 127.0.0.1 8231' > messy.txt
    ```

=== "Windows"

    ```powershell
    $lab = Join-Path $HOME 'lab23'
    'OpsTools', 'reports' | ForEach-Object { New-Item -Path (Join-Path $lab $_) -ItemType Directory -Force | Out-Null }
    Set-Location $lab
    @'
    Name,HostName,Port
    web-frontend,127.0.0.1,8231
    api-backend,127.0.0.1,8232
    metrics,127.0.0.1,8239
    '@ | Set-Content -Path .\inventory.csv -Encoding UTF8
    Import-Csv .\inventory.csv | Where-Object Name -ne 'metrics' | Export-Csv .\healthy.csv -NoTypeInformation
    ```

- Save the listener helper from the [Solution](#solution) section (`lab23-services.sh` / `Lab23-Services.ps1`) into the lab folder and read it before running it.

The `messy.txt` file deliberately contains a line with no port, a port out of range and a final line **without a newline**.

## Step-by-Step Instructions

### Task 1 — Write the library

Create `lib/opslib.sh` with these functions and a **load guard** (sourcing the file twice must be harmless):

| Function | Contract |
|---|---|
| `log LEVEL MESSAGE…` | One line on **stderr**: `2026-11-18T16:41:45Z [WARN ] message` (UTC, level upper-case, padded to 5) |
| `die MESSAGE…` | `log error …`, then `exit 1` |
| `require_cmd CMD…` | Status 0 if every command exists; logs each missing one |
| `is_int_between VALUE MIN MAX` | Status 0 only for whole numbers in range (`0443x`, `-1`, empty → non-zero) |
| `check_tcp HOST PORT [TIMEOUT]` | Status 0 if a TCP connection succeeds within TIMEOUT seconds (default 2); prints nothing |

The library must not run anything when it is sourced, and must start with `# shellcheck shell=bash`.

### Task 2 — Write the tool

Create `bin/svc-check.sh`:

- Options with `getopts`: `-f FILE` (default `../inventory.txt` relative to the script), `-t SECONDS` (1–10, default 2), `-o DIR` (write the report into DIR instead of stdout), `-h` (usage with exit codes). Unknown options, missing values and extra arguments → message on stderr and **exit 1**.
- Find the library relative to the script (`BASH_SOURCE`), so the tool works from any directory.
- `check_inventory FILE TIMEOUT` reads `name host port` lines, skips comments and blank lines, **warns and skips** malformed lines (with the line number), handles a last line without a newline, prints `name,host,port,UP|DOWN` rows and returns **3** if anything is down.
- Write the CSV (header `name,host,port,state`) to a `mktemp` file that a `trap … EXIT` always removes; with `-o`, check that DIR is writable (**exit 2** if not) and `mv` the finished file to `DIR/svc-check-YYYYMMDDTHHMMSSZ.csv`.
- Use a `main` function and the **main guard**.

### Task 3 — Test the happy path and the failures

Start the listeners, then run the tool with the full inventory (expect exit 3: `metrics` is down), with `healthy.txt` (exit 0), with `-o reports` (report file created), and with `messy.txt` (two warnings, one row).

### Task 4 — Test every error path and the cleanup

Run: `-t 0`, `-t abc`, `-f nope.txt`, `-q`, `-o` without a value, an extra argument, and `-o` pointing to a directory you cannot write to (create one with `mkdir ro && chmod 555 ro`). Then prove that **no temporary files** are left in `/tmp` after a normal run, a failed run and a run stopped with `kill -TERM`.

### Task 5 — Unit-test functions by sourcing

Without running `main`, source the script in a new Bash process and call `is_int_between` and `check_tcp` directly with good and bad values. Explain why this works.

### Task 6 — Build the PowerShell module

In `OpsTools\OpsTools.psm1` write:

- `Test-TcpPort` — advanced function; `HostName` (alias `ComputerName`) and `Port` (1–65535) accept pipeline input **by property name**; `TimeoutSec` 1–10 (default 2); outputs `[pscustomobject]` with `HostName`, `Port`, `Open`; `Write-Verbose` per check; comment-based help with two examples.
- `Invoke-ServiceCheck` — `-Path` to an inventory CSV (validated with `ValidateScript`), `-OutputPath` folder (optional); imports the CSV inside `try`/`catch` with `-ErrorAction Stop`, pipes it to `Test-TcpPort`, adds `Name` and `State` (`UP`/`DOWN`), writes a timestamped CSV if `-OutputPath` is given, and outputs the objects.
- `Remove-StaleReport` — `SupportsShouldProcess`; deletes `svc-check-*.csv` files older than `-OlderThanDays` (1–365, default 14) in a folder.
- `Export-ModuleMember` for the three functions; a private helper `Get-UtcStamp` that is **not** exported.

Create a manifest with `New-ModuleManifest` (version 1.0.0), import the module, and check `Get-Command -Module OpsTools` and `Get-Help Test-TcpPort -Examples`.

### Task 7 — Use and test the module

1. `Import-Csv .\inventory.csv | Test-TcpPort -Verbose` (pipeline binding by property name).
2. `Invoke-ServiceCheck -Path .\inventory.csv -OutputPath .\reports` and a script-level exit code: 3 if any `State` is `DOWN`, else 0.
3. `Invoke-ServiceCheck -Path .\missing.csv` (validation error) and with a CSV that lacks the `Port` column (your `catch` message).
4. Age a report to 40 days old and run `Remove-StaleReport -Path .\reports -OlderThanDays 30 -WhatIf`, then without `-WhatIf`.

## Commands to Execute

Write the code yourself first; the complete files are in the [Solution](#solution). Useful commands while you work:

| Purpose | Bash | PowerShell |
|---|---|---|
| Start / stop listeners | `./lab23-services.sh start` / `stop` | `.\Lab23-Services.ps1 -Action Start` / `Stop` |
| Lint | `shellcheck -x bin/svc-check.sh lib/opslib.sh` | `Invoke-ScriptAnalyzer -Path .\OpsTools` (if PSScriptAnalyzer is installed) |
| Run | `./bin/svc-check.sh [-f FILE] [-t N] [-o DIR]` | `Invoke-ServiceCheck -Path .\inventory.csv [-OutputPath .\reports]` |
| Exit code | `echo $?` | `$LASTEXITCODE` (after a script) |
| Inspect | `declare -F`, `type check_tcp` | `Get-Command -Module OpsTools`, `Get-Help Test-TcpPort -Full` |
| Temp files left? | <code>ls /tmp/svc-check.* 2&gt;/dev/null &#124; wc -l</code> (expect 0) | `Get-ChildItem ([IO.Path]::GetTempPath()) -Filter 'svc-check*'` |

## Expected Results

The Bash results below were captured on 2026-11-18 by running the solution files exactly as printed in this lab, as a normal user and as root, with Bash 5.2.21 on Ubuntu 24.04.5 (timestamps are from that run). The PowerShell results are **examples**: PowerShell was not available on the release host.

- **Task 3** — full inventory, stdout (exit **3**):

    ```text
    name,host,port,state
    web-frontend,127.0.0.1,8231,UP
    api-backend,127.0.0.1,8232,UP
    metrics,127.0.0.1,8239,DOWN
    2026-11-18T16:41:45Z [WARN ] one or more services DOWN
    ```

    `-f healthy.txt` → two `UP` rows, `[INFO ] all services up`, exit **0**. `-o reports` → `[INFO ] report written: reports/svc-check-20261118T164145Z.csv` and the same exit code as without `-o`. `messy.txt` → `messy.txt:1: skipped malformed line`, `messy.txt:2: skipped malformed line`, one `web-frontend` row (the last line without a newline **was** read), exit **0**.

- **Task 4** — every bad invocation exits **1** with one clear message (`-t must be 1-10, got '0'`, `cannot read inventory: nope.txt`, `unknown option -q (try -h)`, `option -o needs a value (try -h)`, `unexpected argument: …`). The read-only directory gives `output directory not writable: ro` and exit **2** for a normal user. **Root ignores the directory permission bits**, so as root the report is written and the exit code is that of the checks — a reminder to test as the account that will run the job. Temporary files left after normal, failed and `kill -TERM` runs: **0**.

- **Task 5:**

    ```text
    443 ok
    0443x rejected
    8231 up
    8239 down
    ```

- **Task 6/7 (example):** `Get-Command -Module OpsTools` lists exactly `Invoke-ServiceCheck`, `Remove-StaleReport` and `Test-TcpPort`. `Invoke-ServiceCheck` returns three objects, `metrics` with `State = DOWN`, and the script exit code is 3. `Remove-StaleReport … -WhatIf` prints one `What if: Performing the operation "Delete report" on target "…svc-check-old.csv".` line and the file still exists.

## Verification Steps

=== "Bash"

    ```bash
    cd ~/lab23
    shellcheck -x bin/svc-check.sh lib/opslib.sh && echo "ShellCheck clean"
    ./lab23-services.sh start
    ./bin/svc-check.sh -f healthy.txt >/dev/null 2>&1; echo "healthy -> $?"          # 0
    ./bin/svc-check.sh >/dev/null 2>&1;               echo "full    -> $?"          # 3
    ./bin/svc-check.sh -t 99 >/dev/null 2>&1;         echo "bad -t  -> $?"          # 1
    ./bin/svc-check.sh -o reports 2>/dev/null; ls reports/ | tail -1                # svc-check-<UTC>.csv
    (cd / && ~/lab23/bin/svc-check.sh -f ~/lab23/healthy.txt >/dev/null 2>&1; echo "from / -> $?")   # 0
    ls /tmp/svc-check.* 2>/dev/null | wc -l                                         # 0
    bash -c 'source bin/svc-check.sh; declare -F' | grep -c 'declare -f'             # 8 functions defined, main not run
    ./lab23-services.sh stop
    ```

=== "PowerShell"

    ```powershell
    Set-Location $HOME\lab23
    Import-Module .\OpsTools -Force
    (Get-Command -Module OpsTools).Name                                 # three names
    Test-ModuleManifest .\OpsTools\OpsTools.psd1 | Select-Object Name, Version
    Get-Command Get-UtcStamp -ErrorAction SilentlyContinue              # nothing: private
    .\Lab23-Services.ps1 -Action Start; Start-Sleep -Seconds 2
    $r = Invoke-ServiceCheck -Path .\inventory.csv
    ($r | Where-Object State -eq 'DOWN').Name                           # metrics
    (Invoke-ServiceCheck -Path .\healthy.csv | Where-Object State -eq 'DOWN').Count   # 0
    .\Lab23-Services.ps1 -Action Stop
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `source: …/lib/opslib.sh: No such file or directory` | Library path built from the current directory | `here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)` and `source "$here/../lib/opslib.sh"` |
| Every service is `DOWN` | Listeners not running, or started in another WSL/terminal session | `./lab23-services.sh start`; <code>ss -ltn &#124; grep 823</code> |
| `illegal option -- q` printed by Bash **and** your message | Optstring lacks the leading `:` | `getopts ':hf:t:o:'` |
| Last line of `messy.txt` ignored | `while read` without the <code>&#124;&#124; [[ -n $name ]]</code> clause | See the solution's `while` line (Day 22) |
| Read-only directory still gets a report | You are root (permission bits do not apply) | Test as your normal user |
| Temp file left after Ctrl+C on a **background** job | Non-interactive shells start background jobs with SIGINT ignored, so Ctrl+C never reaches them | Stop background jobs with `kill -TERM`; the `EXIT` trap runs |
| `kill` seems to have no effect on a test run | You killed a wrapping subshell (`cd x && bash … &`), not the script | Run `bash script &` directly and kill `$!` |
| `Import-Module : … running scripts is disabled` | Windows execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` after reading Day 19, or test in PowerShell 7 |
| `Test-TcpPort` processes only the last CSV row | No `process` block | Put the body in `process { }` |
| `Cannot bind argument to parameter 'Port' because it is null` | CSV column named differently (`port_number`) | Rename the column or add `[Alias('port_number')]` |
| Function changes are not picked up | Module cached | `Import-Module .\OpsTools -Force` |
| `WARNING: … unapproved verbs` | A function such as `Check-Port` | Use `Test-`, `Invoke-`, `Get-` (`Get-Verb`) |

## Questions

1. Why does `log` write to stderr, and what would break in `svc-check.sh` if it wrote to stdout?
2. Why is the report written to a temporary file and **moved** into place rather than written directly with `>`?
3. Which three signals or events did your cleanup survive, and which one can no script survive?
4. Why does Task 5 work without starting any checks?
5. What is the PowerShell equivalent of each of these Bash pieces: `getopts` validation, `usage`, the `EXIT` trap, `source lib.sh`?
6. Why must `Test-TcpPort` use `ValueFromPipelineByPropertyName` rather than `ValueFromPipeline` for `Import-Csv` input?
7. What would happen in `Invoke-ServiceCheck` without `-ErrorAction Stop` on `Import-Csv` when the file is locked or unreadable?
8. Why do the module functions output objects instead of printing a formatted table?

## Solution

??? success "Listener helpers (`lab23-services.sh`, `Lab23-Services.ps1`)"
    `lab23-services.sh` (Bash):

    ```bash
    #!/usr/bin/env bash
    # lab23-services.sh start|stop - throwaway HTTP listeners on 127.0.0.1:8231 and :8232 for Lab 23
    set -o nounset -o pipefail
    dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    case ${1:-} in
        start)
            for port in 8231 8232; do
                python3 -m http.server "$port" --bind 127.0.0.1 --directory "$dir" >/dev/null 2>&1 &
                echo $! > "$dir/.listener-$port.pid"
            done
            sleep 1
            echo "listeners started on 127.0.0.1:8231 and :8232 (8239 stays closed)"
            ;;
        stop)
            for f in "$dir"/.listener-*.pid; do
                [[ -f $f ]] || continue
                kill "$(cat -- "$f")" 2>/dev/null
                rm -f -- "$f"
            done
            echo "listeners stopped"
            ;;
        *) echo "usage: ${0##*/} start|stop" >&2; exit 1 ;;
    esac
    ```

    `Lab23-Services.ps1` (listeners run as background jobs in your current session and stop by themselves after 15 minutes):

    ```powershell
    # Lab23-Services.ps1 -Action Start|Stop - throwaway TCP listeners on 127.0.0.1 for Lab 23
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('Start', 'Stop')][string]$Action)
    Set-StrictMode -Version Latest
    $listen = {
        param([int]$Port)
        $l = New-Object -TypeName System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback), $Port
        $l.Start()
        try { Start-Sleep -Seconds 900 } finally { $l.Stop() }
    }
    switch ($Action) {
        'Start' {
            foreach ($p in 8231, 8232) { Start-Job -Name "lab23-$p" -ScriptBlock $listen -ArgumentList $p | Out-Null }
            'listeners starting on 127.0.0.1:8231 and :8232 (8239 stays closed)'
        }
        'Stop' {
            Get-Job -Name 'lab23-*' -ErrorAction SilentlyContinue | Stop-Job -PassThru | Remove-Job
            'listeners stopped'
        }
    }
    ```

??? success "Bash solution: `lib/opslib.sh`"
    ```bash
    # shellcheck shell=bash
    # opslib.sh - shared helpers for Lab 23. Source this file; do not execute it.
    [[ -n ${_OPSLIB_LOADED:-} ]] && return 0
    _OPSLIB_LOADED=1

    # log LEVEL MESSAGE... -> timestamped line on stderr (stdout stays clean for data)
    log() {
        local level=${1^^}; shift
        printf '%s [%-5s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$*" >&2
    }

    # die MESSAGE... -> log an error and exit 1 (usage/validation problems)
    die() { log error "$*"; exit 1; }

    # require_cmd CMD... -> status 0 when every command exists
    require_cmd() {
        local c missing=0
        for c in "$@"; do
            command -v -- "$c" >/dev/null 2>&1 || { log error "missing command: $c"; missing=1; }
        done
        return "$missing"
    }

    # is_int_between VALUE MIN MAX -> status 0 when VALUE is a whole number in range
    is_int_between() {
        [[ $1 =~ ^[0-9]+$ ]] && (( 10#$1 >= $2 && 10#$1 <= $3 ))
    }

    # check_tcp HOST PORT TIMEOUT -> status 0 when a TCP connection succeeds
    check_tcp() {
        local host=$1 port=$2 secs=${3:-2}
        # shellcheck disable=SC2016  # $1/$2 are expanded by the inner bash, on purpose
        timeout "$secs" bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" 2>/dev/null
    }
    ```

    `10#$1` forces base 10, so `08` and `09` (which Bash would otherwise read as invalid octal, Day 21) are accepted. Passing `$host`/`$port` as **arguments** to the inner `bash -c` keeps inventory data from being executed as code (Day 22).

??? success "Bash solution: `bin/svc-check.sh`"
    ```bash
    #!/usr/bin/env bash
    # svc-check.sh - check every service in an inventory file and write a CSV report.
    # Usage: svc-check.sh [-h] [-f FILE] [-t SECONDS] [-o DIR]
    # Exit codes: 0 all up, 1 usage/input error, 2 output problem, 3 at least one service down
    set -o nounset -o pipefail

    here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    # shellcheck source-path=SCRIPTDIR source=../lib/opslib.sh
    source "$here/../lib/opslib.sh"

    usage() {
        cat <<USAGE
    Usage: ${0##*/} [-h] [-f FILE] [-t SECONDS] [-o DIR]
      -f FILE     inventory "name host port" (default: ../inventory.txt)
      -t SECONDS  connect timeout 1-10 (default 2)
      -o DIR      write the CSV report into DIR (default: print to stdout)
      -h          help
    Exit codes: 0 all up, 1 usage/input error, 2 output problem, 3 service down
    USAGE
    }

    # check_inventory FILE TIMEOUT -> CSV rows on stdout; status 3 if anything is down
    check_inventory() {
        local file=$1 secs=$2 name host port extra state down=0 lineno=0
        while read -r name host port extra || [[ -n ${name:-} ]]; do
            lineno=$((lineno + 1))
            [[ -z ${name:-} || $name == \#* ]] && continue
            if [[ -z ${port:-} || -n ${extra:-} ]] || ! is_int_between "$port" 1 65535; then
                log warn "$file:$lineno: skipped malformed line"
                continue
            fi
            if check_tcp "$host" "$port" "$secs"; then state=UP; else state=DOWN; down=$((down + 1)); fi
            printf '%s,%s,%s,%s\n' "$name" "$host" "$port" "$state"
        done < "$file"
        (( down == 0 )) || return 3
    }

    main() {
        local file="$here/../inventory.txt" secs=2 outdir="" opt OPTIND=1
        while getopts ':hf:t:o:' opt; do
            case $opt in
                h) usage; return 0 ;;
                f) file=$OPTARG ;;
                t) secs=$OPTARG ;;
                o) outdir=$OPTARG ;;
                :) die "option -$OPTARG needs a value (try -h)" ;;
                \?) die "unknown option -$OPTARG (try -h)" ;;
            esac
        done
        shift $((OPTIND - 1))
        (( $# == 0 ))                || die "unexpected argument: $1"
        [[ -r $file ]]               || die "cannot read inventory: $file"
        is_int_between "$secs" 1 10  || die "-t must be 1-10, got '$secs'"
        require_cmd timeout          || return 1

        local tmp status=0
        tmp=$(mktemp "${TMPDIR:-/tmp}/svc-check.XXXXXX") || { log error "mktemp failed"; return 2; }
        # shellcheck disable=SC2064  # expand $tmp now, when the trap is set
        trap "rm -f -- '$tmp'" EXIT
        { echo "name,host,port,state"; check_inventory "$file" "$secs"; } > "$tmp" || status=$?

        if [[ -z $outdir ]]; then
            cat -- "$tmp"
        else
            [[ -d $outdir && -w $outdir ]] || { log error "output directory not writable: $outdir"; return 2; }
            local report
            report="$outdir/svc-check-$(date -u +%Y%m%dT%H%M%SZ).csv"
            mv -- "$tmp" "$report" || return 2
            log info "report written: $report"
        fi
        if (( status == 0 )); then log info "all services up"; else log warn "one or more services DOWN"; fi
        return "$status"
    }

    if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
        main "$@"
    fi
    ```

    Notes on the design:

    - `{ …; } > "$tmp" || status=$?` keeps the status of `check_inventory` (3) without stopping the script; a group command `{ }` runs in the current shell, so no subshell is involved.
    - The trap string uses double quotes on purpose: `$tmp` is expanded **when the trap is set** (ShellCheck SC2064 is disabled with a reason). Because the path comes from `mktemp`, it contains no quote characters.
    - After a successful `mv`, the `EXIT` trap's `rm -f` finds nothing to delete, which is harmless.
    - `main` uses `return`, and the main guard passes its status out as the script's exit status.

??? success "Bash test commands (Tasks 3–5)"
    ```bash
    cd ~/lab23 && chmod +x bin/svc-check.sh lab23-services.sh
    shellcheck -x -S style bin/svc-check.sh lib/opslib.sh && echo "ShellCheck clean"
    ./lab23-services.sh start

    # Task 3
    ./bin/svc-check.sh; echo "exit $?"
    ./bin/svc-check.sh -f healthy.txt; echo "exit $?"
    ./bin/svc-check.sh -o reports -t 1; echo "exit $?"; ls reports
    ./bin/svc-check.sh -f messy.txt; echo "exit $?"

    # Task 4 - error paths
    for args in "-t 0" "-t abc" "-f nope.txt" "-q" "-o" "extra-arg"; do
        # shellcheck disable=SC2086  # split the test arguments on purpose
        ./bin/svc-check.sh $args; echo "  [$args] -> exit $?"
    done
    mkdir -p ro && chmod 555 ro
    ./bin/svc-check.sh -f healthy.txt -o ro; echo "exit $?"     # 2 as a normal user
    # Task 4 - cleanup after normal, failed and terminated runs
    ./bin/svc-check.sh >/dev/null 2>&1; ./bin/svc-check.sh -f nope.txt 2>/dev/null
    bash -c 'source bin/svc-check.sh; check_tcp() { sleep 3; }; main -t 2' & pid=$!
    sleep 1; echo "during run: $(ls /tmp/svc-check.* 2>/dev/null | wc -l) temp file(s)"
    kill -TERM "$pid"; wait "$pid"; echo "exit $?"
    echo "after: $(ls /tmp/svc-check.* 2>/dev/null | wc -l) temp file(s)"

    # Task 5 - unit tests by sourcing (main guard: nothing runs)
    bash -c 'source bin/svc-check.sh
             is_int_between 443 1 65535 && echo "443 ok"
             is_int_between 0443x 1 65535 || echo "0443x rejected"
             check_tcp 127.0.0.1 8231 1 && echo "8231 up"
             check_tcp 127.0.0.1 8239 1 || echo "8239 down"'
    ./lab23-services.sh stop
    ```

    **Expected output of the cleanup test (captured):**

    ```text
    during run: 1 temp file(s)
    exit 143
    after: 0 temp file(s)
    ```

    Exit status 143 = 128 + 15 (SIGTERM). The `EXIT` trap ran before Bash terminated. In Task 5, the overridden `check_tcp() { sleep 3; }` shows another benefit of the main guard: tests can replace a function (a "stub") before calling `main`.

??? success "PowerShell solution: `OpsTools\OpsTools.psm1` and the manifest"
    ```powershell
    # OpsTools.psm1 - Lab 23 module. Works in Windows PowerShell 5.1 and PowerShell 7.
    Set-StrictMode -Version Latest

    function Get-UtcStamp {
        # private helper (not exported)
        (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    }

    function Test-TcpPort {
        <#
        .SYNOPSIS
        Tests whether TCP ports accept connections (read-only).
        .DESCRIPTION
        Opens a TCP connection to each port with a timeout and outputs one object per port
        with HostName, Port and Open (True/False). Accepts pipeline input by property name,
        for example from Import-Csv.
        .PARAMETER HostName
        Host name or IP address. Alias: ComputerName.
        .PARAMETER Port
        One or more TCP ports (1-65535).
        .PARAMETER TimeoutSec
        Connect timeout in seconds (1-10). Default 2.
        .EXAMPLE
        Test-TcpPort -HostName 127.0.0.1 -Port 8231, 8239
        .EXAMPLE
        Import-Csv .\inventory.csv | Test-TcpPort -Verbose
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
            [Alias('ComputerName')]
            [ValidateNotNullOrEmpty()]
            [string]$HostName,

            [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
            [ValidateRange(1, 65535)]
            [int[]]$Port,

            [ValidateRange(1, 10)]
            [int]$TimeoutSec = 2
        )
        process {
            foreach ($p in $Port) {
                Write-Verbose "checking ${HostName}:$p (timeout ${TimeoutSec}s)"
                $client = New-Object -TypeName System.Net.Sockets.TcpClient
                try {
                    $open = $client.ConnectAsync($HostName, $p).Wait($TimeoutSec * 1000)
                }
                catch {
                    $open = $false      # refused, unreachable or name not resolved
                    Write-Verbose "${HostName}:$p - $($_.Exception.GetBaseException().Message)"
                }
                finally {
                    $client.Close()
                }
                [pscustomobject]@{ HostName = $HostName; Port = $p; Open = [bool]$open }
            }
        }
    }

    function Invoke-ServiceCheck {
        <#
        .SYNOPSIS
        Checks every service in an inventory CSV (Name,HostName,Port) and optionally writes a CSV report.
        .PARAMETER Path
        Inventory CSV file.
        .PARAMETER OutputPath
        Existing folder for the report svc-check-<UTC>.csv. Omit to only output objects.
        .EXAMPLE
        Invoke-ServiceCheck -Path .\inventory.csv -OutputPath .\reports
        .NOTES
        Script callers should exit 3 when any State is DOWN.
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory)]
            [ValidateScript({ if (Test-Path -LiteralPath $_ -PathType Leaf) { $true } else { throw "Inventory not found: $_" } })]
            [string]$Path,

            [ValidateScript({ if (Test-Path -LiteralPath $_ -PathType Container) { $true } else { throw "Folder not found: $_" } })]
            [string]$OutputPath,

            [ValidateRange(1, 10)]
            [int]$TimeoutSec = 2
        )
        try {
            $rows = @(Import-Csv -LiteralPath $Path -ErrorAction Stop)
            foreach ($column in 'Name', 'HostName', 'Port') {
                if ($rows.Count -gt 0 -and -not ($rows[0].PSObject.Properties.Name -contains $column)) {
                    throw "column '$column' missing"
                }
            }
        }
        catch {
            throw "Cannot read inventory ${Path}: $($_.Exception.Message)"
        }

        $results = foreach ($row in $rows) {
            $t = $row | Test-TcpPort -TimeoutSec $TimeoutSec
            [pscustomobject]@{
                Name     = $row.Name
                HostName = $t.HostName
                Port     = $t.Port
                State    = if ($t.Open) { 'UP' } else { 'DOWN' }
            }
        }

        if ($OutputPath) {
            $report = Join-Path -Path $OutputPath -ChildPath ('svc-check-{0}.csv' -f (Get-UtcStamp))
            $results | Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "report written: $report"
        }
        $results
    }

    function Remove-StaleReport {
        <#
        .SYNOPSIS
        Deletes svc-check-*.csv reports older than a number of days. Supports -WhatIf and -Confirm.
        .EXAMPLE
        Remove-StaleReport -Path .\reports -OlderThanDays 30 -WhatIf
        #>
        [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
        param(
            [Parameter(Mandatory)]
            [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
            [string]$Path,

            [ValidateRange(1, 365)]
            [int]$OlderThanDays = 14
        )
        $cutoff = (Get-Date).AddDays(-$OlderThanDays)
        Get-ChildItem -LiteralPath $Path -Filter 'svc-check-*.csv' -File |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            ForEach-Object {
                if ($PSCmdlet.ShouldProcess($_.FullName, 'Delete report')) {
                    Remove-Item -LiteralPath $_.FullName
                }
            }
    }

    Export-ModuleMember -Function Test-TcpPort, Invoke-ServiceCheck, Remove-StaleReport
    ```

    Create the manifest and load the module:

    ```powershell
    Set-Location $HOME\lab23
    New-ModuleManifest -Path .\OpsTools\OpsTools.psd1 -RootModule OpsTools.psm1 -ModuleVersion 1.0.0 `
        -Author 'Lab 23' -Description 'Lab 23 service-check toolkit' `
        -FunctionsToExport Test-TcpPort, Invoke-ServiceCheck, Remove-StaleReport `
        -CmdletsToExport @() -VariablesToExport @() -AliasesToExport @()
    Import-Module .\OpsTools -Force
    Get-Command -Module OpsTools
    Get-Help Test-TcpPort -Examples
    ```

    Save `OpsTools.psm1` as UTF-8 (`Set-Content -Encoding UTF8` or your editor's UTF-8 option). Notes: `@(Import-Csv …)` guarantees an array even for a one-row file; the column check turns a malformed CSV into one clear message; `[bool]$open` normalises the result of `Wait()`; `Export-Csv -NoTypeInformation` is needed in 5.1 and harmless in 7.

??? success "PowerShell test commands (Task 7) and a runner script"
    `Run-ServiceCheck.ps1` gives schedulers an exit code (functions should not call `exit`):

    ```powershell
    # Run-ServiceCheck.ps1 - wrapper with exit codes 0 (all up), 1 (input error), 3 (service down)
    [CmdletBinding()]
    param([string]$Path = (Join-Path $PSScriptRoot 'inventory.csv'), [string]$OutputPath)
    Set-StrictMode -Version Latest
    Import-Module (Join-Path $PSScriptRoot 'OpsTools') -Force
    try {
        $p = @{ Path = $Path }
        if ($OutputPath) { $p.OutputPath = $OutputPath }
        $results = Invoke-ServiceCheck @p -ErrorAction Stop
    }
    catch {
        Write-Error -Message $_.Exception.Message -ErrorAction Continue
        exit 1
    }
    $results | Format-Table -AutoSize | Out-String | Write-Information -InformationAction Continue
    if (@($results | Where-Object State -eq 'DOWN').Count -gt 0) { exit 3 }
    exit 0
    ```

    ```powershell
    Set-Location $HOME\lab23
    .\Lab23-Services.ps1 -Action Start; Start-Sleep -Seconds 2
    Import-Csv .\inventory.csv | Test-TcpPort -Verbose
    .\Run-ServiceCheck.ps1 -OutputPath .\reports; "exit $LASTEXITCODE"
    .\Run-ServiceCheck.ps1 -Path .\healthy.csv;   "exit $LASTEXITCODE"
    .\Run-ServiceCheck.ps1 -Path .\missing.csv;   "exit $LASTEXITCODE"
    'Name,Address' , 'x,127.0.0.1' | Set-Content .\bad.csv
    .\Run-ServiceCheck.ps1 -Path .\bad.csv;       "exit $LASTEXITCODE"
    $old = Get-ChildItem .\reports -Filter 'svc-check-*.csv' | Select-Object -First 1
    Copy-Item $old.FullName .\reports\svc-check-old.csv
    (Get-Item .\reports\svc-check-old.csv).LastWriteTime = (Get-Date).AddDays(-40)
    Remove-StaleReport -Path .\reports -OlderThanDays 30 -WhatIf
    Test-Path .\reports\svc-check-old.csv                  # True
    Remove-StaleReport -Path .\reports -OlderThanDays 30 -Confirm
    .\Lab23-Services.ps1 -Action Stop
    ```

    **Expected output (example, PowerShell 7.4 on Windows):**

    ```text
    VERBOSE: checking 127.0.0.1:8231 (timeout 2s)

    HostName  Port  Open
    --------  ----  ----
    127.0.0.1 8231  True
    VERBOSE: checking 127.0.0.1:8232 (timeout 2s)
    127.0.0.1 8232  True
    VERBOSE: checking 127.0.0.1:8239 (timeout 2s)
    VERBOSE: 127.0.0.1:8239 - No connection could be made because the target machine actively refused it.
    127.0.0.1 8239 False

    Name         HostName  Port State
    ----         --------  ---- -----
    web-frontend 127.0.0.1 8231 UP
    api-backend  127.0.0.1 8232 UP
    metrics      127.0.0.1 8239 DOWN

    exit 3
    ...
    exit 0
    Run-ServiceCheck.ps1: Cannot validate argument on parameter 'Path'. Inventory not found: …\missing.csv
    exit 1
    Run-ServiceCheck.ps1: Cannot read inventory .\bad.csv: column 'HostName' missing
    exit 1
    What if: Performing the operation "Delete report" on target "C:\Users\student\lab23\reports\svc-check-old.csv".
    True
    ```

    The `missing.csv` case fails during parameter validation of `Invoke-ServiceCheck`; that error is terminating inside the wrapper's `try`, so the wrapper still exits 1. The refused-connection message text comes from the operating system and differs on Linux (`Connection refused`).

??? success "Answers to questions"
    1. Callers capture **stdout** as data. If `log` wrote to stdout, the "report written" and "all services up" lines would end up inside the CSV file (they are printed while stdout is redirected to `$tmp`), corrupting the report for every consumer.
    2. A report written with `>` is visible while it is incomplete, and a failure half-way leaves a truncated file that looks valid. `mv` within one filesystem is atomic: readers see either the old state or the complete new file. The temporary file is also removed by the trap on every failure path.
    3. Normal exit, exit after an error (the `die`/`return` paths) and `SIGTERM` (`kill -TERM`, exit 143). `SIGINT` (Ctrl+C) in an interactive terminal works too. Nothing survives `SIGKILL` (`kill -9`): the kernel stops the process without running any handler.
    4. Because of the main guard: when the file is **sourced**, `${BASH_SOURCE[0]}` is the script path but `$0` is the shell (`bash`), so `main` is not called; only the functions are defined.
    5. `getopts` validation → `param()` with `[Parameter(Mandatory)]`, `[ValidateRange()]`, `[ValidateScript()]`; `usage` → comment-based help (`Get-Help`); `EXIT` trap → `try`/`finally` (or `clean {}` in 7.3+); `source lib.sh` → `Import-Module .\OpsTools`.
    6. `Import-Csv` produces objects with `HostName` and `Port` **properties**. By-property-name binding maps each property to the matching parameter. `ValueFromPipeline` would try to bind the whole row object to one parameter (a `[string]` `HostName` would become the text `@{Name=…; HostName=…; Port=…}`).
    7. The error would be non-terminating: `$rows` would be empty, the `catch` would not run, and the function would return **no results** — the wrapper would then exit 0 ("all up") for an inventory it never read. `-ErrorAction Stop` turns that silent false success into a clear failure.
    8. Objects can be filtered (`Where-Object State -eq 'DOWN'`), counted, exported to CSV/JSON (Day 24) and used for the exit code. A formatted table is only text for the screen; `Format-Table` output cannot be exported or tested reliably.

??? success "Clean-up"
    ```bash
    cd ~/lab23 && ./lab23-services.sh stop
    chmod 755 ro                        # so the folder can be deleted
    cd ~ && rm -rI ~/lab23              # or keep it: Day 25 schedules svc-check.sh
    ```

    ```powershell
    Set-Location $HOME\lab23; .\Lab23-Services.ps1 -Action Stop
    Remove-Module OpsTools -ErrorAction SilentlyContinue
    Set-Location $HOME
    Remove-Item -Path $HOME\lab23 -Recurse -WhatIf     # preview first
    Remove-Item -Path $HOME\lab23 -Recurse
    ```
