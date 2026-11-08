---
description: "Prepare Windows 11 for the course: Windows Terminal, PowerShell editions, VS Code, Git and safe defaults."
---

# Windows 11 Setup

## 1. Check your Windows version

```powershell
Get-ComputerInfo -Property OsName, OsVersion, OsBuildNumber
```

Any Windows 11 build (22000 or later) is supported. Windows 10 22H2 works for almost everything, but it is not the documented target.

## 2. Windows Terminal

Windows Terminal is included in Windows 11. Open it with ++win++ → *Terminal*. Recommended settings (++ctrl+comma++):

- **Startup → Default profile:** *PowerShell* (PowerShell 7, after you install it).
- Keep separate profiles for *Windows PowerShell*, *PowerShell* and *Ubuntu*.

## 3. Confirm Windows PowerShell 5.1

```powershell
$PSVersionTable.PSVersion
$PSVersionTable.PSEdition    # Desktop
```

## 4. Install PowerShell 7

Follow [PowerShell 7 Installation](powershell-install.md). The short version is:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

## 5. Install Git and Visual Studio Code

```powershell
winget install --id Git.Git --source winget
winget install --id Microsoft.VisualStudioCode --source winget
```

Close and reopen the terminal afterwards so the updated `PATH` is loaded, then verify:

```powershell
git --version
code --version
```

Recommended VS Code extensions: **PowerShell** (`ms-vscode.powershell`), **ShellCheck** (`timonwong.shellcheck`), **WSL** (`ms-vscode-remote.remote-wsl`), **Markdown All in One**.

## 6. Script execution policy (read before changing anything)

On Windows client editions the default execution policy is **Restricted**, so `.ps1` scripts will not run. For this course set it **for your user only** to `RemoteSigned`. This allows your own local scripts and requires downloaded scripts to be signed or explicitly unblocked:

```powershell
Get-ExecutionPolicy -List
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

!!! warning "Execution policy is not a security boundary"
    Execution policy prevents *accidental* script execution and is not designed to stop attackers. Never set `Unrestricted` or `Bypass` machine-wide. Day 19 covers this in depth.

## 7. Create your practice folder

```powershell
New-Item -Path $HOME\lpm-lab -ItemType Directory -Force
```

Do all Windows practice work inside `$HOME\lpm-lab` unless a lab says otherwise.

## Verification

```powershell
$PSVersionTable.PSVersion          # 5.1.x in Windows PowerShell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'   # 7.x
git --version
Get-ExecutionPolicy -Scope CurrentUser                 # RemoteSigned
Test-Path $HOME\lpm-lab                                # True
```
