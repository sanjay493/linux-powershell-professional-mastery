---
description: "Investigate a simulated brute-force attempt: find recent, hidden and large files, search logs for failed logins, rank attacker IPs, find a hard-coded credential and clean up safely in Bash and PowerShell."
---

# Lab 04: Needle in the Haystack

| Field | Value |
|---|---|
| **Lab ID** | LAB-04 |
| **Related lesson** | [Day 04: Searching Files and Text](../course/module-1/day-04.md) |
| **Difficulty** | Beginner–Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Low. All data is synthetic and stays inside `~/lab04` / `$HOME\lab04`. One step deletes files, **only** inside the lab folder and **only** after a preview. Never run the sample script. |

## Objective

The security team has copied the file systems of two web servers, `web01` and `web02`, into `~/lab04/srv` for you to analyse. They suspect that:

- someone tried to brute-force the SSH `admin` account,
- a script was dropped in a hidden folder,
- a credential has been left in a configuration file, and
- old temporary files and a large database dump are wasting space.

Using `find` / `Get-ChildItem` and `grep` / `Select-String`, you will confirm or reject each suspicion, quantify the attack, and clean up the old temporary files safely.

## Required Environment

- Ubuntu 24.04 LTS (VM, WSL2 or physical) with Bash, as a normal user, **and/or** Windows 11 with Windows PowerShell 5.1 or PowerShell 7 (not elevated).
- About 12 MB of free disk space.
- Day 03 and Day 04 completed.

## Initial Conditions

- `~/lab04` / `$HOME\lab04` must **not** exist. Check with `ls -d ~/lab04` / `Test-Path $HOME\lab04`, and rename an old copy rather than deleting it.
- Build the evidence tree with the generator for your shell. It creates 12 files that look the same on both platforms. The IP addresses come from ranges reserved for documentation (`203.0.113.0/24`, `198.51.100.0/24`) and private space (`10.0.0.0/8`); the "API key" is fake.

=== "Bash"

    ```bash
    mkdir -p ~/lab04/srv/{web01,web02}/{logs,config,tmp} ~/lab04/srv/web02/backup ~/lab04/srv/web01/tmp/.cache
    cd ~/lab04/srv
    for host in web01 web02; do
      for i in $(seq 1 120); do
        if   [ $((i % 3)) -eq 0 ]; then msg="Failed password for admin from 203.0.113.50 port $((40000 + i)) ssh2"
        elif [ $((i % 5)) -eq 0 ]; then msg="Failed password for admin from 198.51.100.7 port $((40000 + i)) ssh2"
        elif [ $((i % 7)) -eq 0 ]; then msg="Failed password for invalid user test$((i % 4)) from 203.0.113.77 port $((40000 + i)) ssh2"
        else msg="Accepted publickey for deploy from 10.0.0.5 port $((40000 + i)) ssh2"
        fi
        printf 'Nov  8 10:%02d:%02d %s sshd[%d]: %s\n' $((i / 60)) $((i % 60)) "$host" $((2000 + i)) "$msg"
      done > "$host/logs/auth.log"
      printf '2026-11-08 10:00:00 INFO start\n2026-11-08 10:01:00 ERROR upstream timeout\n2026-11-08 10:02:00 INFO ok\n' > "$host/logs/app.log"
      printf 'listen=0.0.0.0:443\nlog_level=info\n' > "$host/config/app.ini"
      touch "$host/tmp/sess-001.tmp" "$host/tmp/sess-002.tmp"
      touch -d '2026-10-15 08:00' "$host/tmp/sess-001.tmp"
    done
    printf 'api_key=LAB-FAKE-0000-1234\n' >> web02/config/app.ini
    printf '#!/bin/sh\n# LAB SAMPLE - harmless text, never run it\necho "beacon 198.51.100.23"\n' > web01/tmp/.cache/update.sh
    truncate -s 5M web02/backup/dump.sql
    ```

=== "PowerShell"

    ```powershell
    $srv = Join-Path $HOME 'lab04\srv'
    foreach ($h in 'web01', 'web02') {
        foreach ($d in 'logs', 'config', 'tmp') { New-Item -Path (Join-Path $srv "$h\$d") -ItemType Directory -Force | Out-Null }
    }
    New-Item -Path (Join-Path $srv 'web02\backup'), (Join-Path $srv 'web01\tmp\.cache') -ItemType Directory -Force | Out-Null
    Set-Location $srv
    foreach ($h in 'web01', 'web02') {
        1..120 | ForEach-Object {
            $port = 40000 + $_
            if     ($_ % 3 -eq 0) { $msg = "Failed password for admin from 203.0.113.50 port $port ssh2" }
            elseif ($_ % 5 -eq 0) { $msg = "Failed password for admin from 198.51.100.7 port $port ssh2" }
            elseif ($_ % 7 -eq 0) { $msg = "Failed password for invalid user test$($_ % 4) from 203.0.113.77 port $port ssh2" }
            else                  { $msg = "Accepted publickey for deploy from 10.0.0.5 port $port ssh2" }
            'Nov  8 10:{0:d2}:{1:d2} {2} sshd[{3}]: {4}' -f [int][math]::Floor($_ / 60), ($_ % 60), $h, (2000 + $_), $msg
        } | Set-Content -Path "$h\logs\auth.log" -Encoding ASCII
        Set-Content -Path "$h\logs\app.log" -Value '2026-11-08 10:00:00 INFO start', '2026-11-08 10:01:00 ERROR upstream timeout', '2026-11-08 10:02:00 INFO ok'
        Set-Content -Path "$h\config\app.ini" -Value 'listen=0.0.0.0:443', 'log_level=info'
        New-Item -Path "$h\tmp\sess-001.tmp", "$h\tmp\sess-002.tmp" -ItemType File -Force | Out-Null
        (Get-Item "$h\tmp\sess-001.tmp").LastWriteTime = Get-Date '2026-10-15 08:00'
    }
    Add-Content -Path web02\config\app.ini -Value 'api_key=LAB-FAKE-0000-1234'
    Set-Content -Path web01\tmp\.cache\update.sh -Value '#!/bin/sh', '# LAB SAMPLE - harmless text, never run it', 'echo "beacon 198.51.100.23"'
    $cache = Get-Item web01\tmp\.cache -Force
    $cache.Attributes = $cache.Attributes -bor [System.IO.FileAttributes]::Hidden   # Windows only: mimic a Linux dot-folder
    $fs = [System.IO.File]::Create((Join-Path $srv 'web02\backup\dump.sql')); $fs.SetLength(5MB); $fs.Close()
    ```

    On Linux PowerShell 7, the `Hidden` attribute line has no effect, because a leading dot is what makes a name hidden there.

## Step-by-Step Instructions

Work from `~/lab04/srv` / `$HOME\lab04\srv` for every task.

### Task 1 — Inventory the evidence

1. Count **all** files, including hidden ones.
2. List all directories. Which one would a casual `ls` / `Get-ChildItem` not show?

### Task 2 — Locate the logs

1. Find every file named `auth.log`.
2. Find every `.log` file and show its size.

### Task 3 — Quantify the brute-force attempt

1. Count the `Failed password` lines in **each** server's `auth.log`.
2. Count the successful logins (`Accepted`) on `web01`. Which account and source address do they use?
3. Extract the source IP of **every** failed login on both servers, then count and rank them (highest first).
4. List the **user names** tried in `invalid user` attempts, with a count for each.

### Task 4 — Find the dropped script

1. Find hidden files and directories (Linux: names starting with `.`; Windows: the Hidden attribute).
2. Find files ending in `.sh` modified in the last 60 minutes.
3. **Read** (do not run) the script with `cat` / `Get-Content`, and extract any IP address it contains.

### Task 5 — Find the leaked credential

1. Search only the `.ini` files for `api_key`, `password=` or `secret`, case-insensitively, with line numbers.
2. Record the file and line number. Do not copy the value into tickets or chat; report its **location**.

### Task 6 — Find the space wasters

1. Find files larger than 1 MiB and show their size.
2. Find `.tmp` files **older than 7 days**.
3. **Preview**, then delete, only those old `.tmp` files. Confirm that the newer `sess-002.tmp` files remain.

### Task 7 — Application errors and tool check

1. Find every `ERROR` line in all `app.log` files, with file name and line number.
2. Check whether `ssh` and `nmap` are installed, using the script-friendly command for your shell.

## Commands to Execute

Try each task yourself first. Full commands are in the [Solution](#solution).

## Expected Results

The Bash values were produced by running the generator and the solution commands on GNU findutils 4.9.0 / grep 3.11. The PowerShell values follow from the same data.

| Task | Expected result |
|---|---|
| 1.1 | **12** files (Windows: 12 only with `-Force`; 11 without it, because the hidden folder is skipped) |
| 1.2 | 11 directories including `.`; the hidden one is `web01/tmp/.cache` |
| 2.1 | `web01/logs/auth.log`, `web02/logs/auth.log` |
| 3.1 | `web01`: **66**; `web02`: **66** |
| 3.2 | **54** `Accepted publickey for deploy from 10.0.0.5` |
| 3.3 | `203.0.113.50` × **80**, `198.51.100.7` × **32**, `203.0.113.77` × **20** |
| 3.4 | `test0` × 6, `test1` × 4, `test2` × 4, `test3` × 6 |
| 4.1 | `web01/tmp/.cache` and `web01/tmp/.cache/update.sh` |
| 4.2 | `web01/tmp/.cache/update.sh` |
| 4.3 | `198.51.100.23` |
| 5 | `web02/config/app.ini`, line **3**, `api_key=...` |
| 6.1 | `web02/backup/dump.sql`, 5.0M |
| 6.2 | `web01/tmp/sess-001.tmp`, `web02/tmp/sess-001.tmp` |
| 6.3 | After cleanup: 2 `.tmp` files remain (`sess-002.tmp` on each server); 10 files in total |
| 7.1 | Line 2 of each `app.log`: `ERROR upstream timeout` |
| 7.2 | Depends on your system; `ssh` is usually present, `nmap` usually not |

**Findings summary:** a password-guessing attack against `admin` from three external addresses (one dominant: `203.0.113.50`), plus probing of non-existent `test*` accounts. The only successful logins are key-based logins of `deploy` from the internal address `10.0.0.5`, so there is **no evidence** in these logs that the attack succeeded. A suspicious script referencing `198.51.100.23` sits in a hidden folder on `web01`, and `web02` has a plain-text API key in its configuration. Both need follow-up.

## Verification Steps

=== "Bash"

    ```bash
    cd ~/lab04/srv
    find . -type f | wc -l                                   # 10 after Task 6
    find . -name '*.tmp' | sort                              # only sess-002.tmp x2
    grep -c 'Failed password' */logs/auth.log                # 66 and 66
    grep -rhoE 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' --include=auth.log . | sort | uniq -c | sort -rn | head -n 1
    grep -rn api_key --include='*.ini' .                     # web02/config/app.ini:3
    ```

=== "PowerShell"

    ```powershell
    Set-Location $HOME\lab04\srv
    (Get-ChildItem -Recurse -File -Force).Count             # 10 after Task 6
    Get-ChildItem -Recurse -Filter *.tmp -Name              # only sess-002.tmp x2
    Get-ChildItem -Recurse -Filter auth.log | ForEach-Object { '{0}: {1}' -f $_.Directory.Parent.Name, (Select-String -Path $_.FullName -SimpleMatch 'Failed password').Count }
    Get-ChildItem -Recurse -Filter *.ini | Select-String -Pattern 'api_key'
    ```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| File count is 11 in PowerShell | Hidden folder skipped | Add `-Force` to `Get-ChildItem` |
| `find . -name '.*'` also prints `.` | The starting point itself starts with a dot | Add `-mindepth 1` |
| IP counts are doubled or include `10.0.0.5` | Searched all lines, not only `Failed password` lines | Filter for `Failed password` first, then extract IPs |
| `grep -E '\d'` finds nothing | GNU `grep -E` does not support `\d` | Use `[0-9]`, or `grep -P '\d'` |
| Counts in PowerShell are higher than expected | `Select-String` is case-insensitive, or a regex `.` matched any character | Add `-CaseSensitive`; use `-SimpleMatch` for literal text |
| `find -mtime +7` finds nothing | The generator's `touch -d` step failed, or the system clock is before the set date | Check with `ls -l --time-style=long-iso */tmp`; rerun the `touch -d` line |
| `Where-Object LastWriteTime -lt ...` finds nothing (Windows) | Date string not parsed | Use `Get-Date '2026-10-15 08:00'` exactly as in the generator |
| Deleted the wrong files | Skipped the preview | Re-run the generator in a fresh folder; always run the identical command without `-delete` / with `-WhatIf` first |

## Questions

1. Why is it essential to filter for `Failed password` **before** extracting IP addresses?
2. Based on Task 3, did the attack succeed? What evidence supports your answer, and what other evidence would you check (Day 17)?
3. Why did `Get-ChildItem -Recurse` without `-Force` miss the dropped script on Windows? What is the Linux equivalent of this "hiding"?
4. Why do you report the **location** of the API key rather than its value?
5. What would `find . -delete -name '*.tmp' -mtime +7` have done?
6. Why is `find` (not `locate`) the correct tool for this investigation?
7. Write one `grep` command that would sweep all logs for any address in a file `iocs.txt` containing `198.51.100.23` and `203.0.113.50`.

## Solution

??? success "Bash solution"
    ```bash
    cd ~/lab04/srv

    # Task 1 - inventory
    find . -type f | wc -l                         # 12
    find . -type d | sort                          # .cache is hidden from plain ls

    # Task 2 - logs
    find . -name auth.log | sort
    find . -name '*.log' -exec ls -lh {} +

    # Task 3 - brute force
    grep -c 'Failed password' */logs/auth.log      # 66 each
    grep -c 'Accepted' web01/logs/auth.log         # 54
    grep 'Accepted' web01/logs/auth.log | head -n 3
    grep -rh 'Failed password' --include=auth.log . |
      grep -Eo 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -rn
    grep -rhoE 'invalid user [^ ]+' --include=auth.log . | sort | uniq -c

    # Task 4 - dropped script
    find . -mindepth 1 -name '.*' | sort
    find . -type f -name '*.sh' -mmin -60
    cat web01/tmp/.cache/update.sh                 # read only - never execute
    grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' web01/tmp/.cache/update.sh

    # Task 5 - credential
    grep -rniE 'api_key|password=|secret' --include='*.ini' .

    # Task 6 - space wasters and safe cleanup
    find . -type f -size +1M -exec ls -lh {} +
    find . -name '*.tmp' -mtime +7                 # preview: two sess-001.tmp
    find . -name '*.tmp' -mtime +7 -delete         # same expression + -delete at the END
    find . -name '*.tmp' | sort                    # sess-002.tmp remain

    # Task 7 - errors and tools
    grep -rn ERROR --include=app.log . | sort
    for t in ssh nmap; do
      if command -v "$t" >/dev/null; then echo "$t: $(command -v "$t")"; else echo "$t: not installed"; fi
    done
    ```

??? success "PowerShell solution"
    ```powershell
    Set-Location $HOME\lab04\srv

    # Task 1 - inventory
    (Get-ChildItem -Recurse -File -Force).Count            # 12 (11 without -Force)
    Get-ChildItem -Recurse -Directory -Force | Select-Object FullName, Attributes

    # Task 2 - logs
    Get-ChildItem -Recurse -Filter auth.log | Select-Object FullName
    Get-ChildItem -Recurse -Filter *.log | Select-Object FullName, Length

    # Task 3 - brute force
    Get-ChildItem -Recurse -Filter auth.log | ForEach-Object {
        [pscustomobject]@{ Server = $_.Directory.Parent.Name
                           Failed = (Select-String -Path $_.FullName -SimpleMatch 'Failed password' -CaseSensitive).Count }
    }
    (Select-String -Path web01\logs\auth.log -SimpleMatch 'Accepted' -CaseSensitive).Count     # 54
    Select-String -Path web01\logs\auth.log -SimpleMatch 'Accepted' | Select-Object -First 3 | ForEach-Object Line
    Get-ChildItem -Recurse -Filter auth.log |
        Select-String -Pattern 'Failed password .* from ((\d{1,3}\.){3}\d{1,3})' -CaseSensitive |
        ForEach-Object { $_.Matches[0].Groups[1].Value } |
        Group-Object | Sort-Object Count -Descending | Select-Object Count, Name
    Get-ChildItem -Recurse -Filter auth.log |
        Select-String -Pattern 'invalid user \S+' -AllMatches |
        ForEach-Object { $_.Matches.Value } | Group-Object | Select-Object Count, Name

    # Task 4 - dropped script
    Get-ChildItem -Recurse -Force | Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::Hidden) -or ($_.Name -like '.*') } |
        Select-Object FullName
    Get-ChildItem -Recurse -Force -Filter *.sh | Where-Object LastWriteTime -gt (Get-Date).AddMinutes(-60)
    Get-Content web01\tmp\.cache\update.sh               # read only - never execute
    Select-String -Path web01\tmp\.cache\update.sh -Pattern '(\d{1,3}\.){3}\d{1,3}' | ForEach-Object { $_.Matches.Value }

    # Task 5 - credential
    Get-ChildItem -Recurse -Filter *.ini | Select-String -Pattern 'api_key|password=|secret'

    # Task 6 - space wasters and safe cleanup
    Get-ChildItem -Recurse -File -Force | Where-Object Length -gt 1MB |
        Select-Object FullName, @{n='MB'; e={[math]::Round($_.Length / 1MB, 1)}}
    $old = Get-ChildItem -Recurse -Filter *.tmp | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7)
    $old | Select-Object FullName, LastWriteTime        # preview
    $old | Remove-Item -WhatIf                           # simulate
    $old | Remove-Item                                   # delete
    Get-ChildItem -Recurse -Filter *.tmp -Name           # sess-002.tmp remain

    # Task 7 - errors and tools
    Get-ChildItem -Recurse -Filter app.log | Select-String -Pattern 'ERROR' -CaseSensitive
    foreach ($t in 'ssh', 'nmap') {
        $c = Get-Command $t -ErrorAction SilentlyContinue
        if ($c) { '{0}: {1}' -f $t, $c.Source } else { '{0}: not installed' -f $t }
    }
    ```

    The parentheses around the address in the failed-login pattern form a **capture group**. `Matches[0].Groups[1].Value` returns only the text inside the first group, which is the bare IP address, so successful logins (which do not match `Failed password`) are never counted.

??? success "Answers to questions"
    1. Successful logins (`Accepted ... from 10.0.0.5`) also contain IP addresses. Extracting from all lines would mix legitimate and attacking sources and inflate the counts.
    2. There is no evidence of success: every `admin` and `invalid user` attempt failed, and the only `Accepted` entries are key-based logins of `deploy` from the internal address `10.0.0.5`, which is the expected pattern. You would still check `last`/`wtmp`, `journalctl -u ssh`, `sudo` usage and (on Windows) Security event IDs 4624/4625 (Day 17), and why a script appeared on `web01`.
    3. The folder has the Hidden attribute, and `Get-ChildItem` skips hidden items unless you use `-Force` (or `-Hidden`). On Linux, any name starting with `.` is hidden from `ls` and from `*` wildcards; `find` shows it by default.
    4. Copying a secret into tickets, chat or reports spreads it further. Report its location so the owner can rotate the key and remove it from the file.
    5. It would have deleted **every** file and empty directory under `.`, because `-delete` is evaluated first, before the name and age tests.
    6. `find` reads the file system live and supports time, size and hidden-file tests. `locate` uses a database that is up to a day old, does not index this new folder until `updatedb` runs, and cannot test age or size.
    7. `grep -rnFf iocs.txt .` (`-f` reads the patterns from the file, `-F` treats them as literal strings, `-n` adds line numbers).

## Clean-up (optional)

```bash
ls -R ~/lab04 | head && rm -rI ~/lab04
```

```powershell
Remove-Item $HOME\lab04 -Recurse -Force -WhatIf
Remove-Item $HOME\lab04 -Recurse -Force
```

`-Force` is needed here because the lab contains a hidden folder.
