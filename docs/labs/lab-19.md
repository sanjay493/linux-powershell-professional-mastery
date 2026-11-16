---
description: "Run a read-only security baseline audit on a disposable VM: find a stale account, an unexpected administrator, a dangerous NOPASSWD sudo rule, an unknown SUID binary, a world-writable root script, an orphaned file and a file capability; classify each finding and write its remediation; repeat the baseline checks on Windows; confirm the clean-up restores the baseline."
---

# Lab 19: Baseline and Hardening Audit

| Field | Value |
|---|---|
| **Lab ID** | LAB-19 |
| **Related lesson** | [Day 19: System Security Auditing](../course/module-4/day-19.md) |
| **Difficulty** | Advanced |
| **Time** | 75–100 minutes (Linux 60 min, Windows 20–30 min) |
| **Risk level** | Low. The setup script plants only safe, reversible findings (locked lab accounts, a scoped sudo rule, harmless copies of `id`/`sleep`, files under `/srv/lab19`). It backs up `/etc/sudoers.d` first and the clean-up script removes everything. Run on a **disposable Ubuntu 24.04 VM** you own. The audit itself is **read-only**. |

## Objective

You are a security analyst performing a **baseline audit** of **host01**, a server that has been in service for a while and has drifted from the hardening standard. Someone has, over time, left behind a former contractor's account, added an intern to `sudo`, created a `NOPASSWD` automation rule, dropped an unknown SUID helper, left a world-writable script that root runs nightly, orphaned a file from a deleted account, and given a stray binary a network capability.

Your job is to **find all seven**, classify each by severity, and write the one-line remediation you *would* apply under change control — **without changing anything during the audit**. Then run the equivalent Windows baseline checks.

## Required Environment

- **Linux:** a disposable Ubuntu 24.04 **VM** (snapshot it first) with `sudo`. Packages:

    ```bash
    sudo apt update && sudo apt install -y libcap2-bin sudo coreutils findutils
    ```

- **Windows (optional second half):** a Windows 11 lab VM with an **elevated** PowerShell (5.1 or 7). The Defender, BitLocker and Secure Boot cmdlets are Windows-only.

## Initial Conditions

- `/srv/lab19` and the `lab19-*` accounts **must not exist** yet. Check: `ls -d /srv/lab19 2>/dev/null; getent passwd lab19-old`.
- You will run the setup script once, as root, and the clean-up script at the end.
- The three lab accounts are created **locked** (`passwd -l`), so none of them can actually log in; the findings are about *configuration*, not live access.

## Setup script (Linux)

Save as `lab19-setup.sh` and run `sudo bash lab19-setup.sh`. **Read it before running it** (never run scripts you have not read).

```bash
#!/usr/bin/env bash
# lab19-setup.sh - plant seven harmless, reversible audit findings on a DISPOSABLE VM.
set -o errexit -o nounset -o pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
LAB=/srv/lab19
if [ -e "$LAB" ] || getent passwd lab19-old >/dev/null; then
    echo "Already set up. Run lab19-cleanup.sh first." >&2; exit 1
fi
mkdir -p "$LAB"/{bin,shared,scripts,data,backup}
chmod 0755 "$LAB" "$LAB"/{bin,scripts,data}; chmod 0700 "$LAB/backup"
cp -a /etc/sudoers.d "$LAB/backup/sudoers.d.orig"           # backup before touching sudo

# F1 stale account: password last changed 2019, never expires (locked)
useradd -m -s /bin/bash -c "Lab19 former contractor" lab19-old
passwd -l lab19-old >/dev/null
chage -d 2019-01-15 -M 99999 lab19-old

# F2 unexpected administrator: intern in the sudo group (locked)
useradd -m -s /bin/bash -c "Lab19 intern" lab19-intern
passwd -l lab19-intern >/dev/null
usermod -aG sudo lab19-intern

# F3 dangerous sudo rule: passwordless find (find -exec = root shell)
useradd -r -m -d /var/lib/lab19-deploy -s /bin/bash -c "Lab19 deploy service" lab19-deploy
passwd -l lab19-deploy >/dev/null
printf 'lab19-deploy ALL=(root) NOPASSWD: /usr/bin/find\n' > /etc/sudoers.d/lab19-deploy
chmod 0440 /etc/sudoers.d/lab19-deploy
visudo -cf /etc/sudoers.d/lab19-deploy >/dev/null

# F4 unknown SUID-root binary (a disguised copy of /usr/bin/id)
install -o root -g root -m 4755 /usr/bin/id "$LAB/bin/sysinfo-helper"

# F5 world-writable root script and directory without sticky bit
chmod 0777 "$LAB/shared"
printf '#!/bin/sh\n# run nightly by root (ticket OPS-1919)\ntar -czf /srv/lab19/backup/data.tgz /srv/lab19/data\n' \
    > "$LAB/scripts/nightly-backup.sh"
chmod 0777 "$LAB/scripts/nightly-backup.sh"

# F6 orphaned file: owner UID/GID 4719 has no name
echo "id,name,email" > "$LAB/data/export-2023.csv"
chown 4719:4719 "$LAB/data/export-2023.csv"

# F7 file capability on an unknown binary (a copy of /usr/bin/sleep)
install -o root -g root -m 0755 /usr/bin/sleep "$LAB/bin/net-probe"
setcap cap_net_raw+ep "$LAB/bin/net-probe"

echo "Lab 19 ready: 7 findings planted under $LAB and in accounts/sudoers."
```

## Step-by-Step Instructions

### Task 1 — Save a baseline

Before planting anything (or on a second clean VM), record the known-good SUID and capability lists so the diff in Task 3 is meaningful:

```bash
mkdir -p ~/baseline
find / -xdev -type f -perm -4000 2>/dev/null | sort > ~/baseline/suid.txt
getcap -r / 2>/dev/null | sort > ~/baseline/caps.txt
getent group sudo > ~/baseline/sudo.txt
```

Then run the setup script.

### Task 2 — Account and privilege audit

Find the stale account (F1), the unexpected admin (F2) and the dangerous sudo rule (F3):

1. List UID 0 accounts and interactive users.
2. Check password ageing for any account you do not recognise (`chage -l`).
3. List the members of `sudo`/`admin`.
4. Run `sudo -l -U <user>` for each suspect and read `/etc/sudoers.d/`.

### Task 3 — Filesystem and privilege-on-disk audit

Find the unknown SUID binary (F4), the world-writable script (F5), the orphaned file (F6) and the capability (F7):

1. Diff the current SUID list against `~/baseline/suid.txt`.
2. For any new SUID file, run `dpkg -S` and record its owner, mode and date.
3. List world-writable directories (no sticky) and world-writable files under system paths.
4. Find orphaned files.
5. Diff `getcap -r /` against `~/baseline/caps.txt`.

### Task 4 — Sensitive modes and kernel hardening

Confirm the sensitive-file modes and read the key `sysctl` values, noting anything not at its secure value (on this lab VM they should be secure, so this task is about *method*, not finding faults).

### Task 5 — Windows baseline (if available)

On a Windows lab VM (elevated PowerShell), capture: execution policy per scope, Defender status, local administrators, your privileges, BitLocker, Secure Boot and the SMB1 setting. Note any value that differs from the secure baseline in the lesson.

### Task 6 — Report and clean up

Write the findings report (Task template in *Expected Results*), then run the clean-up script and confirm the SUID/capability/sudo lists match your Task 1 baseline again.

## Commands to Execute

Try each step yourself first; full commands are in the [Solution](#solution).

## Expected Results

Seven findings, classified roughly like this (your wording may differ):

| # | Finding | Severity | Remediation (under change control) |
|---|---|---|---|
| F1 | `lab19-old`: password from 2019, never expires | Medium | Disable/remove the leaver's account; enforce `PASS_MAX_DAYS` |
| F2 | `lab19-intern` in `sudo` group | High | Remove from `sudo` unless approved; review admin list |
| F3 | `lab19-deploy` has `NOPASSWD: /usr/bin/find` | **Critical** | Replace with a non-shelling scoped command or remove; `find -exec` = root |
| F4 | SUID-root `sysinfo-helper` in `/srv`, no package | **Critical** | Quarantine, hash, investigate; remove the SUID bit |
| F5 | World-writable `nightly-backup.sh` run by root | High | `chmod 755`, `root:root`; audit who edited it |
| F6 | Orphaned `export-2023.csv` (UID 4719) | Low | Reassign owner or archive/delete; check why the account was deleted with files left |
| F7 | `cap_net_raw` on `/srv/.../net-probe` | Medium | Remove the capability (`setcap -r`) unless justified |

## Verification Steps

```bash
# after clean-up, these three diffs should be empty
diff ~/baseline/suid.txt <(find / -xdev -type f -perm -4000 2>/dev/null | sort) && echo "SUID matches baseline"
diff ~/baseline/caps.txt <(getcap -r / 2>/dev/null | sort) && echo "caps match baseline"
diff ~/baseline/sudo.txt <(getent group sudo) && echo "sudo group matches baseline"
getent passwd | grep -c '^lab19-' || echo "no lab19 accounts remain"
visudo -c
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Setup says "Already set up" | A previous run left state | Run `lab19-cleanup.sh` first |
| `find` prints many `Permission denied` | Running as non-root | Add `2>/dev/null`, or run the system-wide scans with `sudo` |
| `getcap: command not found` | `libcap2-bin` missing | `sudo apt install libcap2-bin` |
| `sudo -l -U lab19-deploy` errors | Not run as root | Prefix with `sudo` |
| Clean-up leaves `/srv/lab19` | Script run without `sudo` | Re-run `sudo bash lab19-cleanup.sh` |
| Windows cmdlets "not recognized" | PowerShell 7 on Linux, or feature absent | Run on Windows; some cmdlets need elevation/UEFI |

## Questions

1. Why is the `lab19-deploy` sudo rule classed **Critical** even though it only allows one command?
2. What two pieces of evidence most strongly suggest `sysinfo-helper` is not a legitimate system binary?
3. Why does the setup script create the lab accounts **locked**, and does that make the findings less valid?
4. The orphaned file is owned by UID 4719. Why is leaving it dangerous when you later create new users?
5. Why is the audit deliberately read-only, and when do the fixes actually happen?
6. On Windows, your audit shows `EnableSMB1Protocol : True`. Classify the severity and give the remediation command.

## Solution

??? success "Bash solution"
    ```bash
    # ---- Task 1: baseline (do this on a clean VM / before setup) ----
    mkdir -p ~/baseline
    find / -xdev -type f -perm -4000 2>/dev/null | sort > ~/baseline/suid.txt
    getcap -r / 2>/dev/null | sort > ~/baseline/caps.txt
    getent group sudo > ~/baseline/sudo.txt
    sudo bash lab19-setup.sh

    # ---- Task 2: accounts and privilege ----
    awk -F: '$3==0{print $1}' /etc/passwd                      # expect only: root
    awk -F: '$3>=1000 && $3<65534{print $1, $3, $7}' /etc/passwd
    sudo chage -l lab19-old                                    # F1: changed 2019, never expires
    getent group sudo admin                                    # F2: lab19-intern present
    sudo -l -U lab19-intern                                    # (ALL : ALL) ALL
    sudo -l -U lab19-deploy                                    # F3: NOPASSWD: /usr/bin/find
    sudo grep -rhE '^[^#].*NOPASSWD' /etc/sudoers /etc/sudoers.d/
    sudo visudo -c

    # ---- Task 3: privilege on disk ----
    find / -xdev -type f -perm -4000 2>/dev/null | sort > /tmp/suid.now
    comm -13 ~/baseline/suid.txt /tmp/suid.now                 # F4: /srv/lab19/bin/sysinfo-helper
    ls -l /srv/lab19/bin/sysinfo-helper
    dpkg -S /srv/lab19/bin/sysinfo-helper                      # "no path found" = no package
    sha256sum /srv/lab19/bin/sysinfo-helper
    find / -xdev -type d -perm -0002 ! -perm -1000 -printf '%M %u %p\n' 2>/dev/null   # F5 dir
    sudo find /etc /srv /opt /usr -xdev -type f -perm -0002 -printf '%M %u %p\n' 2>/dev/null  # F5 script
    sudo find / -xdev \( -nouser -o -nogroup \) -printf '%u:%g %p\n' 2>/dev/null      # F6
    getcap -r / 2>/dev/null | sort | comm -13 ~/baseline/caps.txt -                   # F7 net-probe

    # ---- Task 4: sensitive modes and sysctl ----
    stat -c '%a %U:%G %n' /etc/shadow /etc/gshadow /etc/passwd /etc/sudoers
    sysctl fs.protected_symlinks fs.protected_regular fs.suid_dumpable \
           kernel.kptr_restrict kernel.dmesg_restrict \
           net.ipv4.conf.all.rp_filter net.ipv4.tcp_syncookies
    grep -E '^(PASS_MAX_DAYS|UMASK|ENCRYPT_METHOD)' /etc/login.defs

    # ---- Task 6: clean up and verify ----
    sudo bash lab19-cleanup.sh
    diff ~/baseline/suid.txt <(find / -xdev -type f -perm -4000 2>/dev/null | sort) && echo "SUID OK"
    diff ~/baseline/caps.txt <(getcap -r / 2>/dev/null | sort) && echo "caps OK"
    ```

    The **clean-up script**:

    ```bash
    #!/usr/bin/env bash
    # lab19-cleanup.sh - remove everything lab19-setup.sh created.
    set -o nounset -o pipefail
    [ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
    LAB=/srv/lab19
    for u in lab19-old lab19-intern lab19-deploy; do
        getent passwd "$u" >/dev/null && { userdel -r "$u" 2>/dev/null; echo "removed $u"; }
    done
    rm -f -- /etc/sudoers.d/lab19-deploy
    visudo -c >/dev/null && echo "sudoers OK"
    [ -d "$LAB" ] && rm -rf -- "${LAB:?}" && echo "removed $LAB"
    ```

??? success "PowerShell solution"
    ```powershell
    # Run in an ELEVATED PowerShell on a Windows lab VM.
    # Execution policy per scope (baseline: RemoteSigned on servers, Restricted on clients)
    Get-ExecutionPolicy -List

    # Microsoft Defender status and any attacker-added exclusions
    Get-MpComputerStatus |
        Select-Object RealTimeProtectionEnabled, AntivirusEnabled, AntivirusSignatureAge, AMRunningMode
    Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
    Get-MpThreatDetection | Select-Object -First 5 ThreatID, InitialDetectionTime

    # Local administrators vs the approved list, and your own token
    Get-LocalGroupMember -Group Administrators
    whoami /priv
    whoami /groups | Select-String 'Integrity|Administrators'

    # Integrity of a suspect file
    Get-FileHash C:\Temp\update.exe -Algorithm SHA256
    Get-AuthenticodeSignature C:\Temp\update.exe | Select-Object Status, SignerCertificate

    # Boot chain, encryption, legacy protocol
    Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus
    Confirm-SecureBootUEFI
    Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, EnableSMB2Protocol

    # Logging posture
    $k = 'HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
    (Get-ItemProperty $k -ErrorAction SilentlyContinue).EnableScriptBlockLogging
    auditpol /get /category:* | Select-String 'Logon|Process Creation|Privilege Use'
    ```

    Record each value and compare with the secure baseline from the lesson. Remediations (apply later, under change control): remove unapproved admins; `Set-SmbServerConfiguration -EnableSMB1Protocol $false`; enable BitLocker and Secure Boot; turn on script-block logging via Group Policy; remove suspicious Defender exclusions.

??? success "Answers to questions"
    1. Because `find` can run arbitrary commands: `sudo find . -maxdepth 0 -exec /bin/sh \;` is an interactive root shell with no password. The rule's narrow look ("only find") is misleading — scope is about *what the command can do*, not its name.
    2. It is SUID-**root** but **owned by no package** (`dpkg -S` returns "no path found"), and it sits **outside** the normal system paths (`/srv`, not `/usr`), with a creation date that does not match any package install. Its hash and signature (none) complete the picture.
    3. They are locked so the lab can never create a usable login — the findings are about **misconfiguration** (stale ageing, excess privilege, a bad sudo rule), which is just as valid a finding whether or not the account can currently authenticate. In the real world the account might well be unlocked, which is worse.
    4. The file's owning UID (4719) has no name. If you later run `useradd` and the system (or you) assigns UID 4719, that new user **silently becomes the owner** of the orphaned file and gains whatever access its mode allows — an accidental privilege grant.
    5. Read-only auditing is safe to run on production at any time and preserves evidence. Fixes happen afterwards, through change control, each with a backup and a rollback (the Day 7/17/18 method) — never during the audit, so you do not destroy evidence or cause an outage mid-assessment.
    6. **High.** SMB1 is obsolete and was the EternalBlue/WannaCry vector. Remediate with `Set-SmbServerConfiguration -EnableSMB1Protocol $false` (and remove the `SMB1Protocol` Windows feature), unless a documented legacy device requires it — in which case isolate that device instead.
