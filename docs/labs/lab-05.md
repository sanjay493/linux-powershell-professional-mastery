---
description: "NOC scenario: answer questions about a web access log with Bash text pipelines and PowerShell object pipelines, use built-in help only, prove exit-code behaviour, write an OK/ALERT check that exits 0 or 3, and export command history as evidence."
---

# Lab 05: Pipeline Builder

| Field | Value |
|---|---|
| **Lab ID** | LAB-05 |
| **Related lesson** | [Day 05: Command Help, History and Pipelines](../course/module-1/day-05.md) |
| **Difficulty** | Beginner–Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | None to Low. All data is synthetic and stays inside `~/lab05` / `$HOME\lab05`. Nothing is deleted except in the optional clean-up, which is previewed first. No administrator rights are needed. |

## Objective

You are on the night shift in a network operations centre (NOC). The shift lead forwards you an access log from the web server `shop-web01` and asks four questions:

1. How many requests were logged, and which three client IP addresses sent the most?
2. What is the breakdown by HTTP status code?
3. Is anyone hammering the login page (many `401 Unauthorized` responses), and from where?
4. Which path is producing `500 Internal Server Error` responses, and for which client?

Then they ask you to turn question 4 into a **check** that prints `OK` or `ALERT` and returns a proper exit code, so it can later be scheduled (Day 25). Finally, you must attach your command history to the ticket as evidence of what you ran.

You may use **only built-in help** (`man`, `--help`, `help`, `Get-Help`, `Get-Command`, `Get-Member`) to look up options. No web searches.

## Required Environment

- Ubuntu 24.04 LTS (VM, WSL2 or physical) with Bash, as a normal user, **and/or** Windows 11 with Windows PowerShell 5.1 or PowerShell 7 (not elevated). Some steps are marked **PowerShell 7 only**.
- About 1 MB of free disk space.
- For the PowerShell check script: an execution policy that allows local scripts, set as described in [Windows Setup](../getting-started/windows-setup.md) (`RemoteSigned` for the current user). Do **not** change the machine-wide policy for this lab.
- Days 03–05 completed.

## Initial Conditions

- `~/lab05` / `$HOME\lab05` must **not** exist. Check with `ls -d ~/lab05` / `Test-Path $HOME\lab05`. If it exists from an earlier attempt, rename it (`mv ~/lab05 ~/lab05.old` / `Rename-Item $HOME\lab05 lab05.old`).
- Create the log with the generator for your shell. Both produce the same 240 lines. The IP addresses come from documentation ranges (`203.0.113.0/24`, `198.51.100.0/24`) and private space (`10.0.0.0/8`).

=== "Bash"

    ```bash
    mkdir -p ~/lab05 && cd ~/lab05
    for i in $(seq 1 240); do
      if   [ $((i % 4)) -eq 0 ]; then ip=203.0.113.50; p=/login; c=401
      elif [ $((i % 9)) -eq 0 ]; then ip=198.51.100.7; p=/api/orders; c=500
      elif [ $((i % 11)) -eq 0 ]; then ip=203.0.113.77; p=/admin; c=404
      elif [ $((i % 2)) -eq 0 ]; then ip=10.0.0.5; p=/api/orders; c=200
      else ip=10.0.0.8; p=/static/app.js; c=200
      fi
      printf '%s - - [09/Nov/2026:10:%02d:%02d +0530] "GET %s HTTP/1.1" %s %d\n' \
        "$ip" $((i / 60)) $((i % 60)) "$p" "$c" $(( (i * 37) % 5000 + 120 ))
    done > access.log
    wc -l access.log
    ```

=== "PowerShell"

    ```powershell
    New-Item -ItemType Directory -Path $HOME\lab05 | Out-Null
    Set-Location $HOME\lab05
    $lines = foreach ($i in 1..240) {
        if     ($i % 4  -eq 0) { $ip = '203.0.113.50'; $p = '/login';         $c = 401 }
        elseif ($i % 9  -eq 0) { $ip = '198.51.100.7'; $p = '/api/orders';    $c = 500 }
        elseif ($i % 11 -eq 0) { $ip = '203.0.113.77'; $p = '/admin';         $c = 404 }
        elseif ($i % 2  -eq 0) { $ip = '10.0.0.5';     $p = '/api/orders';    $c = 200 }
        else                   { $ip = '10.0.0.8';     $p = '/static/app.js'; $c = 200 }
        $minute = [int](($i - ($i % 60)) / 60)
        '{0} - - [09/Nov/2026:10:{1:D2}:{2:D2} +0530] "GET {3} HTTP/1.1" {4} {5}' -f `
            $ip, $minute, ($i % 60), $p, $c, (($i * 37) % 5000 + 120)
    }
    Set-Content -Path .\access.log -Value $lines -Encoding ASCII
    (Get-Content .\access.log).Count
    ```

Both should report **240** lines. The first line must be:

```text
10.0.0.8 - - [09/Nov/2026:10:00:01 +0530] "GET /static/app.js HTTP/1.1" 200 157
```

Field positions (space-separated): 1 = client IP, 4–5 = timestamp, 7 = path, 9 = status code, 10 = bytes. In PowerShell `-split` arrays are zero-based, so these are indexes 0, 3–4, 6, 8 and 9.

## Step-by-Step Instructions

1. **Help first.** Using built-in help only, find and note: the `sort` options for numeric and reverse order; the `uniq` option that prefixes counts; the `cut` options for the delimiter and field; the `Sort-Object` parameter for descending order; the `Group-Object` switch that omits the grouped items; and the `Measure-Object` parameter that adds up a property. Also run `type -a cut sort` and `Get-Command Group-Object, sort` and note what each name is.
2. **Total and top talkers.** Count the requests, then list the three client IPs with the most requests, highest first.
3. **Status breakdown.** Count requests per status code, highest first.
4. **Brute-force suspect.** Show which IP received the `401` responses, how many, and the time of the first and last one.
5. **Server errors.** Find which path and client produced the `500` responses, and how many.
6. **Bytes served.** Calculate the total of the bytes column. (Bash: `awk` is previewed here and taught on Day 24.)
7. **Exit codes.** Demonstrate and record:
    - Bash: the exit status of `grep -q` for a match, no match and a missing file; `${PIPESTATUS[@]}` for `grep ' 418 ' access.log | wc -l`; the same pipeline's `$?` with and without `set -o pipefail` (run the `pipefail` part in a subshell: `( set -o pipefail; … )`, so that your interactive shell is unchanged).
    - PowerShell: `$?` after `Get-Item` on an existing and a missing file; `$?` and `$LASTEXITCODE` after `ping.exe -n 1 127.0.0.1` (Windows) or `ping -c 1 127.0.0.1` (PowerShell 7 on Linux); a `try`/`catch` that reads a missing file with `-ErrorAction Stop`.
8. **Chaining.** Create `~/lab05/reports` and change into it in one line that only changes directory if the creation succeeded. In PowerShell write a version that works in **5.1** (with `if ($?)`) and, if you have it, a **PowerShell 7** version with `&&`.
9. **The check.** Write `check-5xx.sh` / `Check-5xx.ps1` that:
    - takes a log path (default `~/lab05/access.log`) and a threshold (default `10`),
    - exits **2** with an `UNKNOWN` message on standard error if the log cannot be read,
    - prints `ALERT: <n> server errors …` and exits **3** if the number of `5xx` responses is greater than the threshold,
    - otherwise prints `OK: …` and exits **0**.

    Run it with the default threshold, with threshold `50`, and with a missing file, and record the exit code each time. Then use it in a chain: `./check-5xx.sh || echo "paging on-call"`.
10. **Evidence.** Save your last 40 commands to `~/lab05/reports/lab05-history.txt` (Bash) / `$HOME\lab05\reports\lab05-history.csv` (PowerShell, with `Id`, `CommandLine` and start time). Check the file does not contain any password or secret.

## Commands to Execute

Try each step yourself first. The full commands are in the [Solution](#solution). Key building blocks:

| Purpose | Bash | PowerShell |
|---|---|---|
| Field 1 / property `IP` | `cut -d' ' -f1` | `($_ -split ' ')[0]` → `[pscustomobject]` |
| Count and rank | <code>sort &#124; uniq -c &#124; sort -rn &#124; head -n 3</code> | <code>Group-Object IP &#124; Sort-Object Count -Descending &#124; Select-Object -First 3</code> |
| Filter | `grep ' 401 '` | `Where-Object Status -eq 401` |
| Sum | `awk '{ s += $10 } END { print s }'` | `Measure-Object Bytes -Sum` |
| Status of last command | `echo $?` | `$?` · `$LASTEXITCODE` |
| History | `history 40` | `Get-History -Count 40` |

## Expected Results

| Question | Answer |
|---|---|
| Total requests | 240 |
| Top three clients | `10.0.0.8` (97), `203.0.113.50` (60), `10.0.0.5` (49) |
| Status codes | `200` 146 · `401` 60 · `500` 20 · `404` 14 |
| Brute-force suspect | `203.0.113.50`: 60 × `401` on `/login`, from `10:00:04` to `10:04:00` |
| Server errors | 20 × `500` on `/api/orders`, all from `198.51.100.7` |
| Bytes served | 573840 |
| `grep -q` exit codes | match 0 · no match 1 · missing file 2 |
| `PIPESTATUS` for <code>grep ' 418 ' access.log &#124; wc -l</code> | `1 0`; `$?` = 0 without `pipefail`, 1 with it |
| Check, threshold 10 | `ALERT: 20 server errors …`, exit 3 |
| Check, threshold 50 | `OK: 20 server errors …`, exit 0 |
| Check, missing file | `UNKNOWN: cannot read …` on stderr, exit 2 |

Expected output of the Bash check (generated by running the solution script on Ubuntu 24.04 in a container):

```text
ALERT: 20 server errors in access.log (threshold 10)
exit=3
OK: 20 server errors in access.log (threshold 50)
exit=0
UNKNOWN: cannot read nope.log
exit=2
ALERT: 20 server errors in access.log (threshold 10)
paging on-call (exit 3)
```

## Verification Steps

=== "Bash"

    ```bash
    cd ~/lab05
    wc -l < access.log                                          # expect 240
    cut -d' ' -f1 access.log | sort | uniq -c | sort -rn | head -n 1   # expect 97 10.0.0.8
    grep -c ' 401 ' access.log                                  # expect 60
    ./check-5xx.sh access.log 10; echo $?                       # expect ALERT ... and 3
    ./check-5xx.sh access.log 50; echo $?                       # expect OK ... and 0
    ./check-5xx.sh /no/such.log; echo $?                        # expect UNKNOWN ... and 2
    ls -l reports/lab05-history.txt                             # evidence file exists
    grep -Eic 'pass(word)?=|secret|token' reports/lab05-history.txt   # expect 0
    ```

=== "PowerShell"

    ```powershell
    Set-Location $HOME\lab05
    (Get-Content .\access.log).Count                                     # expect 240
    (Select-String -Path .\access.log -Pattern ' 401 ').Count            # expect 60
    .\Check-5xx.ps1 -Threshold 10; $LASTEXITCODE                         # expect ALERT ... and 3
    .\Check-5xx.ps1 -Threshold 50; $LASTEXITCODE                         # expect OK ... and 0
    .\Check-5xx.ps1 -Path C:\no\such.log; $LASTEXITCODE                  # expect UNKNOWN ... and 2
    Import-Csv .\reports\lab05-history.csv | Select-Object -First 3      # evidence file exists
    (Select-String -Path .\reports\lab05-history.csv -Pattern 'password|secret|token').Count  # expect 0
    ```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Counts are slightly different from the table | Log generated differently or edited | Rename the folder and regenerate the log; compare the first line |
| `uniq -c` shows the same IP several times | `sort` missing before `uniq` | <code>sort &#124; uniq -c</code> (always sort first) |
| `sort -rn` puts `97` below `146` incorrectly | `-n` missing (alphabetical sort) | Use `sort -rn` |
| PowerShell counts are 0 | Wrong index (`-split` is zero-based) or `Status` compared as a string | Use `$f[8]` and `[int]$f[8]` |
| `Group-Object` output includes a long `Group` column | Expected default | Add `-NoElement` or `Select-Object Count, Name` |
| `The token '&&' is not a valid statement separator in this version.` | Windows PowerShell 5.1 | Use `; if ($?) { … }` or run `pwsh` |
| `.\Check-5xx.ps1 cannot be loaded because running scripts is disabled on this system` | Execution policy `Restricted` | Follow [Windows Setup](../getting-started/windows-setup.md) (`RemoteSigned`, `CurrentUser` scope only) |
| `./check-5xx.sh: Permission denied` (exit 126) | Script not executable | `chmod u+x check-5xx.sh`, or run `bash check-5xx.sh` |
| `$LASTEXITCODE` is empty after the check | The script was dot-sourced or `exit` was not reached | Run it as `.\Check-5xx.ps1` (not `. .\Check-5xx.ps1`) and make sure every path ends with `exit` |
| `history` file contains commands from other windows | `histappend` merges sessions | That is fine; trim with `tail` if required |
| `!` inside a double-quoted `echo` gives `event not found` | Interactive history expansion | Use single quotes |

## Questions

1. Why does the Bash pipeline depend on the log's text layout while the PowerShell pipeline (after parsing) does not?
2. What would the top-talker list look like if you removed the first `sort`? Why?
3. In step 7, why is `$?` `0` for `grep ' 418 ' access.log | wc -l` without `pipefail`?
4. Why should a monitoring check return **2** (not **0**) when the log file is missing?
5. Why did you run `set -o pipefail` in a subshell `( … )` during the lab?
6. In PowerShell, why is `$LASTEXITCODE` the right variable to test after running `Check-5xx.ps1`, but `$?` is the right one after `Get-Item`?
7. Which built-in help command told you that `Group-Object` has a `-NoElement` switch?
8. What should you do if you discover that a password was saved in your history file?

## Solution

??? success "Bash solution"
    ```bash
    cd ~/lab05

    # 1. help first
    sort --help | grep -E -- '-n,|-r,'          # -n numeric, -r reverse
    uniq --help | grep -- '-c,'                 # -c prefix lines by the number of occurrences
    cut --help | grep -E -- '-d,|-f,'           # -d DELIM, -f LIST
    type -a cut sort                            # both are programs in /usr/bin (and /bin)

    # 2. total and top talkers
    wc -l < access.log
    cut -d' ' -f1 access.log | sort | uniq -c | sort -rn | head -n 3

    # 3. status breakdown
    cut -d' ' -f9 access.log | sort | uniq -c | sort -rn

    # 4. brute-force suspect
    grep ' 401 ' access.log | cut -d' ' -f1,7 | sort | uniq -c
    grep ' 401 ' access.log | head -n 1 | cut -d' ' -f4
    grep ' 401 ' access.log | tail -n 1 | cut -d' ' -f4

    # 5. server errors
    grep ' 500 ' access.log | cut -d' ' -f1,7 | sort | uniq -c

    # 6. bytes served (awk preview; Day 24)
    awk '{ s += $10 } END { print s }' access.log

    # 7. exit codes
    grep -q ' 500 ' access.log; echo "match: $?"
    grep -q ' 418 ' access.log; echo "no match: $?"
    grep -q ' 500 ' missing.log; echo "missing file: $?"
    grep ' 418 ' access.log | wc -l; echo "PIPESTATUS: ${PIPESTATUS[*]}"
    grep ' 418 ' access.log | wc -l; echo "without pipefail: $?"
    ( set -o pipefail; grep ' 418 ' access.log | wc -l; echo "with pipefail: $?" )

    # 8. chaining
    mkdir -p ~/lab05/reports && cd ~/lab05/reports && pwd
    cd ~/lab05

    # 9. the check script
    cat > check-5xx.sh <<'EOF'
    #!/usr/bin/env bash
    # check-5xx.sh - Lab 05: report HTTP 5xx responses in an access log.
    # Usage: ./check-5xx.sh [LOGFILE] [THRESHOLD]
    # Exit codes: 0 = OK, 2 = log missing/unreadable, 3 = threshold breached
    set -o nounset -o pipefail

    log="${1:-$HOME/lab05/access.log}"
    threshold="${2:-10}"

    if [ ! -r "$log" ]; then
        echo "UNKNOWN: cannot read $log" >&2
        exit 2
    fi

    count=$(cut -d' ' -f9 "$log" | grep -c '^5')

    if [ "$count" -gt "$threshold" ]; then
        echo "ALERT: $count server errors in $log (threshold $threshold)"
        exit 3
    fi
    echo "OK: $count server errors in $log (threshold $threshold)"
    exit 0
    EOF
    chmod u+x check-5xx.sh
    ./check-5xx.sh access.log; echo "exit=$?"
    ./check-5xx.sh access.log 50; echo "exit=$?"
    ./check-5xx.sh nope.log; echo "exit=$?"
    ./check-5xx.sh access.log 50 && echo "no action needed"
    ./check-5xx.sh access.log || echo "paging on-call (exit $?)"

    # 10. evidence
    history 40 > ~/lab05/reports/lab05-history.txt
    grep -Eic 'pass(word)?=|secret|token' ~/lab05/reports/lab05-history.txt
    ```

    The closing `EOF` of the here-document must be alone at the very start of its line, otherwise Bash does not recognise it and keeps waiting for input. Alternatively, create the file in an editor such as `nano check-5xx.sh`. The quoted `'EOF'` stops the shell from expanding `$log` and `$(…)` while writing the file. `grep -c` prints `0` and exits 1 when nothing matches, so `count` is still a number.

??? success "PowerShell solution"
    ```powershell
    Set-Location $HOME\lab05

    # 1. help first
    Get-Help Sort-Object -Parameter Descending
    Get-Help Group-Object -Parameter NoElement
    Get-Help Measure-Object -Parameter Sum
    Get-Command Group-Object, sort        # on Windows, sort is an alias for Sort-Object

    # parse once into objects
    $requests = Get-Content .\access.log | ForEach-Object {
        $f = $_ -split ' '
        [pscustomobject]@{
            IP     = $f[0]
            Time   = $f[3].TrimStart('[')
            Path   = $f[6]
            Status = [int]$f[8]
            Bytes  = [int]$f[9]
        }
    }
    $requests | Get-Member -MemberType NoteProperty

    # 2. total and top talkers
    $requests.Count
    $requests | Group-Object IP -NoElement | Sort-Object Count -Descending | Select-Object -First 3

    # 3. status breakdown
    $requests | Group-Object Status -NoElement | Sort-Object Count -Descending

    # 4. brute-force suspect
    $failed = $requests | Where-Object Status -eq 401
    $failed | Group-Object IP, Path -NoElement
    ($failed | Select-Object -First 1).Time
    ($failed | Select-Object -Last 1).Time

    # 5. server errors
    $requests | Where-Object Status -eq 500 | Group-Object IP, Path -NoElement

    # 6. bytes served
    ($requests | Measure-Object Bytes -Sum).Sum

    # 7. exit codes and error handling
    Get-Item .\access.log > $null; "existing: `$? = $?"
    Get-Item .\missing.log -ErrorAction SilentlyContinue; "missing: `$? = $?"
    ping.exe -n 1 127.0.0.1 > $null; "ping: `$? = $?, LASTEXITCODE = $LASTEXITCODE"   # Linux pwsh: ping -c 1
    try {
        Get-Content -Path .\missing.log -ErrorAction Stop
    } catch {
        "Caught: $($_.Exception.Message)"
    }

    # 8. chaining - 5.1 and 7
    New-Item -ItemType Directory -Path $HOME\lab05\reports -Force | Out-Null; if ($?) { Set-Location $HOME\lab05\reports }
    # PowerShell 7 only:
    # New-Item -ItemType Directory -Path $HOME\lab05\reports -Force && Set-Location $HOME\lab05\reports
    Set-Location $HOME\lab05

    # 9. the check script
    @'
    <#
    .SYNOPSIS
        Lab 05: report HTTP 5xx responses in an access log.
    .NOTES
        Exit codes: 0 = OK, 2 = log missing/unreadable, 3 = threshold breached.
    #>
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $HOME 'lab05\access.log'),
        [ValidateRange(0, 1000000)][int]$Threshold = 10
    )
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        [Console]::Error.WriteLine("UNKNOWN: cannot read $Path")
        exit 2
    }
    $count = @(Get-Content -Path $Path | Where-Object { ($_ -split ' ')[8] -like '5*' }).Count
    if ($count -gt $Threshold) {
        "ALERT: $count server errors in $Path (threshold $Threshold)"
        exit 3
    }
    "OK: $count server errors in $Path (threshold $Threshold)"
    exit 0
    '@ | Set-Content -Path .\Check-5xx.ps1 -Encoding UTF8

    .\Check-5xx.ps1; "exit=$LASTEXITCODE"
    .\Check-5xx.ps1 -Threshold 50; "exit=$LASTEXITCODE"
    .\Check-5xx.ps1 -Path .\nope.log; "exit=$LASTEXITCODE"
    .\Check-5xx.ps1 -Threshold 50; if ($LASTEXITCODE -eq 0) { 'no action needed' }
    .\Check-5xx.ps1; if ($LASTEXITCODE -ne 0) { "paging on-call (exit $LASTEXITCODE)" }

    # 10. evidence
    Get-History -Count 40 |
        Select-Object Id, CommandLine, StartExecutionTime |
        Export-Csv -Path .\reports\lab05-history.csv -NoTypeInformation
    (Select-String -Path .\reports\lab05-history.csv -Pattern 'password|secret|token').Count
    ```

    Expected output of the check (example, not executed for this release):

    ```text
    ALERT: 20 server errors in C:\Users\student\lab05\access.log (threshold 10)
    exit=3
    OK: 20 server errors in C:\Users\student\lab05\access.log (threshold 50)
    exit=0
    UNKNOWN: cannot read .\nope.log
    exit=2
    no action needed
    ALERT: 20 server errors in C:\Users\student\lab05\access.log (threshold 10)
    paging on-call (exit 3)
    ```

    In the here-string, the closing `'@` must be at the very start of its line. `$LASTEXITCODE` is set by the script's `exit` statement. The script writes `UNKNOWN` with `[Console]::Error.WriteLine` so the message goes to standard error without turning into a PowerShell error record. That keeps it compatible with both 5.1 and 7 and avoids `Write-Host`.

??? success "Answers to questions"
    1. `cut -d' ' -f1` relies on the IP being the first space-separated field. If the format changed (an extra space, a different log format) the result would be wrong without any error. After PowerShell parses each line **once** into objects with named properties, later stages use `IP`, `Status` and `Bytes` by name, so only the parsing line has to know the layout.
    2. `uniq -c` would count only **adjacent** duplicates. Because the log alternates between clients, you would get many small counts (mostly `1`) for the same IP instead of one total per IP.
    3. A pipeline's status is the status of its **last** command. `wc -l` succeeded (it printed `0`), so `$?` was `0`, while `grep` returned 1, which only `${PIPESTATUS[0]}` or `pipefail` reveals.
    4. A missing log means "we could not check", not "everything is fine". Returning 0 would hide a broken log pipeline or a deleted file, which might be caused by a failure **or** by an attacker. A distinct code (2 = UNKNOWN) lets the scheduler or monitoring system raise a different alert.
    5. To avoid changing the option permanently in your interactive shell. A subshell is a child process, so the setting disappears when it ends.
    6. `Check-5xx.ps1` sets an integer exit code with `exit`, which PowerShell stores in `$LASTEXITCODE`. `$?` would only say `True`/`False`. `Get-Item` is a cmdlet: it never sets `$LASTEXITCODE`, only `$?` and `$Error`.
    7. `Get-Help Group-Object -Parameter NoElement` (or `Get-Help Group-Object -Full`, or `Get-Command Group-Object -Syntax`).
    8. Treat the secret as **compromised** and rotate (change) it immediately. Then remove the line (`history -d N` and `history -w`, or edit the PSReadLine file), and in future use prompts such as `read -s`, `Read-Host -AsSecureString` or `Get-Credential`.

## Clean-up (optional)

Preview, then delete only the lab folder:

```bash
ls -R ~/lab05
rm -rI ~/lab05
```

```powershell
Remove-Item $HOME\lab05 -Recurse -WhatIf
Remove-Item $HOME\lab05 -Recurse
```
