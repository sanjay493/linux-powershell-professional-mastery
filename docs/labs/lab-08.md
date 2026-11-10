---
description: "Respond to a 100% CPU alert and a failed web service: find the runaway process, collect evidence, end it safely, diagnose and fix a broken systemd unit, and investigate a Windows service with Bash and PowerShell."
---

# Lab 08: Runaway Process

| Field | Value |
|---|---|
| **Lab ID** | LAB-08 |
| **Related lesson** | [Day 08: Processes and Services](../course/module-2/day-08.md) |
| **Difficulty** | Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Low–Medium. You start and end **only processes you create** (named `lab08-…`), and you create, fix and remove one throwaway systemd unit `lab08-web.service` that listens on `127.0.0.1:8088` only. Take a **VM snapshot** first. Never end processes or stop services you did not create, except the optional Windows step on a lab VM. |

## Objective

At 16:40 the monitoring system raised two alerts for the lab server **ubuntu-lab** (and its Windows sibling **WIN11-LAB**):

- **ALERT-1:** *CPU above 90% for 5 minutes.*
- **ALERT-2 (Linux):** *Internal status page `http://127.0.0.1:8088/` is down* — it is served by `lab08-web.service`.

Your job, as the on-call administrator:

1. Confirm the alert with a repeatable measurement (the course's `process-monitor` script).
2. Identify the process responsible and **collect evidence** before you change anything.
3. Reduce its impact, then end it **gracefully**, escalating only if necessary.
4. Diagnose why the service is down using its status and logs, fix the root cause, and make sure it starts at boot.
5. Write a short incident note with UTC timestamps, then clean up.

On Windows you will repeat steps 1–3 and investigate a service read-only (configuration, dependencies, events), practising changes with `-WhatIf`.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS **VM** with systemd as PID 1, or WSL2 with systemd enabled (`/etc/wsl.conf` → `[boot]` `systemd=true`, then `wsl --shutdown` from Windows). Check: `ps -p 1 -o comm=` must print `systemd`. A user with `sudo` rights. `python3` (installed by default on Ubuntu) and `curl` (`sudo apt install curl` if missing).
- **Windows:** Windows 11 lab VM or PC, Windows PowerShell 5.1 or PowerShell 7. Tasks 1–4 run in a normal window; the optional Task 6b needs an **elevated** window.
- The course repository (for `scripts/linux/process-monitor.sh` and `scripts/powershell/Process-Monitor.ps1`), or copies of those two files.
- Day 08 read; Day 05 (exit codes) and Day 07 (permissions) completed.

## Initial Conditions

- A snapshot exists and you know how to revert it.
- Nothing named `lab08` exists yet:
    - Bash: `pgrep -af lab08; systemctl list-unit-files 'lab08*'; ls -d /opt/lab08` — no process, `0 unit files listed`, and `No such file or directory`.
    - PowerShell: `Get-CimInstance Win32_Process | Where-Object CommandLine -like '*lab08*'` prints nothing.
- Port 8088 is free: `ss -tln | grep ':8088'` prints nothing.
- Evidence folder: `mkdir -p ~/lab08` / `New-Item -ItemType Directory $HOME\lab08 -Force`.

### Set up the scenario (the "incident")

Run this **once**. It plays the role of the faulty software you will investigate later — read it, but pretend you have not seen it.

=== "Linux"

    ```bash
    # 1. A runaway "report generator" (a busy loop) started in the background
    cat > ~/lab08/lab08-report.sh <<'EOF'
    #!/usr/bin/env bash
    # LAB 08 runaway process: burns one CPU core until stopped.
    while :; do :; done
    EOF
    chmod 700 ~/lab08/lab08-report.sh
    nohup ~/lab08/lab08-report.sh > /dev/null 2>&1 &

    # 2. A tiny status web service with a typo in its unit file
    sudo mkdir -p /opt/lab08/www
    echo 'lab08 status: OK' | sudo tee /opt/lab08/www/index.html > /dev/null
    sudo tee /etc/systemd/system/lab08-web.service > /dev/null <<'EOF'
    [Unit]
    Description=LAB 08 internal status page (localhost only)

    [Service]
    User=nobody
    ExecStart=/usr/bin/pyhton3 -m http.server 8088 --bind 127.0.0.1 --directory /opt/lab08/www
    Restart=on-failure
    RestartSec=2

    [Install]
    WantedBy=multi-user.target
    EOF
    sudo systemctl daemon-reload
    sudo systemctl start lab08-web.service     # fails: that is the incident
    ```

=== "Windows"

    ```powershell
    # A runaway "report generator": a busy loop in a minimised Windows PowerShell window
    $cmd = '$host.UI.RawUI.WindowTitle = "lab08-report"; while ($true) {}'
    Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile', '-Command', $cmd -WindowStyle Minimized
    ```

## Step-by-Step Instructions

### Task 1 — Confirm the alert

1. Record the start time in UTC in `~/lab08/incident.txt` (`$HOME\lab08\incident.txt`).
2. Run the course's process monitor with a 90% threshold and save the report in `~/lab08`. Note its **exit code**.
3. Record the load average (Linux) or the number of logical processors (Windows).

### Task 2 — Identify the culprit

1. Find the process with the highest **current** CPU usage (not the lifetime average).
2. Write down its PID.

### Task 3 — Collect evidence before acting

For that PID, save to `~/lab08/evidence.txt` (`$HOME\lab08\evidence.txt`): owner, PID, PPID and the parent's name, full command line, executable path, working directory (Linux), start time, state and nice value / priority class.

### Task 4 — Contain, then end gracefully

1. Lower its priority to the lowest value (nice 19 / `Idle`). Confirm the change.
2. Preview what you will stop (`pgrep -a` / `-WhatIf`).
3. End it with `SIGTERM` (Linux). Wait 5 seconds; use `SIGKILL` **only** if it is still running. On Windows use `Stop-Process`.
4. Verify it has gone and run the process monitor again: the exit code should now be 0 (if nothing else is busy).

### Task 5 — Diagnose and fix the service (Linux)

1. Show the service's state. Is it running? Is it enabled? What exit status did it record?
2. Read its last 20 journal lines and find the root cause.
3. Back up the unit file to `~/lab08/`, fix the problem, reload systemd, and restart the service.
4. Verify: `active (running)`, the main PID is a `python3` process running as `nobody`, and `curl -s http://127.0.0.1:8088/` returns `lab08 status: OK`.
5. Make it start at boot and confirm with `is-enabled`.

### Task 6 — Investigate a service (Windows)

1. **Read-only (6a):** for the **Print Spooler** (`Spooler`) service, show status, start type, binary path, service account, required and dependent services, and the last five SCM events (7036) that mention it.
2. Use `-WhatIf` to preview a restart and a start-type change to `Manual`.
3. **Optional (6b), lab VM only and elevated:** actually restart the Spooler (no print jobs must be waiting) and confirm a new `ProcessId` and two new 7036 events.

### Task 7 — Incident note and clean-up

Append to `incident.txt`: end time (UTC), root causes, actions taken, and one prevention idea for each alert. Then run the [Clean-up](#clean-up).

## Commands to Execute

Try each task yourself first, using the lesson's cheat sheet. The full commands are in the [Solution](#solution).

## Expected Results

- **Task 1:** the monitor lists the busy loop (Linux: `bash /home/<you>/lab08/lab08-report.sh`; Windows: `powershell` with the `lab08-report` command line) at about **100% of one core** and exits with code **3**. Load average climbs towards 1.0 above its normal value.
- **Task 2:** the culprit's PID matches the monitor's top CPU line.
- **Task 3:** `evidence.txt` shows the owner is **your** account and state `R`, nice `0`. The parent is the shell that ran the setup (Linux: your `bash`; if you closed that terminal, the orphan was adopted by `systemd` — PID 1 or your `systemd --user` instance) or the `powershell.exe` you started it from (Windows). The executable is `/usr/bin/bash` — the script name appears only in the command line.
- **Task 4:** after `renice` the `NI` column shows `19`; on Windows `PriorityClass` shows `Idle`. After `SIGTERM` the process is gone (a plain busy loop does not catch `SIGTERM`, so `SIGKILL` is not needed). The second monitor run exits **0**.
- **Task 5:** `systemctl status` shows `failed` / `activating (auto-restart)` with `status=203/EXEC`; the journal says `Failed to locate executable /usr/bin/pyhton3: No such file or directory`. After the fix: `active (running)`, `enabled`, and `curl` prints `lab08 status: OK`.
- **Task 6:** Spooler is `Running`/`Automatic`, binary `C:\Windows\System32\spoolsv.exe`, account `LocalSystem`, requires `RPCSS` and `http`; `-WhatIf` prints *What if: Performing the operation …* lines and changes nothing.

## Verification Steps

=== "Bash"

    ```bash
    pgrep -af lab08-report || echo "OK: runaway process gone"
    systemctl is-active lab08-web ; systemctl is-enabled lab08-web     # active / enabled
    systemctl show lab08-web -p MainPID,User --value
    ps -o user=,cmd= -p "$(systemctl show lab08-web -p MainPID --value)"   # nobody /usr/bin/python3 -m http.server ...
    curl -s http://127.0.0.1:8088/                                      # lab08 status: OK
    ss -tln | grep 127.0.0.1:8088                                       # listening on localhost only
    ls ~/lab08/                                                         # evidence.txt incident.txt lab08-web.service.bak process-monitor-*.txt
    bash ~/linux-powershell-professional-mastery/scripts/linux/process-monitor.sh -n 3 > /dev/null; echo "monitor exit: $?"
    ```

=== "PowerShell"

    ```powershell
    Get-CimInstance Win32_Process | Where-Object CommandLine -like '*lab08-report*' |
        Select-Object ProcessId, CommandLine                       # nothing = gone
    Get-Service Spooler | Select-Object Name, Status, StartType     # unchanged: Running / Automatic
    Get-ChildItem $HOME\lab08                                      # evidence.txt incident.txt Process-Monitor-*.txt
    & $HOME\linux-powershell-professional-mastery\scripts\powershell\Process-Monitor.ps1 -Top 3 | Out-Null
    "monitor exit: $LASTEXITCODE"
    ```

    If you ran the script with `powershell.exe -File …`, read the exit code from `$LASTEXITCODE` in the calling session.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `System has not been booted with systemd as init system (PID 1)` | Container or WSL2 without systemd | Use a VM, or enable systemd in WSL2 (`/etc/wsl.conf`) and `wsl --shutdown` |
| Monitor shows the busy loop below 90% | Another busy process shares the core, or a slow VM | Normal; lower the threshold with `-c 50` / `-CpuThreshold 50` |
| `renice: failed to set priority … Permission denied` when going back to 0 | Normal users can only increase nice values | Not needed for the lab; use `sudo` if you really must |
| `pkill` matched more than the lab process | Pattern too broad | Always `pgrep -af` with the same pattern first; use the full script name |
| `Failed to restart lab08-web.service: Unit lab08-web.service not found.` | Unit file not created or wrong name | `ls /etc/systemd/system/lab08*`; re-run the setup; `sudo systemctl daemon-reload` |
| Service still fails after the fix with the same error | Forgot `daemon-reload` (status warns *unit file changed on disk*) | `sudo systemctl daemon-reload && sudo systemctl restart lab08-web` |
| `OSError: [Errno 98] Address already in use` in the journal | Something else listens on 8088 | `sudo ss -tlnp 'sport = :8088'`; stop your own process or change the port in the unit |
| `curl: (7) Failed to connect to 127.0.0.1 port 8088` | Service not yet active, or failed again | `systemctl status lab08-web`; `journalctl -u lab08-web -n 20` |
| Windows: `Get-Process -IncludeUserName` error about elevated rights | Not elevated | Use `Invoke-CimMethod … -MethodName GetOwner` instead |
| Windows: `sc` writes a file called `qc` | `sc` = `Set-Content` alias in 5.1 | Type `sc.exe` |

## Questions

1. Why did you collect evidence **before** ending the process? Give two pieces of evidence that would be lost.
2. The monitor reported about 100% for the busy loop, but Task Manager on an 8-thread PC shows about 12%. Are both correct?
3. Why did `SIGTERM` end the busy loop without `SIGKILL`, and when would you need `SIGKILL`?
4. What did `status=203/EXEC` tell you before you even read the journal?
5. Why must you run `systemctl daemon-reload` after editing the unit file, and what is the difference between that and `systemctl reload lab08-web`?
6. The unit has `Restart=on-failure`. Why did systemd keep failing, and what does that teach you about restart policies?
7. Why does the unit run as `User=nobody` and bind to `127.0.0.1`?
8. On Windows, why would `Stop-Process -Name svchost` be a bad way to restart a service?
9. Which two prevention measures would you propose for ALERT-1 and ALERT-2?

## Solution

??? success "Bash solution"
    ```bash
    # ---- Task 1: confirm ----
    cd ~/lab08
    echo "Incident start (UTC): $(date -u +%FT%TZ)" > incident.txt
    PM=~/linux-powershell-professional-mastery/scripts/linux/process-monitor.sh
    bash "$PM" -n 5 -c 90 -o ~/lab08 ; echo "monitor exit: $?"     # 3 = threshold breached
    echo "Load average: $(cut -d' ' -f1-3 /proc/loadavg) on $(nproc) cores" >> incident.txt

    # ---- Task 2: identify (current CPU, not the ps lifetime average) ----
    top -b -n 2 -d 1 -o %CPU | awk '/^top -/{n++} n==2' | sed -n '7,10p'
    PID=$(pgrep -f lab08-report.sh)
    echo "Culprit PID: $PID" >> incident.txt

    # ---- Task 3: evidence ----
    {
      echo "== Evidence collected $(date -u +%FT%TZ) by $(whoami) on $(hostname)"
      ps -o user,pid,ppid,ni,stat,%cpu,lstart,etime,cmd -p "$PID"
      echo "Parent: $(ps -o pid=,cmd= -p "$(ps -o ppid= -p "$PID" | tr -d ' ')")"
      echo "cmdline: $(tr '\0' ' ' < /proc/"$PID"/cmdline)"
      ls -l /proc/"$PID"/exe /proc/"$PID"/cwd
      grep -E '^(Name|State|PPid|Uid)' /proc/"$PID"/status
    } > evidence.txt
    cat evidence.txt

    # ---- Task 4: contain, preview, end gracefully ----
    renice -n 19 -p "$PID"
    ps -o pid,ni,stat,cmd -p "$PID"
    pgrep -af lab08-report.sh               # preview: exactly one line expected
    kill -TERM "$PID"
    sleep 5
    if kill -0 "$PID" 2>/dev/null; then
        echo "still running - escalating to SIGKILL" | tee -a incident.txt
        kill -KILL "$PID"
    fi
    pgrep -af lab08-report.sh || echo "process $PID ended with SIGTERM at $(date -u +%FT%TZ)" | tee -a incident.txt
    bash "$PM" -n 5 > /dev/null ; echo "monitor exit: $?"            # 0 expected

    # ---- Task 5: diagnose and fix the service ----
    systemctl status lab08-web --no-pager
    systemctl is-active lab08-web ; systemctl is-enabled lab08-web
    journalctl -u lab08-web -n 20 --no-pager
    #   ... lab08-web.service: Failed to locate executable /usr/bin/pyhton3: No such file or directory
    #   ... lab08-web.service: Main process exited, code=exited, status=203/EXEC
    cp /etc/systemd/system/lab08-web.service ~/lab08/lab08-web.service.bak
    sudo sed -i 's#/usr/bin/pyhton3#/usr/bin/python3#' /etc/systemd/system/lab08-web.service
    diff ~/lab08/lab08-web.service.bak /etc/systemd/system/lab08-web.service
    sudo systemctl daemon-reload
    sudo systemctl restart lab08-web
    systemctl status lab08-web --no-pager
    ps -o user=,pid=,cmd= -p "$(systemctl show lab08-web -p MainPID --value)"
    curl -s http://127.0.0.1:8088/
    sudo systemctl enable lab08-web
    systemctl is-enabled lab08-web

    # ---- Task 7: incident note ----
    cat >> incident.txt <<EOF
    Incident end (UTC): $(date -u +%FT%TZ)
    ALERT-1 root cause: runaway lab08-report.sh (busy loop, PID $PID); reniced to 19, ended with SIGTERM.
    ALERT-2 root cause: typo in ExecStart (/usr/bin/pyhton3) -> status=203/EXEC; unit fixed, reloaded, restarted, enabled.
    Prevention: run report jobs with nice -n 19 and timeout; test unit files with systemd-analyze verify before deploying.
    EOF
    ```

    **Expected output of Task 5 before the fix (example, systemd 255):**

    ```text
    × lab08-web.service - LAB 08 internal status page (localhost only)
         Loaded: loaded (/etc/systemd/system/lab08-web.service; disabled; preset: enabled)
         Active: activating (auto-restart) (Result: exit-code) since Tue 2026-11-10 16:41:07 UTC; 1s ago
        Process: 4180 ExecStart=/usr/bin/pyhton3 -m http.server 8088 --bind 127.0.0.1 --directory /opt/lab08/www (code=exited, status=203/EXEC)
       Main PID: 4180 (code=exited, status=203/EXEC)
            CPU: 2ms
    ```

    The service keeps cycling between *auto-restart* and *failed* every two seconds because `Restart=on-failure` restarts it, but the cause is permanent. After five failures in ten seconds systemd's default start limit stops it with `Result: start-limit-hit`; `sudo systemctl reset-failed lab08-web` clears that once the unit is fixed.

    `systemd-analyze verify /etc/systemd/system/lab08-web.service` would have reported the missing executable before the unit was ever started.

??? success "PowerShell solution"
    ```powershell
    # ---- Task 1: confirm ----
    Set-Location $HOME\lab08
    "Incident start (UTC): $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))" | Out-File incident.txt -Encoding utf8
    $pm = "$HOME\linux-powershell-professional-mastery\scripts\powershell\Process-Monitor.ps1"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pm -Top 5 -CpuThreshold 90 -OutputPath $HOME\lab08
    "monitor exit: $LASTEXITCODE"                                   # 3 = threshold breached
    "Logical processors: $([Environment]::ProcessorCount)" | Add-Content incident.txt

    # ---- Task 2: identify by CURRENT CPU (two samples) ----
    $a = @{}; Get-Process | ForEach-Object { if ($null -ne $_.CPU) { $a[$_.Id] = $_.CPU } }
    Start-Sleep -Seconds 2
    $top = Get-Process | Where-Object { $a.ContainsKey($_.Id) -and $null -ne $_.CPU } |
        Select-Object Id, ProcessName, @{ n = 'CpuPct'; e = { [math]::Round(($_.CPU - $a[$_.Id]) / 2 * 100, 1) } } |
        Sort-Object CpuPct -Descending | Select-Object -First 5
    $top
    $procId = (Get-CimInstance Win32_Process | Where-Object CommandLine -like '*lab08-report*' |
        Where-Object ProcessId -ne $PID | Select-Object -First 1).ProcessId
    "Culprit PID: $procId" | Add-Content incident.txt

    # ---- Task 3: evidence ----
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId = $procId"
    $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($cim.ParentProcessId)"
    $owner = Invoke-CimMethod -InputObject $cim -MethodName GetOwner
    $p = Get-Process -Id $procId
    [pscustomobject]@{
        CollectedUtc   = (Get-Date).ToUniversalTime().ToString('o')
        CollectedBy    = "$env:USERDOMAIN\$env:USERNAME on $env:COMPUTERNAME"
        Owner          = "$($owner.Domain)\$($owner.User)"
        ProcessId      = $cim.ProcessId
        ParentId       = $cim.ParentProcessId
        ParentName     = $(if ($parent) { $parent.Name } else { '(exited)' })
        Executable     = $cim.ExecutablePath
        CommandLine    = $cim.CommandLine
        StartTime      = $p.StartTime
        CpuSeconds     = $p.CPU
        PriorityClass  = $p.PriorityClass
    } | Format-List | Out-File evidence.txt -Encoding utf8
    Get-Content evidence.txt

    # ---- Task 4: contain, preview, end ----
    $p.PriorityClass = 'Idle'
    (Get-Process -Id $procId).PriorityClass                         # Idle
    Stop-Process -Id $procId -WhatIf
    Stop-Process -Id $procId -PassThru | Select-Object Id, ProcessName, HasExited
    Wait-Process -Id $procId -Timeout 10 -ErrorAction SilentlyContinue
    if (-not (Get-Process -Id $procId -ErrorAction SilentlyContinue)) {
        "process $procId ended at $((Get-Date).ToUniversalTime().ToString('o'))" | Add-Content incident.txt
    }
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pm -Top 5 | Out-Null ; "monitor exit: $LASTEXITCODE"

    # ---- Task 6a: investigate Spooler read-only ----
    Get-Service -Name Spooler | Select-Object Name, DisplayName, Status, StartType
    Get-CimInstance Win32_Service -Filter "Name = 'Spooler'" | Select-Object Name, State, StartMode, StartName, PathName, ProcessId
    Get-Service -Name Spooler -RequiredServices
    Get-Service -Name Spooler -DependentServices
    sc.exe qc Spooler
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Service Control Manager'; Id = 7036 } -MaxEvents 200 |
        Where-Object Message -like '*Print Spooler*' | Select-Object -First 5 TimeCreated, Message
    Restart-Service -Name Spooler -WhatIf
    Set-Service -Name Spooler -StartupType Manual -WhatIf

    # ---- Task 6b (optional, elevated, lab VM, no print jobs pending) ----
    $before = (Get-CimInstance Win32_Service -Filter "Name = 'Spooler'").ProcessId
    Restart-Service -Name Spooler -PassThru
    $after = (Get-CimInstance Win32_Service -Filter "Name = 'Spooler'").ProcessId
    "Spooler PID before: $before after: $after"

    # ---- Task 7: incident note ----
    @"
    Incident end (UTC): $((Get-Date).ToUniversalTime().ToString('o'))
    ALERT-1 root cause: runaway lab08-report busy loop (PID $procId); set to Idle priority, ended with Stop-Process.
    Prevention: run report jobs as scheduled tasks with BelowNormal priority and an execution time limit.
    "@ | Add-Content incident.txt
    ```

    **Expected output of Task 6a (example):**

    ```text
    Name    DisplayName   Status StartType
    ----    -----------   ------ ---------
    Spooler Print Spooler Running Automatic

    Name    : Spooler
    State   : Running
    StartMode : Auto
    StartName : LocalSystem
    PathName  : C:\Windows\System32\spoolsv.exe
    ProcessId : 3016

    Status   Name               DisplayName
    ------   ----               -----------
    Running  RPCSS              Remote Procedure Call (RPC)
    Running  http               HTTP Service

    What if: Performing the operation "Restart-Service" on target "Print Spooler (Spooler)".
    What if: Performing the operation "Set-Service" on target "Print Spooler (Spooler)".
    ```

    `-DependentServices` usually returns nothing for Spooler on Windows 11 (fax and print-related services vary by edition).

??? success "Answers to questions"
    1. Ending a process destroys volatile information. Lost evidence includes its full command line and arguments, parent relationship (the parent may also exit), open files and network connections, environment, memory contents and exact runtime state. In a real incident this determines whether it was a bug or an attack.
    2. Yes. The monitor (like Linux `top`) reports percent of **one** logical processor; Task Manager reports percent of **all** processors. 100% ÷ 8 ≈ 12.5%.
    3. The busy loop does not install a handler for `SIGTERM`, so the default action (terminate) applies immediately. `SIGKILL` is needed when a process catches or ignores `SIGTERM` and does not exit — for example a hung application stuck in its clean-up code. It does not help for processes in state `D`.
    4. `203/EXEC` is systemd's own exit status meaning *the executable could not be started* (missing file, wrong path, not executable, wrong architecture). It points at `ExecStart=` rather than at the application's code or configuration.
    5. `daemon-reload` makes **systemd** re-read unit files from disk; without it, systemd still uses the old (broken) definition. `systemctl reload lab08-web` would ask the **service** to reload its own configuration, which this unit does not support (no `ExecReload=`).
    6. `Restart=on-failure` restarts after a failure, but the cause (a typo) was permanent, so it failed every time until the start rate limit stopped it. Restart policies help with transient crashes; they hide, but do not fix, configuration errors — alerts must still fire on repeated restarts.
    7. Least privilege: if the web server were compromised, the attacker would get an unprivileged account with no login shell and no write access to `/opt/lab08/www`. Binding to `127.0.0.1` keeps an internal status page off the network.
    8. Many services share each `svchost.exe` process, so you would stop several unrelated services at once (possibly breaking networking or the user session), the SCM would record crashes instead of clean stops, and dependants would not be stopped in order. Use `Restart-Service` with the service name.
    9. ALERT-1: run batch jobs with `nice -n 19`/`BelowNormal`, wrap them in `timeout` / a scheduled-task time limit, and alert on CPU per process rather than only per host. ALERT-2: validate unit files with `systemd-analyze verify` in deployment, monitor `systemctl is-active` and `systemctl --failed`, and alert on repeated restarts (`NRestarts` property).

## Clean-up

=== "Linux"

    ```bash
    pgrep -af lab08                                  # preview: only lab08 processes
    pkill -f lab08-report.sh                         # in case it is still running
    sudo systemctl disable --now lab08-web.service
    sudo rm -i /etc/systemd/system/lab08-web.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed lab08-web.service 2>/dev/null
    sudo rm -ri /opt/lab08                           # confirm each item
    systemctl list-unit-files 'lab08*'               # 0 unit files listed
    # keep ~/lab08 (your evidence) or remove it after review: rm -rI ~/lab08
    ```

=== "Windows"

    ```powershell
    Get-CimInstance Win32_Process | Where-Object CommandLine -like '*lab08-report*' |
        ForEach-Object { Stop-Process -Id $_.ProcessId -WhatIf }
    # If anything was listed, re-run the line without -WhatIf.
    # If you changed the Spooler start type in Task 6b, restore it:
    # Set-Service -Name Spooler -StartupType Automatic
    # Keep $HOME\lab08 (evidence) or remove it after review:
    # Remove-Item $HOME\lab08 -Recurse -WhatIf
    ```
