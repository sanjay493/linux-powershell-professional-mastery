---
description: "Investigate a jump host after a SOC alert: classify a password spray, a single-account brute force and a credential-stuffing attempt from auth.log and its rotated copies, find the compromised account and what it did, run failed-login-report.sh, check sshd -T hardening, safely practise pam_faillock with a rollback, and repeat on Windows with Get-WinEvent, SubStatus codes and net accounts."
---

# Lab 17: Who Got In?

| Field | Value |
|---|---|
| **Lab ID** | LAB-17 |
| **Related lesson** | [Day 17: Authentication and Security Monitoring](../course/module-4/day-17.md) |
| **Difficulty** | Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Low. All generated logs live under `~/lab17`. The optional `pam_faillock` task edits PAM on a **throwaway VM/user only**, with backups and a tested rollback; **never** do it on a machine you cannot afford to be locked out of. The Windows task generates failures for a **local lab account only**. |

## Objective

A SOC alert fired overnight: *"Excessive SSH authentication failures on `jump01` (the Northwind bastion), 02:00–03:30."* You have the host's `auth.log` and its rotated copies. Reconstruct what happened:

1. Classify every attack pattern in the logs — **password spray**, **single-account brute force**, and a **credential-stuffing** attempt.
2. Determine whether anyone **got in**: find the **compromised account**, the attacker address and the exact success-after-failure moment.
3. Trace what the account did after it logged in (`sudo`/`su`).
4. Confirm your findings with the course's `failed-login-report.sh`.
5. Check the **live host's** SSH hardening with `sshd -T`, and safely practise `pam_faillock` with a rollback.
6. Repeat the core investigation on **Windows** with `Get-WinEvent`, SubStatus codes and `net accounts`.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS (VM, WSL2 or a container) with `bash`, `awk`, `grep`, `gzip`, and the course repository available. `openssh-server`, `sudo` and `libpam-modules-bin` (for `faillock`) are needed for Tasks 5–6; install with `sudo apt install openssh-server libpam-modules-bin`. The optional faillock task requires a **disposable VM** where a lockout is harmless.
- **Windows (optional Task 7):** Windows 11 with an **elevated** PowerShell (Windows PowerShell 5.1 or 7) and permission to create a local lab user. You must be able to read the **Security** log (administrator).
- The course script `scripts/linux/failed-login-report.sh` (and `scripts/powershell/Failed-Login-Report.ps1` for Windows).

## Initial Conditions

- `~/lab17` **must not exist** yet. Check: `ls -d ~/lab17` should report `No such file or directory`. The setup script removes and recreates it.
- You will **not** modify the live system in Tasks 1–4 — they read generated files only.
- All addresses in the dataset are from documentation ranges (`203.0.113.0/24`, `198.51.100.0/24`, RFC 5737) and all accounts are fictional.

## Step-by-Step Instructions

### Task 0 — Generate the evidence

Save the script below as `~/lab17-setup.sh`, read it (never run a script you have not read), then run it. It writes `~/lab17/logs/auth.log`, `auth.log.1` and `auth.log.2.gz` — the current and rotated authentication logs of `jump01`.

```bash
#!/usr/bin/env bash
# lab17-setup.sh — generate jump01's auth logs for Lab 17 (safe, local, deterministic).
set -o nounset -o pipefail
LAB="${1:-$HOME/lab17}"
LOGS="$LAB/logs"
rm -rf -- "$LAB"
mkdir -p -- "$LOGS"

# Emit one auth.log line. $1 day (e.g. 12), $2 time "HH:MM:SS.mmmmmm", $3 message.
A() { printf '2026-11-%02dT%s+00:00 jump01 %s\n' "$1" "$2" "$3"; }

# ---------- auth.log.2.gz : 2026-11-11, a normal day (baseline noise) ----------
{
  A 11 '08:02:11.114003' 'sshd[1201]: Accepted publickey for deploy from 198.51.100.24 port 51110 ssh2: ED25519 SHA256:7Hq0m9m4f1ucu5n0Pp3Yl2b8c1a2b3c4d5e6f7g8h9i'
  A 11 '08:02:11.116210' 'sshd[1201]: pam_unix(sshd:session): session opened for user deploy(uid=120) by (uid=0)'
  A 11 '09:17:40.550101' 'sudo:   deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/systemctl restart northwind-api'
  A 11 '18:40:02.330900' 'sshd[1450]: Received disconnect from 198.51.100.24 port 51110:11: disconnected by user'
} > "$LOGS/auth.log.2"
gzip -n "$LOGS/auth.log.2"

# ---------- auth.log.1 : 2026-11-12, reconnaissance (password spray) ----------
{
  u=0
  for acct in root admin oracle postgres git jenkins deploy backup test ubuntu; do
    A 12 "21:4$((u/10)):$(printf '%02d' $((u%60))).100000" "sshd[$((3000+u))]: Invalid user $acct from 203.0.113.45 port $((40100+u))"
    A 12 "21:4$((u/10)):$(printf '%02d' $((u%60))).300000" "sshd[$((3000+u))]: Failed password for invalid user $acct from 203.0.113.45 port $((40100+u)) ssh2"
    u=$((u+1))
  done
  A 12 '21:49:55.400000' 'sshd[3099]: Failed password for deploy from 203.0.113.45 port 40200 ssh2'
} > "$LOGS/auth.log.1"

# ---------- auth.log : night of 2026-11-13 (the incident) ----------
{
  # 03:00-03:05 brute force on a single account "deploy" from 203.0.113.45
  for i in $(seq 0 24); do
    tsec=$((i*12)); mm=$(printf '%02d' $((tsec/60))); ss=$(printf '%02d' $((tsec%60)))
    A 13 "03:${mm}:${ss}.$(printf '%06d' $((i*1000)))" "sshd[$((4200+i))]: Failed password for deploy from 203.0.113.45 port $((45000+i)) ssh2"
  done
  # 03:05 a second address tries a short list of VALID users (credential-stuffing style)
  A 13 '03:05:10.110000' 'sshd[4300]: Failed password for deploy from 198.51.100.77 port 50010 ssh2'
  A 13 '03:05:12.120000' 'sshd[4301]: Failed password for backup-svc from 198.51.100.77 port 50020 ssh2'
  A 13 '03:05:14.130000' 'sshd[4302]: Failed password for jenkins from 198.51.100.77 port 50030 ssh2'
  # 03:06 success-after-failure: attacker 203.0.113.45 finally guesses deploy
  A 13 '03:06:01.500000' 'sshd[4330]: Accepted password for deploy from 203.0.113.45 port 46050 ssh2'
  A 13 '03:06:01.502000' 'sshd[4330]: pam_unix(sshd:session): session opened for user deploy(uid=1020) by (uid=0)'
  # 03:06-03:08 the attacker acts: sudo misuse. deploy is not in sudoers.
  A 13 '03:06:40.210000' 'sudo:   deploy : user NOT in sudoers ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/cat /etc/shadow'
  A 13 '03:07:12.900000' 'su: pam_unix(su:auth): authentication failure; logname= uid=1020 euid=0 tty=pts/1 ruser=deploy rhost=  user=root'
  A 13 '03:07:14.400000' 'su[4360]: FAILED SU (to root) deploy on pts/1'
  A 13 '03:07:48.700000' 'su: pam_unix(su:auth): authentication failure; logname= uid=1020 euid=0 tty=pts/1 ruser=deploy rhost=  user=postgres'
  A 13 '03:07:50.120000' 'su[4362]: FAILED SU (to postgres) deploy on pts/1'
  # 03:09 legitimate admin login as noise (publickey, known address)
  A 13 '03:09:30.330000' 'sshd[4400]: Accepted publickey for carol from 198.51.100.24 port 52120 ssh2: ED25519 SHA256:7Hq0m9m4f1ucu5n0Pp3Yl2b8c1a2b3c4d5e6f7g8h9i'
  A 13 '03:09:30.332000' 'sshd[4400]: pam_unix(sshd:session): session opened for user carol(uid=1001) by (uid=0)'
  A 13 '03:10:02.700000' 'sudo:   carol : TTY=pts/2 ; PWD=/home/carol ; USER=root ; COMMAND=/usr/bin/journalctl -u ssh'
  A 13 '03:20:11.900000' 'sshd[4330]: Received disconnect from 203.0.113.45 port 46050:11: disconnected by user'
  A 13 '03:20:11.901000' 'sshd[4330]: pam_unix(sshd:session): session closed for user deploy'
} > "$LOGS/auth.log"

printf 'Lab 17 ready: %s/auth.log %s/auth.log.1 %s/auth.log.2.gz\n' "$LOGS" "$LOGS" "$LOGS"
```

Run it:

```bash
less ~/lab17-setup.sh          # read it first, press q to quit
bash ~/lab17-setup.sh
cd ~/lab17/logs
ls -l
```

Expected: `Lab 17 ready: …/auth.log …/auth.log.1 …/auth.log.2.gz` and three files.

### Task 1 — Classify the attack patterns

Work in `~/lab17/logs`. Using `grep`, `zgrep`, `sed`/`awk`, `sort` and `uniq -c`:

1. In `auth.log.1` (2026-11-12), is the activity against **one** account or **many**? Count the distinct target accounts from `203.0.113.45`. What attack pattern is this?
2. In `auth.log` (the incident night), how many `Failed password for deploy` come from `203.0.113.45`, and over what time span? What pattern is this?
3. The address `198.51.100.77` makes a handful of attempts against **valid** accounts (`deploy`, `backup-svc`, `jenkins`) with no `invalid user` lines. What pattern does that suggest, and how does it differ from the spray?

### Task 2 — Did anyone get in?

1. Search **all** `auth.log*` files (including the compressed one) for every `Accepted` login. List time, method, account and source.
2. Which `Accepted` came from an **attacker** address that also had failures? That is your compromised account.
3. State the exact timestamp of the success-after-failure and the attacker IP.

### Task 3 — What did the account do?

1. Find every `sudo` and `su` line for the compromised account **after** its login time.
2. Did its privilege escalation **succeed**? Explain from the log lines.
3. Separate the attacker's actions from the legitimate admin (`carol`) noise at 03:09–03:10.

### Task 4 — Confirm with the report script

Run the course script on the incident file and on the full set:

```bash
cd ~/linux-powershell-professional-mastery   # or wherever the repo is
bash scripts/linux/failed-login-report.sh -l ~/lab17/logs/auth.log -s 0 -t 10
echo "exit: $?"
# include the rotated files by concatenating into one temp file (decompressing the .gz)
tmp=$(mktemp)
zcat -f ~/lab17/logs/auth.log.2.gz; cat ~/lab17/logs/auth.log.1 ~/lab17/logs/auth.log > "$tmp"
# (order: oldest first) — rebuild properly:
{ zcat -f ~/lab17/logs/auth.log.2.gz; cat ~/lab17/logs/auth.log.1 ~/lab17/logs/auth.log; } > "$tmp"
bash scripts/linux/failed-login-report.sh -l "$tmp" -s 0 -t 10
echo "exit: $?"
rm -f "$tmp"
```

Confirm: which address is at/over the threshold, what the "Success after failure" line says, and that the exit code is **3** (alert).

### Task 5 — Check the live host's hardening

On the **lab VM itself** (not the generated files):

```bash
sudo sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|maxauthtries|pubkeyauthentication|loglevel) '
```

Decide whether this host would have been vulnerable to the brute force you just analysed. If `passwordauthentication` is `yes`, describe (do **not** necessarily apply) the drop-in you would add under `/etc/ssh/sshd_config.d/` to require keys and lower `MaxAuthTries` — and why you must confirm key access **before** disabling passwords.

### Task 6 — Practise `pam_faillock` safely (disposable VM only)

!!! danger "Only on a throwaway VM. Keep a second root shell open the whole time."
    A faillock mistake can lock out every account. Do not do this on a machine you rely on.

1. Open a **second terminal as root** (`sudo -i`) and leave it open — this is your escape hatch.
2. Back up the PAM files:

    ```bash
    sudo cp -a /etc/pam.d/common-auth /etc/pam.d/common-auth.lab17.bak
    sudo cp -a /etc/pam.d/common-account /etc/pam.d/common-account.lab17.bak
    sudo cp -a /etc/security/faillock.conf /etc/security/faillock.conf.lab17.bak
    ```

3. Create a throwaway user: `sudo useradd -m -s /bin/bash lab17-victim && echo 'lab17-victim:Victim-Pass-17!' | sudo chpasswd`.
4. Enable faillock (`deny=3`, `unlock_time=300`) following the lesson's safe method, then from a normal shell make **three** failed `su - lab17-victim` attempts with a wrong password and a fourth with the **correct** one. Observe the lockout.
5. Inspect and reset: `sudo faillock --user lab17-victim`, then `sudo faillock --user lab17-victim --reset`; confirm the correct password now works.
6. **Roll back** by restoring the three backups and confirm `diff` shows no difference from the originals. Remove the throwaway user: `sudo userdel -r lab17-victim`.

### Task 7 — Windows (optional)

On a lab Windows 11 machine, elevated:

1. Create a local lab user: `New-LocalUser -Name lab17-user -Password (Read-Host -AsSecureString) -AccountNeverExpires`.
2. Generate failed logons safely (no lockout needed): run `runas /user:lab17-user cmd` and enter a **wrong** password three times (or `net use \\localhost\IPC$ /user:lab17-user wrongpw`, then `net use \\localhost\IPC$ /delete`).
3. Read the failures and decode them:

    ```powershell
    Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4625; StartTime=(Get-Date).AddMinutes(-15) } |
        ForEach-Object {
            $x = ([xml]$_.ToXml()).Event.EventData.Data
            [pscustomobject]@{
                Time    = $_.TimeCreated
                Target  = ($x | Where-Object Name -eq 'TargetUserName').'#text'
                Type    = ($x | Where-Object Name -eq 'LogonType').'#text'
                SubStat = ($x | Where-Object Name -eq 'SubStatus').'#text'
            }
        } | Format-Table -AutoSize
    ```

4. Check the account/lockout policy with `net accounts` and the account with `net user lab17-user`.
5. Clean up: `Remove-LocalUser -Name lab17-user`.

## Commands to Execute

Try each task yourself before opening the [Solution](#solution). The exact commands are there.

## Expected Results

- **Task 1:** `auth.log.1` targets **10 distinct accounts** from one address → **password spray**. The incident file has **25** `Failed password for deploy` from `203.0.113.45` over ~03:00–03:05 → **single-account brute force**. `198.51.100.77` hits three **valid** accounts a few times each → **credential-stuffing** style.
- **Task 2:** The only `Accepted` from an attacker address is **`Accepted password for deploy from 203.0.113.45`** at **2026-11-13T03:06:01** — the compromised account is **`deploy`**.
- **Task 3:** `deploy` then ran `sudo cat /etc/shadow` but was **`NOT in sudoers`** (denied), and made two **`FAILED SU`** attempts (to `root` and `postgres`) — escalation **failed**. `carol`'s 03:09 publickey login and `sudo journalctl` are **legitimate** noise.
- **Task 4:** `203.0.113.45` is over the threshold; "Success after failure" names `deploy`; exit code **3**.
- **Task 5:** On a default Ubuntu host `passwordauthentication` is `yes` and `maxauthtries` is `6` → it **would** have been brute-forceable.
- **Task 6:** `lab17-victim` locks after 3 failures, `faillock --reset` unlocks it, and the rollback leaves the PAM files byte-identical to the backups.
- **Task 7:** Three 4625 events for `lab17-user` with SubStatus `0xC000006A` (wrong password), logon type 2 (or 3 for `net use`).

## Verification Steps

```bash
# Task 1
zcat -f ~/lab17/logs/auth.log.1 | grep -oE 'from 203.0.113.45' | wc -l          # 21 attempts (spray + 1 deploy)
zcat -f ~/lab17/logs/auth.log.1 | grep -oE 'user [a-z0-9_-]+ from' | awk '{print $2}' | sort -u | wc -l
grep -c 'Failed password for deploy from 203.0.113.45' ~/lab17/logs/auth.log    # 25

# Task 2
{ zcat -f ~/lab17/logs/auth.log.2.gz; cat ~/lab17/logs/auth.log.1 ~/lab17/logs/auth.log; } | grep 'Accepted'

# Task 4
bash ~/linux-powershell-professional-mastery/scripts/linux/failed-login-report.sh -l ~/lab17/logs/auth.log -s 0 -t 10 >/dev/null; echo $?   # 3
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `bash: ~/lab17-setup.sh: No such file or directory` | Script not saved or wrong path | Save it, then `bash ~/lab17-setup.sh` |
| `zcat: auth.log.2.gz: No such file` | Ran from the wrong directory | `cd ~/lab17/logs` first |
| `grep -c` gives a smaller number than expected | On a **real** host rsyslog folds repeats; the lab file does not, so counts are exact | Count from the journal on real hosts |
| `failed-login-report.sh: command not found` | Wrong path to the repo | Use the full path to `scripts/linux/failed-login-report.sh` |
| Locked out of the VM in Task 6 | faillock misconfigured and no spare root shell | Use the open root shell to restore the `.lab17.bak` files and `faillock --reset`; this is why Step 1 keeps one open |
| `sshd -T` → `Permission denied` | Needs to read host keys | Run with `sudo` |
| Windows: `Get-WinEvent … Security` → Access denied | Not elevated | Run PowerShell as administrator |
| Windows: no 4625 events | Logon auditing disabled | `auditpol /get /subcategory:"Logon"`; enable via Group Policy on a lab host |

## Questions

1. How did you tell the password spray (12 Nov) apart from the brute force (13 Nov) just from the log shape?
2. Why is `198.51.100.77`'s activity classed as credential-stuffing-like rather than spraying?
3. Which single line is the most important in the whole incident, and why?
4. Did the attacker gain root? Cite the exact lines that prove your answer.
5. Why is `carol`'s activity not an alert, even though it includes `sudo` running as root?
6. Why does the report script exit `3` on this data, and what would make it exit `0`?
7. On the live host, which one `sshd` setting would have prevented the brute force entirely, and what must you verify before enabling it?
8. In Task 6, why keep a second root shell open the entire time?

## Solution

??? success "Bash solution"
    **Task 1 — classify**

    ```bash
    cd ~/lab17/logs
    # (1) spray: distinct target accounts from .45 on 12 Nov
    zcat -f auth.log.1 | grep -oE 'user [a-z0-9_-]+ from 203.0.113.45' | awk '{print $2}' | sort -u
    zcat -f auth.log.1 | grep -oE 'user [a-z0-9_-]+ from 203.0.113.45' | awk '{print $2}' | sort -u | wc -l   # 10 accounts
    # (2) brute force: one account, many tries, time span
    grep 'Failed password for deploy from 203.0.113.45' auth.log | wc -l                                      # 25
    grep 'Failed password for deploy from 203.0.113.45' auth.log | sed -nE '1p;$p' | cut -c1-19               # 03:00:00 .. 03:04:48
    # (3) stuffing-like: valid accounts, few tries, no "invalid user", different address
    grep '198.51.100.77' auth.log
    ```

    *Spray* = 10 different accounts, one try each, all `invalid user` except `deploy`. *Brute force* = 25 tries against the single existing account `deploy` in ~5 minutes. *Credential-stuffing style* = `198.51.100.77` hits three **real** accounts a couple of times with no `invalid user` lines, as if using known-valid usernames.

    **Task 2 — did anyone get in?**

    ```bash
    { zcat -f auth.log.2.gz; cat auth.log.1 auth.log; } | grep 'Accepted'
    ```

    ```text
    2026-11-11T08:02:11… Accepted publickey for deploy from 198.51.100.24 …   # legitimate (baseline)
    2026-11-13T03:06:01… Accepted password for deploy from 203.0.113.45 …     # COMPROMISE
    2026-11-13T03:09:30… Accepted publickey for carol  from 198.51.100.24 …   # legitimate admin
    ```

    The `Accepted password for deploy from 203.0.113.45` at **03:06:01** follows 25 failures from that same address: **`deploy` is compromised** via a guessed password.

    **Task 3 — what did it do?**

    ```bash
    awk '$1 >= "2026-11-13T03:06" && $1 < "2026-11-13T03:21"' auth.log | grep -E 'sudo|su\[|su:'
    ```

    ```text
    03:06:40 sudo: deploy : user NOT in sudoers ; … COMMAND=/usr/bin/cat /etc/shadow
    03:07:14 su[4360]: FAILED SU (to root) deploy on pts/1
    03:07:50 su[4362]: FAILED SU (to postgres) deploy on pts/1
    ```

    `deploy` tried `sudo cat /etc/shadow` (denied: **not in sudoers**) and two `su` attempts (to `root` and `postgres`) that **failed**. Escalation did **not** succeed. `carol`'s 03:09 publickey login and `sudo journalctl -u ssh` are normal admin activity from the known address `198.51.100.24`.

    **Task 4 — report**

    ```bash
    cd ~/linux-powershell-professional-mastery
    bash scripts/linux/failed-login-report.sh -l ~/lab17/logs/auth.log -s 0 -t 10 ; echo "exit: $?"
    ```

    Key lines: `203.0.113.45` has 25 failures against 1 account and is **at/over threshold**; **Success after failure** names `deploy` at 03:06; **exit code 3**.

    **Task 5 — hardening (inspect; apply only on a lab VM)**

    ```bash
    sudo sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|maxauthtries|loglevel) '
    # Hardening drop-in (only after confirming key login works!):
    #   printf 'PasswordAuthentication no\nMaxAuthTries 3\nPermitRootLogin no\nLogLevel VERBOSE\n' \
    #     | sudo tee /etc/ssh/sshd_config.d/60-hardening.conf
    #   sudo sshd -t && sudo systemctl reload ssh
    ```

    A default host (`passwordauthentication yes`, `maxauthtries 6`) **was** brute-forceable. `PasswordAuthentication no` removes password guessing entirely — but confirm your key works first, or you lock yourself out.

    **Task 6 — faillock (throwaway VM, second root shell open)**

    ```bash
    # escape hatch: a second terminal running  sudo -i   stays open

    sudo cp -a /etc/pam.d/common-auth{,.lab17.bak}
    sudo cp -a /etc/pam.d/common-account{,.lab17.bak}
    sudo cp -a /etc/security/faillock.conf{,.lab17.bak}
    sudo useradd -m -s /bin/bash lab17-victim && echo 'lab17-victim:Victim-Pass-17!' | sudo chpasswd

    # enable faillock: common-auth
    sudo tee /etc/pam.d/common-auth >/dev/null <<'PAM'
    auth    requisite                       pam_faillock.so preauth
    auth    [success=2 default=ignore]      pam_unix.so nullok
    auth    [default=die]                   pam_faillock.so authfail
    auth    requisite                       pam_deny.so
    auth    sufficient                      pam_faillock.so authsucc
    auth    required                        pam_permit.so
    PAM
    # add the account line and policy
    sudo sed -i '0,/^account/s//account\trequired\t\t\tpam_faillock.so\n&/' /etc/pam.d/common-account
    printf 'deny = 3\nunlock_time = 300\n' | sudo tee -a /etc/security/faillock.conf

    # three wrong, one right
    for p in bad1 bad2 bad3; do echo "$p" | su - lab17-victim -c true 2>/dev/null; done
    echo 'Victim-Pass-17!' | su - lab17-victim -c 'echo got-in' 2>&1   # denied: locked
    sudo faillock --user lab17-victim                                   # shows 3 valid failures
    sudo faillock --user lab17-victim --reset
    echo 'Victim-Pass-17!' | su - lab17-victim -c 'echo got-in'         # now works

    # ROLLBACK
    sudo cp -a /etc/pam.d/common-auth.lab17.bak      /etc/pam.d/common-auth
    sudo cp -a /etc/pam.d/common-account.lab17.bak   /etc/pam.d/common-account
    sudo cp -a /etc/security/faillock.conf.lab17.bak /etc/security/faillock.conf
    diff /etc/pam.d/common-auth /etc/pam.d/common-auth.lab17.bak && echo "common-auth restored"
    sudo userdel -r lab17-victim
    ```

    (The `su` password-piping above is a lab shortcut; interactively you would type the password at the prompt. The point is the lockout after three failures and the clean rollback.)

??? success "PowerShell solution"
    **Task 7 — generate and read 4625 (elevated, lab Windows)**

    ```powershell
    # 1. create a local lab user
    $pw = Read-Host -AsSecureString "Password for lab17-user"
    New-LocalUser -Name lab17-user -Password $pw -AccountNeverExpires -Description 'Lab 17 throwaway'

    # 2. generate three failed logons with a WRONG password (no lockout needed)
    1..3 | ForEach-Object { net use \\localhost\IPC$ /user:lab17-user wrongpw 2>$null }
    net use \\localhost\IPC$ /delete 2>$null

    # 3. read and decode them
    Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4625; StartTime=(Get-Date).AddMinutes(-15) } |
        ForEach-Object {
            $x = ([xml]$_.ToXml()).Event.EventData.Data
            [pscustomobject]@{
                Time    = $_.TimeCreated
                Target  = ($x | Where-Object Name -eq 'TargetUserName').'#text'
                Type    = ($x | Where-Object Name -eq 'LogonType').'#text'
                SubStat  = ($x | Where-Object Name -eq 'SubStatus').'#text'
            }
        } | Format-Table -AutoSize

    # 4. policy and account
    net accounts
    net user lab17-user

    # 5. clean up
    Remove-LocalUser -Name lab17-user
    ```

    Expected: three 4625 rows for `lab17-user` with `SubStatus 0xC000006A` (wrong password) and `LogonType 3` (network, from `net use`). `net accounts` shows the lockout threshold; if it is `Never`, Windows is not locking accounts.

??? success "Answers to questions"
    1. The spray hits **many accounts** once each (mostly `invalid user`); the brute force hits **one existing account** (`deploy`) many times. Different account cardinality, same source.
    2. `198.51.100.77` targets only **valid** accounts (`deploy`, `backup-svc`, `jenkins`) a few times each with **no** `invalid user` lines — consistent with trying known-valid username/password pairs (stuffing), not guessing usernames (spraying).
    3. `2026-11-13T03:06:01 Accepted password for deploy from 203.0.113.45` — the success-after-failure that proves the brute force worked and `deploy` is compromised.
    4. **No.** `sudo … user NOT in sudoers` (denied) and two `FAILED SU (to root)` / `(to postgres)` lines show both escalation routes failed.
    5. `carol` logged in with a **public key** from the **known** address `198.51.100.24`, and `carol` is a legitimate admin whose `sudo` is permitted (a normal `COMMAND=` line, no failures). It matches the baseline, not the attack.
    6. The script exits `3` because an address reached the failure threshold **and** a success-after-failure was found. It would exit `0` only if no address reached the threshold and there were no success-after-failure events (e.g. a quiet day).
    7. `PasswordAuthentication no` (keys only) removes password brute force entirely. Verify that key-based login already works for your admin account **before** disabling passwords, or you will be locked out.
    8. A faillock misconfiguration can lock out **every** account including the one you are using. An already-authenticated root shell lets you restore the backups and `faillock --reset` without needing to log in again.

## Clean-up

```bash
rm -rf ~/lab17 ~/lab17-setup.sh
# If you did Task 6, confirm the PAM files are restored and the throwaway user is gone:
sudo userdel -r lab17-victim 2>/dev/null
ls /etc/pam.d/*.lab17.bak 2>/dev/null && echo "remove the .lab17.bak files once you have confirmed the rollback"
```
