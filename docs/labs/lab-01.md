---
description: "Open Bash and PowerShell, identify the system, use built-in help and produce a one-line identity report."
---

# Lab 01: First Contact

| Field | Value |
|---|---|
| **Lab ID** | LAB-01 |
| **Related lesson** | [Day 01: Introduction to Linux and PowerShell](../course/module-1/day-01.md) |
| **Difficulty** | Beginner |
| **Time** | 45–60 minutes |
| **Risk level** | None. Read-only commands only. |

## Objective

Become comfortable opening both shells, identifying exactly **which user, machine, OS and shell** you are working on, and using built-in help to discover command options. You will finish by writing a one-line identity report you could paste into a change ticket.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS (VM, WSL2 or physical) with a normal (non-root) user account.
- **Windows:** Windows 11 with Windows PowerShell 5.1. PowerShell 7 is optional for Task 1.3.
- The course repository downloaded or cloned (for Task 5), or just the two script files from the [Script Library](../projects/scripts.md).

## Initial Conditions

- You are logged in as a normal user, not root or Administrator.
- No files need to exist. You will create one output file in your home directory: `lab01-report.txt`.

## Step-by-Step Instructions

### Task 1 — Open the shells and identify them

=== "Linux"

    1. Press ++ctrl+alt+t++ (or open the Ubuntu tab in Windows Terminal).
    2. Run:

        ```bash
        echo "$SHELL"
        echo "$BASH_VERSION"
        ```

=== "Windows"

    1. Open **Windows PowerShell** (not PowerShell 7) from the Start menu.
    2. Run:

        ```powershell
        $PSVersionTable.PSVersion
        $PSVersionTable.PSEdition
        ```

    3. If PowerShell 7 is installed, run `pwsh` in the same window, repeat both commands, then type `exit` to return.

### Task 2 — Record identity and system facts

=== "Linux"

    ```bash
    whoami
    hostname
    pwd
    uname -r
    uname -m
    grep PRETTY_NAME /etc/os-release
    date -u -Iseconds
    ```

=== "Windows"

    ```powershell
    whoami
    $env:COMPUTERNAME
    Get-Location
    Get-ComputerInfo -Property OsName, OsVersion, OsArchitecture
    (Get-Date).ToUniversalTime().ToString('o')
    ```

### Task 3 — Use help to discover options (no web search)

=== "Linux"

    1. Use `man ls` (search inside with `/`) to find the options for: long format, show hidden files, human-readable sizes, sort by modification time.
    2. Use `ls --help | grep -i -- '--reverse'` to confirm the reverse-sort option.
    3. Run the combined command and list your home directory sorted newest-first, including hidden files.

=== "Windows"

    1. Run `Get-Help Get-ChildItem -Parameter Force` and `Get-Help Get-ChildItem -Parameter Depth`.
    2. Run `Get-Command -Noun ChildItem` and note every command returned.
    3. List your home folder, including hidden items, sorted newest-first:
       `Get-ChildItem $HOME -Force | Sort-Object LastWriteTime -Descending | Select-Object -First 10`

### Task 4 — One-line identity report

Build a single command that prints `user@host | OS | kernel/build | UTC time`, then save it to `lab01-report.txt` in your home directory.

### Task 5 — Compare with the course script

Run the course's system-information script (read it first: never run scripts you have not read):

=== "Linux"

    ```bash
    cd ~/linux-powershell-professional-mastery/scripts/linux
    less system-info.sh          # read it, press q to quit
    bash system-info.sh
    ```

=== "Windows"

    ```powershell
    Set-Location ~\linux-powershell-professional-mastery\scripts\powershell
    Get-Content .\System-Info.ps1 | more
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\System-Info.ps1
    ```

    `-ExecutionPolicy Bypass` applies **only to this one process**. It does not change the machine policy. Execution policy is explained on Day 19.

## Expected Results

- Task 1: Linux shows `/bin/bash` and a version like `5.2.21(1)-release`. Windows PowerShell shows `5.1.x` / `Desktop`, and PowerShell 7 shows `7.x` / `Core`.
- Task 2: seven (Linux) or five (Windows) facts, all matching your machine.
- Task 3: Linux combined command `ls -laht ~`. Windows lists ten items, newest first.
- Task 4: a file containing one line such as `student@ubuntu-lab | Ubuntu 24.04.1 LTS | 6.8.0-48-generic | 2026-11-08T10:15:00+00:00`.
- Task 5: the script prints a report whose user, host, OS and time match your manual results.

## Verification Steps

=== "Linux"

    ```bash
    cat ~/lab01-report.txt
    wc -l ~/lab01-report.txt          # should print 1
    ```

=== "Windows"

    ```powershell
    Get-Content $HOME\lab01-report.txt
    (Get-Content $HOME\lab01-report.txt).Count    # should print 1
    ```

## Troubleshooting

| Problem | Fix |
|---|---|
| `grep: /etc/os-release: No such file or directory` | You are not on Linux (perhaps Git Bash on Windows). Use a real Ubuntu terminal or WSL. |
| `Get-ComputerInfo` is slow | Normal: it queries WMI. Keep `-Property` short. |
| `Get-Help` shows only syntax | Run `Update-Help` in an elevated Windows PowerShell, or use `Get-Help ... -Online`. |
| `.\System-Info.ps1 cannot be loaded because running scripts is disabled` | Use the `powershell.exe -ExecutionPolicy Bypass -File` form shown above (process scope only). |
| `bash: system-info.sh: No such file or directory` | You are in the wrong directory. Use `pwd`, then `cd` to `scripts/linux`. |

## Questions

1. Which PowerShell edition did you open first, and how did you prove it?
2. Is your kernel release the same as your Ubuntu version? Explain the difference.
3. Which `ls` options did you combine in Task 3, and what does each do?
4. Why is the report time in UTC?
5. What did the system-info script report that you did not collect manually?

## Solution

??? success "Show full solution"
    **Task 1**

    ```bash
    echo "$SHELL"          # /bin/bash
    echo "$BASH_VERSION"   # e.g. 5.2.21(1)-release
    ```

    ```powershell
    $PSVersionTable.PSVersion   # Major 5 Minor 1 ...
    $PSVersionTable.PSEdition   # Desktop  (Core in PowerShell 7)
    ```

    **Task 3**

    ```bash
    ls -laht ~     # -l long, -a all (hidden), -h human sizes, -t newest first
    ls -lahtr ~    # -r reverses: oldest first
    ```

    **Task 4 — Linux**

    ```bash
    echo "$(whoami)@$(hostname) | $(. /etc/os-release && echo "$PRETTY_NAME") | $(uname -r) | $(date -u -Iseconds)" > ~/lab01-report.txt
    cat ~/lab01-report.txt
    ```

    `$( ... )` is **command substitution**: Bash runs the inner command and inserts its output. `. /etc/os-release` loads the file's variables (such as `PRETTY_NAME`) into the subshell.

    **Task 4 — Windows**

    ```powershell
    $os = Get-ComputerInfo -Property OsName, OsVersion
    "$env:USERNAME@$env:COMPUTERNAME | $($os.OsName) | $($os.OsVersion) | $((Get-Date).ToUniversalTime().ToString('o'))" |
        Out-File -FilePath $HOME\lab01-report.txt -Encoding utf8
    Get-Content $HOME\lab01-report.txt
    ```

    `$( ... )` inside a double-quoted string is a **subexpression**: PowerShell evaluates it and inserts the result.

    **Answers to questions**

    1. Usually Windows PowerShell 5.1, proven by `$PSVersionTable.PSEdition` = `Desktop`.
    2. No. The kernel release (e.g. `6.8.0-48-generic`) is the Linux kernel version. Ubuntu 24.04 is the distribution version: the whole collection of kernel, tools and packages.
    3. `-l` long listing, `-a` include hidden, `-h` human-readable sizes, `-t` sort by time.
    4. UTC is unambiguous across time zones and daylight-saving changes, and it sorts correctly.
    5. Typically CPU model, core count, memory, disk usage, uptime and IP addresses. These are covered in later days.
