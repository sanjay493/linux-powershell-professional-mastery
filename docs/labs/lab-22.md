---
description: "Write a read-only triage script in Bash and PowerShell that loops over current, rotated and compressed logs, classifies each with case/switch and if/elif thresholds, reads a host inventory line by line, validates entries and checks local TCP ports with bounded retries and backoff, and returns exit code 3 on problems."
---

# Lab 22: Triage Loop

| Field | Value |
|---|---|
| **Lab ID** | LAB-22 |
| **Related lesson** | [Day 22: Conditions and Loops](../course/module-5/day-22.md) |
| **Difficulty** | Intermediate |
| **Time** | 90 minutes |
| **Risk level** | Low. Data lives in `~/lab22` / `$HOME\lab22`. The only network activity is TCP connections to throwaway listeners on **127.0.0.1** ports 8022–8024 that you start and stop yourself. No root/Administrator rights needed. |

## Objective

It is 22:05 and the on-call engineer has been paged: "payments is failing and something on the app host is down". Before anyone logs in to production, the team runs a **triage script** that answers two questions in seconds:

1. Which log files show trouble, and how bad is it? (count ERROR/WARN/INFO per file, including rotated and compressed logs; classify OK / WARNING / CRITICAL)
2. Which services in the inventory are reachable? (validate every entry; check its TCP port with a bounded retry and backoff; classify UP / DOWN / INVALID)

You will write that script in Bash (`triage.sh`) and PowerShell (`Triage.ps1`) using every construct from Day 22: `case`/`switch`, `if`/`elif`, `for`/`foreach`, `while read`/`Get-Content`, `continue`, `break` and retry loops, and finish with an exit code a scheduler can act on (Day 25).

## Required Environment

- **Linux:** Ubuntu 24.04 LTS (VM, WSL2 or physical), Bash 5.x, coreutils (`timeout`), gzip, Python 3 (for the throwaway web listeners; installed by default on Ubuntu). Normal user.
- **Windows:** Windows 11 with Windows PowerShell 5.1 and/or PowerShell 7.4+. Normal user. The PowerShell scripts also run in PowerShell 7 on Linux.
- Ports **8022, 8023 and 8024** on 127.0.0.1 must be free. Check: `ss -ltn | grep ':802[234]'` (no output) / `Get-NetTCPConnection -LocalPort 8022,8023,8024 -ErrorAction SilentlyContinue` (no output).

## Initial Conditions

- `~/lab22` / `$HOME\lab22` does **not** exist (rename an old one: `mv ~/lab22 ~/lab22.old`). The setup script refuses to run if it does.
- Save the setup and service scripts from the [Solution](#solution) section ("Lab setup scripts") into your home directory, read them, then run the setup:

=== "Linux"

    ```bash
    cd ~
    bash lab22-setup.sh
    cp lab22-services.sh ~/lab22/ && cd ~/lab22
    ls -la logs/ && cat inventory.txt
    ```

=== "Windows"

    ```powershell
    Set-Location $HOME
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Lab22-Setup.ps1
    Copy-Item .\Lab22-Services.ps1 $HOME\lab22\ ; Set-Location $HOME\lab22
    Get-ChildItem .\logs ; Get-Content .\inventory.txt
    ```

The data set:

```text
lab22/
├── inventory.txt            name / address / port, with a comment, a blank line and one bad port
└── logs/
    ├── app.log              current log: 1 ERROR, 1 WARN, 2 INFO
    ├── app.log.1            yesterday (rotated): 2 INFO
    ├── app.log.2.gz         compressed: 3 WARN (certificate expiry)
    ├── notes.txt            not a log: must be skipped
    ├── payments.log         6 ERROR + 1 INFO, and NO newline after the last line
    └── web server.log       a space in the file name: 1 WARN, 1 INFO
```

## Step-by-Step Instructions

### Task 1 — Loop over the log files safely

Loop over everything in `logs/`. Use a **glob** with `nullglob` (Bash) or `Get-ChildItem -File` (PowerShell). Print each file name — including `web server.log` — correctly. Run your loop against an empty folder too and confirm it prints nothing rather than `*`.

### Task 2 — Choose a reader with `case` / `switch`

| File name pattern | Action |
|---|---|
| `*.gz` | Read with `zcat` / a `GZipStream` |
| `*.log`, `*.log.[0-9]` | Read as text |
| anything else | Print `skipped (not a log)` and `continue` |

### Task 3 — Count severities per file

Each log line looks like `2026-11-17T21:55:09Z ERROR app: upstream timeout after 30 s`. The second field is the severity. Count `ERROR`, `WARN` and `INFO` for each file. **Do not lose the last line of `payments.log`** (it has no final newline) and do **not** pipe into `while` (the counters would be lost).

### Task 4 — Classify each file

| Condition | Status |
|---|---|
| ERROR ≥ 5 | `CRITICAL` (counts as a problem) |
| ERROR ≥ 1 **or** WARN ≥ 3 | `WARNING` |
| otherwise | `OK` |

Print an aligned table: `FILE ERROR WARN INFO STATUS`.

### Task 5 — Read and validate the inventory

Read `inventory.txt` line by line. Skip blank lines and lines starting with `#`. Split each entry into name, address and port. A port that is not a whole number from 1 to 65535 is `INVALID (bad port)` and counts as a problem — then `continue` with the next entry.

### Task 6 — Check each port with a bounded retry

For each valid entry, try a TCP connection to `address:port` with a **2-second timeout per attempt**, at most **4 attempts**, waiting 1 s, 2 s, 4 s between attempts (exponential backoff). Stop retrying as soon as it connects (`break`). Report `UP (attempt n/4)` or `DOWN (attempt 4/4)`; DOWN counts as a problem.

Start the lab listeners before running your script:

=== "Linux"

    ```bash
    ./lab22-services.sh start ; sleep 2
    ```

=== "Windows"

    ```powershell
    .\Lab22-Services.ps1 -Action Start ; Start-Sleep -Seconds 2
    ```

`web-01` (8022) is up immediately, `cache-01` (8024) starts about 4 seconds later, and `api-01` (8023) never starts.

### Task 7 — Summary and exit code

Print `== Result: N problem(s)` and exit **0** when there are no problems, **3** when any file is CRITICAL or any entry is DOWN/INVALID, and **1** when the lab folder is missing (usage error).

### Task 8 — Prove the healthy path

Comment out `api-01` and `db-01` in the inventory, move `payments.log` out of `logs/`, wait until both listeners are up, and run again: the result must be `0 problem(s)` and exit code 0. Then restore the files and stop the listeners.

## Commands to Execute

=== "Linux"

    ```bash
    cd ~/lab22
    chmod +x triage.sh && bash -n triage.sh && echo "syntax OK"
    ./lab22-services.sh start ; sleep 2
    time ./triage.sh ; echo "exit=$?"
    ./triage.sh /nonexistent ; echo "exit=$?"
    # Task 8 - healthy path
    cp inventory.txt inventory.bak && mv logs/payments.log .
    sed -i 's/^api-01/# api-01/; s/^db-01/# db-01/' inventory.txt
    sleep 3 ; ./triage.sh | tail -4 ; echo "exit=$?"
    mv payments.log logs/ && mv inventory.bak inventory.txt
    ./lab22-services.sh stop
    ```

=== "Windows"

    ```powershell
    Set-Location $HOME\lab22
    .\Lab22-Services.ps1 -Action Start ; Start-Sleep -Seconds 2
    Measure-Command { .\Triage.ps1 | Out-Host } | Select-Object TotalSeconds
    .\Triage.ps1 ; "exit=$LASTEXITCODE"
    .\Triage.ps1 -LabPath C:\nonexistent ; "exit=$LASTEXITCODE"
    # Task 8 - healthy path
    Copy-Item inventory.txt inventory.bak ; Move-Item .\logs\payments.log .
    (Get-Content inventory.txt) -replace '^(api-01|db-01)', '# $1' | Set-Content inventory.txt
    Start-Sleep -Seconds 3 ; .\Triage.ps1 | Select-Object -Last 4 ; "exit=$LASTEXITCODE"
    Move-Item .\payments.log .\logs\ ; Move-Item inventory.bak inventory.txt -Force
    .\Lab22-Services.ps1 -Action Stop
    ```

## Expected Results

The Bash results were captured by running the solution on Ubuntu 24.04.5 (Bash 5.2.21, Python 3 listeners, container). PowerShell output is an **example** of the same layout; timing-dependent attempt numbers can differ by one on a slow machine.

**Bash (captured):**

```text
syntax OK
web-01 (8022) up now; cache-01 (8024) up in about 4 s; api-01 (8023) stays down
== Log files
FILE                    ERROR  WARN  INFO  STATUS
app.log                     1     1     2  WARNING
app.log.1                   0     0     2  OK
app.log.2.gz                0     3     0  WARNING
notes.txt              skipped (not a log)
payments.log                6     0     1  CRITICAL
web server.log              0     1     1  OK
== Inventory
web-01     127.0.0.1       8022   UP (attempt 1/4)
cache-01   127.0.0.1       8024   UP (attempt 3/4)
api-01     127.0.0.1       8023   DOWN (attempt 4/4)
db-01      127.0.0.1       54x2   INVALID (bad port)
== Result: 3 problem(s)
exit=3
ERROR: /nonexistent is not a Lab 22 folder
exit=1
== Inventory
web-01     127.0.0.1       8022   UP (attempt 1/4)
cache-01   127.0.0.1       8024   UP (attempt 1/4)
== Result: 0 problem(s)
exit=0
lab services stopped
```

What to notice:

- `payments.log` shows **1 INFO**: the final line without a newline was counted.
- `cache-01` needed 3 attempts (waits of 1 s and 2 s) — the backoff gave the slow service time to start.
- `api-01` used all 4 attempts (1 + 2 + 4 = 7 s of waiting) and was reported DOWN; the script did **not** stop there, and still checked `db-01`.
- The whole first run took about 8–9 seconds: bounded, even with a dead service.

**PowerShell (example):** the same table and inventory lines, followed by `exit=3`, `ERROR: C:\nonexistent is not a Lab 22 folder`, `exit=1`, and `== Result: 0 problem(s)` / `exit=0` for the healthy path.

## Verification Steps

=== "Linux"

    ```bash
    cd ~/lab22
    ./triage.sh >/dev/null; echo "exit=$?"                         # 3 with the full data set
    ./triage.sh | grep -c 'CRITICAL'                                # 1 (payments.log)
    ./triage.sh | grep 'web server.log'                             # name with a space handled
    grep -n 'nullglob\|< <(\|timeout 2\|break' triage.sh            # safe-loop features present
    mkdir -p /tmp/lab22-empty/logs && touch /tmp/lab22-empty/inventory.txt
    ./triage.sh /tmp/lab22-empty; echo "exit=$?"                    # no '*' line, 0 problems, exit 0
    rmdir /tmp/lab22-empty/logs && rm /tmp/lab22-empty/inventory.txt && rmdir /tmp/lab22-empty
    ```

=== "Windows"

    ```powershell
    Set-Location $HOME\lab22
    .\Triage.ps1 | Out-Null; "exit=$LASTEXITCODE"                  # 3
    @(.\Triage.ps1 | Select-String 'CRITICAL').Count                # 1
    .\Triage.ps1 | Select-String 'web server.log'
    Select-String -Path .\Triage.ps1 -Pattern 'switch -Wildcard', 'TcpClient', 'break' | Select-Object LineNumber, Line
    $empty = Join-Path $env:TEMP 'lab22-empty'
    New-Item -Path "$empty\logs" -ItemType Directory -Force | Out-Null; New-Item -Path "$empty\inventory.txt" -ItemType File -Force | Out-Null
    .\Triage.ps1 -LabPath $empty; "exit=$LASTEXITCODE"              # 0 problems, exit 0
    Remove-Item -Path $empty -Recurse -WhatIf; Remove-Item -Path $empty -Recurse
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| A line `*` or `logs/*` appears in the table | Glob did not match and `nullglob` is off | `shopt -s nullglob` near the top of the script |
| `payments.log` shows INFO 0 | Last line has no newline and the loop ignores it | <code>while read … &#124;&#124; [[ -n ${level:-} ]]</code> (and reset `level` each pass) |
| All counters are 0 | Loop fed by a pipe (<code>zcat f &#124; while …</code>) | Use `done < <("${reader[@]}" "$f")` |
| `web` and `server.log` treated as two files | Unquoted `$f` | Quote every expansion: `"$f"` |
| `zcat: … not in gzip format` | A plain file ends in `.gz`, or `case` order is wrong | Check with `file logs/*`; keep the `*.gz` branch first |
| Every port DOWN | Listeners not started, or ports in use by something else | `./lab22-services.sh start`; <code>ss -ltnp &#124; grep 802</code> |
| Script hangs on one host | No per-attempt timeout | `timeout 2` around the Bash probe; `.Wait(2000)` on `ConnectAsync` |
| `bash: /dev/tcp/…: No such file or directory` | Script run with `sh`, not Bash | Run `./triage.sh` or `bash triage.sh` |
| PowerShell: `The property 'Count' cannot be found` / index errors | `Set-StrictMode` caught a line with too few fields | Validate the split result (`$parts.Count -lt 3`) before indexing |
| PowerShell: `break` stopped the whole script | `break` inside `ForEach-Object` | Use a `foreach` statement for the retry loop, or `return` in `ForEach-Object` |
| A Windows Defender Firewall prompt appears when starting the listeners | Some systems prompt for any new listener | Choose **Cancel**: loopback connections do not need a firewall rule |

## Questions

1. Why does the script use `case` / `switch` to pick a reader, and what happens to `notes.txt`?
2. Why must the `*.gz` branch come before a more general pattern such as `*.log*`?
3. Explain the two traps the Bash severity loop avoids, and what each would have done to the `payments.log` row.
4. Why does the script use `continue` after an INVALID entry instead of `exit`?
5. How long, at most, can one DOWN host delay the script with the settings used? How would you make the whole run faster for 200 hosts?
6. Why is the Bash probe written as `bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$addr" "$port"` instead of `bash -c "exec 3<>/dev/tcp/$addr/$port"`?
7. Which exit codes does the script return, and how would a scheduled job (Day 25) use them?
8. In the PowerShell version, why is the retry loop a `while` statement rather than `1..4 | ForEach-Object { … break … }`?

## Solution

??? success "Lab setup scripts (Bash: `lab22-setup.sh`, `lab22-services.sh`)"
    `lab22-setup.sh`:

    ```bash
    #!/usr/bin/env bash
    # lab22-setup.sh - create the Lab 22 data set under ~/lab22 (no root, no system changes)
    set -o nounset -o pipefail
    lab="$HOME/lab22"
    if [[ -e $lab ]]; then echo "ERROR: $lab already exists; rename it first" >&2; exit 1; fi
    mkdir -p "$lab/logs"
    cd "$lab" || exit 1
    d=2026-11-17
    {
      echo "${d}T21:50:02Z INFO app: request served in 41 ms"
      echo "${d}T21:51:17Z WARN app: slow query 1250 ms"
      echo "${d}T21:52:40Z INFO app: request served in 38 ms"
      echo "${d}T21:55:09Z ERROR app: upstream timeout after 30 s"
    } > logs/app.log
    {
      echo "2026-11-16T22:00:00Z INFO app: rotated"
      echo "2026-11-16T23:10:44Z INFO app: nightly job finished"
    } > logs/app.log.1
    {
      echo "2026-11-15T02:13:00Z WARN app: certificate expires in 14 days"
      echo "2026-11-15T02:14:00Z WARN app: certificate expires in 14 days"
      echo "2026-11-15T02:15:00Z WARN app: certificate expires in 14 days"
    } | gzip > logs/app.log.2.gz
    {
      echo "${d}T21:40:00Z INFO web: started"
      echo "${d}T21:41:12Z WARN web: client sent invalid header"
    } > "logs/web server.log"
    for i in 1 2 3 4 5 6; do
      printf '%sT21:5%d:00Z ERROR payments: card gateway refused connection\n' "$d" "$i"
    done > logs/payments.log
    printf '%sT21:59:30Z INFO payments: retry queue length 42' "$d" >> logs/payments.log   # no final newline
    echo "remember to rotate the certificate" > logs/notes.txt
    cat > inventory.txt <<'INV'
    # name     address     port   (Lab 22 inventory - 127.0.0.1 only)
    web-01     127.0.0.1   8022
    cache-01   127.0.0.1   8024

    api-01     127.0.0.1   8023
    db-01      127.0.0.1   54x2
    INV
    echo "Lab 22 data created in $lab"
    ```

    `lab22-services.sh`:

    ```bash
    #!/usr/bin/env bash
    # lab22-services.sh start|stop - throwaway listeners on 127.0.0.1 for Lab 22
    set -o nounset -o pipefail
    pidfile="$HOME/lab22/.services.pid"
    case "${1:-}" in
      start)
        python3 -m http.server 8022 --bind 127.0.0.1 >/dev/null 2>&1 &
        echo $! > "$pidfile"
        ( sleep 4; exec python3 -m http.server 8024 --bind 127.0.0.1 >/dev/null 2>&1 ) &
        echo $! >> "$pidfile"
        echo "web-01 (8022) up now; cache-01 (8024) up in about 4 s; api-01 (8023) stays down" ;;
      stop)
        [[ -f $pidfile ]] || { echo "nothing to stop"; exit 0; }
        while read -r pid; do kill "$pid" 2>/dev/null; done < "$pidfile"
        pkill -f 'http.server 802[24] --bind 127.0.0.1' 2>/dev/null
        rm -f -- "$pidfile"; echo "lab services stopped" ;;
      *) echo "usage: $0 start|stop" >&2; exit 1 ;;
    esac
    ```

??? success "Lab setup scripts (PowerShell: `Lab22-Setup.ps1`, `Lab22-Services.ps1`)"
    `Lab22-Setup.ps1`:

    ```powershell
    # Lab22-Setup.ps1 - create the Lab 22 data set under $HOME\lab22 (no admin, no system changes)
    Set-StrictMode -Version Latest
    $lab = Join-Path -Path $HOME -ChildPath 'lab22'
    if (Test-Path -Path $lab) { [Console]::Error.WriteLine("ERROR: $lab already exists; rename it first"); exit 1 }
    $logs = Join-Path -Path $lab -ChildPath 'logs'
    New-Item -Path $logs -ItemType Directory -Force | Out-Null
    $d = '2026-11-17'

    Set-Content -Path (Join-Path $logs 'app.log') -Value @(
        "${d}T21:50:02Z INFO app: request served in 41 ms"
        "${d}T21:51:17Z WARN app: slow query 1250 ms"
        "${d}T21:52:40Z INFO app: request served in 38 ms"
        "${d}T21:55:09Z ERROR app: upstream timeout after 30 s"
    )
    Set-Content -Path (Join-Path $logs 'app.log.1') -Value @(
        '2026-11-16T22:00:00Z INFO app: rotated'
        '2026-11-16T23:10:44Z INFO app: nightly job finished'
    )
    # Compressed rotated log (GZipStream works in 5.1 and 7)
    $text  = (1..3 | ForEach-Object { "2026-11-15T02:1$($_ + 2):00Z WARN app: certificate expires in 14 days" }) -join "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text + "`n")
    $fs = [System.IO.File]::Create((Join-Path $logs 'app.log.2.gz'))
    $gz = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $fs, ([System.IO.Compression.CompressionMode]::Compress)
    $gz.Write($bytes, 0, $bytes.Length); $gz.Dispose(); $fs.Dispose()

    Set-Content -LiteralPath (Join-Path $logs 'web server.log') -Value @(
        "${d}T21:40:00Z INFO web: started"
        "${d}T21:41:12Z WARN web: client sent invalid header"
    )
    $pay = Join-Path $logs 'payments.log'
    Set-Content -Path $pay -Value (1..6 | ForEach-Object { "${d}T21:5${_}:00Z ERROR payments: card gateway refused connection" })
    Add-Content -Path $pay -Value "${d}T21:59:30Z INFO payments: retry queue length 42" -NoNewline   # no final newline
    Set-Content -Path (Join-Path $logs 'notes.txt') -Value 'remember to rotate the certificate'

    Set-Content -Path (Join-Path $lab 'inventory.txt') -Value @(
        '# name     address     port   (Lab 22 inventory - 127.0.0.1 only)'
        'web-01     127.0.0.1   8022'
        'cache-01   127.0.0.1   8024'
        ''
        'api-01     127.0.0.1   8023'
        'db-01      127.0.0.1   54x2'
    )
    "Lab 22 data created in $lab"
    ```

    `Lab22-Services.ps1` (listeners run as background jobs in your current session):

    ```powershell
    # Lab22-Services.ps1 -Action Start|Stop - throwaway TCP listeners on 127.0.0.1 for Lab 22
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('Start', 'Stop')][string]$Action)
    Set-StrictMode -Version Latest
    $listen = {
        param([int]$Port, [int]$DelaySeconds)
        Start-Sleep -Seconds $DelaySeconds
        $l = New-Object -TypeName System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback), $Port
        $l.Start()
        try { Start-Sleep -Seconds 900 } finally { $l.Stop() }      # stops by itself after 15 minutes
    }
    switch ($Action) {
        'Start' {
            Start-Job -Name lab22-web   -ScriptBlock $listen -ArgumentList 8022, 0 | Out-Null
            Start-Job -Name lab22-cache -ScriptBlock $listen -ArgumentList 8024, 4 | Out-Null
            'web-01 (8022) up shortly; cache-01 (8024) up about 4 s later; api-01 (8023) stays down'
        }
        'Stop' {
            Get-Job -Name 'lab22-*' -ErrorAction SilentlyContinue | Stop-Job -PassThru | Remove-Job
            'lab services stopped'
        }
    }
    ```

    Jobs belong to the PowerShell session that started them: run `Start` and `Triage.ps1` in the **same** window, and `Stop` before closing it. A background job takes a second or two to start, so give it a moment before the first triage run.

??? success "Bash solution (`triage.sh`)"
    ```bash
    #!/usr/bin/env bash
    # triage.sh - Lab 22: classify log files and check inventory ports (read-only)
    # Usage: ./triage.sh [LAB_DIR]     (default ~/lab22)
    # Exit codes: 0 = all OK/WARNING and UP, 1 = usage or input error, 3 = CRITICAL file or DOWN host
    set -o nounset -o pipefail
    shopt -s nullglob

    lab="${1:-$HOME/lab22}"
    [[ -d $lab/logs && -r $lab/inventory.txt ]] || { echo "ERROR: $lab is not a Lab 22 folder" >&2; exit 1; }
    problems=0

    echo "== Log files"
    printf '%-22s %6s %5s %5s  %s\n' FILE ERROR WARN INFO STATUS
    for f in "$lab"/logs/*; do
      name="${f##*/}"
      case "$name" in
        *.gz)               reader=(zcat --) ;;
        *.log|*.log.[0-9])  reader=(cat --) ;;
        *)                  printf '%-22s %s\n' "$name" "skipped (not a log)"; continue ;;
      esac
      [[ -r $f ]] || { printf '%-22s %s\n' "$name" "UNKNOWN (unreadable)"; problems=$((problems + 1)); continue; }

      err=0 warn=0 info=0
      while read -r _ level _ || [[ -n ${level:-} ]]; do
        case "$level" in
          ERROR) err=$((err + 1)) ;;
          WARN)  warn=$((warn + 1)) ;;
          INFO)  info=$((info + 1)) ;;
        esac
        level=""
      done < <("${reader[@]}" "$f")

      if   (( err >= 5 ));               then status=CRITICAL; problems=$((problems + 1))
      elif (( err >= 1 || warn >= 3 ));  then status=WARNING
      else                                    status=OK
      fi
      printf '%-22s %6d %5d %5d  %s\n' "$name" "$err" "$warn" "$info" "$status"
    done

    echo "== Inventory"
    max=4
    while IFS= read -r line || [[ -n $line ]]; do
      [[ -z ${line//[[:space:]]/} || $line == \#* ]] && continue      # blank or comment
      read -r host addr port _ <<< "$line"
      if [[ ! $port =~ ^[0-9]+$ ]] || (( 10#$port < 1 || 10#$port > 65535 )); then
        printf '%-10s %-15s %-6s %s\n' "$host" "$addr" "$port" "INVALID (bad port)"; problems=$((problems + 1)); continue
      fi
      attempt=1 delay=1 state=DOWN
      while (( attempt <= max )); do
        if timeout 2 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$addr" "$port" 2>/dev/null; then
          state=UP; break
        fi
        (( attempt < max )) && sleep "$delay"
        attempt=$((attempt + 1)); delay=$((delay * 2))
      done
      (( attempt > max )) && attempt=$max
      [[ $state == DOWN ]] && problems=$((problems + 1))
      printf '%-10s %-15s %-6s %s (attempt %d/%d)\n' "$host" "$addr" "$port" "$state" "$attempt" "$max"
    done < "$lab/inventory.txt"

    echo "== Result: $problems problem(s)"
    (( problems == 0 )) && exit 0 || exit 3
    ```

    How the loops work:

    - `shopt -s nullglob` makes `"$lab"/logs/*` expand to nothing in an empty folder, so the `for` loop does not run with a literal `*`.
    - `reader=(zcat --)` stores the command as an **array**, so `"${reader[@]}" "$f"` runs it with the file name as one argument — no `eval`, safe with spaces.
    - `done < <(…)` keeps the counters in the current shell; `|| [[ -n ${level:-} ]]` processes the last line of `payments.log`; `level=""` at the end of each pass stops a stale value from being counted twice at end of file.
    - The `if`/`elif` chain checks the most severe condition first.
    - `[[ -z ${line//[[:space:]]/} || $line == \#* ]] && continue` skips blank (even whitespace-only) and comment lines.
    - The port is validated with a regex before arithmetic, and `10#` avoids the octal trap.
    - `timeout 2 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$addr" "$port"` opens a TCP connection using Bash's built-in `/dev/tcp` feature; the values are passed as **arguments**, never pasted into the code string.
    - The retry loop breaks on success, waits 1 → 2 → 4 s between failures (no wait after the last one), and the script continues with the next host either way.

??? success "PowerShell solution (`Triage.ps1`)"
    ```powershell
    <#
    .SYNOPSIS
        Lab 22: classify log files and check inventory ports (read-only).
    .DESCRIPTION
        Exit codes: 0 = all OK/WARNING and UP, 1 = usage or input error, 3 = CRITICAL file or DOWN/INVALID entry.
    .EXAMPLE
        .\Triage.ps1 -LabPath $HOME\lab22
    #>
    [CmdletBinding()]
    param(
        [string]$LabPath = (Join-Path -Path $HOME -ChildPath 'lab22'),
        [ValidateRange(1, 10)][int]$MaxAttempts = 4
    )
    Set-StrictMode -Version Latest

    function Read-LogLine {
        param([System.IO.FileInfo]$File)
        if ($File.Extension -eq '.gz') {
            $fs = [System.IO.File]::OpenRead($File.FullName)
            $reader = $null
            try {
                $gz = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $fs, ([System.IO.Compression.CompressionMode]::Decompress)
                $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $gz
                while ($null -ne ($line = $reader.ReadLine())) { $line }
            }
            finally {
                if ($null -ne $reader) { $reader.Dispose() }
                $fs.Dispose()
            }
        }
        else {
            Get-Content -LiteralPath $File.FullName
        }
    }

    function Test-TcpPort {
        param([string]$Address, [int]$Port, [int]$TimeoutMs = 2000)
        $client = New-Object -TypeName System.Net.Sockets.TcpClient
        try   { return $client.ConnectAsync($Address, $Port).Wait($TimeoutMs) }
        catch { return $false }                 # refused or unreachable
        finally { $client.Dispose() }
    }

    $logDir    = Join-Path -Path $LabPath -ChildPath 'logs'
    $inventory = Join-Path -Path $LabPath -ChildPath 'inventory.txt'
    if (-not (Test-Path -LiteralPath $logDir -PathType Container) -or -not (Test-Path -LiteralPath $inventory -PathType Leaf)) {
        [Console]::Error.WriteLine("ERROR: $LabPath is not a Lab 22 folder")
        exit 1
    }
    $problems = 0

    '== Log files'
    '{0,-22} {1,6} {2,5} {3,5}  {4}' -f 'FILE', 'ERROR', 'WARN', 'INFO', 'STATUS'
    foreach ($file in Get-ChildItem -LiteralPath $logDir -File | Sort-Object -Property Name) {
        $kind = switch -Wildcard ($file.Name) {
            '*.gz'        { 'gzip'; break }
            '*.log'       { 'text'; break }
            '*.log.[0-9]' { 'text'; break }
            default       { 'skip' }
        }
        if ($kind -eq 'skip') { '{0,-22} {1}' -f $file.Name, 'skipped (not a log)'; continue }

        $count = @{ ERROR = 0; WARN = 0; INFO = 0 }
        try {
            foreach ($line in (Read-LogLine -File $file)) {
                if ($line -cmatch '^\S+\s+(ERROR|WARN|INFO)\b') { $count[$Matches[1]]++ }
            }
        }
        catch {
            '{0,-22} {1}' -f $file.Name, 'UNKNOWN (unreadable)'; $problems++; continue
        }

        if ($count.ERROR -ge 5) { $status = 'CRITICAL'; $problems++ }
        elseif ($count.ERROR -ge 1 -or $count.WARN -ge 3) { $status = 'WARNING' }
        else { $status = 'OK' }
        '{0,-22} {1,6} {2,5} {3,5}  {4}' -f $file.Name, $count.ERROR, $count.WARN, $count.INFO, $status
    }

    '== Inventory'
    foreach ($line in Get-Content -LiteralPath $inventory) {
        if ($line -match '^\s*(#|$)') { continue }                     # comment or blank
        $parts = -split $line
        if ($parts.Count -lt 3) { '{0,-10} {1}' -f $line.Trim(), 'INVALID (too few fields)'; $problems++; continue }
        $name, $address, $portText = $parts[0], $parts[1], $parts[2]

        $port = 0
        if (-not [int]::TryParse($portText, [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
            '{0,-10} {1,-15} {2,-6} {3}' -f $name, $address, $portText, 'INVALID (bad port)'; $problems++; continue
        }

        $attempt = 1; $delay = 1; $state = 'DOWN'
        while ($attempt -le $MaxAttempts) {
            if (Test-TcpPort -Address $address -Port $port) { $state = 'UP'; break }
            if ($attempt -lt $MaxAttempts) { Start-Sleep -Seconds $delay }
            $attempt++; $delay *= 2
        }
        if ($attempt -gt $MaxAttempts) { $attempt = $MaxAttempts }
        if ($state -eq 'DOWN') { $problems++ }
        '{0,-10} {1,-15} {2,-6} {3} (attempt {4}/{5})' -f $name, $address, $port, $state, $attempt, $MaxAttempts
    }

    "== Result: $problems problem(s)"
    if ($problems -eq 0) { exit 0 } else { exit 3 }
    ```

    How the loops work:

    - `switch -Wildcard` with `break` in each branch chooses exactly one reader; `default` sends `notes.txt` to `continue`.
    - `Read-LogLine` streams the decompressed text line by line, so the same `foreach` works for plain and `.gz` files. `Get-Content` handles the missing final newline without special code.
    - `-cmatch` (case-sensitive) and an anchored regex count only real severity fields; `$Matches[1]` is the captured level.
    - Inventory lines are split with the unary `-split` (any whitespace) and checked for field count **before** indexing, which `Set-StrictMode` would otherwise turn into an error.
    - The retry loop is a `while` **statement**, so `break` leaves only the retry loop; the outer `foreach` carries on with the next host.
    - `New-Object` is used instead of `::new()` to keep the script readable for 5.1 users; both work in 5.1 and 7.

??? success "Answers to questions"
    1. The reader depends on the file name pattern, which is exactly what `case`/`switch` matches. `notes.txt` hits the default branch: it is reported as `skipped (not a log)` and the loop `continue`s.
    2. Patterns are tested top to bottom and the first match wins (with `break` in PowerShell). A broad pattern such as `*.log*` placed first would also match `app.log.2.gz` and send compressed data to `cat`.
    3. (a) Piping into `while` would run the loop in a subshell, so `err`/`warn`/`info` would stay 0 in the parent — every row would read `0 0 0 OK`, hiding the payments outage. (b) Without `|| [[ -n … ]]`, the final line without a newline would be ignored: `payments.log` would show INFO 0.
    4. One bad entry should not hide the state of the other services. `continue` records the problem and moves on; the exit code at the end still reports failure.
    5. Up to 4 attempts × 2 s timeout plus 1 + 2 + 4 s of waiting = about 15 s per completely unresponsive (filtered) host; a refused port fails instantly, so `api-01` cost about 7 s. For 200 hosts, check them in **parallel** (Bash background jobs with `wait`, or `xargs -P`; PowerShell 7 `ForEach-Object -Parallel -ThrottleLimit 20`) and/or lower the attempts for a first pass.
    6. Building code from data (`"…/dev/tcp/$addr/$port"`) lets a malicious inventory entry inject commands. Passing values as positional arguments (`$1`, `$2`) keeps them data. It is the loop version of Day 21's "never `eval` input" rule.
    7. 0 = healthy, 1 = usage error (wrong folder), 3 = problems found. A cron job or scheduled task can alert only on 3, and treat 1 as a broken job that the automation owner must fix.
    8. `break` inside a `ForEach-Object` script block does not end just the retry loop: it looks for an enclosing loop — here the inventory `foreach` — and would stop checking every remaining host (or, with no enclosing loop, the whole script). A `while` statement gives `break` its normal, local meaning.

??? success "Clean-up"
    ```bash
    cd ~ && ./lab22/lab22-services.sh stop
    rm -ri ~/lab22            # review each prompt; or keep it for Day 25 scheduling
    ```

    ```powershell
    Set-Location $HOME; & $HOME\lab22\Lab22-Services.ps1 -Action Stop
    Remove-Item -Path $HOME\lab22 -Recurse -WhatIf    # preview first
    Remove-Item -Path $HOME\lab22 -Recurse
    ```
