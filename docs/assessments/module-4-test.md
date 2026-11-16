---
description: "Module 4 test (Days 16–20): 25 questions on system logs, authentication and security monitoring, firewall management, security auditing and network security investigation in Bash and PowerShell, with a collapsible answer key and a practical investigation task."
---

# Module 4 Test: Security, Logs & Monitoring

| | |
|---|---|
| **Covers** | [Day 16](../course/module-4/day-16.md) – [Day 20](../course/module-4/day-20.md) |
| **Questions** | 25: 15 multiple choice (1 mark each), 7 command-writing (2 marks each), 3 short-answer and practical (3 marks each) |
| **Total** | 38 marks · pass mark 23 (60%) |
| **Time** | 75 minutes, closed book except for built-in help (`man`, `--help`, `Get-Help`) |
| **Environment** | For Part C you need an Ubuntu 24.04 **VM** (or WSL2) with `sudo` where you can create network namespaces, and/or a Windows 11 lab VM. Take a snapshot first, work only with the names given in the task (`m4test…`), and scan or capture **only** on systems you own or are authorised to use (localhost, your lab, `scanme.nmap.org`). Never disable a security control as a workaround. |

Answer every question before opening the answers. Each answer explains *why*, so use the key to learn, not only to mark. Grade with the table on the [Assessments](index.md#grading-guidance) page.

## Part A — Multiple choice (1 mark each)

**1.** On Ubuntu 24.04, which command shows only **kernel** messages from the current boot, newest filtering applied, in the journal?

- A. `journalctl -k -b`
- B. `dmesg --clear`
- C. `cat /var/log/kern.log.1`
- D. `journalctl -u kernel`

??? question "Answer and explanation"
    **A.** `journalctl -k` limits output to kernel (`dmesg`) messages and `-b` to the current boot. `dmesg --clear` *erases* the ring buffer, there is no `kernel` unit, and the rotated file is only part of the picture. (Day 16)

**2.** A log line reads `Nov 16 10:02:14 host sshd[1301]: Failed password for invalid user admin from 203.0.113.9 port 51022 ssh2`. What does "invalid user" tell you?

- A. The password was correct but expired
- B. The account `admin` does not exist on this host, so this is almost certainly a guessing attack
- C. SSH is misconfigured
- D. The user typed the wrong hostname

??? question "Answer and explanation"
    **B.** `Failed password for invalid user X` means `X` is not a real account — a hallmark of brute-force/credential-guessing against common names. A failure for a *real* user omits "invalid user". (Day 17)

**3.** Which Windows Security event ID records a **failed** logon, and where do you look for the reason it failed?

- A. 4624; the Keywords field
- B. 4625; the Status/SubStatus codes
- C. 4634; the logon type
- D. 4720; the SID

??? question "Answer and explanation"
    **B.** 4625 is a failed logon; the `Status`/`SubStatus` codes explain why (e.g. `0xC000006A` bad password, `0xC0000064` no such user). 4624 is a *successful* logon, 4634 a logoff, 4720 account creation. (Day 17)

**4.** On a default-deny host firewall, a rule allows `established,related` traffic. Why is that one rule enough to make replies to your outbound connections work?

- A. It allows all inbound traffic
- B. Connection tracking recognises packets belonging to a connection you already initiated and lets the replies back in
- C. It disables the firewall for outbound traffic
- D. It opens every ephemeral port permanently

??? question "Answer and explanation"
    **B.** Stateful filtering (conntrack) tracks flows; once you initiate a connection, its replies match the `ESTABLISHED`/`RELATED` state and are allowed without opening inbound ports. (Day 18)

**5.** `ufw status numbered` shows `[ 2] 22/tcp ALLOW IN 10.18.0.16/28`. You want to remove it. What is the safest way?

- A. `ufw disable`
- B. `ufw reset`
- C. `ufw delete 2` (reading the rule it shows before confirming)
- D. Edit `/etc/ufw/user.rules` by hand

??? question "Answer and explanation"
    **C.** `ufw delete N` removes one rule and shows it for confirmation first. `disable`/`reset` remove the whole firewall (lockout/overkill), and hand-editing the rules file bypasses ufw's own bookkeeping. Delete from the highest number down when removing several. (Day 18)

**6.** Which sudoers rule is effectively a passwordless root shell?

- A. `ops ALL=(root) /usr/bin/systemctl restart app`
- B. `ops ALL=(root) NOPASSWD: /usr/bin/find`
- C. `ops ALL=(root) /usr/bin/journalctl -u app`
- D. `ops ALL=(root) /usr/bin/id`

??? question "Answer and explanation"
    **B.** `find` can run arbitrary commands (`find . -exec /bin/sh \;`), so `NOPASSWD: /usr/bin/find` grants a root shell with no password. The others are scoped to a single, non-shelling action. GTFOBins catalogues such binaries. (Day 19)

**7.** `find / -xdev -type f -perm -4000` is auditing for what, and what does `-xdev` do?

- A. World-writable files; stay on one filesystem
- B. SUID files; stay on one filesystem (don't descend into other mounts)
- C. SGID files; include all mounts
- D. Orphaned files; follow symlinks

??? question "Answer and explanation"
    **B.** `-perm -4000` matches the SUID bit; `-xdev` keeps `find` on the starting filesystem so it doesn't crawl network or other mounts. (Day 19)

**8.** In `nmap` output a port is reported as `filtered`. What does that mean?

- A. A service is listening and accepting connections
- B. The host sent a RST (nothing listening)
- C. A firewall dropped the probe (no reply) — equivalent to "timed out"
- D. The port is open but the service is unknown

??? question "Answer and explanation"
    **C.** *filtered* = no usable reply, typically a firewall DROP. *open* = SYN-ACK, *closed* = RST ("refused"). `--reason` shows `no-response` for filtered. (Days 12, 20)

**9.** Which statement about the PowerShell execution policy is correct?

- A. It is a security boundary that blocks all malicious scripts
- B. It is defence in depth, not a security boundary; `-ExecutionPolicy Bypass` defeats it
- C. The default on Windows clients is `Unrestricted`
- D. It applies to pasted commands as well as scripts

??? question "Answer and explanation"
    **B.** Microsoft states it is **not** a security boundary — a user can bypass it trivially (paste the code, or `-ExecutionPolicy Bypass`). It prevents *accidental* execution. Clients default to `Restricted`. (Day 19)

**10.** `Get-MpComputerStatus` reports `RealTimeProtectionEnabled : False`. In a security audit this is:

- A. Normal and expected
- B. A finding — real-time Defender protection is off and should be re-enabled
- C. Proof the machine is offline
- D. Only relevant on servers

??? question "Answer and explanation"
    **B.** Real-time protection off is a significant finding (and a common attacker action). Investigate why, check for attacker-added exclusions in `Get-MpPreference`, and re-enable it. (Day 19)

**11.** You suspect a host is beaconing. Which evidence is the **most trustworthy and least intrusive** to collect first?

- A. An external `nmap` scan of the host
- B. The host's own socket table and logs (`ss`, `Get-NetTCPConnection`, journal/Event Log)
- C. Rebooting the host
- D. Deleting the suspicious process

??? question "Answer and explanation"
    **B.** The live socket table and logs on the host itself are read-only, safe on production, and directly tie a connection to its owning process — far more informative than an external scan, and they don't destroy evidence. (Day 20)

**12.** A `/proc/1337/exe` symlink points to `/usr/bin/nc (deleted)`. Why is `(deleted)` significant?

- A. The process has finished
- B. The binary was unlinked from disk while still running — a common anti-forensics/IoC sign
- C. `nc` is always deleted after use
- D. It means the file is read-only

??? question "Answer and explanation"
    **B.** Normal software does not delete its own running executable. A `(deleted)` target is a strong indicator of compromise; you can still recover the binary from `/proc/PID/exe`. (Day 20)

**13.** Which `journalctl` option filters to messages at **error** priority and worse?

- A. `-p err`
- B. `-u err`
- C. `-g err`
- D. `--priority=debug`

??? question "Answer and explanation"
    **A.** `-p err` (priority 3) shows that severity and higher (crit, alert, emerg). `-g` greps the message text, `-u` selects a unit, and `debug` is the *lowest* priority. (Day 16)

**14.** On Windows, which command confirms whether the obsolete SMB1 protocol is enabled on the server?

- A. `Get-SmbShare`
- B. `Get-SmbServerConfiguration | Select EnableSMB1Protocol`
- C. `Get-NetTCPConnection -LocalPort 445`
- D. `Test-NetConnection -Port 445`

??? question "Answer and explanation"
    **B.** `Get-SmbServerConfiguration` exposes `EnableSMB1Protocol` (should be `False`). The others show shares or that port 445 is reachable, not which SMB *version* is enabled. (Day 19)

**15.** Which pattern most strongly indicates C2 beaconing in a packet capture?

- A. A single large download over HTTPS
- B. Regular, small, outbound connections to the same external address at a fixed interval
- C. Inbound SYN packets to many ports
- D. ARP requests on the local segment

??? question "Answer and explanation"
    **B.** Metronomic, repeated outbound connections to one destination are the beacon signature (often on 443/53 to blend in). A one-off download, a port scan (C), and ARP (D) are different behaviours. (Day 20)

## Part B — Command writing (2 marks each)

**16.** Write a `journalctl` command that shows all messages from the `ssh` service since 09:00 today, in ISO timestamp format.

??? question "Answer and explanation"
    ```bash
    journalctl -u ssh --since "09:00" -o short-iso
    ```
    `-u ssh` selects the unit (`ssh.service` on Ubuntu 24.04), `--since "09:00"` the time window (today is assumed), and `-o short-iso` renders ISO 8601 local timestamps. Accept `_COMM=sshd` as an alternative to `-u ssh`, and `--since today`. (Days 16–17)

**17.** Write the Bash command that lists every SUID file on the root filesystem only, showing the symbolic mode and owner, and sorts the output.

??? question "Answer and explanation"
    ```bash
    find / -xdev -type f -perm -4000 -printf '%M %u %p\n' 2>/dev/null | sort
    ```
    `-xdev` stays on one filesystem, `-perm -4000` matches SUID, `-printf '%M %u %p'` prints mode/owner/path, `2>/dev/null` hides permission-denied noise. Save this as a baseline and `comm -13 baseline now` to see new entries. (Day 19)

**18.** Write a `ufw` command that allows SSH **only** from the admin subnet `10.18.0.16/28`, with a comment, and say how you would avoid locking yourself out when enabling the firewall.

??? question "Answer and explanation"
    ```bash
    sudo ufw allow from 10.18.0.16/28 to any port 22 proto tcp comment 'admin SSH'
    ```
    Add this allow rule **before** running `sudo ufw enable`, keep a second session open, and (on a remote host) arm a timed rollback (`systemd-run --on-active=5m … ufw disable` or `nft -f known-good`) that you cancel once a new session proves access. (Day 18)

**19.** Write the Bash command that lists listening TCP and UDP sockets with their owning process, and say which extra privilege you may need.

??? question "Answer and explanation"
    ```bash
    sudo ss -tulpn
    ```
    `-t` TCP, `-u` UDP, `-l` listening, `-p` process, `-n` numeric. You need **root** (`sudo`) to see processes owned by other users; without it the process column is blank for them. (Days 14, 20)

**20.** Write the PowerShell that lists every **established** TCP connection with its remote address, remote port, owning PID and the owning process's executable path.

??? question "Answer and explanation"
    ```powershell
    Get-NetTCPConnection -State Established |
        Select-Object RemoteAddress, RemotePort, OwningProcess,
            @{n='Path'; e={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Path }}
    ```
    `Get-NetTCPConnection -State Established` lists the connections; the calculated property resolves each `OwningProcess` PID to the binary's path with `Get-Process`. `netstat -anob` (elevated) is an accepted alternative. (Days 14, 20)

**21.** Write a `tcpdump` command that captures only traffic to or from `203.0.113.10`, stops after 100 packets, writes to `/tmp/case.pcap`, and performs no name resolution.

??? question "Answer and explanation"
    ```bash
    sudo tcpdump -n -c 100 -w /tmp/case.pcap 'host 203.0.113.10'
    ```
    `-n` no DNS (no tip-off, no delay), `-c 100` packet limit, `-w` writes the pcap, and the BPF filter `host 203.0.113.10` restricts capture to that address. Read it back with `tcpdump -r` or `tshark -r`. (Days 15, 20)

**22.** Write the PowerShell to check Microsoft Defender's real-time protection state and signature age, and to list any configured scan exclusion paths.

??? question "Answer and explanation"
    ```powershell
    Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, AntivirusSignatureAge
    Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
    ```
    `Get-MpComputerStatus` reports protection state and signature age (in days); `Get-MpPreference` reveals exclusions — an attacker-added exclusion path is a finding. (Day 19)

## Part C — Short answer and practical (3 marks each)

**23.** You are handed a host and told "it may be compromised." List, in order, the first six steps of your investigation workflow and say why each comes where it does. (1 mark for authorisation/scope and read-only-first; 1 for socket→process→binary mapping; 1 for correlation and reporting.)

??? question "Answer and explanation"
    1. **Authorise and scope** — confirm you may investigate this host and what you may do; without it, stop. 2. **Collect read-only evidence first** — the live socket table (`ss`/`Get-NetTCPConnection`) and logs, because they are safe on production and preserve the attacker's live state. 3. **Map sockets to processes to binaries** — resolve each suspicious connection's `OwningProcess`/PID to its executable (`/proc/PID/exe`, `Get-Process … Path`); the process is the key evidence, and `(deleted)`/fake-path binaries are IoCs. 4. **Targeted active checks if in scope** — a scoped `tcpdump`/`pktmon` capture, or an `nmap` scan from another host, only once the quiet methods are done. 5. **Correlate** with auth logs (Day 17), firewall logs (Day 18) and the host audit (Day 19) to build the story. 6. **Report** a UTC timeline with the raw evidence and a severity/recommendation. Containment (killing processes, blocking IPs) comes **after** evidence collection, per the IR plan. (Day 20)

**24.** Explain the difference between an `nmap` result of *closed* and *filtered*, how `--reason` helps you tell them apart, and what each implies about the target's firewall. (1 mark per correct distinction, reason, and firewall implication.)

??? question "Answer and explanation"
    *closed* means the host is reachable and actively refused the probe — it sent a TCP **RST** — so **no firewall is dropping that port**; there is simply nothing listening. *filtered* means Nmap got **no reply** (or an ICMP unreachable), so a **firewall is dropping** the probe and you cannot tell whether a service is behind it. `--reason` prints the deciding packet: `reset`/`conn-refused` for closed, `no-response` for filtered, `syn-ack` for open — turning the label into defensible evidence. This maps onto Day 12's *refused* (closed) vs *timed out* (filtered). (Days 12, 20)

**25.** **Practical task.** On your lab VM (snapshot first), using only names beginning `m4test`: (a) append a line to a log file `~/m4test.log` with `logger -t m4test` and show it in the journal; (b) create a locked user `m4test-tmp`, confirm with `passwd -S` that it is locked, then show it has no sudo rights with `sudo -l -U m4test-tmp`; (c) find any SUID file you can, and name the package that owns `/usr/bin/passwd` with `dpkg -S`; (d) start a harmless listener on `127.0.0.1:9999` (`nc -lvnp 9999` or a Python/TcpListener), find it with `ss -tlnp` (or `Get-NetTCPConnection`), map it to its PID and binary, then stop it; (e) remove the user and clean up. Give the commands.

??? question "Answer and explanation"
    Marking: 0.6 mark per part (a)–(e).

    ```bash
    # (a) write a log entry and read it back
    logger -t m4test "Module 4 practical test marker"
    journalctl -t m4test --since "-5 min" -o short-iso
    # (b) locked user, status, no sudo
    sudo useradd -m -s /bin/bash m4test-tmp ; sudo passwd -l m4test-tmp
    passwd -S m4test-tmp            # m4test-tmp L ...   (L = locked)
    sudo -l -U m4test-tmp          # "not allowed to run sudo" / no rules
    # (c) a SUID file and package ownership
    find /usr/bin -perm -4000 -type f 2>/dev/null | head
    dpkg -S /usr/bin/passwd        # passwd: /usr/bin/passwd
    # (d) listener -> PID -> binary -> stop
    nc -lvnp 9999 &                # lab only, loopback
    sudo ss -tlnp 'sport = :9999'  # users:(("nc",pid=PID,fd=3))
    pid=$(pgrep -f 'nc -lvnp 9999'); ls -l /proc/"$pid"/exe
    kill "$pid"
    # (e) clean up
    sudo userdel -r m4test-tmp
    ```

    Windows alternative for (d): `$l=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,9999); $l.Start()`, then `Get-NetTCPConnection -LocalPort 9999 -State Listen | Select OwningProcess`, `Get-Process -Id <PID> | Select Path`, `$l.Stop()`. All steps are read-only except the throwaway user and listener you create and then remove. (Days 16–20)

## After the test

| Score (of 38) | What to do next |
|---|---|
| 34–38 | Distinction. Move on to [Module 5](../course/module-5/index.md). |
| 29–33 | Merit. Re-read the lessons for any questions you missed. |
| 23–28 | Pass. Repeat the labs for the days you lost marks on. |
| < 23 | Repeat Labs 16–20 before starting Module 5. |
