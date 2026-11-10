---
description: "Release history of the course."
---

# Changelog

All notable changes are listed here, newest first. Nightly releases add two days each.

## 2026-11-10 — v0.4.0 (nightly release: Days 07–08)

- **Day 07** File Permissions and Access Control (`ls -l`/`stat` permission strings, `chmod` numeric and symbolic incl. `X`, `chown`, `chgrp`, `umask` (0022 vs 0002 via `pam_umask`), setuid/setgid/sticky bits, `find -perm` audits, POSIX ACLs with `getfacl`/`setfacl` and `getfacl -R` backups, `chattr`/`lsattr`; NTFS DACLs, ACEs, inheritance and deny precedence, `Get-Acl`, `Set-Acl`, `FileSystemAccessRule`, `SetAccessRuleProtection`, `icacls /save /restore /grant /remove /inheritance`, `takeown`), with **Lab 07: Lock It Down**.
- **Day 08** Processes and Services (PIDs, process states, jobs, `ps`, `top`, `htop`, `pgrep`/`pkill`, signals and `kill`, `nice`/`renice`, `/proc/PID`, `systemctl`, `journalctl -u`; `Get-Process`, `Stop-Process`, `Start-Process`, `Wait-Process`, `Win32_Process` command lines, `Get-Service`, `Start/Stop/Restart-Service`, `Set-Service`, `sc.exe`, `tasklist`/`taskkill`, Service Control Manager events), with **Lab 08: Runaway Process**.
- New scripts: **`process-monitor.sh`** and **`Process-Monitor.ps1`** (top processes by sampled CPU and memory, thresholds, text/CSV(/JSON) output, exit code 3 on breach), documented in the Script Library.
- Command reference: new **Permissions** and **Processes & Services** categories for Linux and PowerShell, plus matching comparison tables.
- Day 06 now links to Day 07; course, module, lab, schedule and assessment indexes updated.

## 2026-11-09 — v0.3.0 (nightly release: Days 05–06)

- **Day 05** Command Help, History and Pipelines (`man` sections, `man -k`/`-f`, `--help`, `help`, `type -a`, `command -v`, `history`, `fc`, history expansion, `HISTCONTROL`/`HISTTIMEFORMAT`; `Get-Help -Examples/-Parameter/-Online`, `Get-Command -All/-ParameterName`, `Get-Alias -Definition`, `Get-Member`, `Get-History`, `Invoke-History`, PSReadLine history; text vs object pipelines, `;` `&&` `||` (PowerShell 7+), `$?`, `PIPESTATUS`, `pipefail`, `$LASTEXITCODE`, `-ErrorAction`, `try`/`catch`/`finally`), with **Lab 05: Pipeline Builder**.
- **Day 06** Users and Groups (`/etc/passwd`, `/etc/shadow`, `/etc/group`, `id`, `getent`, `useradd`, `adduser` (Debian/Ubuntu), `usermod -aG`, `passwd`, `chage`, `userdel`, `groupadd`, `gpasswd`; `Get-LocalUser`, `New-LocalUser`, `Set-LocalUser`, `Disable-LocalUser`, `Remove-LocalUser`, `Add-LocalGroupMember`, `Get-LocalGroupMember`, `net user`, `whoami /groups`; onboarding, offboarding and account audits), with **Lab 06: Onboard & Offboard**.
- **Module 1 test** (25 questions, 38 marks, collapsible answer key and practical task) in Assessments.
- Command reference: new **Pipelines, History & Exit Codes** and **Users & Groups** categories for Linux and PowerShell, plus matching comparison tables.
- Day 04 now links to Day 05; course, module, lab, schedule and assessment indexes updated.

## 2026-11-08 — v0.2.0 (nightly release: Days 03–04)

- **Day 03** Reading and Managing Files (`cat`, `less`, `head`, `tail -F`, `wc`, `Get-Content -TotalCount/-Tail/-Wait`, `Measure-Object`, redirection, `Out-File`, `Tee-Object`, the six PowerShell streams, encodings and line endings), with **Lab 03: Log Reader**.
- **Day 04** Searching Files and Text (`find`, `grep`, `xargs`, `locate`/`plocate`, `which`, `type`, `command -v`, `Get-ChildItem -Recurse`, `Select-String`, `Where-Object`, `Get-Command`, wildcards vs regular expressions), with **Lab 04: Needle in the Haystack**.
- Command reference: new **Reading Files & Redirection** and **Searching** categories for Linux and PowerShell, plus matching comparison tables.
- Day 02 now links to Day 03; course, module, lab, schedule and assessment indexes updated.
- Fix: the `Move-Item / Rename-Item` reference example rendered `$_` as italics on the site; it now uses `$PSItem`.

## 2026-11-08 — v0.1.0 (launch)

- Site, navigation, search, light/dark themes and CI/CD to GitHub Pages.
- **Day 01** Introduction to Linux and PowerShell, with **Lab 01**.
- **Day 02** File and Directory Management, with **Lab 02**.
- Getting Started guides: Windows, Ubuntu, WSL2, PowerShell 7, lab safety.
- Command reference (navigation, help, files) for Linux and PowerShell, plus a comparison table.
- Career pathways: SOC Analyst, Network Analyst, System Administrator.
- Scripts: `system-info.sh`, `System-Info.ps1`.
- PDFs: complete handbook (published days), Linux and PowerShell cheat sheets, lab workbook.
