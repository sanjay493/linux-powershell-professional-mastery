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

## Reading files & redirection

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| Show file | `cat f` | `Get-Content f` | `cat` is an alias only on Windows |
| Invisible characters | `cat -A f` | `Format-Hex f` | |
| Page | `less f` | <code>Get-Content f &#124; Out-Host -Paging</code> | No search in PowerShell |
| First N lines | `head -n N f` | `Get-Content f -TotalCount N` | |
| Last N lines | `tail -n N f` | `Get-Content f -Tail N` | |
| Skip header | `tail -n +2 f` | <code>Get-Content f &#124; Select-Object -Skip 1</code> | |
| Line range | `sed -n '10,20p' f` | <code>Get-Content f &#124; Select-Object -Skip 9 -First 11</code> | ⚠ arrays are zero-based |
| Follow | `tail -F f` | `Get-Content f -Tail 0 -Wait` | `-F` survives rotation |
| Count lines | `wc -l f` | `(Get-Content f).Count` | |
| Words / characters | `wc -w f` · `wc -m f` | <code>Get-Content f &#124; Measure-Object -Word -Character</code> | |
| Overwrite / append | `>` / `>>` | `>` / `>>` · `Out-File [-Append]` | ⚠ 5.1 writes UTF-16 LE |
| Errors to file | `2> f` | `2> f` | |
| All output to file | `&> f` · `> f 2>&1` | `*> f` | |
| Discard | `> /dev/null` · `2>/dev/null` | <code>&#124; Out-Null</code> · `2>$null` | |
| Save and show | <code>&#124; tee [-a] f</code> | <code>&#124; Tee-Object [-Append] f</code> | |
| Refuse overwrite | `set -o noclobber` | `Out-File -NoClobber` | |
| Input from file | `cmd < f` | <code>Get-Content f &#124; cmd</code> | ⚠ no `<` in PowerShell |
| Privileged append | <code>echo x &#124; sudo tee -a f</code> | Elevated session + `Add-Content` | |

## Searching

| Task | Bash | PowerShell | Notes |
|---|---|---|---|
| Find by name | `find . -name '*.log'` | `Get-ChildItem -Recurse -Filter *.log` | Quote Bash patterns |
| Files / folders only | `-type f` / `-type d` | `-File` / `-Directory` | |
| Depth limit | `-maxdepth N` | `-Depth N` | 5.0+ |
| Size | `-size +100M` | `Where-Object Length -gt 100MB` | |
| Age | `-mtime -1` · `-mmin -30` | `Where-Object LastWriteTime -gt (Get-Date).AddDays(-1)` | |
| Hidden | `-name '.*'` | `-Force` / `-Hidden` | |
| Act on results | `-exec cmd {} +` | <code>&#124; ForEach-Object { }</code> | |
| Delete results | `-delete` (last, after preview) | <code>&#124; Remove-Item -WhatIf</code> | |
| Search text | `grep 'x' f` | `Select-String -Pattern 'x' -Path f` | ⚠ opposite case defaults |
| Ignore case / match case | `-i` | default / `-CaseSensitive` | |
| Invert | `-v` | `-NotMatch` | |
| Count | `-c` | `(Select-String ...).Count` | |
| Matching file names | `-l` | <code>-List &#124; Select-Object -ExpandProperty Path</code> | |
| Recursive | `grep -r` | <code>Get-ChildItem -Recurse &#124; Select-String</code> | |
| Context | `-C N` | `-Context N` | |
| Literal | `-F` | `-SimpleMatch` | |
| Only the match | `-o` | `-AllMatches` + `.Matches.Value` | |
| Quiet test | `-q` | `-Quiet` | |
| Indexed name search | `locate` | — | |
| Which program runs | `command -v` · `type -a` · `which -a` | `Get-Command [-All]` · `where.exe` | ⚠ `where` = `Where-Object` |
