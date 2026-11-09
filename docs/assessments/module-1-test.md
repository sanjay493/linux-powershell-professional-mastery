---
description: "Module 1 test (Days 1–5): 25 questions on shells, files and directories, reading and redirecting output, searching, help, history, pipelines and exit codes, with a collapsible answer key and a practical task."
---

# Module 1 Test: Command-Line Fundamentals

| | |
|---|---|
| **Covers** | [Day 01](../course/module-1/day-01.md) – [Day 05](../course/module-1/day-05.md) |
| **Questions** | 25: 15 multiple choice (1 mark each), 7 command-writing (2 marks each), 3 short-answer and practical (3 marks each) |
| **Total** | 38 marks · pass mark 23 (60%) |
| **Time** | 60 minutes, closed book except for built-in help (`man`, `--help`, `Get-Help`) |
| **Environment** | For Part C you need an Ubuntu 24.04 terminal and/or a Windows PowerShell window (5.1 or 7). Work only inside a new folder `~/m1test` / `$HOME\m1test`. |

Answer every question before opening the answers. Each answer explains *why*, so use the key to learn, not only to mark. Grade with the table on the [Assessments](index.md#grading-guidance) page.

## Part A — Multiple choice (1 mark each)

**1.** Which layer actually reads a file from disk when you run `cat notes.txt`?

- A. The terminal emulator
- B. The shell
- C. The kernel, through system calls made by the `cat` program
- D. The prompt

??? question "Answer and explanation"
    **C.** The terminal only displays text, and the shell finds and starts `cat`. The program asks the kernel to open and read the file. (Day 01)

**2.** What does `PSEdition` show in `$PSVersionTable` when you run PowerShell 7?

- A. `Desktop`
- B. `Core`
- C. `7`
- D. `Windows`

??? question "Answer and explanation"
    **B.** `Desktop` is Windows PowerShell 5.1 (.NET Framework). `Core` is PowerShell 6/7 on modern .NET. (Day 01)

**3.** You are in `/home/student/projects/web`. Which path refers to `/home/student/notes.txt`?

- A. `./notes.txt`
- B. `../notes.txt`
- C. `../../notes.txt`
- D. `~/projects/notes.txt`

??? question "Answer and explanation"
    **C.** `..` goes to `projects`, the second `..` to `/home/student`. `~/notes.txt` would also work. (Day 02)

**4.** `backup/` already exists. What does `cp -r config backup` create?

- A. The files of `config` directly inside `backup`
- B. `backup/config/` containing the files
- C. An error, because `backup` exists
- D. A file called `backup`

??? question "Answer and explanation"
    **B.** Copying a directory into an existing directory **nests** it. To copy only the contents use `cp -r config/. backup/` (or `Copy-Item config\* backup` in PowerShell). (Day 02)

**5.** Which PowerShell parameter shows what `Remove-Item` **would** delete without deleting anything?

- A. `-Confirm`
- B. `-Force`
- C. `-WhatIf`
- D. `-Preview`

??? question "Answer and explanation"
    **C.** `-WhatIf` simulates the action. `-Confirm` asks before each item, which is useful but still deletes when you answer yes. (Day 02)

**6.** Which command follows a log file that is **rotated** (renamed and recreated) while you watch it?

- A. `tail -f /var/log/syslog`
- B. `tail -F /var/log/syslog`
- C. `head -f /var/log/syslog`
- D. `less /var/log/syslog`

??? question "Answer and explanation"
    **B.** `-F` = `--follow=name --retry`: it reopens the file by name after rotation. `-f` keeps following the old, renamed file. (Day 03)

**7.** What does `command > out.txt 2>&1` do?

- A. Sends only errors to `out.txt`
- B. Sends standard output and standard error to `out.txt`
- C. Appends output to `out.txt`
- D. Sends output to the screen and to the file

??? question "Answer and explanation"
    **B.** First stdout is redirected to the file, then stderr (2) is pointed at the same place as stdout (1). The order matters: `2>&1 > out.txt` would leave errors on the screen. (Day 03)

**8.** Which PowerShell cmdlet returns the **last 20 lines** of a file?

- A. `Get-Content app.log -TotalCount 20`
- B. `Get-Content app.log -Tail 20`
- C. `Get-Content app.log -Last 20`
- D. `Select-String app.log -Tail 20`

??? question "Answer and explanation"
    **B.** `-Tail` reads from the end. `-TotalCount` (alias `-First`/`-Head`) reads from the start. `Select-Object -Last 20` also works but reads the whole file first. (Day 03)

**9.** By default, which is true of `grep` and `Select-String`?

- A. Both are case-insensitive
- B. Both are case-sensitive
- C. `grep` is case-sensitive; `Select-String` is case-insensitive
- D. `grep` is case-insensitive; `Select-String` is case-sensitive

??? question "Answer and explanation"
    **C.** Use `grep -i` to ignore case, and `Select-String -CaseSensitive` to match case. (Day 04)

**10.** Why should you quote the pattern in `find /var/log -name '*.log'`?

- A. `find` requires quotes around every argument
- B. Without quotes, the shell may expand `*.log` against the current directory before `find` sees it
- C. Quotes make the search case-insensitive
- D. Quotes make `find` faster

??? question "Answer and explanation"
    **B.** If the current directory contains `.log` files, the unquoted pattern is replaced by their names and `find` searches for the wrong thing (or fails with *paths must precede expression*). (Day 04)

**11.** Which regular expression matches the whole line `ERROR` exactly and nothing else?

- A. `ERROR`
- B. `^ERROR$`
- C. `*ERROR*`
- D. `[ERROR]`

??? question "Answer and explanation"
    **B.** `^` anchors the start and `$` the end. C is a wildcard (glob) pattern, not a regex, and D is a character class matching one of the letters E, R or O. (Day 04)

**12.** Which command documents the Bash built-in `cd`?

- A. `man cd`
- B. `help cd`
- C. `info cd`
- D. `Get-Help cd`

??? question "Answer and explanation"
    **B.** Built-ins are part of Bash and are documented with `help` (and in `man bash`). (Days 01 and 05)

**13.** What is printed by `false | true; echo $?` in Bash without `set -o pipefail`?

- A. `0`
- B. `1`
- C. `1 0`
- D. `127`

??? question "Answer and explanation"
    **A.** A pipeline's status is that of its **last** command. `${PIPESTATUS[*]}` would show `1 0`. (Day 05)

**14.** Which line runs in Windows PowerShell 5.1 and only lists the folder if it exists?

- A. `Test-Path C:\Temp && Get-ChildItem C:\Temp`
- B. `if (Test-Path C:\Temp) { Get-ChildItem C:\Temp }`
- C. `Test-Path C:\Temp || Get-ChildItem C:\Temp`
- D. `Test-Path C:\Temp ; Get-ChildItem C:\Temp`

??? question "Answer and explanation"
    **B.** `&&` and `||` are parser errors in 5.1 (PowerShell 7+ only). Even in 7, A would run `Get-ChildItem` when the path is missing, because `Test-Path` succeeds and returns `False`. D always runs both commands. (Day 05)

**15.** Why does `Get-Service | Format-Table Name, Status | Export-Csv svc.csv` produce a useless CSV?

- A. Services cannot be exported
- B. `Format-Table` outputs formatting objects, so `Export-Csv` no longer receives service objects
- C. `Export-Csv` needs `-Force`
- D. Only administrators can read services

??? question "Answer and explanation"
    **B.** "Filter left, format right": use `Select-Object Name, Status` before `Export-Csv`, and put `Format-*` only at the end of a pipeline that goes to the screen. (Day 05)

## Part B — Write the command (2 marks each)

Write the command for **both** shells unless the question names one. One mark for a working command, one for using the safe or efficient form described in the lessons.

**16.** List all files in `/etc` (Bash) and `C:\Windows` (PowerShell), including hidden ones, in long format with human-readable sizes in Bash.

??? question "Answer and explanation"
    - Bash: `ls -lah /etc`
    - PowerShell: `Get-ChildItem -Path C:\Windows -Force`

    `-a` / `-Force` include hidden items. PowerShell has no "human-readable" switch; the `Length` property is in bytes. (Days 01–02)

**17.** Create the directory tree `project/{src,docs,logs}` in a single command, so that it does not fail if it already exists.

??? question "Answer and explanation"
    - Bash: `mkdir -p project/{src,docs,logs}`
    - PowerShell: `'src','docs','logs' | ForEach-Object { New-Item -ItemType Directory -Path "project\$_" -Force }`

    `-p` and `-Force` make the command idempotent (safe to run twice). (Day 02)

**18.** Show lines 101 to 110 of `big.log`.

??? question "Answer and explanation"
    - Bash: <code>head -n 110 big.log &#124; tail -n 10</code> (or `sed -n '101,110p' big.log`)
    - PowerShell: <code>Get-Content big.log -TotalCount 110 &#124; Select-Object -Last 10</code> (or `(Get-Content big.log)[100..109]`, which reads the whole file)

    Reading only the first 110 lines is faster on large files. (Day 03)

**19.** Run a command and save its output to `report.txt` **and** show it on screen at the same time.

??? question "Answer and explanation"
    - Bash: <code>df -h &#124; tee report.txt</code> (use `tee -a` to append)
    - PowerShell: <code>Get-PSDrive -PSProvider FileSystem &#124; Tee-Object -FilePath report.txt</code>

    Any command is acceptable; the key is `tee` / `Tee-Object`. (Day 03)

**20.** Find every `.conf` file under `/etc` (Bash) or `.config` file under `C:\ProgramData` (PowerShell) modified in the last 7 days, hiding permission errors.

??? question "Answer and explanation"
    - Bash: `find /etc -type f -name '*.conf' -mtime -7 2>/dev/null`
    - PowerShell: <code>Get-ChildItem C:\ProgramData -Recurse -File -Filter &#42;.config -ErrorAction SilentlyContinue &#124; Where-Object LastWriteTime -gt (Get-Date).AddDays(-7)</code>

    `-Filter` is applied by the file system and is faster than filtering later. (Day 04)

**21.** Count the `Failed password` lines in `auth.log`, then list the source IP addresses ranked by count (Bash), or the matching line count (PowerShell).

??? question "Answer and explanation"
    - Bash count: `grep -c 'Failed password' auth.log`
    - Bash ranking: <code>grep 'Failed password' auth.log &#124; grep -Eo 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' &#124; sort &#124; uniq -c &#124; sort -rn</code>
    - PowerShell count: `(Select-String -Path auth.log -Pattern 'Failed password').Count`

    `sort` must come before `uniq -c`, because `uniq` only collapses adjacent lines. (Days 04–05)

**22.** Find out what the name `ls` refers to, and list every PowerShell alias that points to `Get-ChildItem`.

??? question "Answer and explanation"
    - Bash: `type -a ls` (shows the alias, then `/usr/bin/ls` and `/bin/ls` on Ubuntu)
    - PowerShell: `Get-Command ls -All` and `Get-Alias -Definition Get-ChildItem`

    (Days 01 and 05)

## Part C — Short answer and practical (3 marks each)

**23.** Explain the difference between a **text pipeline** and an **object pipeline**, using one Bash and one PowerShell example that answer the same question.

??? question "Answer and explanation"
    Marking: 1 mark for the concept, 1 for each correct example.

    In Bash, programs pass **bytes/lines of text**, so each stage must know the layout and extract fields (`cut`, `grep`, `awk`). In PowerShell, cmdlets pass **.NET objects** with named properties, so stages work on properties and formatting happens only at the end. Example — five largest files:

    - Bash: <code>ls -lS /var/log &#124; head -n 6</code> (or <code>du -a /var/log 2>/dev/null &#124; sort -rn &#124; head -n 5</code>)
    - PowerShell: <code>Get-ChildItem C:\Windows\Logs -Recurse -File &#124; Sort-Object Length -Descending &#124; Select-Object -First 5 Name, Length</code>

    (Days 01, 05)

**24.** A colleague's monitoring script contains `grep -q 'CRITICAL' /var/log/app.log || echo OK`. Explain the flaw and rewrite it so that it prints `ALERT` (exit 3) on a match, `OK` (exit 0) on no match, and `UNKNOWN` (exit 2) if the log cannot be read.

??? question "Answer and explanation"
    Marking: 1 mark for the flaw, 2 for a working rewrite.

    The flaw: `grep` returns **1** for "no match" and **2** for "error" (for example, the file is missing). `||` treats both the same, so a missing or unreadable log prints `OK`. That hides failures and possibly tampering.

    ```bash
    grep -q 'CRITICAL' /var/log/app.log
    rc=$?
    case $rc in
        0) echo "ALERT: CRITICAL found"; exit 3 ;;
        1) echo "OK"; exit 0 ;;
        *) echo "UNKNOWN: cannot read log" >&2; exit 2 ;;
    esac
    ```

    The PowerShell equivalent tests `Test-Path` first, then uses `Select-String -Quiet`. (Days 04–05)

**25.** **Practical task.** In `~/m1test` / `$HOME\m1test`: (a) create `logs/` and three files `app1.log`, `app2.log`, `notes.txt`; (b) write the line `ERROR disk full` into `app2.log` and `INFO ok` into `app1.log`; (c) list the `.log` files that contain `ERROR`; (d) copy those files into `archive/`; (e) preview, then delete `notes.txt`; (f) save the commands you used from your history to `m1test-history.txt`.

??? question "Answer and explanation"
    Marking: 3 marks if all six parts work, 2 for four or five parts, 1 for two or three. Deduct 1 mark if anything was deleted without a preview.

    ```bash
    mkdir -p ~/m1test/logs ~/m1test/archive && cd ~/m1test
    touch logs/app1.log logs/app2.log logs/notes.txt
    echo 'ERROR disk full' > logs/app2.log
    echo 'INFO ok' > logs/app1.log
    grep -l 'ERROR' logs/*.log                     # (c) logs/app2.log
    grep -l 'ERROR' logs/*.log | xargs -r cp -v -t archive/   # (d)
    ls logs/notes.txt && rm -i logs/notes.txt      # (e)
    history 15 > m1test-history.txt                # (f)
    ```

    ```powershell
    New-Item -ItemType Directory -Path $HOME\m1test\logs, $HOME\m1test\archive -Force | Out-Null
    Set-Location $HOME\m1test
    'app1.log','app2.log','notes.txt' | ForEach-Object { New-Item -ItemType File -Path "logs\$_" -Force | Out-Null }
    Set-Content -Path logs\app2.log -Value 'ERROR disk full'
    Set-Content -Path logs\app1.log -Value 'INFO ok'
    $hits = Get-ChildItem logs -Filter *.log | Select-String -Pattern 'ERROR' -List | Select-Object -ExpandProperty Path
    $hits                                          # (c)
    $hits | Copy-Item -Destination archive -PassThru   # (d)
    Remove-Item logs\notes.txt -WhatIf             # (e) preview
    Remove-Item logs\notes.txt
    Get-History -Count 15 | Select-Object -ExpandProperty CommandLine | Set-Content m1test-history.txt   # (f)
    ```

    Clean up afterwards by previewing and removing only the `m1test` folder. (Days 02–05)

## After the test

| Score (of 38) | What to do next |
|---|---|
| 34–38 | Distinction. Move on to [Module 2](../course/module-2/index.md). |
| 29–33 | Merit. Re-read the lessons for any questions you missed. |
| 23–28 | Pass. Repeat the labs for the days you lost marks on. |
| < 23 | Repeat Labs 02–05 before starting Module 2. |
