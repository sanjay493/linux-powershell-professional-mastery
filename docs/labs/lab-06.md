---
description: "Process an onboarding and an offboarding ticket: create lab users and a lab group, set password and expiry policy, repair a usermod -G membership loss, audit privileged accounts and safely delete a leaver in Bash and PowerShell."
---

# Lab 06: Onboard & Offboard

| Field | Value |
|---|---|
| **Lab ID** | LAB-06 |
| **Related lesson** | [Day 06: Users and Groups](../course/module-2/day-06.md) |
| **Difficulty** | Beginner–Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Medium. The lab creates, changes and deletes **local accounts**. Take a **VM snapshot** (or `wsl --export` your WSL2 distribution) first. Touch only accounts and groups whose names begin with `lab-`. Never lock, change or delete your own account, `root` or `Administrator`. |

## Objective

You are the administrator of a small team's build machine. Two tickets are waiting:

- **REQ-1001 (onboarding):** create accounts for `lab-alice` (permanent developer) and `lab-bob` (contractor until 2026-12-31), both in a new group `lab-devs`. Alice needs a 90-day maximum password age. Neither gets administrator rights.
- **REQ-1002 (offboarding):** `lab-bob`'s contract ended early. Stop his access immediately, preserve his home directory, then delete the account.

While doing REQ-1001 a colleague's script "accidentally" runs `usermod -G` and removes alice's memberships; you must detect and repair this. Before and after, you will run an account audit and compare the results, as an auditor would.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS VM or WSL2, a normal user with `sudo` rights. `adduser` steps are Debian/Ubuntu-specific.
- **Windows:** Windows 11 test VM, **elevated** Windows PowerShell 5.1 (recommended for this lab) or PowerShell 7 on Windows. The LocalAccounts cmdlets are Windows-only.
- About 5 MB free disk space. No network access is needed.
- Day 06 read; Days 03–05 completed (redirection, `grep`/`Select-String`, pipelines).

## Initial Conditions

- A snapshot exists and you know how to revert it.
- None of the lab names exist yet:
    - Bash: `getent passwd lab-alice lab-bob; getent group lab-devs; echo $?` must print only `2`.
    - PowerShell: `Get-LocalUser lab-* -ErrorAction SilentlyContinue; Get-LocalGroup lab-* -ErrorAction SilentlyContinue` must print nothing.
- A working folder for evidence exists: `mkdir -p ~/lab06` / `New-Item -ItemType Directory $HOME\lab06 -Force`.
- Choose a **lab-only** password (for example a long random phrase you use nowhere else). You will type it at prompts only, never on the command line.

## Step-by-Step Instructions

1. **Before-audit.** Save to `~/lab06/before.txt` (`$HOME\lab06\before.txt`): all UID 0 accounts, accounts with an empty password, members of the admin group (`sudo` / `Administrators`) and all regular users (UID ≥ 1000 / all local users with `Enabled`).
2. **Create the group** `lab-devs`.
3. **Create the users** with comments that contain the ticket number:
    - `lab-alice`, comment `Lab Alice REQ-1001`, home directory, Bash shell.
    - `lab-bob`, comment `Lab Bob contractor REQ-1001`, home directory, Bash shell, **account expiry 2026-12-31**.
4. **Set passwords** at a prompt for both users, and force alice to change hers at first login. Give alice a 90-day maximum password age (Linux) / ensure her password expires (Windows).
5. **Add both users** to `lab-devs` using an append-safe method. Verify with `id` / `Get-LocalGroupMember`.
6. **Simulate the colleague's mistake** (Linux): first add alice to a second group `lab-ops` (create it), then run `sudo usermod -G lab-devs lab-alice` **without** `-a`. Show that `lab-ops` has gone, then repair it with an append-safe command. (Windows has no equivalent trap: instead, remove alice from `lab-devs` with `Remove-LocalGroupMember` and add her back.)
7. **Verify REQ-1001**: print each user's groups, password status and expiry. Confirm neither user is in `sudo` / `Administrators`.
8. **Offboard lab-bob (REQ-1002)**, in this order: check he is not logged in; lock **and** expire (Linux) / disable (Windows); remove him from `lab-devs`; preview and archive his home to `~/lab06/lab-bob-home-<date>.tar.gz` (Linux) or copy his profile folder if it exists (Windows); preview the deletion; delete the account **keeping** the home; confirm the account is gone and find the orphaned home directory.
9. **After-audit.** Save the same audit as step 1 to `after.txt` and compare it with `before.txt` (`diff` / `Compare-Object`). The only differences should be the lab accounts.
10. **Clean up** (see Clean-up).

## Commands to Execute

Try each step yourself first, using the lesson's cheat sheet. Full commands are in the [Solution](#solution).

## Expected Results

- `before.txt` and `after.txt` show **only `root`** with UID 0 and **no** empty-password accounts; the admin group membership is unchanged.
- After step 5: `getent group lab-devs` → `lab-devs:x:<GID>:lab-alice,lab-bob` (example); `Get-LocalGroupMember lab-devs` lists both users.
- After step 6: `id -nG lab-alice` first shows `lab-alice lab-devs` (lab-ops lost), and after the repair `lab-alice lab-devs lab-ops`.
- After step 7: `sudo chage -l lab-alice` shows `Maximum number of days between password change : 90` and `Last password change : password must be changed`; `sudo chage -l lab-bob` shows `Account expires : Dec 31, 2026`.
- After step 8: `getent passwd lab-bob` prints nothing and returns exit code `2`; `sudo find /home -maxdepth 1 -nouser` prints `/home/lab-bob`; the archive exists and `tar -tzf` lists `lab-bob/.bashrc`. On Windows, `Get-LocalUser lab-bob` fails with *User lab-bob was not found*.
- `diff before.txt after.txt` shows only `lab-alice` added to the regular-users section.

## Verification Steps

=== "Bash"

    ```bash
    id lab-alice                                   # groups include lab-devs and lab-ops, not sudo
    sudo passwd -S lab-alice                       # P ... 0 90 ...
    sudo chage -l lab-alice | grep -E 'Last password|Maximum'
    getent passwd lab-bob; echo "lab-bob exit: $?" # expect exit 2
    getent group lab-devs                          # lab-alice only
    ls -l ~/lab06/                                 # before.txt after.txt lab-bob-home-*.tar.gz
    tar -tzf ~/lab06/lab-bob-home-*.tar.gz | head -3
    getent group sudo                              # unchanged from before.txt
    ```

=== "PowerShell"

    ```powershell
    Get-LocalUser lab-alice | Select-Object Name, Enabled, PasswordExpires, AccountExpires, Description
    Get-LocalGroupMember lab-devs | Select-Object Name
    Get-LocalUser lab-bob -ErrorAction SilentlyContinue; "lab-bob exists: $?"   # expect False
    (Get-LocalGroupMember Administrators).Name -match 'lab-'                    # expect nothing
    Compare-Object (Get-Content $HOME\lab06\before.txt) (Get-Content $HOME\lab06\after.txt)
    ```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `useradd: group 'lab-devs' does not exist` | Step 2 skipped or typo | `sudo groupadd lab-devs` and retry |
| `useradd: user 'lab-alice' already exists` | Leftover from an earlier attempt | Revert the snapshot, or finish the Clean-up section first |
| `passwd: Authentication token manipulation error` | Not using `sudo` / `/etc/shadow` locked by another tool | Use `sudo`; close other account tools |
| `userdel: user lab-bob is currently used by process ...` | A session or process of lab-bob is running | `who`, `ps -u lab-bob`; end it, then retry |
| `id lab-alice` is correct but alice's open shell lacks the group | Groups are read at login | Log alice out and in (`su - lab-alice` starts a fresh login) |
| `New-LocalUser : Access denied` | PowerShell not elevated | Open *Terminal (Admin)* |
| `The term 'Get-LocalUser' is not recognized` | PowerShell on Linux, or 32-bit PowerShell | Use 64-bit Windows PowerShell 5.1 on Windows |
| PowerShell 7 type-load error importing LocalAccounts | Known compatibility issue | `Import-Module Microsoft.PowerShell.LocalAccounts -UseWindowsPowerShell`, or use 5.1 |
| `The password does not meet the password policy requirements` | Local policy demands length/complexity | Use a longer lab passphrase |
| `Set-LocalUser : A positional parameter cannot be found ... 'True'` / missing argument | `-PasswordNeverExpires` on `Set-LocalUser` needs a Boolean | `-PasswordNeverExpires $false` |

## Questions

1. In step 4, why must passwords be typed at a prompt rather than as command arguments?
2. In step 6, why did `usermod -G` remove `lab-ops`, and which two commands are safe alternatives?
3. Why does the offboarding order put "lock and expire / disable" **first** and "delete" **last**?
4. `passwd -l` alone was not enough for lab-bob on Linux. What else did you do, and why?
5. After `userdel`, why does `ls -ld /home/lab-bob` show a number instead of a name as the owner?
6. Why does the before/after audit matter to an auditor, and what would a new UID 0 account in `after.txt` indicate?
7. What would happen to file permissions if you deleted `lab-alice` and immediately recreated her with the same name?

## Solution

??? success "Bash solution"
    ```bash
    mkdir -p ~/lab06 && cd ~/lab06

    # 1. before-audit
    audit() {
      echo "## UID 0";            awk -F: '$3 == 0 {print $1}' /etc/passwd
      echo "## Empty passwords";  sudo awk -F: '$2 == "" {print $1}' /etc/shadow
      echo "## sudo group";       getent group sudo
      echo "## Regular users";    awk -F: '$3 >= 1000 && $3 < 60000 {print $1, $3, $7}' /etc/passwd
    }
    audit > before.txt ; cat before.txt

    # 2. group
    sudo groupadd lab-devs

    # 3. users
    sudo useradd -m -s /bin/bash -c "Lab Alice REQ-1001" lab-alice
    sudo useradd -m -s /bin/bash -c "Lab Bob contractor REQ-1001" -e 2026-12-31 lab-bob

    # 4. passwords (typed at the prompt), policy
    sudo passwd lab-alice
    sudo passwd lab-bob
    sudo chage -M 90 lab-alice
    sudo passwd -e lab-alice                # must change at first login

    # 5. append-safe membership
    sudo usermod -aG lab-devs lab-alice
    sudo gpasswd -a lab-bob lab-devs
    id lab-alice ; id lab-bob

    # 6. the -G trap and the repair
    sudo groupadd lab-ops
    sudo gpasswd -a lab-alice lab-ops
    id -nG lab-alice                        # lab-alice lab-devs lab-ops
    sudo usermod -G lab-devs lab-alice      # the colleague's mistake (no -a)
    id -nG lab-alice                        # lab-alice lab-devs   <- lab-ops lost
    sudo gpasswd -a lab-alice lab-ops       # repair
    id -nG lab-alice                        # lab-alice lab-devs lab-ops

    # 7. verify REQ-1001
    for u in lab-alice lab-bob; do
      id -nG "$u"; sudo passwd -S "$u"; sudo chage -l "$u" | grep -E 'Last password|Maximum|Account expires'
    done
    getent group sudo | grep -E 'lab-' || echo "no lab users in sudo: OK"

    # 8. offboard lab-bob
    who | grep lab-bob || echo "lab-bob not logged in"
    sudo passwd -l lab-bob
    sudo usermod -e 1 lab-bob               # expire: blocks key-based logins too
    sudo gpasswd -d lab-bob lab-devs
    sudo ls -la /home/lab-bob ; sudo du -sh /home/lab-bob
    sudo tar -czf ~/lab06/lab-bob-home-$(date +%F).tar.gz -C /home lab-bob
    sudo chown "$USER": ~/lab06/lab-bob-home-*.tar.gz
    tar -tzf ~/lab06/lab-bob-home-*.tar.gz | head -3
    getent passwd lab-bob                   # preview what will be deleted
    sudo userdel lab-bob                    # keep the home directory
    getent passwd lab-bob ; echo "exit: $?" # exit: 2
    sudo find /home -maxdepth 1 -nouser     # /home/lab-bob

    # 9. after-audit and comparison
    audit > after.txt
    diff before.txt after.txt
    ```

    **Expected output of the final `diff` (example):**

    ```text
    7a8
    > lab-alice 1001 /bin/bash
    ```

??? success "PowerShell solution"
    ```powershell
    # Elevated Windows PowerShell 5.1
    $lab = Join-Path $HOME 'lab06'
    New-Item -ItemType Directory -Path $lab -Force | Out-Null

    # 1. before-audit
    function Get-LabAudit {
        '## Enabled users without a required password'
        Get-LocalUser | Where-Object { $PSItem.Enabled -and -not $PSItem.PasswordRequired } | ForEach-Object Name
        '## Administrators'
        Get-LocalGroupMember -Group 'Administrators' | ForEach-Object Name
        '## Local users'
        Get-LocalUser | ForEach-Object { '{0} {1}' -f $PSItem.Name, $PSItem.Enabled }
    }
    Get-LabAudit | Set-Content (Join-Path $lab 'before.txt')

    # 2. group
    New-LocalGroup -Name 'lab-devs' -Description 'LAB group REQ-1001'

    # 3 + 4. users, passwords at a prompt, expiry
    $pwA = Read-Host -Prompt 'Lab password for lab-alice' -AsSecureString
    $pwB = Read-Host -Prompt 'Lab password for lab-bob' -AsSecureString
    New-LocalUser -Name 'lab-alice' -Password $pwA -FullName 'Lab Alice' -Description 'Lab Alice REQ-1001'
    New-LocalUser -Name 'lab-bob' -Password $pwB -FullName 'Lab Bob' -Description 'Lab Bob contractor REQ-1001' `
        -AccountExpires (Get-Date '2026-12-31')
    Set-LocalUser -Name 'lab-alice' -PasswordNeverExpires $false
    net user lab-alice /logonpasswordchg:yes        # must change at first sign-in

    # 5. membership (Add-LocalGroupMember always appends)
    Add-LocalGroupMember -Group 'lab-devs' -Member 'lab-alice', 'lab-bob'
    Get-LocalGroupMember -Group 'lab-devs'

    # 6. remove and re-add (no -G trap on Windows)
    Remove-LocalGroupMember -Group 'lab-devs' -Member 'lab-alice'
    Get-LocalGroupMember -Group 'lab-devs'
    Add-LocalGroupMember -Group 'lab-devs' -Member 'lab-alice'

    # 7. verify REQ-1001
    Get-LocalUser 'lab-alice', 'lab-bob' |
        Select-Object Name, Enabled, PasswordExpires, AccountExpires, Description
    (Get-LocalGroupMember Administrators).Name -match 'lab-'     # expect nothing

    # 8. offboard lab-bob
    query user 2>$null
    Disable-LocalUser -Name 'lab-bob'
    Remove-LocalGroupMember -Group 'lab-devs' -Member 'lab-bob'
    if (Test-Path C:\Users\lab-bob) {
        Get-ChildItem C:\Users\lab-bob -Force
        Copy-Item C:\Users\lab-bob -Destination (Join-Path $lab "lab-bob-profile-$(Get-Date -Format yyyy-MM-dd)") -Recurse
    } else { 'lab-bob never signed in: no profile folder' }
    Remove-LocalUser -Name 'lab-bob' -WhatIf
    Remove-LocalUser -Name 'lab-bob'
    Get-LocalUser -Name 'lab-bob' -ErrorAction SilentlyContinue; "lab-bob exists: $?"

    # 9. after-audit and comparison
    Get-LabAudit | Set-Content (Join-Path $lab 'after.txt')
    Compare-Object (Get-Content (Join-Path $lab 'before.txt')) (Get-Content (Join-Path $lab 'after.txt'))
    ```

    **Expected output of `Compare-Object` (example):**

    ```text
    InputObject    SideIndicator
    -----------    -------------
    lab-alice True =>
    ```

??? success "Answers to questions"
    1. Command arguments are saved in shell history (`~/.bash_history`, PSReadLine history) and are visible to other users in the process list while the command runs. Prompts (`passwd`, `Read-Host -AsSecureString`) avoid both.
    2. `-G` sets the complete supplementary group list; without `-a` it replaces instead of appending. Safe alternatives: `sudo usermod -aG GROUP USER` and `sudo gpasswd -a USER GROUP`.
    3. Locking/disabling stops access immediately and is reversible if the ticket was a mistake. Deletion is irreversible and destroys the UID/SID mapping, so it comes last, after data has been preserved.
    4. The account was also expired (`usermod -e 1`) and removed from `lab-devs`. A password lock does not stop public-key SSH logins; account expiry does.
    5. The directory still stores the numeric UID as owner, but there is no longer an `/etc/passwd` entry to translate it into a name, so `ls` shows the number. `find -nouser` finds such files.
    6. It proves that the change did exactly what the tickets requested and nothing else (no new admins, no empty passwords). A new UID 0 account would be a critical finding: an extra root-equivalent account, possibly attacker persistence.
    7. The new account would get a new UID (Linux) or SID (Windows). Files and permissions that referenced the old ID would not apply to the new account: on Linux, a recycled UID could even give the new account access to files it should not own.

## Clean-up

Preview first, then remove only the lab objects (or simply revert the snapshot).

```bash
getent passwd lab-alice ; getent group lab-devs lab-ops
sudo userdel -r lab-alice
sudo rm -rI /home/lab-bob
sudo groupdel lab-devs ; sudo groupdel lab-ops
rm -rI ~/lab06
```

```powershell
Remove-LocalUser -Name 'lab-alice' -WhatIf ; Remove-LocalUser -Name 'lab-alice'
Remove-LocalGroup -Name 'lab-devs' -WhatIf ; Remove-LocalGroup -Name 'lab-devs'
Get-CimInstance Win32_UserProfile | Where-Object LocalPath -like '*\lab-*' | Select-Object LocalPath
Remove-Item $HOME\lab06 -Recurse -WhatIf ; Remove-Item $HOME\lab06 -Recurse
```
