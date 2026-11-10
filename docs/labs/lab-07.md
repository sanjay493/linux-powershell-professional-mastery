---
description: "Audit and fix an over-permissive shared project folder: back up permissions, repair ownership and modes, build a setgid team directory, add a read-only auditor ACL, verify as each user and restore from backup, in Bash and PowerShell."
---

# Lab 07: Lock It Down

| Field | Value |
|---|---|
| **Lab ID** | LAB-07 |
| **Related lesson** | [Day 07: File Permissions and Access Control](../course/module-2/day-07.md) |
| **Difficulty** | Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Low–Medium. Needs `sudo` / an elevated PowerShell and creates throwaway `lab-*` accounts. All permission changes stay inside `/srv/lab07` or `C:\Lab07`. **Take a VM snapshot first** and back up permissions before every change (Task 2). |

## Objective

A project folder used by a small team was created in a hurry: everything is world-writable, the database credentials file is readable by every account on the machine, and the files belong to the project lead's private group instead of the team group. Your job as the on-call administrator is to:

1. Record the current (bad) state as evidence.
2. **Back up** the permissions so the change can be rolled back.
3. Apply the least-privilege design below.
4. Prove the design works by testing as each user.
5. Prove the rollback works by simulating an accident and restoring.

Target design:

| Identity | `docs/`, `scripts/` | `secrets/` | Everything else |
|---|---|---|---|
| `lab-alice` (project lead, owner) | Read/write | Read/write | — |
| `lab-bob` (team member, group `lab-proj`) | Read/write | **Read only** | — |
| `lab-carol` (auditor, not in the team) | **Read only** | **No access** | — |
| `lab-eve` (any other user) | **No access** | **No access** | — |

## Required Environment

- **Linux:** Ubuntu 24.04 LTS VM or WSL2 with `sudo`. The `acl` package (`getfacl`/`setfacl`) is preinstalled on standard Ubuntu installs; on minimal images run `sudo apt install acl`.
- **Windows:** Windows 11 VM with an **elevated** Windows PowerShell 5.1 or PowerShell 7 session (the `Microsoft.PowerShell.LocalAccounts` cmdlets from Day 06 and `Get-Acl`/`Set-Acl` are Windows-only).
- About 1 MB of disk space.

!!! note "Why `/srv/lab07` and not your home directory?"
    Ubuntu 24.04 creates home directories with mode `750` (`HOME_MODE` in `/etc/login.defs`), so other users cannot even enter `~/lab07`. The lab therefore uses a dedicated, empty `/srv/lab07` directory that you create and delete yourself. Do not run any lab command against other paths in `/srv`.

## Initial Conditions

Run the setup for your platform. It creates the accounts and the deliberately broken folder. Read it before running it.

=== "Linux"

    Save as `~/lab07/setup.sh`, read it, then run `sudo bash ~/lab07/setup.sh`:

    ```bash
    #!/usr/bin/env bash
    # Lab 07 setup: creates the deliberately broken /srv/lab07/project (lab use only)
    set -o nounset -o pipefail
    getent group lab-proj >/dev/null || groupadd lab-proj
    for u in lab-alice lab-bob lab-carol lab-eve; do
        id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
    done
    usermod -aG lab-proj lab-alice
    usermod -aG lab-proj lab-bob
    mkdir -p /srv/lab07/project/{docs,secrets,scripts}
    printf '# Q4 migration plan\n' > /srv/lab07/project/docs/plan.md
    printf 'DB_USER=app\nDB_PASS=Lab07-NotARealPassword\n' > /srv/lab07/project/secrets/db.env
    printf '#!/usr/bin/env bash\necho "deploying..."\n' > /srv/lab07/project/scripts/deploy.sh
    chown -R lab-alice:lab-alice /srv/lab07/project
    chmod -R 777 /srv/lab07/project
    chmod 644 /srv/lab07/project/secrets/db.env
    echo "Lab 07 environment ready: /srv/lab07/project"
    ```

    The accounts have **no passwords** (they cannot log in); you will test them with `sudo -u`.

=== "Windows"

    Run in an **elevated** PowerShell. The passwords are typed interactively and never stored.

    ```powershell
    New-LocalGroup -Name Lab07-Proj -Description 'Lab 07 project team'
    foreach ($u in 'lab-alice', 'lab-bob', 'lab-carol', 'lab-eve') {
        if (-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)) {
            New-LocalUser -Name $u -Password (Read-Host -AsSecureString "Password for $u") -Description 'Lab 07 account'
        }
    }
    Add-LocalGroupMember -Group Lab07-Proj -Member lab-alice, lab-bob
    'docs', 'secrets', 'scripts' | ForEach-Object { New-Item -Path "C:\Lab07\Project\$_" -ItemType Directory -Force | Out-Null }
    Set-Content -Path C:\Lab07\Project\docs\plan.md -Value '# Q4 migration plan'
    Set-Content -Path C:\Lab07\Project\secrets\db.env -Value 'DB_USER=app', 'DB_PASS=Lab07-NotARealPassword'
    Set-Content -Path C:\Lab07\Project\scripts\deploy.ps1 -Value "Write-Output 'deploying...'"
    icacls C:\Lab07\Project /grant "Everyone:(OI)(CI)F" | Out-Null      # the "quick fix" someone applied
    New-Item -Path C:\Lab07\backup -ItemType Directory -Force | Out-Null
    'Lab 07 environment ready: C:\Lab07\Project'
    ```

## Step-by-Step Instructions

### Task 1 — Inspect and record the current state

Produce evidence of every problem: the mode/ACL of every item, the list of world-writable items (Linux) or the `Everyone` and `Users` ACEs (Windows), and the owner/group of the secrets file.

### Task 2 — Back up the permissions

Before changing **anything**, save a complete permissions backup of `project` to `~/lab07/perms-before.acl` (Linux) or `C:\Lab07\backup\perms-before.txt` (Windows). Confirm the file is not empty.

### Task 3 — Fix ownership

Linux: owner `lab-alice`, group `lab-proj`, recursively. Windows: make sure the owner of `C:\Lab07\Project` is `BUILTIN\Administrators` (or your admin account), and that the team will be granted through the `Lab07-Proj` group, not individual users.

### Task 4 — Apply the least-privilege design

- **Linux:** all directories `2770` (setgid team directories), all files `660`, `scripts/deploy.sh` `750`, `secrets/` `2750` and `secrets/db.env` `640`. Nothing may be accessible to others.
- **Windows:** grant Administrators and SYSTEM Full control and `Lab07-Proj` Modify (inheritable) on `Project`, **then** remove inheritance and remove `Everyone`. On `secrets`, replace the team's Modify with Read only.

### Task 5 — Give the auditor read-only access

`lab-carol` must be able to read `docs` and `scripts` (including files created later) and must **not** be able to read `secrets`. Use a POSIX ACL with a default ACL on Linux, and an inheritable `RX` ACE on Windows that `secrets` does not inherit.

### Task 6 — Verify as each user

Test the access table in the Objective as `lab-bob`, `lab-carol` and `lab-eve`. Also check that a file `lab-bob` creates in `docs` is group-owned by `lab-proj` and group-writable, and that no world-writable items remain.

### Task 7 — Take an "after" backup, simulate an accident, restore

Save a second backup of the fixed state. Then simulate a colleague's mistake (`chmod -R 777 project/secrets` or `icacls ... /grant Everyone:(OI)(CI)F`), restore from the **after** backup, and prove the state matches.

## Commands to Execute

Try each task yourself first. The complete commands are in the [Solution](#solution). Useful building blocks:

| Purpose | Linux | Windows |
|---|---|---|
| Inspect | `ls -lR`, `stat -c '%a %U:%G %n'`, `find -perm -o+w`, `getfacl` | `icacls`, `Get-Acl`, `(Get-Acl).Access` |
| Back up / restore | `getfacl -R`, `setfacl --restore=` | `icacls /save /t /c`, `icacls PARENT /restore` |
| Ownership | `chown -R user:group` | `icacls /setowner`, `takeown` |
| Modes / ACEs | `chmod`, `find -type d -exec chmod`, `setfacl -m`, `setfacl -d -m`, `setfacl -x` | `icacls /grant`, `/grant:r`, `/remove:g`, `/inheritance:r`, `Set-Acl` |
| Test as a user | `sudo -u USER cat FILE` | `runas /user:lab-bob powershell` or check with `Get-Acl` |

## Expected Results

=== "Linux"

    After Task 5 (`ls -lR /srv/lab07/project`, example from a test run on Ubuntu 24.04.5 in a container):

    ```text
    project:
    total 20
    drwxrws---+ 2 lab-alice lab-proj 4096 Nov 10 16:44 docs
    drwxrws---+ 2 lab-alice lab-proj 4096 Nov 10 16:44 scripts
    drwxr-s---+ 2 lab-alice lab-proj 4096 Nov 10 16:44 secrets

    project/docs:
    total 4
    -rw-rw----+ 1 lab-alice lab-proj 20 Nov 10 16:44 plan.md

    project/scripts:
    total 4
    -rwxr-x---+ 1 lab-alice lab-proj 40 Nov 10 16:44 deploy.sh

    project/secrets:
    total 4
    -rw-r-----+ 1 lab-alice lab-proj 43 Nov 10 16:44 db.env
    ```

    Task 6 access matrix (example from the same run):

    ```text
    lab-bob    cat docs/plan.md        ALLOWED
    lab-bob    append docs/plan.md     ALLOWED
    lab-bob    cat secrets/db.env      ALLOWED
    lab-bob    append secrets/db.env   DENIED
    lab-bob    create docs/bob-notes.md ALLOWED
    lab-carol  cat docs/plan.md        ALLOWED
    lab-carol  append docs/plan.md     DENIED
    lab-carol  cat secrets/db.env      DENIED
    lab-eve    ls project              DENIED
    lab-eve    cat docs/plan.md        DENIED
    ```

=== "Windows"

    After Task 5 (`icacls C:\Lab07\Project` and `icacls C:\Lab07\Project\secrets`; **example**, not captured):

    ```text
    C:\Lab07\Project BUILTIN\Administrators:(OI)(CI)(F)
                     NT AUTHORITY\SYSTEM:(OI)(CI)(F)
                     WIN11-LAB\Lab07-Proj:(OI)(CI)(M)
                     WIN11-LAB\lab-carol:(OI)(CI)(RX)

    Successfully processed 1 files; Failed processing 0 files
    C:\Lab07\Project\secrets BUILTIN\Administrators:(OI)(CI)(F)
                             NT AUTHORITY\SYSTEM:(OI)(CI)(F)
                             WIN11-LAB\Lab07-Proj:(OI)(CI)(RX)

    Successfully processed 1 files; Failed processing 0 files
    ```

    No `Everyone`, `BUILTIN\Users` or `Authenticated Users` entries remain, and `secrets` shows no `(I)` entries because its inheritance was removed.

## Verification Steps

=== "Bash"

    ```bash
    P=/srv/lab07/project
    sudo find "$P" -perm -o+w | wc -l                 # expect 0
    sudo find "$P" -type d ! -perm -2000 | wc -l      # expect 0 (every directory setgid)
    stat -c '%a %U:%G %n' "$P"/secrets/db.env         # expect 640 lab-alice:lab-proj
    getfacl -p "$P"/secrets/db.env | grep -c lab-carol   # expect 0
    sudo -u lab-carol cat "$P"/docs/plan.md >/dev/null && echo "carol reads docs: OK"
    sudo -u lab-carol cat "$P"/secrets/db.env 2>/dev/null || echo "carol blocked from secrets: OK"
    sudo -u lab-eve ls "$P" 2>/dev/null || echo "eve blocked: OK"
    diff <(cd /srv/lab07 && sudo getfacl -R project) ~/lab07/perms-after.acl && echo "matches after-fix backup"
    ```

=== "PowerShell"

    ```powershell
    $p = 'C:\Lab07\Project'
    (Get-Acl $p).AreAccessRulesProtected                                  # expect True
    (Get-Acl $p).Access.IdentityReference -match 'Everyone|BUILTIN\\Users|Authenticated Users'   # expect nothing
    (Get-Acl "$p\secrets").Access | Where-Object IdentityReference -like '*lab-carol'            # expect nothing
    (Get-Acl "$p\secrets").Access | Where-Object IdentityReference -like '*Lab07-Proj' |
        Select-Object FileSystemRights                                     # expect ReadAndExecute, Synchronize
    Test-Path C:\Lab07\backup\perms-before.txt, C:\Lab07\backup\perms-after.txt   # expect True True
    ```

    For a real end-to-end test, open `runas /user:lab-carol powershell` and try `Get-Content C:\Lab07\Project\docs\plan.md` (works) and `Get-Content C:\Lab07\Project\secrets\db.env` (*Access to the path ... is denied*).

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `setfacl: command not found` | `acl` package missing (minimal image) | `sudo apt install acl` |
| `lab-bob` still denied after setup | Not in `lab-proj` (setup step skipped) | `id lab-bob`; `sudo usermod -aG lab-proj lab-bob` (sudo -u starts a fresh credential set, so no log-out is needed for the test) |
| `lab-carol` can read `secrets` | The ACL was applied recursively and not removed from `secrets` | `sudo setfacl -R -x u:lab-carol,d:u:lab-carol /srv/lab07/project/secrets` |
| New file in `docs` is not group-writable | No default ACL, and the creator's umask is `022` | `sudo setfacl -R -d -m g:lab-proj:rwX /srv/lab07/project` |
| `chmod 2770` "did nothing" on a directory | It was already setgid; or you expected `770` to clear setgid | `stat -c %a dir`; use `g-s` or `00770` to clear |
| `setfacl --restore` reports *No such file or directory* | Restored from a different working directory than the backup | `cd /srv/lab07` (where you ran `getfacl -R project`) and retry |
| `icacls : The term 'OI' is not recognized` | Unquoted parentheses in PowerShell | Quote: `"Lab07-Proj:(OI)(CI)M"` |
| Everyone lost access to `Project` on Windows | Ran `/inheritance:r` before granting explicit ACEs | `takeown /f C:\Lab07\Project /a /r /d y`, then `icacls C:\Lab07 /restore C:\Lab07\backup\perms-before.txt` |
| `icacls /restore` fails with *The system cannot find the file specified* | Restored against `Project` instead of its parent | `icacls C:\Lab07 /restore C:\Lab07\backup\perms-after.txt` |
| `Set-Acl : The security identifier is not allowed to be the owner of this object.` | 5.1 trying to write an owner you cannot assign | Run elevated, or use the `icacls` commands from the solution |

## Questions

1. Why is `chmod -R 777` never an acceptable fix, even "temporarily"? Name two concrete risks for this project.
2. Why does the solution set **setgid** on the directories, and what would `ls -l` show for a file `lab-bob` creates without it?
3. `lab-bob` creates `docs/bob-notes.md` with a umask of `0002`. Why does the file end up `rw-rw----` and not `rw-rw-r--`?
4. Why does the solution grant explicit ACEs **before** running `icacls /inheritance:r`?
5. Explain why `icacls /restore` is run on `C:\Lab07` and `setfacl --restore` is run from `/srv/lab07`.
6. `lab-bob` can read `secrets/db.env`. Is that acceptable in the design? How would you remove it if the security team disagreed?
7. What evidence from this lab would you attach to the change ticket?

## Solution

??? success "Bash solution"
    ```bash
    mkdir -p ~/lab07
    cd /srv/lab07

    # ---- Task 1: inspect and record ----
    ls -lR project | tee ~/lab07/state-before.txt
    sudo find project -perm -o+w | sort              # every item is world-writable
    stat -c '%a %U:%G %n' project/secrets/db.env     # 644 lab-alice:lab-alice

    # ---- Task 2: back up permissions (owner, group, mode and ACLs) ----
    sudo getfacl -R project > ~/lab07/perms-before.acl
    wc -l ~/lab07/perms-before.acl                   # 49 lines in the test run
    head -6 ~/lab07/perms-before.acl

    # ---- Task 3: ownership ----
    sudo chown -R lab-alice:lab-proj project

    # ---- Task 4: least-privilege modes ----
    sudo find project -type d -exec chmod 2770 {} +  # setgid team directories
    sudo find project -type f -exec chmod 0660 {} +  # team read/write, others nothing
    sudo chmod 0750 project/scripts/deploy.sh        # executable script
    sudo chmod 2750 project/secrets                  # team may read, not add/delete
    sudo chmod 0640 project/secrets/db.env           # team read only

    # ---- Task 5: auditor read-only via ACL, excluding secrets ----
    sudo setfacl -R -m u:lab-carol:rX project                         # existing items
    sudo setfacl -R -d -m u:lab-carol:rX,g:lab-proj:rwX project       # future items (directories only)
    sudo setfacl -R -x u:lab-carol,d:u:lab-carol project/secrets      # remove from secrets
    ls -lR project
    getfacl -p project/docs/plan.md

    # ---- Task 6: verify as each user ----
    P=/srv/lab07/project
    t() { u=$1; shift; if sudo -u "$u" bash -c "$*" >/dev/null 2>&1; then r=ALLOWED; else r=DENIED; fi
          printf '%-10s %-55s %s\n' "$u" "$*" "$r"; }
    t lab-bob   "cat $P/docs/plan.md"
    t lab-bob   "echo edit >> $P/docs/plan.md"
    t lab-bob   "cat $P/secrets/db.env"
    t lab-bob   "echo x >> $P/secrets/db.env"
    t lab-bob   "touch $P/docs/bob-notes.md"
    t lab-carol "cat $P/docs/plan.md"
    t lab-carol "echo x >> $P/docs/plan.md"
    t lab-carol "cat $P/secrets/db.env"
    t lab-eve   "ls $P"
    t lab-eve   "cat $P/docs/plan.md"
    ls -l $P/docs/bob-notes.md
    sudo find $P -perm -o+w | wc -l                   # 0

    # ---- Task 7: after-backup, accident, restore ----
    sudo getfacl -R project > ~/lab07/perms-after.acl
    sudo chmod -R 777 project/secrets                 # the "accident"
    ls -ld project/secrets ; ls -l project/secrets
    sudo setfacl --restore="$HOME/lab07/perms-after.acl"
    ls -ld project/secrets ; ls -l project/secrets
    diff <(sudo getfacl -R project) ~/lab07/perms-after.acl && echo "ACLs match the after-fix backup"
    ```

    **Output of the verification and restore steps (from a test run on Ubuntu 24.04.5 in a container):**

    ```text
    lab-bob    cat /srv/lab07/project/docs/plan.md                     ALLOWED
    lab-bob    echo edit >> /srv/lab07/project/docs/plan.md            ALLOWED
    lab-bob    cat /srv/lab07/project/secrets/db.env                   ALLOWED
    lab-bob    echo x >> /srv/lab07/project/secrets/db.env             DENIED
    lab-bob    touch /srv/lab07/project/docs/bob-notes.md              ALLOWED
    lab-carol  cat /srv/lab07/project/docs/plan.md                     ALLOWED
    lab-carol  echo x >> /srv/lab07/project/docs/plan.md               DENIED
    lab-carol  cat /srv/lab07/project/secrets/db.env                   DENIED
    lab-eve    ls /srv/lab07/project                                   DENIED
    lab-eve    cat /srv/lab07/project/docs/plan.md                     DENIED
    -rw-rw----+ 1 lab-bob lab-proj 0 Nov 10 16:44 /srv/lab07/project/docs/bob-notes.md
    0
    drwxrwsrwx+ 2 lab-alice lab-proj 4096 Nov 10 16:44 project/secrets
    total 4
    -rwxrwxrwx+ 1 lab-alice lab-proj 43 Nov 10 16:44 db.env
    drwxr-s---+ 2 lab-alice lab-proj 4096 Nov 10 16:44 project/secrets
    total 4
    -rw-r-----+ 1 lab-alice lab-proj 43 Nov 10 16:44 db.env
    ACLs match the after-fix backup
    ```

    The ACL of the new file shows why it is group-writable even though `lab-bob`'s umask would normally allow `r` for others: the **default ACL** replaced the umask.

    ```text
    $ getfacl --omit-header /srv/lab07/project/docs/bob-notes.md
    user::rw-
    user:lab-carol:r-x      #effective:r--
    group::rwx      #effective:rw-
    group:lab-proj:rwx      #effective:rw-
    mask::rw-
    other::---
    ```

??? success "PowerShell solution"
    ```powershell
    # Run in an ELEVATED Windows PowerShell 5.1 or PowerShell 7 session (Windows only).
    $p = 'C:\Lab07\Project'

    # ---- Task 1: inspect and record ----
    icacls $p /t | Tee-Object -FilePath C:\Lab07\backup\state-before.txt
    (Get-Acl $p).Access | Where-Object IdentityReference -match 'Everyone|BUILTIN\\Users|Authenticated Users' |
        Format-Table IdentityReference, FileSystemRights, IsInherited -AutoSize

    # ---- Task 2: back up DACLs of the whole tree ----
    icacls $p /save C:\Lab07\backup\perms-before.txt /t /c
    (Get-Item C:\Lab07\backup\perms-before.txt).Length -gt 0     # True

    # ---- Task 3: ownership ----
    icacls $p /setowner 'BUILTIN\Administrators' /t /c

    # ---- Task 4: least privilege ----
    # 4a. Grant what must remain FIRST (explicit, inheritable ACEs)
    icacls $p /grant 'Administrators:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' 'Lab07-Proj:(OI)(CI)M'
    # 4b. Remove inherited ACEs (Users, Authenticated Users) and the bad explicit Everyone ACE
    icacls $p /inheritance:r
    icacls $p /remove:g Everyone /t /c
    # 4c. secrets: team gets Read & execute only
    icacls "$p\secrets" /inheritance:r /grant:r 'Administrators:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' 'Lab07-Proj:(OI)(CI)RX'

    # ---- Task 5: auditor read-only with Set-Acl (inherits to docs and scripts, NOT secrets) ----
    $acl  = Get-Acl -Path $p
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        'lab-carol', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -Path $p -AclObject $acl -WhatIf
    Set-Acl -Path $p -AclObject $acl
    # secrets has inheritance removed (4c), so the new inheritable ACE does not reach it.

    icacls $p
    icacls "$p\secrets"

    # ---- Task 6: verify ----
    (Get-Acl $p).AreAccessRulesProtected
    (Get-Acl "$p\docs\plan.md").Access | Format-Table IdentityReference, FileSystemRights, IsInherited -AutoSize
    (Get-Acl "$p\secrets\db.env").Access | Format-Table IdentityReference, FileSystemRights, IsInherited -AutoSize

    # ---- Task 7: after-backup, accident, restore ----
    icacls $p /save C:\Lab07\backup\perms-after.txt /t /c
    icacls "$p\secrets" /grant 'Everyone:(OI)(CI)F'          # the "accident"
    icacls "$p\secrets"
    icacls C:\Lab07 /restore C:\Lab07\backup\perms-after.txt # restore on the PARENT folder
    icacls "$p\secrets"
    ```

    **Expected output of the final checks (example, not captured):**

    ```text
    True

    IdentityReference         FileSystemRights            IsInherited
    -----------------         ----------------            -----------
    BUILTIN\Administrators    FullControl                        True
    NT AUTHORITY\SYSTEM       FullControl                        True
    WIN11-LAB\Lab07-Proj      Modify, Synchronize                True
    WIN11-LAB\lab-carol       ReadAndExecute, Synchronize        True

    IdentityReference         FileSystemRights            IsInherited
    -----------------         ----------------            -----------
    BUILTIN\Administrators    FullControl                        True
    NT AUTHORITY\SYSTEM       FullControl                        True
    WIN11-LAB\Lab07-Proj      ReadAndExecute, Synchronize        True
    ```

    If `Set-Acl` fails in Windows PowerShell 5.1 with an owner-related error, apply the same ACE with `icacls $p /grant 'lab-carol:(OI)(CI)RX'`: the result is identical.

??? success "Answers to questions"
    1. `777` lets **every** account (including compromised service accounts) read the database password and **replace** `deploy.sh`, which the team then runs: code execution as whoever deploys. It also destroys the evidence of who changed what, and "temporary" fixes are routinely forgotten.
    2. setgid makes new files and subdirectories inherit group `lab-proj`, so the whole team can access them. Without it, a file `lab-bob` creates would show `lab-bob lab-bob` (his private group) and the rest of the team could not open it.
    3. The directory has a **default ACL**. When a default ACL exists, the umask is not applied; the new file's permissions come from the default ACL entries (`other::---`), limited by the mode `touch` requested (`666`), which gives `rw-rw----`.
    4. `/inheritance:r` deletes the inherited ACEs. If no explicit ACEs exist at that moment, the folder has an empty DACL and **nobody** (not even administrators) has access until someone takes ownership and rewrites it.
    5. `icacls /save` records paths relative to the folder given (`Project\...`), so `/restore` must run on the folder that **contains** `Project`. `getfacl -R project` records relative paths (`# file: project/...`), so `setfacl --restore` must run from the same directory, `/srv/lab07`.
    6. Yes: the design says the team may **read** secrets so the application can be deployed. If the security team disagrees, remove group read: `sudo chmod 0600 project/secrets/db.env` (owner only) or, on Windows, `icacls "$p\secrets" /remove:g Lab07-Proj` and grant a dedicated deployment group instead.
    7. `state-before.txt` (the bad state), `perms-before.acl` / `perms-before.txt` (rollback), the commands run, the verification matrix from Task 6, and `perms-after.acl` / `perms-after.txt` (the new baseline).

## Clean-up

=== "Linux"

    ```bash
    sudo ls -R /srv/lab07                       # preview
    sudo rm -r -- /srv/lab07
    for u in lab-alice lab-bob lab-carol lab-eve; do sudo userdel -r "$u"; done
    sudo groupdel lab-proj
    rm -r -- ~/lab07
    ```

=== "Windows"

    ```powershell
    Remove-Item C:\Lab07 -Recurse -WhatIf
    Remove-Item C:\Lab07 -Recurse
    'lab-alice', 'lab-bob', 'lab-carol', 'lab-eve' | ForEach-Object { Remove-LocalUser -Name $_ }
    Remove-LocalGroup -Name Lab07-Proj
    ```
