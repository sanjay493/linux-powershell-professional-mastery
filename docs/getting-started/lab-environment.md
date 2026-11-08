---
description: "Rules of engagement for every lab in the course: authorised systems, backups, credentials and destructive commands."
---

# Lab Environment & Safety Rules

Every lab in this course follows these rules. They reflect how professional IT and security teams work.

## 1. Authorised systems only

- Run labs on **localhost**, **WSL2**, **your own virtual machines**, or systems you have **explicit written permission** to test.
- **Never** scan, probe, brute-force or capture traffic on networks or hosts you do not own or administer. That includes employer, school, public Wi-Fi and internet hosts. Unauthorised scanning is illegal in many countries (for example under the IT Act 2000 in India and the Computer Misuse Act in the UK).
- Network discovery labs (Nmap, Days 20 and 27) target `127.0.0.1`, your own VMs, or `scanme.nmap.org`, which the Nmap project explicitly permits for light testing.

## 2. Snapshots and backups before changes

Before any lab that changes **permissions, firewall rules, services, users or system configuration**:

- **VM:** take a snapshot.
- **WSL:** `wsl --export Ubuntu-24.04 $HOME\wsl-backup.tar`
- **Windows:** create a restore point (`Checkpoint-Computer -Description "Before Day 18 lab"` in an elevated Windows PowerShell 5.1), and export what you will change (for example `netsh advfirewall export C:\Backup\fw.wfw`).
- **Files:** copy the original with a timestamp (`cp -a file file.bak.$(date +%F)`).

## 3. No real credentials

- Use throwaway lab accounts (`student`, `labuser1`) and passwords that you use nowhere else.
- **Never** paste real passwords, API keys, tokens or private keys into scripts, screenshots, tickets or this course's repository.

## 4. Destructive commands are always explained first

Commands that delete, overwrite or disrupt (`rm -r`, `Remove-Item -Recurse`, `kill -9`, `Stop-Service`, firewall changes) are marked with a :material-alert: warning, explained, and preceded by a **preview** (`ls`, `-WhatIf`) step.

## 5. Never disable security controls as a workaround

If a lab fails because of the firewall, antivirus, SELinux/AppArmor or execution policy, **diagnose why**. Do not turn the control off. Where a control must be adjusted, the lesson shows the narrowest, reversible change, and how to undo it.

## 6. Least privilege

Work as a normal user. Use `sudo` or an elevated PowerShell only for the specific command that needs it, then return to the normal session.

## Recommended folder layout

```text
~/lpm-lab/            # Linux practice root
$HOME\lpm-lab\        # Windows practice root
    day01/ day02/ ...  # one folder per day
    reports/           # output of course scripts
```
