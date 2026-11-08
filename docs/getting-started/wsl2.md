---
description: "Install Windows Subsystem for Linux 2 with Ubuntu 24.04 on Windows 11."
---

# WSL2 Installation

The **Windows Subsystem for Linux 2** runs a real Linux kernel in a lightweight VM, integrated with Windows.

## Requirements

- Windows 11 (any edition) or Windows 10 version 2004+.
- Virtualisation enabled in BIOS/UEFI. Check: Task Manager → Performance → CPU → *Virtualization: Enabled*.

## Install

Open **Windows PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu-24.04
```

Restart when prompted. After the restart Ubuntu finishes installing and asks you to create a **Linux user name and password**. These are separate from your Windows account.

## Verify

```powershell
wsl --list --verbose
```

**Expected output (example):**

```text
  NAME            STATE           VERSION
* Ubuntu-24.04    Running         2
```

`VERSION` must be **2**. If it shows 1, run `wsl --set-version Ubuntu-24.04 2`.

Inside Ubuntu:

```bash
cat /etc/os-release | head -3
sudo apt update && sudo apt full-upgrade -y
```

Then install the course tools listed in [Ubuntu Setup](ubuntu-setup.md#first-boot-configuration).

## Useful WSL commands

| Command (PowerShell) | Purpose |
|---|---|
| `wsl` | Start the default distribution |
| `wsl -d Ubuntu-24.04` | Start a specific distribution |
| `wsl --shutdown` | Stop all distributions (fixes many networking glitches) |
| `wsl --update` | Update the WSL kernel and components |
| `wsl --export Ubuntu-24.04 backup.tar` | Back up the whole distribution |
| `wsl --status` | Show default version and settings |

## Files across both systems

- Windows drives appear in Linux under `/mnt/c`, `/mnt/d`.
- Linux files appear in Windows Explorer at `\\wsl$\Ubuntu-24.04\home\<user>`.
- **Keep Linux lab work in the Linux home directory** (`~`), not under `/mnt/c`. Performance is much better, and Linux permissions (Day 7) behave correctly.

## Known limitations for this course

| Topic | WSL2 behaviour | Recommendation |
|---|---|---|
| systemd services (Day 8) | Supported. Ubuntu 24.04 on WSL enables systemd by default | OK |
| UFW / nftables firewall (Day 18) | Works inside WSL, but does not protect Windows | Use a VM for realism |
| Packet capture (Days 15, 20, 27) | `tcpdump` sees only the WSL virtual NIC | Use a VM for full captures |
| Network interfaces (Day 15) | Single virtual adapter (NAT or mirrored mode) | VM for multi-NIC labs |
| Login history `last`/`lastb` (Day 17) | Limited because WSL logins are not real logins | VM recommended |
