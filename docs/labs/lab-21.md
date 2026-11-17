---
description: "Build a safe change-ticket intake script in Bash and PowerShell: arguments with defaults, prompts only at a terminal, a settings file overridden by the environment, pattern and range validation, a never-echoed approver PIN checked by hash, and a ticket summary file."
---

# Lab 21: Change Ticket Intake

| Field | Value |
|---|---|
| **Lab ID** | LAB-21 |
| **Related lesson** | [Day 21: Variables and User Input](../course/module-5/day-21.md) |
| **Difficulty** | Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Low. Everything is created inside `~/lab21` (Linux) or `$HOME\lab21` (Windows). No root/Administrator rights, no system changes. The approver PIN `2468` is a **lab-only** value, not a real secret. |

## Objective

The operations team wants a small tool that engineers run before every out-of-hours change. It records **which ticket, which host, which change window and which engineer**, and it confirms that an approver typed their PIN — without ever displaying or storing the PIN.

You will build `intake.sh` and `Intake.ps1`, which:

1. take their input from **arguments**, fall back to **prompts** only when a person is at a terminal, and read site defaults from a **settings file** that the **environment** can override;
2. **validate** every value (pattern, range, time format) and refuse to continue with bad input (exit code 1);
3. read the PIN **silently**, compare only its SHA-256 hash, and discard it;
4. write a ticket summary file and report clear errors (exit code 2 when the output cannot be written).

## Required Environment

- **Linux:** Ubuntu 24.04 LTS (VM, WSL2 or physical), Bash 5.x, coreutils (`sha256sum`). Normal user.
- **Windows:** Windows 11 with Windows PowerShell 5.1 and/or PowerShell 7.4+. Normal (non-elevated) user. The PowerShell solution also runs in PowerShell 7 on Linux.
- A text editor that saves Bash scripts with **LF** line endings.

## Initial Conditions

- `~/lab21` / `$HOME\lab21` must **not** exist. Check: `ls -d ~/lab21` should fail; `Test-Path $HOME\lab21` should return `False`. If it exists from an earlier attempt, rename it (`mv ~/lab21 ~/lab21.old`) rather than deleting it.
- Nothing else is required. You will create:

```text
lab21/
├── Q4 change plan.txt     (Task 1 only)
├── site.env / site.psd1   (settings)
├── intake.sh / Intake.ps1 (the tool)
└── tickets/               (output)
```

## Step-by-Step Instructions

### Task 1 — Quoting and expansion warm-up

=== "Linux"

    ```bash
    mkdir -p ~/lab21 && cd ~/lab21
    touch "Q4 change plan.txt"
    f="Q4 change plan.txt"
    ls $f          # observe the error
    ls "$f"        # correct
    path="$HOME/lab21/tickets/CHG-104233.txt"
    echo "${path##*/}"   "${path%/*}"   "${path%.txt}.bak"
    echo "${ENGINEER:-$USER}"
    ```

    Write down what each expansion printed and why the unquoted `ls $f` failed.

=== "Windows"

    ```powershell
    New-Item -Path $HOME\lab21 -ItemType Directory | Out-Null
    Set-Location $HOME\lab21
    New-Item -Path 'Q4 change plan.txt' -ItemType File | Out-Null
    $f = 'Q4 change plan.txt'
    Get-Item $f                    # works: no word splitting in PowerShell
    $path = Join-Path $HOME 'lab21\tickets\CHG-104233.txt'
    Split-Path $path -Leaf; Split-Path $path -Parent
    [System.IO.Path]::ChangeExtension($path, '.bak')
    if ($env:ENGINEER) { $env:ENGINEER } else { [Environment]::UserName }
    ```

### Task 2 — Create the settings file

Create a settings file that holds site defaults. The **environment wins** over the file, so an operator can run `SITE=DR-Pune ./intake.sh ...` without editing anything.

=== "Linux"

    Create `~/lab21/site.env`:

    ```bash
    # Lab 21 site defaults. Values already set in the environment win.
    SITE="${SITE:-Mumbai-DC1}"
    DEFAULT_DURATION="${DEFAULT_DURATION:-60}"
    OUTPUT_DIR="${OUTPUT_DIR:-$HOME/lab21/tickets}"
    # SHA-256 of the lab-only approver PIN 2468 (never store the PIN itself)
    PIN_SHA256="a1fb4e703a9ef1fa4936801721ff285a97ac85330856674412e054892afe6972"
    ```

    Prove the hash yourself: `printf '%s' 2468 | sha256sum`. (`printf` is a Bash built-in, so the value never appears in the process list.)

=== "Windows"

    Create `$HOME\lab21\site.psd1` (a PowerShell data file: it can hold only data, never code, which makes it safe to load):

    ```powershell
    @{
        Site            = 'Mumbai-DC1'
        DefaultDuration = 60
        OutputSubDir    = 'lab21\tickets'
        # SHA-256 of the lab-only approver PIN 2468
        PinSha256       = 'a1fb4e703a9ef1fa4936801721ff285a97ac85330856674412e054892afe6972'
    }
    ```

### Task 3 — Accept input from arguments, with defaults and prompts

Write the first part of the tool:

- Arguments (Bash positional: `TICKET HOST START DURATION`; PowerShell named: `-Ticket -ComputerName -Start -Duration -Pin`).
- `DURATION` defaults to the setting; the engineer comes from `ENGINEER` or the current user name.
- When a required value is missing **and** a person is at a terminal, prompt for it. When there is no terminal (cron, pipeline, Task Scheduler), do not hang: fail validation instead.

### Task 4 — Validate every value

| Value | Rule |
|---|---|
| Ticket | `CHG-` followed by exactly 6 digits |
| Host | Short host name: letters, digits, hyphens; 1–63 characters; does not start or end with `-` |
| Start | `HH:MM`, 24-hour, `00:00`–`23:59` |
| Duration | Whole minutes, 15–240 (beware of leading zeros in Bash) |

On any failure, print a clear `ERROR:` message to **standard error** and exit with code **1**.

### Task 5 — Read the approver PIN without echoing it

- Interactive: `read -r -s` / `Read-Host -AsSecureString`.
- Non-interactive test mode: Bash reads the PIN from **standard input**; PowerShell accepts a `SecureString` in `-Pin`.
- Hash the PIN with SHA-256, compare with the stored hash, then **unset/clear** the plain value. Wrong PIN → exit 1.

### Task 6 — Write the ticket summary

Calculate the window end time (it may cross midnight), and write `tickets/<TICKET>.txt` with aligned fields: Ticket, Host (lower case), Site, Window, Engineer, Approved, Recorded (UTC ISO 8601). If the output directory cannot be created or written, exit with code **2**.

### Task 7 — Test like an auditor

Run the tool with valid input, each kind of invalid input, a wrong PIN, no input at all, an environment override, and an unwritable output directory. Then prove that the PIN never reached the output files.

## Commands to Execute

Try to write the tools yourself first; the full scripts are in the [Solution](#solution). Test commands:

=== "Linux"

    ```bash
    cd ~/lab21
    chmod +x intake.sh && bash -n intake.sh && echo "syntax OK"
    echo 2468 | ./intake.sh CHG-104233 WEB-01 22:30 90 ; echo "exit=$?"
    cat tickets/CHG-104233.txt
    echo 2468 | ./intake.sh CHG-1042   web-01   22:30     ; echo "exit=$?"
    echo 2468 | ./intake.sh CHG-104233 "web 01" 22:30     ; echo "exit=$?"
    echo 2468 | ./intake.sh CHG-104233 web-01   24:10     ; echo "exit=$?"
    echo 2468 | ./intake.sh CHG-104233 web-01   23:30 08  ; echo "exit=$?"
    echo 2468 | ./intake.sh CHG-104233 web-01   23:30 300 ; echo "exit=$?"
    echo 1111 | ./intake.sh CHG-104234 web-02   23:30     ; echo "exit=$?"
    ./intake.sh CHG-104235 < /dev/null                    ; echo "exit=$?"
    echo 2468 | SITE=DR-Pune ENGINEER=asha ./intake.sh CHG-104236 db-01 23:30 45
    cat tickets/CHG-104236.txt
    echo 2468 | OUTPUT_DIR=/proc/lab21 ./intake.sh CHG-104237 db-01 23:30 ; echo "exit=$?"
    grep -rc 2468 tickets/ ; echo "grep exit=$?"
    ./intake.sh            # interactive run in a terminal: answer the prompts
    ```

=== "Windows"

    ```powershell
    Set-Location $HOME\lab21
    $testPin = ConvertTo-SecureString '2468' -AsPlainText -Force    # lab-only PIN; never do this with a real secret
    .\Intake.ps1 -Ticket CHG-104233 -ComputerName WEB-01 -Start 22:30 -Duration 90 -Pin $testPin; "exit=$LASTEXITCODE"
    Get-Content .\tickets\CHG-104233.txt
    .\Intake.ps1 -Ticket CHG-1042 -ComputerName web-01 -Start 22:30 -Pin $testPin
    .\Intake.ps1 -Ticket CHG-104233 -ComputerName 'web 01' -Start 22:30 -Pin $testPin
    .\Intake.ps1 -Ticket CHG-104233 -ComputerName web-01 -Start 24:10 -Pin $testPin
    .\Intake.ps1 -Ticket CHG-104233 -ComputerName web-01 -Start 23:30 -Duration 300 -Pin $testPin
    .\Intake.ps1 -Ticket CHG-104234 -ComputerName web-02 -Start 23:30 -Pin (ConvertTo-SecureString '1111' -AsPlainText -Force); "exit=$LASTEXITCODE"
    $env:SITE = 'DR-Pune'; $env:ENGINEER = 'asha'
    .\Intake.ps1 -Ticket CHG-104236 -ComputerName db-01 -Start 23:30 -Duration 45 -Pin $testPin
    Remove-Item Env:SITE, Env:ENGINEER
    Get-Content .\tickets\CHG-104236.txt
    Select-String -Path .\tickets\*.txt -Pattern '2468' ; "matches: $(@(Select-String -Path .\tickets\*.txt -Pattern '2468').Count)"
    powershell.exe -NoProfile -NonInteractive -File .\Intake.ps1 ; "exit=$LASTEXITCODE"
    .\Intake.ps1           # interactive run: answer the prompts
    ```

    Validation errors raised while binding parameters stop the script before its first line runs. In the interactive console `$LASTEXITCODE` is not updated by them; when the script is started with `powershell.exe -File` / `pwsh -File` (as a scheduler would), the process exit code is `1`.

## Expected Results

The Bash results below were captured from the solution script on Ubuntu 24.04.5 (Bash 5.2.21, container; the user name was not set there, so `ENGINEER`/`USER` is shown here as `student`, and the path prefix as `/home/student`). PowerShell results are **examples**.

**Bash (captured):**

```text
syntax OK
Saved /home/student/lab21/tickets/CHG-104233.txt
exit=0
Ticket:    CHG-104233
Host:      web-01
Site:      Mumbai-DC1
Window:    22:30-00:00 (90 min)
Engineer:  student
Approved:  yes (PIN verified)
Recorded:  2026-11-17T16:48:05Z
ERROR: ticket 'CHG-1042' must look like CHG-123456
exit=1
ERROR: host 'web 01' is not a valid short host name
exit=1
ERROR: start '24:10' must be HH:MM (00:00-23:59)
exit=1
ERROR: duration '08' must be 15-240 minutes
exit=1
ERROR: duration '300' must be 15-240 minutes
exit=1
ERROR: approver PIN rejected
exit=1
ERROR: host '' is not a valid short host name
exit=1
Saved /home/student/lab21/tickets/CHG-104236.txt
Ticket:    CHG-104236
Host:      db-01
Site:      DR-Pune
Window:    23:30-00:15 (45 min)
Engineer:  asha
Approved:  yes (PIN verified)
Recorded:  2026-11-17T16:48:05Z
ERROR: cannot create /proc/lab21
exit=2
tickets/CHG-104236.txt:0
tickets/CHG-104233.txt:0
grep exit=1
```

Note that `08` is rejected because it is **below 15**, not because of the octal trap: the script uses `10#$duration` so `08` is read as eight.

**PowerShell (example):**

```text
Saved C:\Users\student\lab21\tickets\CHG-104233.txt
exit=0
Ticket:    CHG-104233
Host:      web-01
Site:      Mumbai-DC1
Window:    22:30-00:00 (90 min)
Engineer:  student
Approved:  yes (PIN verified)
Recorded:  2026-11-17T16:48:05Z
Intake.ps1: Cannot validate argument on parameter 'Ticket'. The argument "CHG-1042" does not match the "^CHG-\d{6}$" pattern. ...
Intake.ps1: Cannot validate argument on parameter 'ComputerName'. The argument "web 01" does not match the ... pattern. ...
Intake.ps1: Cannot validate argument on parameter 'Start'. The argument "24:10" does not match the ... pattern. ...
Intake.ps1: Cannot validate argument on parameter 'Duration'. The 300 argument is greater than the maximum allowed range of 240. ...
ERROR: approver PIN rejected
exit=1
Saved C:\Users\student\lab21\tickets\CHG-104236.txt
Ticket:    CHG-104236
Host:      db-01
Site:      DR-Pune
...
matches: 0
ERROR: Ticket is required (no terminal to prompt)
exit=1
```

## Verification Steps

=== "Linux"

    ```bash
    cd ~/lab21
    ls tickets/                                  # CHG-104233.txt  CHG-104236.txt only
    grep -c . tickets/CHG-104233.txt             # 7 lines
    grep -rq 2468 tickets/ && echo "LEAK" || echo "no PIN in output"
    grep -n 'read -r -s' intake.sh               # silent read present
    grep -n '"\$' intake.sh | head               # variables are quoted
    bash -n intake.sh && echo "syntax OK"
    ```

=== "Windows"

    ```powershell
    Set-Location $HOME\lab21
    Get-ChildItem .\tickets -Name                                   # CHG-104233.txt, CHG-104236.txt
    (Get-Content .\tickets\CHG-104233.txt).Count                    # 7
    if (Select-String -Path .\tickets\*.txt -Pattern '2468' -Quiet) { 'LEAK' } else { 'no PIN in output' }
    Select-String -Path .\Intake.ps1 -Pattern 'AsSecureString'      # secure prompt present
    $tokens = $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile("$PWD\Intake.ps1", [ref]$tokens, [ref]$errs); "parse errors: $($errs.Count)"
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `site.env: No such file or directory` | Script run from another directory and the path is relative | The solution builds the path from `BASH_SOURCE[0]`; PowerShell uses `$PSScriptRoot` |
| `$'\r': command not found` | `intake.sh` or `site.env` saved with CRLF endings | `sed -i 's/\r$//' intake.sh site.env` |
| Valid PIN rejected in Bash | `echo` added a newline into the hash, or the stored hash has a typo | Hash with `printf '%s'`; re-run <code>printf '%s' 2468 &#124; sha256sum</code> and compare |
| Script waits forever in a pipeline | Prompting without checking for a terminal | Only `read -p` when `[[ -t 0 ]]` is true |
| `duration '09' must be 15-240` but you expected *value too great for base* | The solution already forces base 10 with `10#` | Correct behaviour — the value is simply below 15 |
| `Intake.ps1 cannot be loaded because running scripts is disabled` | Execution policy | `powershell.exe -ExecutionPolicy Bypass -File .\Intake.ps1 ...` (process only), see Day 19 |
| `Import-PowerShellDataFile` not recognised | Very old PowerShell | It exists in 5.0+; check `$PSVersionTable` |
| PowerShell hash never matches | Comparing with different case, or hashing a `SecureString` object instead of its text | Compare lower-case hex; convert with `NetworkCredential` first (see solution) |
| `Read and Prompt functionality is not available` | `-NonInteractive` session with a missing parameter | Expected — the tool must receive all values as parameters in automation |

## Questions

1. Why does the Bash tool check `[[ -t 0 ]]` before prompting, and what would happen in cron without that check?
2. In `site.env`, why is `SITE="${SITE:-Mumbai-DC1}"` better than `SITE="Mumbai-DC1"`?
3. Why is the PIN compared by hash, and why is `printf '%s' "$pin" | sha256sum` acceptable while `sha256sum <<< "$pin"` would give a different result?
4. What does `10#$duration` protect against? Give an input that would break without it.
5. Why does the PowerShell solution use `Import-PowerShellDataFile` rather than dot-sourcing a `.ps1` settings file?
6. In the PowerShell solution, assigning a prompted value to `$Ticket` re-runs the `ValidatePattern` check. Why is that useful?
7. Which exit codes does the tool use, and why would a scheduler or wrapper script care about the difference between 1 and 2?
8. Name two places where the approver PIN could still leak if an engineer used the tool carelessly.

## Solution

??? success "Bash solution (`intake.sh`)"
    ```bash
    #!/usr/bin/env bash
    # intake.sh - Lab 21 change-ticket intake (writes only under ~/lab21)
    # Usage: ./intake.sh [TICKET] [HOST] [START_HH:MM] [DURATION_MIN]
    #        The approver PIN is prompted silently, or read from standard input when there is no terminal.
    # Exit codes: 0 = saved, 1 = invalid or missing input, 2 = cannot write output
    set -o nounset -o pipefail

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=/dev/null
    source "$script_dir/site.env"

    ask() {            # ask VAR "Prompt" : prompt only when a person is at a terminal
        local __var=$1 __prompt=$2 __val=""
        if [[ -t 0 ]]; then read -r -p "$__prompt: " __val; fi
        printf -v "$__var" '%s' "$__val"
    }

    ticket="${1:-}";  [[ -n $ticket ]] || ask ticket "Ticket (CHG-nnnnnn)"
    host="${2:-}";    [[ -n $host ]]   || ask host   "Target host"
    start="${3:-}";   [[ -n $start ]]  || ask start  "Window start (HH:MM, 24h)"
    duration="${4:-$DEFAULT_DURATION}"
    engineer="${ENGINEER:-${USER:-unknown}}"

    fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
    [[ $ticket =~ ^CHG-[0-9]{6}$ ]]                             || fail "ticket '$ticket' must look like CHG-123456"
    [[ $host =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] || fail "host '$host' is not a valid short host name"
    [[ $start =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]             || fail "start '$start' must be HH:MM (00:00-23:59)"
    [[ $duration =~ ^[0-9]+$ ]] && (( 10#$duration >= 15 && 10#$duration <= 240 )) \
                                                                || fail "duration '$duration' must be 15-240 minutes"
    duration=$(( 10#$duration ))

    pin=""
    if [[ -t 0 ]]; then read -r -s -p "Approver PIN: " pin; echo >&2
    else read -r pin || true; fi                 # non-interactive: PIN on standard input
    pin_hash="$(printf '%s' "$pin" | sha256sum | cut -d' ' -f1)"
    unset pin
    [[ $pin_hash == "$PIN_SHA256" ]] || fail "approver PIN rejected"

    start_min=$(( 10#${start%%:*} * 60 + 10#${start##*:} ))
    end_min=$(( (start_min + duration) % 1440 ))
    printf -v end '%02d:%02d' $(( end_min / 60 )) $(( end_min % 60 ))

    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || { echo "ERROR: cannot create $OUTPUT_DIR" >&2; exit 2; }
    out="$OUTPUT_DIR/$ticket.txt"
    {
        printf '%-10s %s\n' "Ticket:" "$ticket" "Host:" "${host,,}" "Site:" "$SITE" \
            "Window:" "$start-$end ($duration min)" "Engineer:" "$engineer" \
            "Approved:" "yes (PIN verified)" "Recorded:" "$(date -u +%FT%TZ)"
    } > "$out" 2>/dev/null || { echo "ERROR: cannot write $out" >&2; exit 2; }
    echo "Saved $out"
    ```

    Key points:

    - `printf -v "$__var"` assigns to the variable **named** by the first argument, so one `ask` helper fills `ticket`, `host` or `start` (functions are covered on Day 23).
    - `printf '%s\n'` reuses its format for every pair of arguments, printing seven aligned lines from one call.
    - Every expansion is quoted; `--` after `mkdir -p` stops an output directory that begins with `-` from being read as an option.
    - The `(( ... ))` range check runs only after the regular expression has confirmed the value is all digits, so text such as `abc` never reaches arithmetic.

??? success "PowerShell solution (`Intake.ps1`)"
    ```powershell
    <#
    .SYNOPSIS
        Lab 21 change-ticket intake (writes only under $HOME\lab21).
    .DESCRIPTION
        Records ticket, host, change window and engineer after verifying the approver PIN by SHA-256 hash.
        Exit codes: 0 = saved, 1 = invalid or missing input, 2 = cannot write output.
    .EXAMPLE
        .\Intake.ps1 -Ticket CHG-104233 -ComputerName web-01 -Start 22:30 -Duration 90
    #>
    [CmdletBinding()]
    param(
        [ValidatePattern('^CHG-\d{6}$')]
        [string]$Ticket,

        [ValidatePattern('^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$')]
        [string]$ComputerName,

        [ValidatePattern('^([01]\d|2[0-3]):[0-5]\d$')]
        [string]$Start,

        [ValidateRange(15, 240)]
        [int]$Duration,

        [securestring]$Pin
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function Stop-Intake([string]$Message, [int]$Code) {
        [Console]::Error.WriteLine("ERROR: $Message")
        exit $Code
    }

    $settings = Import-PowerShellDataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath 'site.psd1')
    $site     = if ($env:SITE)     { $env:SITE }     else { $settings.Site }
    $outDir   = if ($env:OUTPUT_DIR) { $env:OUTPUT_DIR } else { Join-Path -Path $HOME -ChildPath $settings.OutputSubDir }
    $engineer = if ($env:ENGINEER) { $env:ENGINEER } else { [Environment]::UserName }
    if (-not $PSBoundParameters.ContainsKey('Duration')) { $Duration = $settings.DefaultDuration }

    $interactive = [Environment]::UserInteractive -and -not ([Environment]::GetCommandLineArgs() -match '^-NonI')
    try {
        # Assigning to a parameter variable re-runs its validation attribute.
        if (-not $Ticket)       { if ($interactive) { $Ticket = Read-Host -Prompt 'Ticket (CHG-nnnnnn)' }       else { Stop-Intake 'Ticket is required (no terminal to prompt)' 1 } }
        if (-not $ComputerName) { if ($interactive) { $ComputerName = Read-Host -Prompt 'Target host' }          else { Stop-Intake 'ComputerName is required (no terminal to prompt)' 1 } }
        if (-not $Start)        { if ($interactive) { $Start = Read-Host -Prompt 'Window start (HH:MM, 24h)' }   else { Stop-Intake 'Start is required (no terminal to prompt)' 1 } }
        if (-not $Pin)          { if ($interactive) { $Pin = Read-Host -Prompt 'Approver PIN' -AsSecureString } else { Stop-Intake 'Pin is required (no terminal to prompt)' 1 } }
    }
    catch {
        Stop-Intake $_.Exception.Message 1      # a prompted value failed its validation attribute
    }

    # Convert the SecureString only for the moment needed to hash it.
    $plain = [System.Net.NetworkCredential]::new('', $Pin).Password
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    $hash  = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($plain)) | ForEach-Object { $_.ToString('x2') })
    $plain = $null
    $sha.Dispose()
    if ($hash -ne $settings.PinSha256) { Stop-Intake 'approver PIN rejected' 1 }

    $startTime = [datetime]::ParseExact($Start, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    $end       = $startTime.AddMinutes($Duration).ToString('HH:mm')

    try {
        New-Item -Path $outDir -ItemType Directory -Force | Out-Null
        $out = Join-Path -Path $outDir -ChildPath "$Ticket.txt"
        $lines = @(
            '{0,-10} {1}' -f 'Ticket:',   $Ticket
            '{0,-10} {1}' -f 'Host:',     $ComputerName.ToLower()
            '{0,-10} {1}' -f 'Site:',     $site
            '{0,-10} {1}' -f 'Window:',   "$Start-$end ($Duration min)"
            '{0,-10} {1}' -f 'Engineer:', $engineer
            '{0,-10} {1}' -f 'Approved:', 'yes (PIN verified)'
            '{0,-10} {1}' -f 'Recorded:', [datetime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
        )
        Set-Content -Path $out -Value $lines -Encoding utf8
    }
    catch {
        Stop-Intake "cannot write output: $($_.Exception.Message)" 2
    }
    Write-Output "Saved $out"
    ```

    Key points:

    - Parameters are **optional** so the script can prompt, but each carries a validation attribute. Because validation attributes stay attached to the variable, `$Ticket = Read-Host ...` with a bad answer throws a validation error, which the `catch` block turns into exit code 1.
    - The interactive check combines `[Environment]::UserInteractive` with a look for `-NonInteractive` on the command line, so Task Scheduler and CI runs fail fast instead of waiting.
    - `[System.Net.NetworkCredential]::new('', $Pin).Password` is the supported way to read a `SecureString` in both 5.1 and 7; the plain text lives only for one line.
    - Errors go to the **error stream** via `[Console]::Error` so that callers can separate them from the `Saved ...` output.
    - `'{0,-10} {1}' -f` aligns the fields exactly like the Bash `printf '%-10s %s\n'`.

??? success "Answers to questions"
    1. `[[ -t 0 ]]` is true only when standard input is a terminal. Under cron, standard input is not a terminal; without the check `read -p` would read nothing (or block on an open pipe), and the operator would get a confusing failure — or none at all. With the check the value stays empty and validation fails clearly with exit code 1.
    2. The `:-` form keeps any value already in the environment, so `SITE=DR-Pune ./intake.sh` overrides the default without editing the file. A plain assignment would overwrite the operator's choice.
    3. Storing or comparing a hash means the real PIN is never written anywhere. `printf '%s'` hashes exactly the characters typed; a here-string (`<<<`) appends a newline, so the hash would differ. Because `printf` is a Bash built-in, the PIN is not visible in `ps` as a command argument.
    4. It forces base 10. Without it, durations or times such as `08` or `09` cause *value too great for base*, and `010` would be read as octal 8.
    5. A `.psd1` data file can only contain literal data, so loading it cannot execute code; dot-sourcing a `.ps1` would run anything inside it with the script's rights.
    6. The same rule protects every path into the variable — command line and prompt — so there is no way to bypass validation by leaving the parameter out.
    7. 0 = saved, 1 = bad or missing input (a person must fix the request), 2 = environment problem (disk, permissions). A wrapper can retry or alert operations on 2 but return the ticket to the requester on 1.
    8. Any two of: typing it as a command-line argument (history, `ps`, event 4688), using `ConvertTo-SecureString -AsPlainText` with a real PIN in a saved script, `echo`ing it while debugging, exporting it as an environment variable, piping it from a file that other users can read.

??? success "Clean-up"
    ```bash
    rm -ri ~/lab21          # review each prompt; or keep the folder for Lab 22
    ```

    ```powershell
    Remove-Item -Path $HOME\lab21 -Recurse -WhatIf    # preview first
    Remove-Item -Path $HOME\lab21 -Recurse
    ```
