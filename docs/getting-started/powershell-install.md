---
description: "Install PowerShell 7 on Windows 11 and Ubuntu 24.04 side by side with Windows PowerShell 5.1."
---

# PowerShell 7 Installation

PowerShell 7 installs **side by side** with Windows PowerShell 5.1. It does not replace it. The executable is `pwsh`. Microsoft's current Long-Term Support (LTS) release is 7.4. Any supported 7.x release works for this course.

## Windows 11

=== "winget (recommended)"

    ```powershell
    winget search --id Microsoft.PowerShell
    winget install --id Microsoft.PowerShell --source winget
    ```

=== "MSI package"

    Download the latest `PowerShell-7.x.x-win-x64.msi` from <https://github.com/PowerShell/PowerShell/releases> and run it. Keep the defaults, and enable *Add PowerShell to PATH*.

=== "Microsoft Store"

    Search for **PowerShell** by Microsoft Corporation. It updates automatically. Note that some system-level tasks behave differently in the Store version.

Verify in a **new** terminal:

```powershell
pwsh -NoProfile -Command '$PSVersionTable'
```

## Ubuntu 24.04

Install from Microsoft's package repository:

```bash
# Prerequisites
sudo apt update && sudo apt install -y wget apt-transport-https software-properties-common

# Register the Microsoft repository (reads VERSION_ID from /etc/os-release)
source /etc/os-release
wget -q "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb"
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Install
sudo apt update && sudo apt install -y powershell

# Start
pwsh
```

Alternatively: `sudo snap install powershell --classic`.

## Which edition should I use?

| Situation | Use |
|---|---|
| Learning, new scripts, cross-platform work | **PowerShell 7** |
| Modules that only run on .NET Framework (some older RSAT/Exchange tooling) | Windows PowerShell 5.1 |
| Group Policy logon scripts on older fleets | Windows PowerShell 5.1 (always present) |

Every lesson marks commands that are **5.1-only**, **7-only** or **Windows-only**.

## Keep it updated

```powershell
winget upgrade --id Microsoft.PowerShell
```

```bash
sudo apt update && sudo apt install --only-upgrade powershell
```

Official documentation: <https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell>
