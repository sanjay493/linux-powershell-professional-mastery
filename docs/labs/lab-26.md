---
description: "Join the ops team and replace password logins with keys on a lab server (a private sshd on 127.0.0.1:2222): verify the host key fingerprint out of band, generate an ed25519 key with a passphrase, install it, fix a planted authorized_keys permission problem and a stale contractor key, write ~/.ssh/config with ProxyJump, run a BatchMode/ConnectTimeout fleet loop with exit codes, transfer files with scp, sftp -b and rsync --dry-run, open an -L tunnel to an internal page, harden sshd with a drop-in (sshd -t, safety session, password login refused), find which key logged in; then PowerShell Remoting on Windows (Enable-PSRemoting, Invoke-Command fan-out, $using:, Copy-Item -ToSession, deserialized objects, PowerShell 7 SSH remoting) and a complete clean-up."
---

# Lab 26: Secure Remote Access

| Field | Value |
|---|---|
| **Lab ID** | LAB-26 |
| **Related lesson** | [Day 26: Remote Administration](../course/module-6/day-26.md) |
| **Difficulty** | Advanced |
| **Time** | 2–3 hours (Linux part 90–120 minutes, Windows part 45–60 minutes) |
| **Risk level** | Low to medium. The Linux part runs a **separate** `sshd` on `127.0.0.1:2222` with its own configuration under `/srv/lab26` and a throwaway account `lab26-ops`; it never edits `/etc/ssh/sshd_config` or your real `sshd`. It needs `sudo` (to create the account and start the lab daemon) — use a **lab VM or WSL2**, take a snapshot first. The Windows part enables PowerShell Remoting and optionally OpenSSH Server: do it **only on a lab VM** you can revert, and follow the clean-up section. |

## Objective

You joined the operations team on Monday. The team lead hands you three things: access to a lab "server" (`lab26-srv`), a note that it still uses **password** logins for the shared `lab26-ops` account, and a ticket: *"Move lab26-srv to key-only access, make sure nobody else can get in, document which key is used, and show me you can work on it remotely and safely."* The server team also sent the server's **host key fingerprint** through the ticket system — the out-of-band value you must check before trusting the server.

By the end you will have:

1. verified the host key, created a passphrase-protected `ed25519` key and installed it;
2. found and fixed why the key is refused, and removed a key that should not be there;
3. a `~/.ssh/config` with aliases and a `ProxyJump` entry, and a fleet script that reports per-host exit codes;
4. moved files with `scp`, `sftp -b` and `rsync` (previewed first), and reached an internal-only web page through a tunnel;
5. hardened the server (keys only, three tries, one group, no agent/remote forwarding), validated before reload, with a safety session open;
6. proven from the log **which key** logged in;
7. done the same kind of work on Windows with PowerShell Remoting (WinRM and SSH) — and cleaned everything up.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS (VM or WSL2) with `sudo`, `openssh-server` and `openssh-client`, `rsync`, `python3`, `curl` (`sudo apt install openssh-server rsync curl`). The setup does **not** need the system `ssh` service running and does not change it. Ports `127.0.0.1:2222` and `127.0.0.1:8026` must be free.
- **Windows (Tasks 11–16):** a Windows 11 or Windows Server 2022 **lab VM**, Windows PowerShell 5.1 (elevated for some tasks) and PowerShell 7.4+ for Task 15. For Task 15 the Linux lab host needs PowerShell 7 too (`sudo snap install powershell --classic`, or Microsoft's package repository) and must be reachable from Windows — with **WSL2** on the same Windows machine, `localhost:2222` reaches the lab `sshd` through WSL's localhost forwarding; with a separate VM, see the note in Task 15.
- About 10 MB of disk space.

## Initial Conditions

- No account `lab26-ops`, no `/srv/lab26`, no `~/lab26` (run the clean-up script first if you repeat the lab).
- Save `lab26-setup.sh`, `lab26-cleanup.sh` and `lab26-fleet.sh` from the [Solution](#solution) section into your home directory, **read them**, then run the setup **with sudo from your normal account** (the script uses `SUDO_USER` to know who you are):

```bash
cd ~ && sudo bash lab26-setup.sh
```

**Expected output (captured on 2026-11-19; your fingerprint is different — it is generated fresh):**

```text
Lab 26 ready.
  Lab sshd         : 127.0.0.1:2222  (config /srv/lab26/sshd_config, log /srv/lab26/logs/sshd.log)
  Target account   : lab26-ops (temporary password in /home/student/lab26/ops-password.txt)
  Internal web page: 127.0.0.1:8026 on the server (reach it through an SSH tunnel)
  Out-of-band host key fingerprint ("from the server team"):
    256 SHA256:dNN7rl/cpjhCu9TVQhJ/E1EkKKBrb3lw9PJTutA+LJs lab26-hostkey (ED25519)
  Workspace        : /home/student/lab26
```

What the setup built:

```text
/srv/lab26/
├── sshd_config                 lab sshd: 127.0.0.1:2222, PasswordAuthentication yes, LogLevel VERBOSE,
│                               AllowUsers lab26-ops, Include /srv/lab26/sshd_config.d/*.conf FIRST
├── sshd_config.d/              empty - your hardening drop-in goes here (Task 8)
├── hostkeys/                   the lab server's own ed25519 host key
├── hostkey-fingerprint.txt     the "out-of-band" fingerprint from the server team
├── logs/sshd.log               the lab sshd's log (-E), readable with sudo
├── sshd.pid                    PID of the lab sshd (reload = kill -HUP)
└── www/index.html              internal status page, served on 127.0.0.1:8026 only
/home/lab26-ops/.ssh/authorized_keys   (planted problems - find them)
~/lab26/                        hosts.txt, files/report.txt, deploy/*.conf, ops-password.txt
```

You are also added to the group `lab26-ssh` (the "ops team" group). The new group membership is not needed in your current session.

## Step-by-Step Instructions

Work as your normal user in `~/lab26`. Use `sudo` only where a task says so. Keep notes of every command and result — the ticket needs them.

### Task 1 — Verify the host key out of band

Read the fingerprint the server team sent (`/srv/lab26/hostkey-fingerprint.txt`). Collect the server's key with `ssh-keyscan -p 2222 -t ed25519 127.0.0.1`, compute its fingerprint with `ssh-keygen -lf`, and compare the two **character by character** (or with a script). Only then connect for the first time (`ssh -p 2222 lab26-ops@127.0.0.1`) and answer the host-key question — by typing `yes` or by pasting the expected fingerprint. Press Ctrl+C at the password prompt. Look at the resulting `~/.ssh/known_hosts` line: why can you not read the host name?

### Task 2 — Create your key

Create `~/.ssh/lab26_ed25519` with `ssh-keygen -t ed25519 -a 100`, a meaningful comment (`you@host lab26 YYYY-MM`) and a **passphrase**. Check the file modes in `~/.ssh` and write down the key's fingerprint.

### Task 3 — Install the key and fix what is wrong

1. Install the public key with `ssh-copy-id -i ~/.ssh/lab26_ed25519.pub -p 2222 lab26-ops@127.0.0.1`, using the temporary password from `~/lab26/ops-password.txt`.
2. Test a **key-only** login: `ssh -o PasswordAuthentication=no -i ~/.ssh/lab26_ed25519 -p 2222 lab26-ops@127.0.0.1 id`. It fails. Find the reason in the **server** log (`sudo tail /srv/lab26/logs/sshd.log`).
3. Log in with the password (`-o PubkeyAuthentication=no`) and inspect `~/.ssh/authorized_keys` with `ls -l` and `ssh-keygen -lf`. You will find something else that should not be there.
4. Back up the file (with safe permissions), remove the unexpected key, fix the permissions, and prove the key-only login now works.

### Task 4 — Client configuration, agent and ProxyJump

Create `~/.ssh/config.d/lab26.conf` with three hosts and a wildcard defaults block, and include it from the **top** of `~/.ssh/config`:

- `lab26-srv` → `127.0.0.1`, port 2222, user `lab26-ops`;
- `lab26-srv-b` → the same server, but reached **through** `lab26-srv` with `ProxyJump` (in real life: an internal server behind a bastion);
- `lab26-down` → `127.0.0.1` port **2299** (nothing listens there — your "broken" fleet member);
- `Host lab26-*` defaults: `IdentityFile ~/.ssh/lab26_ed25519`, `IdentitiesOnly yes`, `ConnectTimeout 5`, `ServerAliveInterval 30`.

Check the result with `ssh -G lab26-srv-b`. Start `ssh-agent`, add your key with a one-hour lifetime, and log in to `lab26-srv-b`. Explain in your notes why `ProxyJump` is preferable to `ssh -A` to a bastion.

### Task 5 — Fleet command loop

1. Demonstrate the `while read` + `ssh` stdin bug on `~/lab26/hosts.txt` (without `-n`) and note how many hosts were processed.
2. Run `lab26-fleet.sh` (from the Solution — read it first). It must use `-n`, `BatchMode=yes`, `ConnectTimeout`, print `host,exit_code,status,output` CSV and exit **3** when any host fails. Record the exit code.
3. Run the remote command `echo $HOME $USER` once with double and once with single quotes and explain the difference.

### Task 6 — File transfer

1. `scp` `files/report.txt` to `/tmp/lab26-report.txt` on the server and download `motd.txt` from the server's home directory.
2. Write `sftp-batch.txt` that uploads `files/report.txt` as `/tmp/lab26-sftp.txt`, lists `/tmp/lab26-*` and downloads it back as `files/back.txt`; run it with `sftp -b` and prove the round trip with `cmp`.
3. Synchronise `~/lab26/deploy/` to `~/deploy/` on the server with `rsync`: **dry run first**, then for real. Explain what the dry run would have done **without** the trailing slash.

### Task 7 — Tunnel to the internal page

The status page listens only on the server's `127.0.0.1:8026`. Open a background tunnel `-f -N -L 127.0.0.1:18026:127.0.0.1:8026` (with `ExitOnForwardFailure=yes`), fetch `http://127.0.0.1:18026/` with `curl`, then close the tunnel and verify it is gone.

### Task 8 — Harden the lab sshd

1. Open a **safety session** in a second terminal and leave it open: `ssh lab26-srv` (in a real change this is your root session).
2. Back up the lab config (`sudo cp -a /srv/lab26/sshd_config /srv/lab26/sshd_config.bak-lab26`).
3. Create `/srv/lab26/sshd_config.d/10-lab26-hardening.conf` with: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `MaxAuthTries 3`, `LoginGraceTime 30`, `AllowGroups lab26-ssh`, `AllowAgentForwarding no`, `AllowTcpForwarding local` (ProxyJump and `-L` still work, `-R` does not), `X11Forwarding no`.
4. Validate with `sudo /usr/sbin/sshd -t -f /srv/lab26/sshd_config`, show the effective values with `sshd -T -f …`, then reload the lab daemon: `sudo kill -HUP "$(cat /srv/lab26/sshd.pid)"` (on a real Ubuntu server: `sudo systemctl reload ssh`).
5. From a **new** terminal prove: a password login is refused, a key login works, a remote forward (`-R`) is refused — and the safety session is still alive.
6. Optional: deliberately put a typo in the drop-in, run `sshd -t`, and read the error before fixing it.

### Task 9 — Which key logged in?

With `sudo`, extract the `Accepted publickey` lines from `/srv/lab26/logs/sshd.log`, count logins per fingerprint, and map the fingerprint to a key comment with `ssh-keygen -lf /home/lab26-ops/.ssh/authorized_keys`. Also find the earlier `Authentication refused` and `Accepted password` lines — what do they document?

### Task 10 (optional) — A restricted monitoring key

Create a passphrase-less key `~/.ssh/lab26_monitor` and add it to `lab26-ops`'s `authorized_keys` with `from="127.0.0.1",restrict,command="cat /proc/loadavg"`. Offering **only** that key (`-o IdentityAgent=none -o IdentitiesOnly=yes -i ~/.ssh/lab26_monitor -p 2222 lab26-ops@127.0.0.1` — not the `lab26-srv` alias, whose `IdentityFile` and your agent would offer your admin key first), show that a request for `cat /etc/passwd` only prints the load average, and that a tunnel with this key is refused. Use only harmless commands for such tests: if the wrong key is accepted, the command really runs.

### Task 11 — Windows: enable and test WinRM (lab VM, elevated)

In an **elevated** Windows PowerShell 5.1: record the current state (`Get-Service WinRM`, `Get-NetConnectionProfile`), run `Enable-PSRemoting -Force` (add `-SkipNetworkProfileCheck` only if the VM's network is Public and you understand the consequence), then `Test-WSMan -ComputerName localhost`, list the listener (`winrm enumerate winrm/config/listener`) and the endpoints (`Get-PSSessionConfiguration`). Check `Get-Item WSMan:\localhost\Client\TrustedHosts` — and leave it empty.

### Task 12 — Interactive and fan-out remoting

1. `Enter-PSSession -ComputerName localhost`, run `hostname` and `whoami`, `Exit-PSSession`.
2. Fan out to `localhost`, `127.0.0.1`, `$env:COMPUTERNAME` and a name that does not exist (`lab26-down`) with `Invoke-Command -ThrottleLimit 2 -ErrorVariable failed`, returning the computer's uptime in hours. Show the successes with `PSComputerName` and the failure from `$failed`.
3. Pass a local variable `$svc = 'WinRM'` into the script block — first wrongly (plain `$svc`), then with `$using:svc`, then with `-ArgumentList`.

### Task 13 — Persistent session and file copy

Create `$s = New-PSSession -ComputerName localhost`; set a variable in one `Invoke-Command -Session $s` call and read it in the next; create `C:\Temp\lab26` remotely; copy `report.txt` there with `Copy-Item -ToSession` and copy it back with `-FromSession` as `back.txt`; compare hashes; `Remove-PSSession $s`.

### Task 14 — Deserialized objects

Get the `Spooler` service through `Invoke-Command`, show its type name, try to call `.Stop()` on the result and read the error. Then do the same action the right way (inside the script block — use `Restart-Service Spooler -WhatIf` so nothing changes).

### Task 15 — PowerShell 7 over SSH to the Linux lab host

1. On the Linux host: install PowerShell 7, add `Subsystem powershell /usr/bin/pwsh -sshs -nologo` to a drop-in (for example `/srv/lab26/sshd_config.d/20-lab26-pwsh.conf`; adjust the path to `command -v pwsh` — the snap installs `/snap/bin/pwsh`), `sshd -t`, reload.
2. On Windows: create a key with `ssh-keygen.exe -t ed25519 -a 100`, append the public key to `/home/lab26-ops/.ssh/authorized_keys` (as `lab26-ops`, using your Linux key session), verify the host key fingerprint on first connect, then `Enter-PSSession -HostName localhost -Port 2222 -UserName lab26-ops -KeyFilePath $HOME\.ssh\lab26_win_ed25519` and `Invoke-Command -HostName …` running `uname -a` and `$PSVersionTable.PSVersion`.

If the Linux host is a separate VM, the lab `sshd` listens only on its loopback: either open a tunnel from Windows (`ssh.exe -N -L 2222:127.0.0.1:2222 student@VM-IP` using the VM's normal SSH) and use `-HostName localhost -Port 2222`, or skip this task.

### Task 16 — Clean up

Remove everything: on Linux run `sudo bash lab26-cleanup.sh -n` (dry run), read it, then `sudo bash lab26-cleanup.sh`, and remove the `Include config.d/lab26.conf` line from `~/.ssh/config`. On Windows, undo Task 11 completely — and note that **`Disable-PSRemoting` alone does not**: see the PowerShell solution for the extra steps. Revert the VM snapshot if you prefer.

## Commands to Execute

Try each task yourself first; the complete commands are in the [Solution](#solution). Building blocks:

| Need | Bash / OpenSSH | PowerShell |
|---|---|---|
| Fingerprint of a scanned key | `ssh-keyscan -p 2222 -t ed25519 127.0.0.1 > scan.txt; ssh-keygen -lf scan.txt` | `ssh-keyscan.exe` + `ssh-keygen.exe -lf` |
| Key with passphrase | `ssh-keygen -t ed25519 -a 100 -C … -f ~/.ssh/lab26_ed25519` | `ssh-keygen.exe -t ed25519 -a 100 -f $HOME\.ssh\…` |
| Install key | `ssh-copy-id -i KEY.pub -p 2222 user@host` | append to `authorized_keys` / `administrators_authorized_keys` + `icacls` |
| Server-side reason | `sudo tail /srv/lab26/logs/sshd.log` | `Get-WinEvent -LogName OpenSSH/Operational` |
| Keys in a file | `ssh-keygen -lf ~/.ssh/authorized_keys` | `ssh-keygen.exe -lf …` |
| Effective client config | `ssh -G lab26-srv-b` | `ssh.exe -G …` |
| Fleet loop | `ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$h" 'cmd'` | `Invoke-Command -ComputerName $list -ThrottleLimit 2 -ErrorVariable failed` |
| Pass a value | single quotes / `printf %q` | `$using:svc` · `-ArgumentList` |
| Transfer | `scp` · `sftp -b` · `rsync -avz --dry-run src/ host:dst/` | `Copy-Item -ToSession` / `-FromSession` |
| Tunnel | `ssh -f -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18026:127.0.0.1:8026 lab26-srv` | `ssh.exe -N -L …` |
| Validate / effective server config | `sudo /usr/sbin/sshd -t -f CFG` · `sudo /usr/sbin/sshd -T -f CFG` | `winrm get winrm/config` · `sshd.exe -t` |
| Which key logged in | <code>sudo grep 'Accepted publickey' LOG &#124; grep -oE 'SHA256:[A-Za-z0-9+/]{43}' &#124; sort &#124; uniq -c</code> | `Get-WinEvent` WinRM/Operational 91, Security 4624 |

## Expected Results

The Linux values below were **captured** on 2026-11-19 by running `lab26-setup.sh`, the Bash solution commands of Tasks 1–9 and `lab26-cleanup.sh` end to end on Ubuntu 24.04.5 (OpenSSH 9.6p1, rsync 3.2.7) in a container, as user `student` (host shown as `ubuntu-lab`); passphrase and password prompts were answered by an `SSH_ASKPASS` helper so they do not appear. **Fingerprints, PIDs, ports and dates differ on every run.** The Windows tasks were **not executed** (no Windows on the release host); their outputs in the solution are examples.

| Task | Result |
|---|---|
| 1 | Both fingerprints identical (`SHA256:dNN7rl…+LJs` in the capture); `Warning: Permanently added '[127.0.0.1]:2222' (ED25519)`; the `known_hosts` line starts with <code>&#124;1&#124;</code> (hashed, `HashKnownHosts yes` on Ubuntu) |
| 2 | `~/.ssh/lab26_ed25519` mode `600`, `.pub` mode `644`; `ssh-keygen -lf` prints `256 SHA256:… you@host lab26 … (ED25519)` |
| 3 | `Number of key(s) added: 1`; key-only login → `Permission denied (publickey,password)`, exit 255; server log: `Authentication refused: bad ownership or modes for file /home/lab26-ops/.ssh/authorized_keys`; the file is `-rw-rw-r-- lab26-ops lab26-ssh` and contains **two** keys — `contractor@old-laptop` and yours. After the fix: one key, mode `600`, `key login OK as lab26-ops` |
| 4 | `ssh -G lab26-srv-b` shows `hostname 127.0.0.1`, `port 2222`, `user lab26-ops`, `identitiesonly yes`, `proxyjump lab26-srv`; `Identity added … Lifetime set to 3600 seconds`; `via jump: ubuntu-lab` |
| 5 | Loop without `-n`: only the first host is printed. Fleet script: `lab26-srv,0,ok,…`, `lab26-srv-b,0,ok,…`, `lab26-down,255,ssh-error,"ssh: connect to host 127.0.0.1 port 2299: Connection refused"`, script exit **3**. `"echo $HOME $USER"` → `/home/student student`; `'echo $HOME $USER'` → `/home/lab26-ops lab26-ops` |
| 6 | `LAB26 server <date>` downloaded; `sftp -b` exit 0 and `round trip identical`; dry run lists `./`, `app.conf`, `logging.conf` and ends `(DRY RUN)`; without the slash it would list `deploy/`, `deploy/app.conf` … (a nested `deploy/deploy`) |
| 7 | `curl` prints `<html><body><h1>LAB26 internal status</h1><p>queue=ok replicas=3</p></body></html>`; `tunnel closed` |
| 8 | `sshd -t` silent (exit 0); `sshd -T` shows `passwordauthentication no`, `kbdinteractiveauthentication no`, `permitrootlogin no`, `maxauthtries 3`, `allowgroups lab26-ssh`, `allowtcpforwarding local`, `allowagentforwarding no`; password login → `Permission denied (publickey).` (only `publickey` offered), key login works, `-R` → `Error: remote port forwarding failed for listen port 19026`; the safety session printed its message after the reload |
| 9 | Every `Accepted publickey` fingerprint maps to one `authorized_keys` line — your `student@ubuntu-lab lab26 …` key (24 logins in the capture) and, if you already did Task 10, `lab26-monitor` (2). No login used an unknown key. Earlier lines: `Authentication refused: bad ownership or modes …` (the planted problem) and `Accepted password for lab26-ops` (the password sessions used to install and fix the key) |
| 10 | A load line such as `0.26 0.11 0.03 1/130 8945` instead of `/etc/passwd`; tunnel → `channel 1: open failed: administratively prohibited: open failed` |
| 16 | `Lab 26 clean-up finished.`; no `lab26-ops` account, no `/srv/lab26`, no lab sshd or web server process, known_hosts entry removed (`known_hosts.old` kept) |

## Verification Steps

=== "Bash"

    ```bash
    # Before clean-up:
    ssh -G lab26-srv-b | grep -E '^proxyjump '                                  # proxyjump lab26-srv
    ssh -o BatchMode=yes lab26-srv 'stat -c "%a %U" ~/.ssh ~/.ssh/authorized_keys'  # 700 / 600 lab26-ops
    ssh lab26-srv 'ssh-keygen -lf ~/.ssh/authorized_keys' | grep -c contractor   # 0
    bash ~/lab26-fleet.sh > /dev/null; echo "fleet exit=$?"                       # 3 (lab26-down)
    sudo /usr/sbin/sshd -T -f /srv/lab26/sshd_config | grep -E '^(passwordauthentication|allowgroups) '
    ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password lab26-srv true; echo $?   # 255
    # After clean-up:
    id lab26-ops; ls /srv/lab26; pgrep -af '/srv/lab26'                          # all "no such" / nothing
    ssh-keygen -F '[127.0.0.1]:2222' || echo "known_hosts entry removed"
    ```

=== "PowerShell"

    ```powershell
    # Before clean-up (elevated):
    (Test-WSMan -ComputerName localhost).ProductVendor                         # Microsoft Corporation
    (Get-Item WSMan:\localhost\Client\TrustedHosts).Value                      # empty
    Get-PSSession                                                              # nothing left open
    # After clean-up:
    Get-Service WinRM | Select-Object Status, StartType                       # as recorded in Task 11
    Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue     # none (client) - only if WinRM still runs
    Get-NetFirewallRule -DisplayGroup 'Windows Remote Management' | Select-Object DisplayName, Enabled
    Get-WindowsCapability -Online -Name OpenSSH.Server* | Select-Object Name, State   # NotPresent if you removed it
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Setup: `something already listens on 127.0.0.1:2222` | A previous run is still active, or another service | `sudo bash lab26-cleanup.sh`; check `ss -ltnp` |
| Setup: `run with sudo from your normal account` | Ran as root directly (`SUDO_USER` empty) | `sudo bash lab26-setup.sh` from your user, or `sudo LAB26_LEARNER=you bash …` |
| `ssh-copy-id` asks for a passphrase first | It tries the new key before installing it | Enter the passphrase (or press Enter); then the password prompt follows |
| `Permission denied (publickey,password)` after installing the key | The planted permission problem (Task 3) — or the key has a passphrase and `BatchMode` cannot ask | Read `/srv/lab26/logs/sshd.log`; load the key into the agent |
| `Too many authentication failures` | Agent offers many keys (`MaxAuthTries 3` after Task 8) | `IdentitiesOnly yes` (in the `lab26-*` block) |
| `ssh lab26-srv` connects to the wrong place | `Include` line not at the top of `~/.ssh/config`, or a `Host *` block above it sets values first | Put `Include config.d/lab26.conf` first; check `ssh -G` |
| Fleet loop processes one host only | Missing `-n` | `ssh -n …` |
| `rsync: command not found` on the remote side | rsync not installed on the target | `sudo apt install rsync` (both ends need it) |
| `bind [127.0.0.1]:18026: Address already in use` | Tunnel from a previous attempt still running | `pgrep -af 'ssh -f -N'`, then `pkill -f -- '-L 127.0.0.1:18026'` |
| `sshd -t` → `Bad configuration option` | Typo in the drop-in | Fix the keyword (the message gives file and line) |
| After Task 8 you cannot log in at all | `AllowGroups` without being able to authenticate as a member, or key not loaded | Use the safety session; `sudo mv` the drop-in away and `kill -HUP` again |
| `cat: /srv/lab26/sshd.pid: No such file` right after a reload | sshd re-executes and rewrites the PID file | Wait a second and retry |
| `Enable-PSRemoting`: network connection type is Public | Client VM on a Public network | `Set-NetConnectionProfile -InterfaceAlias Ethernet -NetworkCategory Private` (lab VM) or `-SkipNetworkProfileCheck` |
| `Enter-PSSession localhost`: Access is denied | Not elevated / not in Administrators or Remote Management Users | Run elevated, or add a lab user to Remote Management Users |
| `Enter-PSSession -HostName`: `subsystem request failed on channel 0` | No `Subsystem powershell` line, wrong `pwsh` path, or `sshd` not reloaded | `command -v pwsh`; fix the drop-in; `sshd -t`; `kill -HUP` |
| Windows key login to Linux fails with `bad permissions` locally | Private key file ACL too open | `icacls.exe $HOME\.ssh\lab26_win_ed25519 /inheritance:r /grant:r "$($env:USERNAME):F"` |

## Questions

1. Why is comparing the `ssh-keyscan` fingerprint with the value from the ticket meaningful, while `ssh-keyscan` alone proves nothing?
2. The client only said `Permission denied (publickey,password)` in Task 3. Why does `sshd` not tell the client the real reason, and where did you find it?
3. Why was the `contractor@old-laptop` key a bigger problem than the file permissions, and what should happen next in a real organisation?
4. In Task 5, why is exit code 255 treated differently from other non-zero codes in the fleet script?
5. Explain what `AllowTcpForwarding local` allows and blocks, and why it is a reasonable choice for a bastion but not for an application server.
6. Why did you keep a safety session open during Task 8, and why does a reload not kill it?
7. Which log line proves which person's key was used, and what makes the mapping possible?
8. Why do `Invoke-Command` results lose their methods, and how did you perform the action correctly in Task 14?
9. Why is `Set-Item WSMan:\localhost\Client\TrustedHosts -Value *` a bad "fix" for authentication errors, and what are the better options?
10. List what `Disable-PSRemoting` does **not** undo, and why that matters for a client VM.

## Solution

??? success "Lab setup scripts (Bash: `lab26-setup.sh`, `lab26-cleanup.sh`)"
    `lab26-setup.sh` — run with `sudo bash lab26-setup.sh` from your normal account:

    ```bash
    #!/usr/bin/env bash
    # lab26-setup.sh - build the Lab 26 "server": a separate, throwaway sshd on 127.0.0.1:2222
    #                  with its own config, host key and log, a target account lab26-ops,
    #                  a planted permission problem, a stale authorized_keys entry and an
    #                  internal-only web page on 127.0.0.1:8026.
    # Target OS : Ubuntu 24.04 LTS (lab VM or WSL2). Does NOT touch /etc/ssh/sshd_config.
    # Needs     : root (run with sudo from your normal account), openssh-server, python3.
    # Usage     : sudo bash lab26-setup.sh
    # Exit codes: 0 ready, 1 precondition failed, 2 a step failed.
    set -o errexit -o nounset -o pipefail

    LAB=/srv/lab26
    OPS=lab26-ops
    PORT=2222
    WEBPORT=8026
    LEARNER=${LAB26_LEARNER:-${SUDO_USER:-}}

    die() { printf 'lab26-setup: %s\n' "$1" >&2; exit "${2:-1}"; }
    listening() { timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/$1" 2>/dev/null; }

    [[ $EUID -eq 0 ]] || die "run as root: sudo bash $0"
    [[ -n $LEARNER && $LEARNER != root ]] || die "run with sudo from your normal account (or set LAB26_LEARNER)"
    LHOME=$(getent passwd "$LEARNER" | cut -d: -f6)
    [[ -d $LHOME ]] || die "home directory of $LEARNER not found"
    for c in /usr/sbin/sshd ssh-keygen python3 useradd chpasswd; do
        command -v "$c" >/dev/null || die "missing command: $c (sudo apt install openssh-server python3)"
    done
    [[ ! -e $LAB ]] || die "$LAB exists - run lab26-cleanup.sh first"
    ! id "$OPS" >/dev/null 2>&1 || die "account $OPS exists - run lab26-cleanup.sh first"
    ! listening "$PORT" || die "something already listens on 127.0.0.1:$PORT"
    ! listening "$WEBPORT" || die "something already listens on 127.0.0.1:$WEBPORT"

    trap 'die "step failed at line $LINENO - run lab26-cleanup.sh, then retry" 2' ERR

    # 1. Target account with a random password (password logins are what we replace).
    groupadd lab26-ssh
    useradd --create-home --shell /bin/bash --groups lab26-ssh "$OPS"
    pw=$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | cut -c1-16)
    printf '%s:%s\n' "$OPS" "$pw" | chpasswd

    # 2. Lab sshd: own directory, host key, config and log file.
    install -d -m 755 "$LAB" "$LAB/sshd_config.d" "$LAB/www"
    install -d -m 700 "$LAB/hostkeys"
    install -d -m 750 "$LAB/logs"
    ssh-keygen -q -t ed25519 -N '' -C lab26-hostkey -f "$LAB/hostkeys/ssh_host_ed25519_key"
    cat > "$LAB/sshd_config" <<EOF
    # Lab 26 test sshd - started by hand, never by systemd. Drop-ins first: first value wins.
    Include $LAB/sshd_config.d/*.conf
    Port $PORT
    ListenAddress 127.0.0.1
    HostKey $LAB/hostkeys/ssh_host_ed25519_key
    PidFile $LAB/sshd.pid
    LogLevel VERBOSE
    PermitRootLogin no
    PasswordAuthentication yes
    KbdInteractiveAuthentication no
    PubkeyAuthentication yes
    StrictModes yes
    UsePAM yes
    AllowUsers $OPS
    AllowTcpForwarding yes
    X11Forwarding no
    Subsystem sftp /usr/lib/openssh/sftp-server
    EOF
    chmod 644 "$LAB/sshd_config"
    ssh-keygen -lf "$LAB/hostkeys/ssh_host_ed25519_key.pub" > "$LAB/hostkey-fingerprint.txt"
    chmod 644 "$LAB/hostkey-fingerprint.txt"

    # 3. Planted problems: a stale key from a former contractor, and an authorized_keys file
    #    that is writable by the shared lab26-ssh group (which the learner is also in).
    #    (Ubuntu's sshd tolerates group-write only when the group is the user's private group.)
    usermod --append --groups lab26-ssh "$LEARNER"
    install -d -m 700 -o "$OPS" -g "$OPS" "/home/$OPS/.ssh"
    tmpk=$(mktemp -d)
    ssh-keygen -q -t ed25519 -N '' -C contractor@old-laptop -f "$tmpk/k"
    install -m 664 -o "$OPS" -g lab26-ssh "$tmpk/k.pub" "/home/$OPS/.ssh/authorized_keys"
    rm -rf "$tmpk"
    install -d -m 755 -o "$OPS" -g "$OPS" "/home/$OPS/deploy"
    printf 'LAB26 server %s\n' "$(date -u +%F)" > "/home/$OPS/motd.txt"
    chown "$OPS:$OPS" "/home/$OPS/motd.txt"

    # 4. Internal-only web page (loopback of the server only).
    printf '<html><body><h1>LAB26 internal status</h1><p>queue=ok replicas=3</p></body></html>\n' \
        > "$LAB/www/index.html"
    runuser -u "$OPS" -- nohup python3 -m http.server "$WEBPORT" --bind 127.0.0.1 \
        --directory "$LAB/www" > "$LAB/logs/web.log" 2>&1 &
    echo $! > "$LAB/web.pid"

    # 5. Validate and start the lab sshd.
    install -d -m 755 /run/sshd
    /usr/sbin/sshd -t -f "$LAB/sshd_config"
    /usr/sbin/sshd -f "$LAB/sshd_config" -E "$LAB/logs/sshd.log"
    for _ in 1 2 3 4 5 6 7 8 9 10; do listening "$PORT" && listening "$WEBPORT" && break; sleep 0.5; done
    listening "$PORT" || die "lab sshd did not start - see $LAB/logs/sshd.log" 2

    # 6. Learner workspace.
    W=$LHOME/lab26
    install -d -m 700 -o "$LEARNER" -g "$(id -gn "$LEARNER")" "$W" "$W/files" "$W/deploy"
    printf '%s\n' lab26-srv lab26-srv-b lab26-down > "$W/hosts.txt"
    printf 'quarterly report v1\n' > "$W/files/report.txt"
    printf 'max_clients = 100\n' > "$W/deploy/app.conf"
    printf 'log_level = info\n' > "$W/deploy/logging.conf"
    printf '%s\n' "$pw" > "$W/ops-password.txt"
    chmod 600 "$W/ops-password.txt"
    chown -R "$LEARNER:$(id -gn "$LEARNER")" "$W"

    cat <<EOF
    Lab 26 ready.
      Lab sshd         : 127.0.0.1:$PORT  (config $LAB/sshd_config, log $LAB/logs/sshd.log)
      Target account   : $OPS (temporary password in $W/ops-password.txt)
      Internal web page: 127.0.0.1:$WEBPORT on the server (reach it through an SSH tunnel)
      Out-of-band host key fingerprint ("from the server team"):
        $(cat "$LAB/hostkey-fingerprint.txt")
      Workspace        : $W
    EOF
    ```

    `lab26-cleanup.sh` — `sudo bash lab26-cleanup.sh -n` (dry run) then `sudo bash lab26-cleanup.sh`:

    ```bash
    #!/usr/bin/env bash
    # lab26-cleanup.sh - remove everything lab26-setup.sh and the Lab 26 tasks created:
    #                    stop the lab sshd and web server, delete lab26-ops, the lab26-ssh group,
    #                    /srv/lab26, the learner's lab26 key, ssh config drop-in, known_hosts
    #                    entries and ~/lab26 workspace. Never touches /etc/ssh.
    # Target OS : Ubuntu 24.04 LTS.   Needs: root (sudo from your normal account).
    # Usage     : sudo bash lab26-cleanup.sh [-n]     (-n = dry run: only show what would happen)
    # Exit codes: 0 done, 1 precondition failed.
    set -o nounset -o pipefail

    LAB=/srv/lab26
    OPS=lab26-ops
    LEARNER=${LAB26_LEARNER:-${SUDO_USER:-}}
    DRY=0
    [[ ${1:-} == -n ]] && DRY=1

    run() { if ((DRY)); then printf 'would run:'; printf ' %q' "$@"; printf '\n'; else "$@"; fi; }

    [[ $EUID -eq 0 ]] || { echo "lab26-cleanup: run as root: sudo bash $0" >&2; exit 1; }

    # 1. Stop the lab sshd - only if the PID really is our sshd (cmdline mentions our config).
    if [[ -r $LAB/sshd.pid ]]; then
        pid=$(<"$LAB/sshd.pid")
        if tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q -- "$LAB/sshd_config"; then
            run kill "$pid"
        fi
    fi
    # 2. Stop anything still running as the lab account (web server, sessions), then delete it.
    if id "$OPS" >/dev/null 2>&1; then
        run pkill -u "$OPS"
        ((DRY)) || sleep 1
        run userdel --remove "$OPS"
    fi
    getent group lab26-ssh >/dev/null && run groupdel lab26-ssh   # also drops the learner's membership
    [[ -e $LAB ]] && run rm -rf -- "$LAB"

    # 3. Learner-side files (only lab26-named items; your other keys and config stay).
    if [[ -n $LEARNER && $LEARNER != root ]]; then
        LHOME=$(getent passwd "$LEARNER" | cut -d: -f6)
        for f in "$LHOME/.ssh/lab26_ed25519" "$LHOME/.ssh/lab26_ed25519.pub" \
                 "$LHOME/.ssh/lab26_monitor" "$LHOME/.ssh/lab26_monitor.pub" \
                 "$LHOME/.ssh/config.d/lab26.conf"; do
            [[ -e $f ]] && run rm -f -- "$f"
        done
        if [[ -f $LHOME/.ssh/known_hosts ]]; then
            for h in '[127.0.0.1]:2222' '[localhost]:2222'; do
                if ssh-keygen -F "$h" -f "$LHOME/.ssh/known_hosts" >/dev/null; then
                    run runuser -u "$LEARNER" -- ssh-keygen -q -R "$h" -f "$LHOME/.ssh/known_hosts"
                fi
            done
        fi
        [[ -d $LHOME/lab26 ]] && run rm -rf -- "$LHOME/lab26"
        if grep -qs 'config.d/lab26.conf' "$LHOME/.ssh/config"; then
            echo "Note: remove the 'Include config.d/lab26.conf' line from $LHOME/.ssh/config by hand."
        fi
    fi
    echo "Lab 26 clean-up finished$( ((DRY)) && echo ' (dry run, nothing changed)')."
    ```

    Both scripts pass `shellcheck -S style` (ShellCheck 0.9.0) and were executed end to end on 2026-11-19 (setup → Tasks 1–10 → clean-up, three complete runs).

??? success "Bash solution: Tasks 1–4"
    ```bash
    # ---- Task 1: host key ----
    cat /srv/lab26/hostkey-fingerprint.txt
    ssh-keyscan -p 2222 -t ed25519 127.0.0.1 2>/dev/null > ~/lab26/scan.txt
    ssh-keygen -lf ~/lab26/scan.txt
    a=$(ssh-keygen -lf ~/lab26/scan.txt | cut -d' ' -f2); b=$(cut -d' ' -f2 /srv/lab26/hostkey-fingerprint.txt)
    [ "$a" = "$b" ] && echo "MATCH $a" || echo "MISMATCH - do not connect"
    ssh -p 2222 lab26-ops@127.0.0.1        # answer yes (or paste the fingerprint), then Ctrl+C at the password prompt
    head -c 60 ~/.ssh/known_hosts; echo     # |1|... hashed host name

    # ---- Task 2: key with passphrase ----
    ssh-keygen -t ed25519 -a 100 -C "$USER@$(hostname) lab26 $(date +%Y-%m)" -f ~/.ssh/lab26_ed25519
    ls -l ~/.ssh; ssh-keygen -lf ~/.ssh/lab26_ed25519.pub

    # ---- Task 3: install, diagnose, fix ----
    cat ~/lab26/ops-password.txt                      # temporary password (it will stop working in Task 8)
    ssh-copy-id -i ~/.ssh/lab26_ed25519.pub -p 2222 lab26-ops@127.0.0.1
    ssh -o PasswordAuthentication=no -i ~/.ssh/lab26_ed25519 -p 2222 lab26-ops@127.0.0.1 id   # fails
    sudo tail -5 /srv/lab26/logs/sshd.log             # Authentication refused: bad ownership or modes ...
    ssh -o PubkeyAuthentication=no -p 2222 lab26-ops@127.0.0.1 \
        'ls -l ~/.ssh/authorized_keys; ssh-keygen -lf ~/.ssh/authorized_keys'
    ssh -o PubkeyAuthentication=no -p 2222 lab26-ops@127.0.0.1 \
        'install -m 600 ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak-lab26 &&
         sed -i "/contractor@old-laptop/d" ~/.ssh/authorized_keys &&
         chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh &&
         ls -l ~/.ssh && ssh-keygen -lf ~/.ssh/authorized_keys'
    ssh -o PasswordAuthentication=no -i ~/.ssh/lab26_ed25519 -p 2222 lab26-ops@127.0.0.1 'echo key login OK as $(id -un)'

    # ---- Task 4: config, agent, ProxyJump ----
    mkdir -p ~/.ssh/config.d && chmod 700 ~/.ssh/config.d
    cat > ~/.ssh/config.d/lab26.conf <<'EOF'
    Host lab26-srv
        HostName 127.0.0.1
        Port 2222
        User lab26-ops

    Host lab26-srv-b
        HostName 127.0.0.1
        Port 2222
        User lab26-ops
        ProxyJump lab26-srv

    Host lab26-down
        HostName 127.0.0.1
        Port 2299
        User lab26-ops

    Host lab26-*
        IdentityFile ~/.ssh/lab26_ed25519
        IdentitiesOnly yes
        ConnectTimeout 5
        ServerAliveInterval 30
    EOF
    # Put the Include line at the TOP of ~/.ssh/config (keeping anything that was there):
    if ! grep -qs 'config.d/lab26.conf' ~/.ssh/config; then
        { printf 'Include config.d/lab26.conf\n\n'; cat ~/.ssh/config 2>/dev/null; } > ~/.ssh/config.new &&
            mv ~/.ssh/config.new ~/.ssh/config
    fi
    chmod 600 ~/.ssh/config ~/.ssh/config.d/lab26.conf
    ssh -G lab26-srv-b | grep -E '^(hostname|port|user|proxyjump|identitiesonly) '
    eval "$(ssh-agent -s)"
    ssh-add -t 1h ~/.ssh/lab26_ed25519
    ssh-add -l
    ssh lab26-srv-b 'echo via jump: $(hostname)'
    ```

    **Expected output (captured, Tasks 3–4 excerpt):**

    ```text
    Number of key(s) added: 1
    lab26-ops@127.0.0.1: Permission denied (publickey,password).
    Authentication refused: bad ownership or modes for file /home/lab26-ops/.ssh/authorized_keys
    -rw-rw-r-- 1 lab26-ops lab26-ssh 209 Nov 19 17:10 /home/lab26-ops/.ssh/authorized_keys
    256 SHA256:ispZ+JiCJVfM6VKjxAIlLakkEfxR1b96OKsUXJE3WPY contractor@old-laptop (ED25519)
    256 SHA256:G4c+kRXTh1hbBpa+++QIzps+S52kb9MgCjAbLfdoxdo student@ubuntu-lab lab26 2026-11 (ED25519)
    total 8
    -rw------- 1 lab26-ops lab26-ssh 106 Nov 19 17:10 authorized_keys
    -rw------- 1 lab26-ops lab26-ops 209 Nov 19 17:10 authorized_keys.bak-lab26
    256 SHA256:G4c+kRXTh1hbBpa+++QIzps+S52kb9MgCjAbLfdoxdo student@ubuntu-lab lab26 2026-11 (ED25519)
    key login OK as lab26-ops
    user lab26-ops
    hostname 127.0.0.1
    port 2222
    identitiesonly yes
    proxyjump lab26-srv
    Identity added: /home/student/.ssh/lab26_ed25519 (student@ubuntu-lab lab26 2026-11)
    Lifetime set to 3600 seconds
    256 SHA256:G4c+kRXTh1hbBpa+++QIzps+S52kb9MgCjAbLfdoxdo student@ubuntu-lab lab26 2026-11 (ED25519)
    via jump: ubuntu-lab
    ```

    Notes:

    - The file was writable by the **shared** group `lab26-ssh`, of which you (and in real life the whole ops team) are a member — anyone in it could have added a key. Ubuntu's `sshd` tolerates group-write only for a user's *private* group, so it refused the file.
    - `install -m 600` makes a backup with safe permissions (`cp -p` would have copied the bad mode). The `sed` pattern matches the key's comment; on a real server match the **fingerprint** you verified with `ssh-keygen -lf`, because comments are free text.
    - `printf` + `cat` puts the `Include` line first; `ssh_config` uses the first value obtained, so an `Include` at the end would be overridden by earlier `Host *` settings.

??? success "Bash solution: Tasks 5–7 (fleet script `lab26-fleet.sh`, transfers, tunnel)"
    `lab26-fleet.sh` (save in your home directory; passes `shellcheck -S style`):

    ```bash
    #!/usr/bin/env bash
    # lab26-fleet.sh - run one read-only command on every host in a list over SSH and report
    #                  host,exit_code,status,output as CSV. Never prompts (BatchMode).
    # Usage : lab26-fleet.sh [-f HOSTFILE] [-t SECONDS] [-c COMMAND]
    # Exit  : 0 all hosts OK, 1 bad arguments, 3 at least one host failed or was unreachable
    set -o nounset -o pipefail

    hostfile=$HOME/lab26/hosts.txt
    timeout=5
    # shellcheck disable=SC2016  # expanded on the remote host on purpose
    cmd='printf "%s %s" "$(hostname)" "$(cut -d" " -f1 /proc/loadavg)"'

    while getopts ':f:t:c:h' opt; do
        case $opt in
            f) hostfile=$OPTARG ;;
            t) timeout=$OPTARG ;;
            c) cmd=$OPTARG ;;
            h) sed -n '2,5p' "$0"; exit 0 ;;
            *) echo "usage: $0 [-f HOSTFILE] [-t SECONDS] [-c COMMAND]" >&2; exit 1 ;;
        esac
    done
    [[ -r $hostfile ]] || { echo "cannot read $hostfile" >&2; exit 1; }
    [[ $timeout =~ ^[0-9]+$ ]] || { echo "timeout must be a number" >&2; exit 1; }

    failed=0
    echo "host,exit_code,status,output"
    while read -r host _; do
        [[ -z $host || $host == \#* ]] && continue
        # -n: do not let ssh read the host list from stdin; the command is single-quoted
        # here so that it is expanded on the REMOTE host, not locally.
        out=$(ssh -n -o BatchMode=yes -o ConnectTimeout="$timeout" "$host" "$cmd" 2>&1)
        rc=$?
        case $rc in
            0) status=ok ;;
            255) status=ssh-error; failed=1 ;;
            *) status=command-failed; failed=1 ;;
        esac
        out=${out//$'\n'/ }
        printf '%s,%s,%s,"%s"\n' "$host" "$rc" "$status" "${out//\"/\'}"
    done < "$hostfile"
    ((failed)) && exit 3
    exit 0
    ```

    ```bash
    # ---- Task 5 ----
    while read -r h; do printf '%-12s ' "$h"; ssh -o BatchMode=yes "$h" hostname; done < ~/lab26/hosts.txt   # the bug
    bash ~/lab26-fleet.sh; echo "fleet exit=$?"
    ssh lab26-srv "echo $HOME $USER"; ssh lab26-srv 'echo $HOME $USER'

    # ---- Task 6 ----
    cd ~/lab26
    scp files/report.txt lab26-srv:/tmp/lab26-report.txt && scp lab26-srv:motd.txt files/ && cat files/motd.txt
    printf 'cd /tmp\nput files/report.txt lab26-sftp.txt\nls -l lab26-*\nget lab26-sftp.txt files/back.txt\n' > sftp-batch.txt
    sftp -b sftp-batch.txt lab26-srv; echo "sftp rc=$?"
    cmp files/report.txt files/back.txt && echo "round trip identical"
    rsync -avz --dry-run deploy lab26-srv:deploy/     # WITHOUT slash: would create deploy/deploy
    rsync -avz --dry-run deploy/ lab26-srv:deploy/    # preview
    rsync -avz deploy/ lab26-srv:deploy/              # for real
    ssh lab26-srv 'ls ~/deploy'

    # ---- Task 7 ----
    ssh -f -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18026:127.0.0.1:8026 lab26-srv
    curl -s http://127.0.0.1:18026/
    pkill -f -- '-L 127.0.0.1:18026:127.0.0.1:8026' && echo "tunnel closed"
    pgrep -af 'ssh -f -N' || echo "no tunnel left"
    ```

    **Expected output (captured, excerpt):**

    ```text
    lab26-srv    ubuntu-lab
    host,exit_code,status,output
    lab26-srv,0,ok,"ubuntu-lab 0.19"
    lab26-srv-b,0,ok,"ubuntu-lab 0.19"
    lab26-down,255,ssh-error,"ssh: connect to host 127.0.0.1 port 2299: Connection refused"
    fleet exit=3
    /home/student student
    /home/lab26-ops lab26-ops
    LAB26 server 2026-11-19
    sftp> cd /tmp
    sftp> put files/report.txt lab26-sftp.txt
    sftp> ls -l lab26-*
    -rw-r--r--    ? lab26-ops lab26-ops       20 Nov 19 17:10 lab26-report.txt
    -rw-r--r--    ? lab26-ops lab26-ops       20 Nov 19 17:10 lab26-sftp.txt
    sftp> get lab26-sftp.txt files/back.txt
    sftp rc=0
    round trip identical
    sending incremental file list
    ./
    app.conf
    logging.conf

    sent 120 bytes  received 25 bytes  290.00 bytes/sec
    total size is 35  speedup is 0.24 (DRY RUN)
    <html><body><h1>LAB26 internal status</h1><p>queue=ok replicas=3</p></body></html>
    tunnel closed
    ```

    The fleet script quotes the remote command in **single** quotes so `$(hostname)` runs on each target, uses `-n` so the host list is not eaten, `BatchMode` so a missing key fails instead of prompting, and `ConnectTimeout` so a dead host costs at most 5 seconds. Exit 255 is classified as `ssh-error` (unreachable / authentication) — a different problem from a command that ran and failed.

??? success "Bash solution: Tasks 8–10 (hardening, logs, restricted key)"
    ```bash
    # ---- Task 8 (terminal 2 first: ssh lab26-srv  -> leave it open) ----
    L=/srv/lab26
    sudo cp -a $L/sshd_config $L/sshd_config.bak-lab26
    sudo tee $L/sshd_config.d/10-lab26-hardening.conf >/dev/null <<'EOF'
    # Lab 26 hardening - keys only, fewer tries, only the lab26-ssh group, no agent/X11/remote forwarding
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitRootLogin no
    MaxAuthTries 3
    LoginGraceTime 30
    AllowGroups lab26-ssh
    AllowAgentForwarding no
    AllowTcpForwarding local
    X11Forwarding no
    EOF
    sudo /usr/sbin/sshd -t -f $L/sshd_config && echo "config OK"
    sudo /usr/sbin/sshd -T -f $L/sshd_config | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|maxauthtries|allowgroups|allowtcpforwarding|allowagentforwarding) '
    sudo /usr/sbin/sshd -t -f $L/sshd_config && sudo kill -HUP "$(cat $L/sshd.pid)"   # real server: sudo systemctl reload ssh
    # terminal 3 (new connections):
    ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password lab26-srv true; echo "password login rc=$?"
    ssh lab26-srv 'echo key login still works'
    ssh -o ExitOnForwardFailure=yes -R 127.0.0.1:19026:127.0.0.1:8026 lab26-srv true; echo "remote forward rc=$?"
    # terminal 2: type a command - the safety session still works

    # ---- Task 9 ----
    sudo grep -E 'Authentication refused|Accepted password' $L/logs/sshd.log | head -3
    sudo grep 'Accepted publickey' $L/logs/sshd.log | grep -oE 'SHA256:[A-Za-z0-9+/]{43}' | sort | uniq -c
    sudo ssh-keygen -lf /home/lab26-ops/.ssh/authorized_keys

    # ---- Task 10 (optional) ----
    ssh-keygen -q -t ed25519 -N '' -C lab26-monitor -f ~/.ssh/lab26_monitor
    ssh lab26-srv "printf '%s\n' 'from=\"127.0.0.1\",restrict,command=\"cat /proc/loadavg\" $(cat ~/.ssh/lab26_monitor.pub)' >> ~/.ssh/authorized_keys"
    ssh -o IdentityAgent=none -o IdentitiesOnly=yes -o BatchMode=yes -i ~/.ssh/lab26_monitor -p 2222 lab26-ops@127.0.0.1 'cat /etc/passwd'; echo "exit=$?"   # load average only
    ssh -o IdentityAgent=none -o IdentitiesOnly=yes -o BatchMode=yes -i ~/.ssh/lab26_monitor -N -L 18027:127.0.0.1:8026 -p 2222 lab26-ops@127.0.0.1 & sleep 2
    curl -s -m 3 http://127.0.0.1:18027/; echo "curl exit=$?"; kill %1
    ```

    **Expected output (captured, excerpt):**

    ```text
    config OK
    maxauthtries 3
    permitrootlogin no
    passwordauthentication no
    kbdinteractiveauthentication no
    allowtcpforwarding local
    allowagentforwarding no
    allowgroups lab26-ssh
    lab26-ops@127.0.0.1: Permission denied (publickey).
    password login rc=255
    key login still works
    Error: remote port forwarding failed for listen port 19026
    remote forward rc=255
    safety session survived the reload
    Authentication refused: bad ownership or modes for file /home/lab26-ops/.ssh/authorized_keys
    Accepted password for lab26-ops from 127.0.0.1 port 53512 ssh2
    Authentication refused: bad ownership or modes for file /home/lab26-ops/.ssh/authorized_keys
         24 SHA256:G4c+kRXTh1hbBpa+++QIzps+S52kb9MgCjAbLfdoxdo
          2 SHA256:n3UsEPz+qrp5sGfhMjxZDCyJSe26AVInvnKVQpecKbw
    256 SHA256:G4c+kRXTh1hbBpa+++QIzps+S52kb9MgCjAbLfdoxdo student@ubuntu-lab lab26 2026-11 (ED25519)
    256 SHA256:n3UsEPz+qrp5sGfhMjxZDCyJSe26AVInvnKVQpecKbw lab26-monitor (ED25519)
    from="127.0.0.1",restrict,command="cat /proc/loadavg" ssh-ed25519 AAAA
    0.26 0.11 0.03 1/130 8945
    exit=0
    channel 1: open failed: administratively prohibited: open failed
    curl exit=56
    ```

    - In the captured run Task 10 was done **before** Task 8, which is why the log already contains the `lab26-monitor` fingerprint.
    - `Permission denied (publickey).` lists only `publickey`: the server no longer offers passwords at all.
    - On a real Ubuntu 24.04 server the same drop-in goes into `/etc/ssh/sshd_config.d/10-hardening.conf`; validate with `sudo sshd -t`, check `sudo sshd -T`, then `sudo systemctl reload ssh`. A `Port` change would additionally need `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket`.
    - Rollback if something goes wrong: from the safety session, `sudo mv $L/sshd_config.d/10-lab26-hardening.conf /root/` and `sudo kill -HUP "$(cat $L/sshd.pid)"`.

??? success "PowerShell solution (Tasks 11–16, lab VM, elevated where noted)"
    ```powershell
    # ---- Task 11 (elevated Windows PowerShell 5.1) ----
    $before = [pscustomobject]@{
        WinRM   = (Get-Service WinRM).Status
        Start   = (Get-Service WinRM).StartType
        Profile = (Get-NetConnectionProfile).NetworkCategory -join ','
    }
    $before | Export-Clixml $HOME\lab26-winrm-before.xml          # needed for an exact clean-up
    Enable-PSRemoting -Force                                       # Public network: add -SkipNetworkProfileCheck (local subnet only)
    Test-WSMan -ComputerName localhost
    winrm enumerate winrm/config/listener
    Get-PSSessionConfiguration | Select-Object Name, Permission
    (Get-Item WSMan:\localhost\Client\TrustedHosts).Value          # leave empty

    # ---- Task 12 ----
    Enter-PSSession -ComputerName localhost
    #   [localhost]: PS C:\Users\student\Documents> hostname; whoami; Exit-PSSession
    $hosts = 'localhost', '127.0.0.1', $env:COMPUTERNAME, 'lab26-down'
    Invoke-Command -ComputerName $hosts -ThrottleLimit 2 -ErrorAction SilentlyContinue -ErrorVariable failed -ScriptBlock {
        [math]::Round(((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours, 1)
    } | ForEach-Object { [pscustomobject]@{ Computer = $_.PSComputerName; UptimeHours = $_ } }
    $failed | ForEach-Object { "FAILED: $($_.TargetObject) - $($_.FullyQualifiedErrorId)" }
    $svc = 'WinRM'
    (Invoke-Command -ComputerName localhost { Get-Service -Name $svc }).Count          # many: $svc is $null remotely
    Invoke-Command -ComputerName localhost { Get-Service -Name $using:svc } | Select-Object Name, Status
    Invoke-Command -ComputerName localhost { param($n) Get-Service -Name $n } -ArgumentList $svc | Select-Object Name, Status

    # ---- Task 13 ----
    $s = New-PSSession -ComputerName localhost
    Invoke-Command -Session $s { $lab = "set at $(Get-Date -Format T)" }
    Invoke-Command -Session $s { $lab }                                                 # value survived
    Invoke-Command -Session $s { New-Item -ItemType Directory -Path C:\Temp\lab26 -Force | Out-Null }
    Set-Content -Path $HOME\lab26-report.txt -Value 'quarterly report v1'
    Copy-Item -Path $HOME\lab26-report.txt -Destination C:\Temp\lab26\report.txt -ToSession $s
    Copy-Item -Path C:\Temp\lab26\report.txt -Destination $HOME\lab26-back.txt -FromSession $s
    (Get-FileHash $HOME\lab26-report.txt, $HOME\lab26-back.txt).Hash | Select-Object -Unique   # one hash = identical
    Remove-PSSession $s

    # ---- Task 14 ----
    $r = Invoke-Command -ComputerName localhost { Get-Service -Name Spooler }
    $r.PSObject.TypeNames[0]
    try { $r.Stop() } catch { $_.Exception.Message }
    Invoke-Command -ComputerName localhost { Restart-Service -Name Spooler -WhatIf }      # act remotely

    # ---- Task 15 (PowerShell 7, after the Linux Subsystem line is in place) ----
    ssh-keygen.exe -t ed25519 -a 100 -C "$env:USERNAME@$env:COMPUTERNAME lab26" -f $HOME\.ssh\lab26_win_ed25519
    Get-Content $HOME\.ssh\lab26_win_ed25519.pub     # append this line to /home/lab26-ops/.ssh/authorized_keys on Linux
    ssh.exe -p 2222 -i $HOME\.ssh\lab26_win_ed25519 lab26-ops@localhost true     # verify the fingerprint on first connect
    Enter-PSSession -HostName localhost -Port 2222 -UserName lab26-ops -KeyFilePath $HOME\.ssh\lab26_win_ed25519
    #   [localhost]: PS /home/lab26-ops> uname -a; exit
    Invoke-Command -HostName localhost -Port 2222 -UserName lab26-ops -KeyFilePath $HOME\.ssh\lab26_win_ed25519 -ScriptBlock {
        uname -a; $PSVersionTable.PSVersion.ToString()
    }
    ```

    Linux side of Task 15 (as your user, with `sudo`):

    ```bash
    sudo snap install powershell --classic          # or Microsoft's apt repository
    command -v pwsh                                 # /snap/bin/pwsh with the snap
    printf 'Subsystem powershell %s -sshs -nologo\n' "$(command -v pwsh)" | sudo tee /srv/lab26/sshd_config.d/20-lab26-pwsh.conf
    sudo /usr/sbin/sshd -t -f /srv/lab26/sshd_config && sudo kill -HUP "$(cat /srv/lab26/sshd.pid)"
    ```

    **Expected output (example, Tasks 11–15 excerpt):**

    ```text
    wsmid           : http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd
    ProtocolVersion : http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd
    ProductVendor   : Microsoft Corporation
    ProductVersion  : OS: 0.0.0 SP: 0.0 Stack: 3.0

    Computer  UptimeHours
    --------  -----------
    localhost        26.4
    127.0.0.1        26.4
    WIN11-LAB        26.4
    FAILED: lab26-down - NetworkPathNotFound,PSSessionStateBroken
    289

    Name  Status
    ----  ------
    WinRM Running
    WinRM Running
    set at 10:15:02
    3F2C0A7E9D5B... (one hash)
    Deserialized.System.ServiceProcess.ServiceController
    Method invocation failed because [Deserialized.System.ServiceProcess.ServiceController] does not contain a method named 'Stop'.
    What if: Performing the operation "Restart-Service" on target "Print Spooler (Spooler)".
    Linux ubuntu-lab 6.8.0-48-generic #48-Ubuntu SMP PREEMPT_DYNAMIC ... x86_64 GNU/Linux
    7.4.6
    ```

    - `ThrottleLimit 2` makes the fan-out visible (two at a time); the default is 32.
    - Connecting to `127.0.0.1` works for loopback; to a **remote** IP address WinRM would need HTTPS or TrustedHosts because Kerberos needs a name.
    - `289` (a count of services) is the wrong-variable trap: `Get-Service -Name $null` returns all services.

??? success "Clean-up (Linux and Windows)"
    Linux:

    ```bash
    pkill -f -- '-L 127.0.0.1:1802' ; ssh-agent -k 2>/dev/null   # tunnels and the agent from this lab
    sudo bash ~/lab26-cleanup.sh -n                              # dry run - read the list
    sudo bash ~/lab26-cleanup.sh
    sed -i '/^Include config.d\/lab26.conf$/d' ~/.ssh/config     # then check: cat ~/.ssh/config
    rm -f ~/lab26-setup.sh ~/lab26-cleanup.sh ~/lab26-fleet.sh
    ```

    **Expected output (captured):**

    ```text
    userdel: lab26-ops mail spool (/var/mail/lab26-ops) not found
    /home/student/.ssh/known_hosts updated.
    Original contents retained as /home/student/.ssh/known_hosts.old
    Note: remove the 'Include config.d/lab26.conf' line from /home/student/.ssh/config by hand.
    Lab 26 clean-up finished.
    ```

    (The `mail spool not found` line is harmless: the account never received mail.) If you installed PowerShell only for this lab: `sudo snap remove powershell`.

    Windows (elevated). **`Disable-PSRemoting` only blocks remote access to the session configurations** (it adds a deny entry for network logons to the endpoints); it does **not** stop the WinRM service, remove the listener, close the firewall exceptions or reset `LocalAccountTokenFilterPolicy`. Undo Task 11 completely on a client VM where remoting was off before — in this order, because the `WSMan:` drive needs the WinRM service:

    ```powershell
    Get-PSSession | Remove-PSSession
    Disable-PSRemoting -Force                                              # run from each edition you enabled (5.1 and 7)
    Get-PSSessionConfiguration -Name 'PowerShell.7*' -ErrorAction SilentlyContinue | Unregister-PSSessionConfiguration -Force   # from PowerShell 7, if registered
    Clear-Item WSMan:\localhost\Client\TrustedHosts -Force                 # only if you changed it
    Remove-Item -Path WSMan:\localhost\Listener\listener* -Recurse         # delete the listener(s)
    Disable-NetFirewallRule -DisplayGroup 'Windows Remote Management'      # firewall exceptions
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
        -Name LocalAccountTokenFilterPolicy -Value 0                       # restore UAC remote restriction
    Stop-Service WinRM; Set-Service WinRM -StartupType (Import-Clixml $HOME\lab26-winrm-before.xml).Start
    Remove-Item C:\Temp\lab26 -Recurse -WhatIf; Remove-Item C:\Temp\lab26 -Recurse
    Remove-Item $HOME\lab26-report.txt, $HOME\lab26-back.txt, $HOME\lab26-winrm-before.xml
    Remove-Item $HOME\.ssh\lab26_win_ed25519, $HOME\.ssh\lab26_win_ed25519.pub
    ssh-keygen.exe -R '[localhost]:2222'
    # Only if you installed Windows OpenSSH Server for this lab:
    Stop-Service sshd; Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    ```

    On a **Windows Server** remoting is enabled by default and other tools may depend on it — there, do not stop WinRM or remove the listener; only revert what you changed (TrustedHosts, extra endpoints). Check each step against the current `Disable-PSRemoting` documentation for your PowerShell version. Reverting the VM snapshot is the simplest complete clean-up.

??? success "Answers to questions"
    1. `ssh-keyscan` asks the network, so anyone in the path could answer with their own key. The ticket's fingerprint came through a **different, trusted channel** from the people who control the server; when both match, an attacker would have to control both channels. Without the comparison, the scan is just trust on first use.
    2. Detailed reasons would help an attacker (for example confirming that an account exists or that a particular key is installed), so the protocol only lists the methods that may continue. The cause is logged on the server: `Authentication refused: bad ownership or modes …` in `/srv/lab26/logs/sshd.log` (`journalctl _COMM=sshd` on a normal server).
    3. The permission problem only made **your** key fail; the contractor's key would have **worked** (once permissions were right) for someone who no longer belongs to the organisation — a standing backdoor, and possibly a sign of persistence (ATT&CK T1098.004). Next: identify when and by whom it was added (backups, change records, file timestamps, auditd), check the logs for that fingerprint (`Accepted publickey … SHA256:ispZ…` in the capture), remove it everywhere it appears, and review the offboarding process.
    4. 255 means `ssh` itself failed — the host is unreachable, the key or host key is wrong — so the command never ran and the host's state is **unknown**. Other non-zero codes mean the command ran and reported a failure, which is real information about the host. They need different follow-up (connectivity vs the service).
    5. `local` allows client-requested local forwards (`-L`) and the `direct-tcpip` channels that `ProxyJump` uses, and blocks remote forwards (`-R`), which open listening ports **on the server** (reverse tunnels, a classic backdoor/exfiltration path). A bastion must allow ProxyJump, so `local` fits; an application server normally needs neither, so `AllowTcpForwarding no` (or `DisableForwarding yes`) is better there.
    6. If the new configuration locked you out, the open session is your way back to undo it (without a console). `sshd` handles each connection in its own process; a reload (SIGHUP) makes the listening daemon re-read its configuration and re-execute, while existing session processes continue — the capture showed `safety session survived the reload`.
    7. `Accepted publickey for lab26-ops from 127.0.0.1 port … ssh2: ED25519 SHA256:G4c+…` (in the capture). The fingerprint matches one line of `ssh-keygen -lf authorized_keys`, and that line's **comment** (`student@ubuntu-lab lab26 2026-11`) names the person — which is why each person needs their own key with a meaningful comment, even when they share an account.
    8. Objects cross the network as serialized XML and are rebuilt as `Deserialized.*` property bags; methods cannot be serialized because they need the live object on the remote machine. The action was performed **inside** the script block (`Invoke-Command { Restart-Service Spooler -WhatIf }`), where the real object exists.
    9. TrustedHosts tells the client to send credentials to hosts **whose identity it cannot verify**; `*` does that for every name, so a spoofed host (DNS, ARP, rogue Wi-Fi) receives your NTLM authentication. Better: Kerberos with proper names in a domain, an HTTPS listener with a trusted certificate (`-UseSSL`), or PowerShell remoting over SSH with verified host keys — and if TrustedHosts is unavoidable in an isolated lab, list exact names only.
    10. It does not stop or disable the WinRM service, delete the WS-Management listener, remove the firewall exceptions, or reset `LocalAccountTokenFilterPolicy` (and PowerShell 7 endpoints are separate configurations). On a client VM that means the machine keeps listening on 5985 with firewall rules open and the UAC remote restriction relaxed — an attack surface you no longer use. Undo each item explicitly or revert the snapshot.
