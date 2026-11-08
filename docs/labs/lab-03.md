---
description: "Sample, slice, count and follow a web-server access log, and save evidence with correct redirection and encoding in Bash and PowerShell."
---

# Lab 03: Log Reader

| Field | Value |
|---|---|
| **Lab ID** | LAB-03 |
| **Related lesson** | [Day 03: Reading and Managing Files](../course/module-1/day-03.md) |
| **Difficulty** | Beginner |
| **Time** | 60–75 minutes |
| **Risk level** | Low. You only read system files; everything you create stays inside `~/lab03` / `$HOME\lab03`. No `sudo` or Administrator rights are needed. |

## Objective

You are the on-call engineer for a small web application. Users report "random login failures" between 10:00 and 10:35 UTC. The web team has sent you the server's access log. Using **only** the reading, counting and redirection tools from Day 03, you will:

1. Measure the log before opening it.
2. Sample the top and bottom of the log and extract an exact range of lines as evidence.
3. Count status codes to quantify the problem.
4. Follow the log live while new requests arrive.
5. Save a short incident summary, with output and errors captured correctly and in a portable encoding.

## Required Environment

- Ubuntu 24.04 LTS (VM, WSL2 or physical) with Bash, as a normal user, **and/or** Windows 11 with Windows PowerShell 5.1 or PowerShell 7 (not elevated).
- Two terminal windows or tabs (for Task 5).
- About 1 MB of free disk space.

## Initial Conditions

- `~/lab03` (Linux) / `$HOME\lab03` (Windows) must **not** exist. Check:
    - Bash: `ls -d ~/lab03` should report `No such file or directory`.
    - PowerShell: `Test-Path $HOME\lab03` should return `False`.
- If it exists from an earlier attempt, rename it (`mv ~/lab03 ~/lab03.old` / `Rename-Item $HOME\lab03 lab03.old`).
- Create the lab log with the generator for your shell. It produces 2,000 requests in Apache/Nginx "common log" style, identical on both platforms.

=== "Bash"

    ```bash
    mkdir -p ~/lab03/{logs,evidence} && cd ~/lab03
    paths=(/ /index.html /login /api/orders /api/users /static/app.js /admin)
    codes=(200 200 200 200 304 404 500)
    for i in $(seq 1 2000); do
      ip="10.0.$(( i % 4 )).$(( (i * 7) % 250 + 1 ))"
      p=${paths[$(( i % 7 ))]}
      c=${codes[$(( (i * 3) % 7 ))]}
      printf '%s - - [08/Nov/2026:10:%02d:%02d +0000] "GET %s HTTP/1.1" %s %d\n' \
        "$ip" $(( i / 60 % 60 )) $(( i % 60 )) "$p" "$c" $(( 200 + i % 900 ))
    done > logs/access.log
    ```

=== "PowerShell"

    ```powershell
    $lab = Join-Path $HOME 'lab03'
    New-Item -Path (Join-Path $lab 'logs'), (Join-Path $lab 'evidence') -ItemType Directory -Force | Out-Null
    Set-Location $lab
    $paths = '/', '/index.html', '/login', '/api/orders', '/api/users', '/static/app.js', '/admin'
    $codes = 200, 200, 200, 200, 304, 404, 500
    1..2000 | ForEach-Object {
        $ip = '10.0.{0}.{1}' -f ($_ % 4), (($_ * 7) % 250 + 1)
        '{0} - - [08/Nov/2026:10:{1:d2}:{2:d2} +0000] "GET {3} HTTP/1.1" {4} {5}' -f $ip,
            ([int][math]::Floor($_ / 60) % 60), ($_ % 60), $paths[$_ % 7], $codes[($_ * 3) % 7], (200 + $_ % 900)
    } | Set-Content -Path logs\access.log -Encoding ASCII
    ```

All addresses are private (`10.0.x.x`) and the data is synthetic. No real system is involved.

## Step-by-Step Instructions

### Task 1 — Measure before you read

1. Show the size of `logs/access.log` in human-readable form.
2. Count its lines.
3. Decide (and write down) whether it is reasonable to `cat` the whole file. Why or why not?

### Task 2 — Sample the top and the bottom

1. Display the first 5 lines.
2. Display the last 5 lines.
3. From the timestamps, write down the time range the log covers.

### Task 3 — Extract an exact range as evidence

1. Save lines **1000 to 1010** (11 lines) to `evidence/sample-1000-1010.txt`.
2. Verify the evidence file has exactly 11 lines and that its first line is request number 1000 (timestamp `10:16:40`).

### Task 4 — Quantify the problem

1. Count the requests that returned status **500**.
2. Count status **404** and status **200**.
3. Look at a few of the 500 lines (use `head` / `-First` on the filtered result). Which URL path do they have in common?

    The quotation mark in the pattern `'" 500 '` anchors the match to the status field (it follows the closing quote of the request). Day 04 explains searching properly.

### Task 5 — Follow the log live

1. In **terminal 1**, follow `logs/access.log` showing **only new lines**, filtered to status 500.
2. In **terminal 2**, append three new requests: two `/login` requests with status 500 and one `/` request with status 200, one per second.
3. Confirm that terminal 1 shows exactly the two 500 lines. Stop following with ++ctrl+c++.

### Task 6 — Write an incident summary with correct redirection

1. Create `evidence/summary.txt` containing: a heading line, the total line count, and the number of 500 responses. Use `>` for the first line and `>>` for the others.
2. Run one command that reads **both** `logs/access.log` and a file that does not exist (`logs/access.log.1`), sending normal output to `evidence/combined.txt` and errors to `evidence/errors.txt`.
3. Run the same command again, capturing **both** streams in `evidence/all.txt`.
4. Turn on overwrite protection (Bash `noclobber`, PowerShell `-NoClobber`) and prove that it stops you from overwriting `summary.txt`.

### Task 7 — Check the encoding (Windows only; Linux users check line endings)

1. **PowerShell:** save the output of `Get-Item logs\access.log` with `>` to `evidence\item-default.txt` and with `Out-File -Encoding utf8` to `evidence\item-utf8.txt`. Compare their sizes and first bytes with `Format-Hex`.
2. **Bash:** run `file` on `logs/access.log` and on `evidence/summary.txt`, and confirm both are plain ASCII with LF line endings.

## Commands to Execute

Try each task yourself first. The full commands are in the [Solution](#solution).

## Expected Results

| Check | Linux (Bash) | Windows (PowerShell) |
|---|---|---|
| Line count | `2000` | `2000` |
| File size | `152203` bytes (≈ 149K) | `154203` bytes (CRLF adds 2,000 bytes) |
| First line | `10.0.1.8 - - [08/Nov/2026:10:00:01 +0000] "GET /index.html HTTP/1.1" 200 201` | same |
| Last line | `10.0.0.1 - - [08/Nov/2026:10:33:20 +0000] "GET /static/app.js HTTP/1.1" 200 400` | same |
| Time range | 10:00:01 → 10:33:20 UTC | same |
| Evidence file | 11 lines, first `... 10:16:40 ... /admin ... 304 300`, last `... 10:16:50 ... /login ... 500 310` | same |
| Status 500 | `286` | `286` |
| Status 404 | `286` | `286` |
| Status 200 | `1143` | `1143` |
| Common path of the 500s | `/login` (every 500 is a `/login` request) | same |
| Live follow (Task 5) | Exactly 2 new lines shown | same |

The Bash values were produced by running the generator on GNU Bash 5.2 / coreutils 9.4. The PowerShell values follow from the same arithmetic; sizes on your system match exactly only if you used the generator unchanged.

**Finding to report:** every `/login` request in the window failed with HTTP 500, so the "random" login failures are not random. They are a server-side error on one endpoint, which points to the application or its authentication back end, not the network.

## Verification Steps

=== "Bash"

    ```bash
    cd ~/lab03
    wc -l < logs/access.log                         # 2000
    wc -l < evidence/sample-1000-1010.txt           # 11
    head -n 1 evidence/sample-1000-1010.txt         # ... 10:16:40 ...
    cat evidence/summary.txt                        # heading, 2000, 286
    cat evidence/errors.txt                         # "No such file or directory" message
    grep -c 'No such file' evidence/all.txt         # 1
    file logs/access.log evidence/summary.txt       # ASCII text
    ```

=== "PowerShell"

    ```powershell
    Set-Location $HOME\lab03
    (Get-Content logs\access.log).Count                       # 2000
    (Get-Content evidence\sample-1000-1010.txt).Count         # 11
    Get-Content evidence\sample-1000-1010.txt -TotalCount 1   # ... 10:16:40 ...
    Get-Content evidence\summary.txt                          # heading, 2000, 286
    Get-Content evidence\errors.txt -TotalCount 1             # "Cannot find path" message
    (Select-String -Path evidence\all.txt -Pattern 'Cannot find path').Count   # 1 or more
    Format-Hex evidence\item-utf8.txt | Select-Object -First 1                 # no FF FE at the start
    ```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Line count is not 2000 | Generator was edited or interrupted | Delete `logs/access.log` (preview first) and run the generator again unchanged |
| `printf: 10.0.1.8: invalid number` or odd output | Arguments in the wrong order after editing | Copy the generator exactly; the format string has six `%` placeholders and six arguments |
| PowerShell: `Error formatting a string: Input string was not in a correct format.` | `{1:d2}` received a non-integer | Keep the `[int][math]::Floor(...)` cast |
| Counts of 500 are too high | Pattern `500` without the quote also matches byte sizes such as `500` at the end of a line | Use `'" 500 '` exactly |
| Terminal 1 shows the whole log | You forgot `-n 0` / `-Tail 0` | Restart with `tail -n 0 -F` / `Get-Content -Tail 0 -Wait` |
| Terminal 1 shows nothing | Filter typo, or the appended lines were written to a different file | Check the path in terminal 2 with `pwd` / `Get-Location` |
| `grep` output in terminal 1 appears late or in bursts | Output buffering after a pipe | Add `--line-buffered` to `grep` |
| `summary.txt` contains only the last line | You used `>` for every line | First line `>`, others `>>` |
| `errors.txt` is empty and errors appeared on screen | Redirections in the wrong order, or `2>` omitted | `cmd > combined.txt 2> errors.txt` |
| `item-default.txt` starts with `FF FE` | Windows PowerShell 5.1 `>` writes UTF-16 LE | Expected. That is the point of Task 7; use `-Encoding utf8` for portable files |

## Questions

1. Why is it better to run `ls -lh` and `wc -l` before opening an unknown log?
2. In Task 3, what would `(Get-Content logs\access.log)[1000..1010]` return, and why is that not the requested range?
3. Why does the pattern `'" 500 '` give a more accurate count than `500`?
4. In Task 5, why must you use `-n 0` / `-Tail 0`, and why is `tail -F` preferred to `tail -f` for real server logs?
5. In Task 6, how could you capture both streams into `all.txt` while still seeing the output on screen?
6. Why are the Windows file sizes larger than the Linux ones even though the line count is identical?
7. Based on your counts, what would you write in the incident ticket, and which team would you assign it to?

## Solution

??? success "Bash solution"
    ```bash
    cd ~/lab03

    # Task 1 - measure
    ls -lh logs/access.log
    wc -l logs/access.log            # 2000: small enough to cat, but paging is still kinder

    # Task 2 - sample
    head -n 5 logs/access.log
    tail -n 5 logs/access.log        # range 10:00:01 -> 10:33:20

    # Task 3 - exact range as evidence
    sed -n '1000,1010p' logs/access.log > evidence/sample-1000-1010.txt
    # alternative: head -n 1010 logs/access.log | tail -n 11 > evidence/sample-1000-1010.txt
    wc -l < evidence/sample-1000-1010.txt
    head -n 1 evidence/sample-1000-1010.txt

    # Task 4 - quantify
    grep -c '" 500 ' logs/access.log     # 286
    grep -c '" 404 ' logs/access.log     # 286
    grep -c '" 200 ' logs/access.log     # 1143
    grep '" 500 ' logs/access.log | head -n 5    # all /login

    # Task 5 - terminal 1
    tail -n 0 -F logs/access.log | grep --line-buffered '" 500 '
    # Task 5 - terminal 2
    for r in '/login 500' '/login 500' '/ 200'; do
      set -- $r
      printf '10.0.9.9 - - [08/Nov/2026:10:40:00 +0000] "GET %s HTTP/1.1" %s 512\n' "$1" "$2" >> ~/lab03/logs/access.log
      sleep 1
    done

    # Task 6 - summary and redirection
    echo "Incident summary - access.log - $(date -u +%FT%TZ)" > evidence/summary.txt
    echo "Total requests: $(wc -l < logs/access.log)"        >> evidence/summary.txt
    echo "HTTP 500: $(grep -c '" 500 ' logs/access.log)"     >> evidence/summary.txt
    cat evidence/summary.txt

    wc -l logs/access.log logs/access.log.1 > evidence/combined.txt 2> evidence/errors.txt
    wc -l logs/access.log logs/access.log.1 > evidence/all.txt 2>&1
    set -o noclobber
    echo "oops" > evidence/summary.txt     # bash: evidence/summary.txt: cannot overwrite existing file
    set +o noclobber

    # Task 7 - line endings
    file logs/access.log evidence/summary.txt
    ```

    After Task 5, the log has 2,003 lines and the summary reports 2003 requests and 288 errors. That is correct: the summary reflects the file at the time you wrote it.

??? success "PowerShell solution"
    ```powershell
    Set-Location $HOME\lab03

    # Task 1 - measure
    Get-Item logs\access.log | Select-Object Name, @{n='KB'; e={[math]::Round($_.Length / 1KB, 1)}}
    (Get-Content logs\access.log).Count

    # Task 2 - sample
    Get-Content logs\access.log -TotalCount 5
    Get-Content logs\access.log -Tail 5

    # Task 3 - exact range (lines 1000-1010 = indexes 999-1009)
    Get-Content logs\access.log | Select-Object -Skip 999 -First 11 |
        Set-Content evidence\sample-1000-1010.txt -Encoding ASCII
    (Get-Content evidence\sample-1000-1010.txt).Count
    Get-Content evidence\sample-1000-1010.txt -TotalCount 1

    # Task 4 - quantify
    (Select-String -Path logs\access.log -SimpleMatch '" 500 ').Count    # 286
    (Select-String -Path logs\access.log -SimpleMatch '" 404 ').Count    # 286
    (Select-String -Path logs\access.log -SimpleMatch '" 200 ').Count    # 1143
    Get-Content logs\access.log | Where-Object { $_ -like '*" 500 *' } | Select-Object -First 5

    # Task 5 - terminal 1
    Get-Content logs\access.log -Tail 0 -Wait | Where-Object { $_ -like '*" 500 *' }
    # Task 5 - terminal 2
    '/login 500', '/login 500', '/ 200' | ForEach-Object {
        $p, $c = $_ -split ' '
        Add-Content -Path $HOME\lab03\logs\access.log -Encoding ASCII `
            -Value ('10.0.9.9 - - [08/Nov/2026:10:40:00 +0000] "GET {0} HTTP/1.1" {1} 512' -f $p, $c)
        Start-Sleep -Seconds 1
    }

    # Task 6 - summary and redirection
    "Incident summary - access.log - $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))" |
        Out-File evidence\summary.txt -Encoding utf8
    "Total requests: $((Get-Content logs\access.log).Count)" | Out-File evidence\summary.txt -Append -Encoding utf8
    "HTTP 500: $((Select-String -Path logs\access.log -SimpleMatch '" 500 ').Count)" |
        Out-File evidence\summary.txt -Append -Encoding utf8
    Get-Content evidence\summary.txt

    Get-Item logs\access.log, logs\access.log.1 > evidence\combined.txt 2> evidence\errors.txt
    Get-Item logs\access.log, logs\access.log.1 *> evidence\all.txt
    'oops' | Out-File evidence\summary.txt -NoClobber     # error: file already exists

    # Task 7 - encoding
    Get-Item logs\access.log > evidence\item-default.txt
    Get-Item logs\access.log | Out-File evidence\item-utf8.txt -Encoding utf8
    Get-Item evidence\item-*.txt | Select-Object Name, Length
    Format-Hex evidence\item-default.txt | Select-Object -First 1   # 5.1: FF FE ... (UTF-16 LE)
    Format-Hex evidence\item-utf8.txt    | Select-Object -First 1   # 5.1: EF BB BF ... (UTF-8 BOM)
    ```

    In PowerShell 7, `item-default.txt` is already UTF-8 without a BOM, so both files are almost the same size. `Out-File -Encoding utf8` in 7 also writes no BOM; use `utf8BOM` if a program needs one.

??? success "Answers to questions"
    1. They tell you how big the file is before you open it, so you choose the right tool (`less`, `head`, `tail`) and avoid flooding the terminal or loading gigabytes into memory.
    2. It returns lines **1001 to 1011**, because PowerShell arrays are zero-based. Lines 1000–1010 are indexes `[999..1009]`.
    3. `500` also matches other fields that contain those digits, such as a response size of 500 bytes. `'" 500 '` matches only the status field, which comes right after the closing quotation mark of the request.
    4. Without `-n 0` / `-Tail 0`, the follow command first prints the last 10 lines (`tail`) or the **whole** file (`Get-Content -Wait`), which would mix old lines with new ones. `-F` re-opens the file by name after log rotation; `-f` would keep watching the old, renamed file.
    5. Bash: `wc -l logs/access.log logs/access.log.1 2>&1 | tee evidence/all.txt`. PowerShell: `Get-Item logs\access.log, logs\access.log.1 *>&1 | Tee-Object evidence\all.txt`.
    6. Windows uses CRLF line endings (2 bytes per line ending instead of 1), and Windows PowerShell 5.1 may add a byte order mark depending on the encoding.
    7. For example: "Between 10:00:01 and 10:33:20 UTC, 286 of 2,000 requests (14.3%) returned HTTP 500. All of them are `GET /login`. Other endpoints are healthy (1,143 × 200). Server-side fault in the login endpoint; assign to the application team, attach `evidence/sample-1000-1010.txt` and `summary.txt`."

## Clean-up (optional)

```bash
ls -R ~/lab03 && rm -rI ~/lab03
```

```powershell
Remove-Item $HOME\lab03 -Recurse -WhatIf
Remove-Item $HOME\lab03 -Recurse
```
