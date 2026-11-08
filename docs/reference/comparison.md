---
description: "Task-oriented Bash and PowerShell equivalents, updated with each lesson."
---

# Bash ↔ PowerShell Side-by-Side

Rows are added as each day is released. ⚠ marks behaviour that differs in an important way.

## Identity & system

| Task | Bash (Ubuntu) | PowerShell | Notes |
|---|---|---|---|
| Current user | `whoami` | `whoami` · `$env:USERNAME` | |
| Host name | `hostname` | `hostname` · `$env:COMPUTERNAME` | |
| OS version | `cat /etc/os-release` | `Get-ComputerInfo -Property OsName,OsVersion` | Windows-only cmdlet |
| Kernel / build | `uname -r` | `[Environment]::OSVersion.Version` | |
| Architecture | `uname -m` | `$env:PROCESSOR_ARCHITECTURE` | |
| Shell version | `echo $BASH_VERSION` | `$PSVersionTable.PSVersion` | |
| Date / UTC | `date` · `date -u` | `Get-Date` · `(Get-Date).ToUniversalTime()` | |
| ISO timestamp | `date -Iseconds` | `Get-Date -Format o` | |

## Help

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| Full help | `man cmd` | `Get-Help cmd -Full` | `Update-Help` first |
| Examples | `man cmd` (EXAMPLES section) | `Get-Help cmd -Examples` | |
| Find commands | `apropos word` | `Get-Command *word*` | |
| What runs? | `type -a name` | `Get-Command name -All` | |

## Navigation & files

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| Where am I | `pwd` | `Get-Location` | |
| List (incl. hidden) | `ls -la` | `Get-ChildItem -Force` | ⚠ `ls -la` fails in PowerShell |
| Recursive list | `ls -R` | `Get-ChildItem -Recurse` | |
| Change dir | `cd dir` | `Set-Location dir` | |
| Previous dir | `cd -` | `Set-Location -` | 6.2+ only |
| Make dirs | `mkdir -p a/b` | `New-Item a\b -ItemType Directory -Force` | |
| New empty file | `touch f` | `New-Item f -ItemType File` | ⚠ `-Force` overwrites |
| Copy | `cp a b` | `Copy-Item a b` | |
| Copy tree | `cp -r a b` | `Copy-Item a b -Recurse` | Same nesting rule |
| Move / rename | `mv a b` | `Move-Item a b` · `Rename-Item a -NewName b` | |
| Delete | `rm f` | `Remove-Item f` | No recycle bin |
| Delete tree | `rm -r d` | `Remove-Item d -Recurse` | |
| Force | `rm -rf d` | `Remove-Item d -Recurse -Force` | ⚠ `-rf` is not a PS parameter |
| Simulate | *(preview with ls)* | `-WhatIf` | |
| Exists? | `[ -e p ]` | `Test-Path p` | |
| Literal name | `'a[1].txt'` | `-LiteralPath 'a[1].txt'` | |
