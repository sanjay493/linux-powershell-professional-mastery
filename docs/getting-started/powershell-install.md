---
description: "Install PowerShell 7 on Windows 11 and Ubuntu 24.04 side by side with Windows PowerShell 5.1."
---

# PowerShell 7 Installation

PowerShell 7 installs **side by side** with Windows PowerShell 5.1. It does not replace it. The executable is `pwsh`. Any supported 7.x release works for this course. `winget` installs the latest stable release (7.6 at the time of writing).

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

## Troubleshooting Windows installation

### `Installer failed with exit code: 0x80072ee2`

**Symptom (reported by a learner on Windows 11):**

```text
PS ~ > winget install --id Microsoft.PowerShell --source winget
Found PowerShell [Microsoft.PowerShell] Version 7.6.9.0
This application is licensed to you by its owner.
Microsoft is not responsible for, nor does it grant any licenses to, third-party packages.
Successfully verified installer hash
Starting package install...
Installer failed with exit code: 0x80072ee2 : unknown error
```

**What it means:** `0x80072EE2` is the Windows networking error `ERROR_INTERNET_TIMEOUT` ("The operation timed out"). The **download and hash check already succeeded**, so the failure happened while the MSI installer itself was running. By default, the PowerShell MSI contacts the network during setup to opt you in to updates through **Microsoft Update** (the `USE_MU` / `ENABLE_MU` installer options). On a slow connection, behind a proxy or firewall, or on a VPN, that request can time out and the installation rolls back.

**Fix it, in this order:**

1. **Check the connection, then retry once.**

    ```powershell
    Test-NetConnection -ComputerName www.microsoft.com -Port 443   # TcpTestSucceeded should be True
    netsh winhttp show proxy                                       # system (WinHTTP) proxy settings
    ```

    Disconnect from VPNs and metered or captive-portal Wi-Fi, then run the `winget install` command again.

2. **Install without the Microsoft Update opt-in.** This avoids the network call that timed out. Run it in an **elevated** terminal:

    ```powershell
    winget install --id Microsoft.PowerShell --source winget --override "/quiet /norestart ADD_PATH=1 USE_MU=0 ENABLE_MU=0"
    ```

    `--override` **replaces** winget's default installer arguments, which is why `/quiet` and `ADD_PATH=1` are included explicitly. You then keep PowerShell updated with `winget upgrade --id Microsoft.PowerShell` instead of Microsoft Update.

3. **Use the MSI directly.** Download `PowerShell-7.x.x-win-x64.msi` from <https://github.com/PowerShell/PowerShell/releases>, then either run it and **untick** the two *Microsoft Update* checkboxes, or install silently from an elevated terminal:

    ```powershell
    msiexec.exe /package .\PowerShell-7.6.9-win-x64.msi /quiet ADD_PATH=1 USE_MU=0 ENABLE_MU=0
    ```

    Adjust the file name to the version you downloaded.

4. **Use an alternative package.** Install from the Microsoft Store (`winget install --id 9MZ1SNWT0N5D --source msstore`), or use the portable **ZIP** package from the same releases page if you cannot install software system-wide.

**Collect diagnostics if it still fails:**

```powershell
winget install --id Microsoft.PowerShell --source winget --log "$env:TEMP\pwsh-install.log"
winget --logs          # opens winget's log folder
```

Search the log for `Return value 3` (the MSI step that failed) and for the URL that timed out.

**Verify success:**

```powershell
winget list --id Microsoft.PowerShell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
```

!!! note "Validation status"
    This fix is based on the documented PowerShell MSI options (`ADD_PATH`, `USE_MU`, `ENABLE_MU`) and the Windows error code definition. It has not been reproduced in CI, because the failure depends on the local network.

### Other common Windows installation problems

| Symptom | Cause | Fix |
|---|---|---|
| `'winget' is not recognized` | App Installer missing or outdated | Update **App Installer** from the Microsoft Store, then open a new terminal |
| `pwsh` not recognized after a successful install | `PATH` not refreshed in the current window | Close and reopen the terminal, or run `& "$env:ProgramFiles\PowerShell\7\pwsh.exe"` |
| `0x80070005` / access denied | Installing system-wide without elevation | Run the terminal **as Administrator** for the install only |
| Install blocked by company policy | Software restriction or Intune/AppLocker rules | Ask IT, or use the Store/ZIP package if policy allows |

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
