---
description: "Module 2 test (Days 6–10): 25 questions on users and groups, permissions and ACLs, processes and services, disks and filesystems, and package management in Bash and PowerShell, with a collapsible answer key and a practical task."
---

# Module 2 Test: System Administration

| | |
|---|---|
| **Covers** | [Day 06](../course/module-2/day-06.md) – [Day 10](../course/module-2/day-10.md) |
| **Questions** | 25: 15 multiple choice (1 mark each), 7 command-writing (2 marks each), 3 short-answer and practical (3 marks each) |
| **Total** | 38 marks · pass mark 23 (60%) |
| **Time** | 75 minutes, closed book except for built-in help (`man`, `--help`, `Get-Help`) |
| **Environment** | For Part C you need an Ubuntu 24.04 **VM** with `sudo` (and/or a Windows 11 lab VM with an elevated PowerShell window). Take a snapshot first and work only with the names given in the task (`m2test…`). |

Answer every question before opening the answers. Each answer explains *why*, so use the key to learn, not only to mark. Grade with the table on the [Assessments](index.md#grading-guidance) page.

## Part A — Multiple choice (1 mark each)

**1.** Which file stores the **password hashes** of local Linux accounts?

- A. `/etc/passwd`
- B. `/etc/shadow`
- C. `/etc/group`
- D. `/etc/login.defs`

??? question "Answer and explanation"
    **B.** `/etc/passwd` is world-readable and holds an `x` placeholder in the password field; the hashes and ageing data are in `/etc/shadow`, readable only by root (and the `shadow` group). `/etc/login.defs` holds defaults such as UID ranges. (Day 06)

**2.** `sudo usermod -G developers alice` was run instead of `sudo usermod -aG developers alice`. What happened?

- A. Nothing different; `-a` is optional
- B. Alice was added to `developers` **and removed from all her other supplementary groups**
- C. Alice's primary group became `developers`
- D. The command failed

??? question "Answer and explanation"
    **B.** `-G` **replaces** the supplementary group list; `-a` (append) is required to add one group while keeping the others. Losing `sudo` or `adm` membership this way is a classic outage. The primary group is changed with `-g`. (Day 06)

**3.** Which PowerShell cmdlet disables a local account without deleting it (Windows PowerShell 5.1 or PowerShell 7 on Windows)?

- A. `Remove-LocalUser`
- B. `Set-LocalUser -Enabled $false`
- C. `Disable-LocalUser`
- D. `Lock-LocalUser`

??? question "Answer and explanation"
    **C.** `Disable-LocalUser -Name alice` sets the account disabled and keeps its SID, profile and group memberships for a later decision. `Set-LocalUser` has no `-Enabled` parameter, `Remove-LocalUser` deletes, and `Lock-LocalUser` does not exist. (Day 06)

**4.** A file has permissions `-rw-r-----`, owner `root`, group `adm`. Who can read it?

- A. Everyone
- B. Only root
- C. Root and members of the `adm` group
- D. Members of `adm` only

??? question "Answer and explanation"
    **C.** `rw-` for the owner, `r--` for the group, `---` for others = `640`. Root can read everything anyway; members of `adm` may read; others may not. This is how Ubuntu protects `/var/log/auth.log`. (Day 07)

**5.** What is the numeric mode for `rwxr-x---`?

- A. `755`
- B. `750`
- C. `740`
- D. `640`

??? question "Answer and explanation"
    **B.** `rwx` = 4+2+1 = 7, `r-x` = 4+1 = 5, `---` = 0. (Day 07)

**6.** On NTFS, a user is a member of two groups: one has an **Allow Modify** ACE on a folder, the other an **explicit Deny Write** ACE on the same folder. What is the effective result for writing?

- A. Allowed, because Allow Modify includes Write
- B. Denied, because an explicit Deny takes precedence over an Allow at the same level
- C. Depends on which group was added first
- D. Allowed only for the folder owner

??? question "Answer and explanation"
    **B.** Explicit Deny ACEs are evaluated before Allow ACEs at the same level, so the write is denied. (An explicit Allow can override an **inherited** Deny, which is why inheritance matters.) (Day 07)

**7.** What does `%CPU` in `ps aux` show?

- A. The CPU usage during the last second
- B. The average CPU usage since the process started (CPU time ÷ elapsed time)
- C. Total CPU seconds used
- D. The process priority

??? question "Answer and explanation"
    **B.** `ps` calculates `%CPU` over the whole lifetime of the process, so a process that just became busy can look idle. `top` (from its second frame) or the course's `process-monitor` script sample current usage. PowerShell's `CPU` column is total seconds. (Day 08)

**8.** Which signal should you send **first** to ask a misbehaving Linux process to exit cleanly?

- A. `SIGKILL` (9)
- B. `SIGTERM` (15)
- C. `SIGSTOP` (19)
- D. `SIGCONT` (18)

??? question "Answer and explanation"
    **B.** `SIGTERM` (the default of `kill`) lets the process clean up (flush files, remove locks). `SIGKILL` cannot be caught and is the last resort. `SIGSTOP`/`SIGCONT` pause and resume. (Day 08)

**9.** Which command shows the last 50 log lines of the systemd service `nginx`?

- A. `systemctl log nginx -n 50`
- B. `journalctl -u nginx -n 50`
- C. `tail -n 50 /var/log/systemd/nginx`
- D. `service nginx logs 50`

??? question "Answer and explanation"
    **B.** `journalctl -u UNIT` filters the journal by unit; `-n 50` limits the lines (`-f` follows, `--since` limits time). `systemctl status nginx` also shows the most recent lines. (Day 08)

**10.** `df -h /data` shows 100% used, but `sudo du -sh /data` shows only 40% of the size. What is the **first** thing to check?

- A. `df -i /data`
- B. `sudo lsof +L1` for deleted files that are still open
- C. `sudo fsck /data` while it is mounted
- D. `lsblk -f`

??? question "Answer and explanation"
    **B.** A large `df`–`du` gap usually means deleted-but-open files (a service still writing to a log that was deleted). Restarting or reloading the owner frees the space. `df -i` diagnoses a different symptom (no inodes), and `fsck` on a mounted filesystem is dangerous. (Day 09)

**11.** Why should `/etc/fstab` entries for data disks use `UUID=…` and `nofail`?

- A. UUIDs are shorter than device names
- B. Device names such as `/dev/sdb1` can change between boots; `nofail` lets the boot continue if the disk is missing
- C. `nofail` makes the disk read-only
- D. systemd ignores lines without UUIDs

??? question "Answer and explanation"
    **B.** The UUID belongs to the filesystem, so it is stable; `nofail` prevents emergency mode when a non-essential disk is absent. Verify edits with `sudo findmnt --verify` and `sudo mount -a` before rebooting. (Day 09)

**12.** Which PowerShell pipeline walks from drive letter `D` to the physical disk it is stored on?

- A. `Get-PSDrive D | Get-Disk`
- B. `Get-Volume -DriveLetter D | Get-Partition | Get-Disk`
- C. `Get-Disk -DriveLetter D`
- D. `Get-ChildItem D:\ | Get-Disk`

??? question "Answer and explanation"
    **B.** The Storage module objects pipe into each other along the stack: volume → partition → disk. `Get-PSDrive` objects do not bind to `Get-Disk`, and `Get-Disk` has no `-DriveLetter` parameter. (Day 09)

**13.** What is the difference between `sudo apt remove nginx` and `sudo apt purge nginx`?

- A. None; they are aliases
- B. `remove` keeps the package's configuration files (status `rc`); `purge` deletes them too
- C. `purge` also removes all dependencies
- D. `remove` only stops the service

??? question "Answer and explanation"
    **B.** `remove` leaves conffiles such as `/etc/nginx/nginx.conf`, so a reinstall reuses them. `purge` removes declared conffiles. Unneeded dependencies are removed separately by `apt autoremove`. (Day 10)

**14.** Why should you avoid `Get-CimInstance Win32_Product` for a software inventory?

- A. It only lists Store apps
- B. It requires PowerShell 7
- C. Enumerating it makes Windows Installer check (and possibly repair) every MSI product, which is slow and has side effects
- D. It does not return version numbers

??? question "Answer and explanation"
    **C.** Use the Uninstall registry keys (`HKLM:\…\Uninstall`, `HKLM:\…\WOW6432Node\…\Uninstall`, `HKCU:\…\Uninstall`), `winget list` or `Get-Package` in 5.1 instead. (Day 10)

**15.** Which statement about installing PowerShell modules is correct?

- A. `Install-PSResource` is only available in Windows PowerShell 5.1
- B. The PowerShell Gallery is trusted by default, so no prompt appears
- C. `-Scope CurrentUser` installs for your account without elevation; reviewing a module with `Save-PSResource`/`Save-Module` before installing is good practice
- D. Modules must always be installed with `-Scope AllUsers`

??? question "Answer and explanation"
    **C.** PSResourceGet ships with PowerShell 7.4+ (and can be added to 5.1); `PSGallery` is untrusted by default and prompts; `CurrentUser` avoids elevation and system-wide impact. (Day 10)

## Part B — Write the command (2 marks each)

Write the command for **both** shells unless the question names one. One mark for a working command, one for using the safe or precise form described in the lessons.

**16.** Create a local user `m2test-user` with a home directory and Bash as the shell (Linux), and a local user `m2test-user` with a password you are prompted for (PowerShell, elevated).

??? question "Answer and explanation"
    - Bash: `sudo useradd -m -s /bin/bash m2test-user` (then `sudo passwd m2test-user`), or interactively `sudo adduser m2test-user` on Ubuntu.
    - PowerShell: `New-LocalUser -Name 'm2test-user' -Password (Read-Host -AsSecureString 'Password')`

    Never put passwords in plain text on the command line: they end up in history and process listings. (Day 06)

**17.** Give the group `finance` read and write access to `/srv/finance` and everything inside it, without giving anything to "others", and make new files inherit the group (Linux). On Windows, back up the ACL of `D:\Finance` before any change.

??? question "Answer and explanation"
    - Bash: `sudo chgrp -R finance /srv/finance && sudo chmod -R g+rwX,o-rwx /srv/finance && sudo chmod g+s /srv/finance` (`X` = execute only for directories; the setgid bit makes new files inherit the group). A `getfacl -R /srv/finance > finance-acl.bak` backup before the change earns full marks.
    - PowerShell: `icacls D:\Finance /save $HOME\finance-acl.txt /t` (restore with `icacls D:\ /restore $HOME\finance-acl.txt`), or `Get-Acl D:\Finance | Export-Clixml $HOME\finance-acl.xml`.

    (Day 07)

**18.** Find the five processes using the most memory, showing PID, user, %MEM and command (Bash); the five with the largest working set, showing name, Id and working set in MB (PowerShell).

??? question "Answer and explanation"
    - Bash: <code>ps -eo pid,user,%mem,cmd --sort=-%mem &#124; head -n 6</code>
    - PowerShell: <code>Get-Process &#124; Sort-Object WorkingSet64 -Descending &#124; Select-Object -First 5 Name, Id, @{ n = 'WS_MB'; e = { [math]::Round($_.WorkingSet64 / 1MB) } }</code>

    Six lines in Bash because of the header. (Day 08)

**19.** Show whether the service `ssh` (Linux) / `Spooler` (Windows) is running and whether it starts at boot, without changing anything.

??? question "Answer and explanation"
    - Bash: `systemctl is-active ssh; systemctl is-enabled ssh` (or `systemctl status ssh`). On Ubuntu 24.04 the OpenSSH server unit is `ssh.service`, and it may be socket-activated (`ssh.socket`).
    - PowerShell: <code>Get-Service -Name Spooler &#124; Select-Object Name, Status, StartType</code>

    (Day 08)

**20.** List the ten largest directories directly under `/var`, staying on one filesystem and hiding permission errors (Bash); the ten largest sub-folders of `C:\ProgramData` in MB (PowerShell).

??? question "Answer and explanation"
    - Bash: <code>sudo du -xh -d 1 /var 2&gt;/dev/null &#124; sort -rh &#124; head -n 11</code>
    - PowerShell: <code>Get-ChildItem C:\ProgramData -Directory -Force &#124; ForEach-Object { $s = (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue &#124; Measure-Object Length -Sum).Sum; [pscustomobject]@{ Folder = $_.Name; MB = [math]::Round($s / 1MB, 1) } } &#124; Sort-Object MB -Descending &#124; Select-Object -First 10</code>

    `-x` keeps `du` on one filesystem; the first Bash line is `/var` itself, hence 11. (Day 09)

**21.** Show which package owns `/usr/bin/ssh` and list every file installed by that package (Ubuntu). On Windows, list installed programs whose name starts with `Microsoft Visual C++` with their versions, without using `Win32_Product`.

??? question "Answer and explanation"
    - Bash: `dpkg -S /usr/bin/ssh` (→ `openssh-client`), then `dpkg -L openssh-client`.
    - PowerShell: <code>Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\&#42;', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\&#42;' -ErrorAction SilentlyContinue &#124; Where-Object DisplayName -like 'Microsoft Visual C++*' &#124; Select-Object DisplayName, DisplayVersion</code>

    (Day 10)

**22.** Install `tree` the safe way: show its candidate version and source, simulate the install, then install it (Ubuntu). Install Git by exact ID from the community source (winget).

??? question "Answer and explanation"
    - Bash: `apt policy tree && apt-get -s install tree && sudo apt install tree` (after `sudo apt update`).
    - winget: `winget show --id Git.Git -e` then `winget install --id Git.Git -e --source winget`

    Exact IDs and simulations are the "safe form" marks. (Day 10)

## Part C — Short answer and practical (3 marks each)

**23.** A web server reports *No space left on device* when creating session files, but `df -h` shows `/var` at 45%. Explain the likely cause, how you prove it, and how you fix it now and permanently.

??? question "Answer and explanation"
    Marking: 1 mark for the cause, 1 for the proof, 1 for short- and long-term fixes.

    - **Cause:** the filesystem has run out of **inodes** — millions of tiny session files each use one inode although they use little space.
    - **Proof:** `df -i /var` shows `IUse%` at or near 100%; <code>sudo find /var -xdev -type f &#124; cut -d/ -f1-4 &#124; sort &#124; uniq -c &#124; sort -rn &#124; head</code> points to the directory (for example `/var/lib/php/sessions`).
    - **Fix now:** delete expired files after a preview, for example `sudo find /var/lib/php/sessions -type f -mmin +1440 | head` then the same with `-delete`.
    - **Permanent:** fix the application's session cleanup (garbage collection or a timer), alert on inode usage as well as space, and if the workload needs it, rebuild the filesystem with more inodes (`mkfs.ext4 -i`/`-N`) or use XFS.

    (Day 09)

**24.** At 03:00 an application stopped working on an Ubuntu server. You suspect an automatic update. Describe, with commands, how you confirm what changed, when, and what you would do next.

??? question "Answer and explanation"
    Marking: 1 mark for finding the change, 1 for linking it to the failure, 1 for a safe next step.

    1. **What changed:** `grep -A6 'Start-Date: 2026-11-11' /var/log/apt/history.log` and `less /var/log/unattended-upgrades/unattended-upgrades.log` show the upgraded packages and times; `grep ' upgrade ' /var/log/dpkg.log | tail` gives one line per package.
    2. **Link to the failure:** compare the time with the application's errors (`journalctl -u app --since 02:30`); check whether a service was restarted (`needrestart`, `journalctl -u app` "Stopped/Started" lines) and whether `/var/run/reboot-required` exists.
    3. **Next step:** restore service according to the change process — for example roll back the single package to the previous version (`sudo apt install PKG=OLDVERSION` from `apt policy PKG` / `apt-cache madison PKG`), `apt-mark hold` it with a documented reason and review date, and open a ticket with the vendor. Do not disable automatic security updates globally.

    (Days 08, 10)

**25.** **Practical task.** On your lab VM (snapshot first): (a) create the group `m2test` and the directory `/srv/m2test` owned by `root:m2test` with mode `2770`; (b) create user `m2test-user`, add it to `m2test` and prove the membership; (c) start a background `sleep 600` as `m2test-user`, find its PID, and end it with `SIGTERM`; (d) show the free space of the filesystem that contains `/srv/m2test` and the size of the directory; (e) install `tree`, show which package owns its binary, then remove it again; (f) clean up everything you created. (Windows alternative for (a)–(c): local group `m2test`, user `m2test-user`, folder `C:\m2test` with Modify for the group only, a `ping -n 600 127.0.0.1` process started and stopped with `Stop-Process -WhatIf` first.)

??? question "Answer and explanation"
    Marking: 0.5 mark per step (a)–(f).

    ```bash
    sudo groupadd m2test                                         # (a)
    sudo install -d -o root -g m2test -m 2770 /srv/m2test
    ls -ld /srv/m2test                                           # drwxrws--- root m2test
    sudo useradd -m -s /bin/bash -G m2test m2test-user           # (b)
    id m2test-user                                               # ... groups=...(m2test)
    sudo -u m2test-user bash -c 'sleep 600 & echo $!'            # (c) prints the PID
    pgrep -u m2test-user -a sleep
    sudo pkill -TERM -u m2test-user -x sleep ; sleep 1 ; pgrep -u m2test-user sleep || echo "stopped"
    df -h /srv/m2test ; sudo du -sh /srv/m2test                  # (d)
    sudo apt install -y tree && dpkg -S "$(command -v tree)"     # (e)
    sudo apt remove -y tree                                      # skip if tree was installed before
    sudo userdel -r m2test-user ; sudo rmdir /srv/m2test ; sudo groupdel m2test   # (f)
    getent group m2test || echo "group removed"
    ```

    ```powershell
    New-LocalGroup -Name m2test                                                  # (a) elevated
    New-Item -ItemType Directory -Path C:\m2test | Out-Null
    icacls C:\m2test /save $HOME\m2test-acl.txt
    icacls C:\m2test /inheritance:r /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "m2test:(OI)(CI)M"
    New-LocalUser -Name m2test-user -Password (Read-Host -AsSecureString 'Password')   # (b)
    Add-LocalGroupMember -Group m2test -Member m2test-user
    Get-LocalGroupMember -Group m2test
    $p = Start-Process -FilePath ping.exe -ArgumentList '-n', '600', '127.0.0.1' -PassThru -WindowStyle Hidden   # (c)
    Stop-Process -Id $p.Id -WhatIf ; Stop-Process -Id $p.Id
    Get-Volume -FilePath C:\m2test | Select-Object DriveLetter, SizeRemaining, Size    # (d)
    winget install --id 7zip.7zip -e ; winget uninstall --id 7zip.7zip -e             # (e) optional
    Remove-Item C:\m2test -Recurse -WhatIf ; Remove-Item C:\m2test -Recurse           # (f)
    Remove-LocalUser -Name m2test-user ; Remove-LocalGroup -Name m2test
    ```

    The Windows process in (c) runs as you, not as `m2test-user`; starting it as another user needs `Start-Process -Credential`. (Days 06–10)

## After the test

| Score (of 38) | What to do next |
|---|---|
| 34–38 | Distinction. Move on to [Module 3](../course/module-3/index.md). |
| 29–33 | Merit. Re-read the lessons for any questions you missed. |
| 23–28 | Pass. Repeat the labs for the days you lost marks on. |
| < 23 | Repeat Labs 06–10 before starting Module 3. |
