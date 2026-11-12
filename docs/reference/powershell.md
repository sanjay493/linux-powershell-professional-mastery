---
description: "PowerShell cmdlet reference for Windows PowerShell 5.1 and PowerShell 7: syntax, parameters, examples, expected output, equivalents, common errors and documentation."
---

# PowerShell Command Reference

Platforms: **Windows PowerShell 5.1** (Windows 11) and **PowerShell 7.4+** (Windows, Linux, macOS). Version and OS restrictions are noted per entry.

## Navigation & System Information

### Get-Location

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS |
| **Description** | Returns the current location as a `PathInfo` object. Alias: `pwd`, `gl`. |
| **Syntax** | `Get-Location [-PSProvider <String[]>] [-PSDrive <String[]>] [-Stack]` |
| **Parameters** | `-Stack` shows the `Push-Location` stack |
| **Example** | `(Get-Location).Path` |
| **Expected output** | `C:\Users\student` |
| **Equivalent** | `pwd` |
| **Common errors** | Using the object where a string is required. Use `.Path`. |
| **Use case** | Building absolute paths in scripts: `Join-Path (Get-Location) 'out.csv'`. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-location> |

### Get-ChildItem

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS (aliases `ls`, `dir`, `gci`; `ls` only on Windows) |
| **Description** | Gets the items in one or more locations (files, folders, registry keys, certificates). |
| **Syntax** | `Get-ChildItem [[-Path] <String[]>] [[-Filter] <String>] [-Include] [-Exclude] [-Recurse] [-Depth <UInt32>] [-Force] [-Name] [-File] [-Directory] [-Hidden]` |
| **Parameters** | `-Filter *.log` fast filter · `-Recurse`/`-Depth` · `-Force` hidden/system · `-File`/`-Directory` · `-Name` strings only |
| **Example** | <code>Get-ChildItem C:\Windows\Logs -Recurse -File &#124; Sort-Object Length -Descending &#124; Select-Object -First 5 FullName, Length</code> |
| **Expected output** | A table of the five largest log files with `FullName` and `Length` (bytes) |
| **Equivalent** | `ls -la`, `find`, `ls -R` |
| **Common errors** | `Access to the path ... is denied` during `-Recurse`: add `-ErrorAction SilentlyContinue` only when you understand what is skipped |
| **Use case** | Inventory files by size or date; find recently changed files. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-childitem> |

### Get-ComputerInfo

| Field | Detail |
|---|---|
| **Version / OS** | 5.1+, 7.x · **Windows only** |
| **Description** | Returns a consolidated object with ~180 OS, hardware, BIOS and configuration properties. Alias: `gin`. |
| **Syntax** | `Get-ComputerInfo [[-Property] <String[]>]` |
| **Parameters** | `-Property` limit to named properties (wildcards allowed) |
| **Example** | `Get-ComputerInfo -Property OsName, OsVersion, OsArchitecture, CsTotalPhysicalMemory` |
| **Expected output** | `Microsoft Windows 11 Home Single Language 10.0.26200 64-bit ...` |
| **Equivalent** | `uname -a`, `cat /etc/os-release`, `hostnamectl` |
| **Common errors** | Slow without `-Property` · not available on Linux PowerShell |
| **Use case** | Help-desk triage and patch-compliance inventory. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-computerinfo> |

### Get-Date

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS (`-AsUTC` needs 7.1+) |
| **Description** | Returns the current (or a specified) date and time as a `DateTime` object, or a formatted string. |
| **Syntax** | `Get-Date [[-Date] <DateTime>] [-Format <String>] [-UFormat <String>] [-AsUTC]` |
| **Parameters** | `-Format 'yyyy-MM-dd HH:mm:ss'` · `-Format o` ISO 8601 · `-UFormat %Y-%m-%d` · `-AsUTC` |
| **Example** | `(Get-Date).AddDays(-30).ToString('yyyy-MM-dd')` |
| **Expected output** | `2026-10-09` |
| **Equivalent** | `date`, `date -d '30 days ago' +%F` |
| **Common errors** | Using `-Format` and then date arithmetic (the result is a string) |
| **Use case** | Filtering logs to "last 24 hours": `(Get-Date).AddHours(-24)`. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date> |

### $PSVersionTable · $env: variables

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS |
| **Description** | `$PSVersionTable` holds engine version and edition. `$env:NAME` reads environment variables (`USERNAME`, `COMPUTERNAME`, `TEMP`, `USERPROFILE`). |
| **Example** | `$PSVersionTable.PSEdition; $env:COMPUTERNAME` |
| **Expected output** | `Desktop` / `WIN11-LAB` |
| **Equivalent** | `echo $BASH_VERSION`, `echo $USER $HOSTNAME` |
| **Common errors** | On Linux use `$env:USER` (not `USERNAME`); `$env:COMPUTERNAME` is empty there |
| **Use case** | Scripts that branch on edition or OS (`if ($IsLinux) { ... }` in 7). |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables> |

## Help & Discovery

### Get-Help

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS |
| **Description** | Displays help for cmdlets, functions and `about_` topics. Alias: `help`. |
| **Syntax** | <code>Get-Help [[-Name] &lt;String&gt;] [-Examples &#124; -Detailed &#124; -Full &#124; -Online &#124; -Parameter &lt;String&gt;]</code> |
| **Example** | `Get-Help Remove-Item -Parameter WhatIf` |
| **Expected output** | Parameter description, type, position and whether it is required |
| **Equivalent** | `man`, `--help`, `help` |
| **Common errors** | Only syntax shown, because help is not downloaded. Run `Update-Help` (elevated in 5.1; `-Scope CurrentUser` in 7). |
| **Use case** | Learning a cmdlet offline. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-help> |

### Get-Command

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Alias: `gcm` |
| **Description** | Finds commands (cmdlets, functions, aliases, executables). |
| **Syntax** | `Get-Command [[-Name] <String[]>] [-Verb <String[]>] [-Noun <String[]>] [-Module <String[]>] [-All]` |
| **Example** | `Get-Command -Noun Item` |
| **Expected output** | `Clear-Item, Copy-Item, Get-Item, Invoke-Item, Move-Item, New-Item, Remove-Item, Rename-Item, Set-Item` |
| **Equivalent** | `type`, `which`, `apropos`, `compgen -c` |
| **Common errors** | None common |
| **Use case** | Discover commands by noun; resolve which `ls` will actually run. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-command> |

### Get-Alias

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x (fewer aliases on Linux/macOS) |
| **Description** | Lists aliases or resolves one. |
| **Example** | `Get-Alias -Definition Remove-Item` |
| **Expected output** | `del, erase, rd, ri, rm, rmdir` |
| **Equivalent** | `alias` |
| **Use case** | Translating someone's alias-heavy one-liner into a readable script. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-alias> |

## Files & Directories

### Set-Location

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `cd`, `chdir`, `sl` |
| **Description** | Changes the current location (file system, registry, certificate store...). |
| **Syntax** | `Set-Location [[-Path] <String>] [-LiteralPath <String>] [-PassThru]` |
| **Parameters** | `-` / `+` history navigation (6.2+) · `-LiteralPath` · `-PassThru` |
| **Example** | `Set-Location HKLM:\SOFTWARE\Microsoft` |
| **Expected output** | Prompt becomes `PS HKLM:\SOFTWARE\Microsoft>` |
| **Equivalent** | `cd` |
| **Common errors** | `Cannot find path ... because it does not exist` |
| **Use case** | Navigating the registry like a file system. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-location> |

### New-Item

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Alias: `ni` (`mkdir` is a wrapper function on Windows) |
| **Description** | Creates files, directories, links and registry keys. |
| **Syntax** | `New-Item [-Path] <String[]> [-ItemType <String>] [-Name <String>] [-Value <Object>] [-Force]` |
| **Parameters** | `-ItemType File/Directory/SymbolicLink/Junction/HardLink` · `-Value` initial content · `-Force` (⚠ overwrites existing **files**) |
| **Example** | `New-Item -Path C:\Lab\logs -ItemType Directory -Force` |
| **Expected output** | `Directory: C:\Lab` … `d----- ... logs` |
| **Equivalent** | `mkdir -p`, `touch` |
| **Common errors** | `An item with the specified name ... already exists` (no `-Force`) |
| **Use case** | Idempotent folder creation in setup scripts. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item> |

### Copy-Item

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `copy`, `cp` (Windows), `cpi` |
| **Description** | Copies items. |
| **Syntax** | `Copy-Item [-Path] <String[]> [[-Destination] <String>] [-Recurse] [-Force] [-Filter] [-Include] [-Exclude] [-PassThru] [-WhatIf]` |
| **Example** | `Copy-Item C:\App\config.xml "C:\App\config.xml.bak.$(Get-Date -Format yyyyMMdd)"` |
| **Expected output** | None (add `-PassThru` to see the new item) |
| **Equivalent** | `cp`, `cp -r`; `robocopy` to preserve ACLs/attributes |
| **Common errors** | Nested folder when the destination exists · `Access denied` on read-only items without `-Force` |
| **Use case** | Configuration backups. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/copy-item> |

### Move-Item / Rename-Item

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `move`, `mv` (Windows), `mi` / `ren`, `rni` |
| **Description** | `Move-Item` moves (and can rename); `Rename-Item` renames in place. |
| **Syntax** | `Move-Item [-Path] <String[]> [[-Destination] <String>] [-Force]` · `Rename-Item [-Path] <String> [-NewName] <String>` |
| **Example** | <code>Get-ChildItem &#42;.log &#124; Rename-Item -NewName { $PSItem.BaseName + '-old' + $PSItem.Extension }</code> |
| **Expected output** | `app.log` → `app-old.log` (no output by default) |
| **Equivalent** | `mv` |
| **Common errors** | `Cannot create a file when that file already exists` (`Move-Item` without `-Force`) · `-NewName` given a path |
| **Use case** | Bulk renaming with a script block. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/move-item> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/rename-item> |

### Remove-Item

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `del`, `erase`, `rd`, `rmdir`, `ri`, `rm` (Windows) |
| **Description** | Deletes items. **Permanent: no Recycle Bin.** |
| **Syntax** | `Remove-Item [-Path] <String[]> [-LiteralPath] [-Recurse] [-Force] [-Filter] [-Include] [-Exclude] [-WhatIf] [-Confirm]` |
| **Example** | `Remove-Item C:\Temp\build -Recurse -WhatIf` |
| **Expected output** | `What if: Performing the operation "Remove Directory" on target "C:\Temp\build".` |
| **Equivalent** | `rm`, `rm -r`, `rmdir` |
| **Common errors** | `... has children and the Recurse parameter was not specified` · `being used by another process` · `-rf` is not a parameter |
| **Use case** | Previewed cleanup of temporary folders. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item> |

### Test-Path

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS |
| **Description** | Returns `$true`/`$false` for whether a path exists (optionally as file or folder). |
| **Syntax** | <code>Test-Path [-Path] &lt;String[]&gt; [-PathType &lt;Any&#124;Container&#124;Leaf&gt;]</code> |
| **Example** | `Test-Path C:\Windows\System32\drivers\etc\hosts -PathType Leaf` |
| **Expected output** | `True` |
| **Equivalent** | `[ -e path ]`, `[ -f file ]`, `[ -d dir ]` |
| **Use case** | Guard clauses before create/delete operations. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-path> |

### Join-Path / Split-Path

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS |
| **Description** | Build or take apart paths with the correct separator. |
| **Example** | `Join-Path $HOME 'lpm-lab'` · `Split-Path C:\a\b\file.txt -Leaf` |
| **Expected output** | `C:\Users\student\lpm-lab` · `file.txt` |
| **Equivalent** | `"$HOME/lpm-lab"`, `basename`, `dirname` |
| **Use case** | Cross-platform scripts. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/join-path> |

## Reading Files & Redirection

### Get-Content

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `gc`, `cat` and `type` (Windows) |
| **Description** | Reads a file and emits one string object per line (or one string with `-Raw`). |
| **Syntax** | `Get-Content [-Path] <String[]> [-TotalCount <Int64>] [-Tail <Int32>] [-Wait] [-Raw] [-ReadCount <Int64>] [-Encoding <Encoding>] [-LiteralPath <String[]>]` |
| **Parameters** | `-TotalCount` (`-First`, `-Head`) first N lines · `-Tail` (`-Last`) last N lines · `-Wait` follow new lines · `-Raw` whole file as one string · `-ReadCount` batch size · `-Encoding` · `-AsByteStream` (7; 5.1 uses `-Encoding Byte`) |
| **Example** | <code>Get-Content C:\Logs\app.log -Tail 0 -Wait &#124; Where-Object { $&#95; -match 'ERROR' }</code> |
| **Expected output** | New `ERROR` lines as they are written (Ctrl+C to stop) |
| **Equivalent** | `cat`, `head`, `tail`, `tail -f` |
| **Common errors** | `Cannot find path ...` · file locked by another process · `-Wait` without `-Tail` prints the whole file first · `cat -n` fails on Windows (alias) |
| **Use case** | Sampling and following large logs without opening an editor. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-content> |

### Select-Object (first / last / skip)

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Alias: `select` |
| **Description** | Selects objects by position (and properties, covered later). |
| **Syntax** | `Select-Object [-First <Int32>] [-Last <Int32>] [-Skip <Int32>] [-SkipLast <Int32>] [-Index <Int32[]>] [-Unique]` |
| **Parameters** | `-First N` · `-Last N` · `-Skip N` · `-SkipLast N` (5.0+) · `-Index` zero-based positions · `-Unique` |
| **Example** | <code>Get-Content access.log &#124; Select-Object -Skip 999 -First 11</code> |
| **Expected output** | Lines 1000–1010 of the file |
| **Equivalent** | `tail -n +N`, <code>head &#124; tail</code>, `sed -n 'A,Bp'` |
| **Common errors** | Off-by-one with zero-based `-Index` and array indexes |
| **Use case** | Extracting an exact line range as evidence. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-object> |

### Measure-Object

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Alias: `measure`. `-StandardDeviation` and `-AllStats` are 7.x only |
| **Description** | Counts objects, measures text (lines, words, characters) and calculates sum, average, minimum and maximum of a property. |
| **Syntax** | `Measure-Object [[-Property] <String[]>] [-Line] [-Word] [-Character] [-IgnoreWhiteSpace] [-Sum] [-Average] [-Minimum] [-Maximum]` |
| **Parameters** | `-Line`, `-Word`, `-Character` text statistics · `-Property` with `-Sum`, `-Average`, `-Minimum`, `-Maximum` |
| **Example** | <code>Get-ChildItem C:\Windows\Logs -Recurse -File -ErrorAction SilentlyContinue &#124; Measure-Object Length -Sum</code> |
| **Expected output** | `Count : 214` · `Sum : 98345012` … (example) |
| **Equivalent** | `wc`, `du` (Day 9), `awk` sums (Day 24) |
| **Common errors** | `-Line` may differ from `wc -l` (empty lines); use `(Get-Content f).Count` for exact line counts |
| **Use case** | Totalling log sizes or counting error lines. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/measure-object> |

### Out-File

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS |
| **Description** | Writes formatted output to a file; this is what `>` and `>>` do. |
| **Syntax** | `Out-File [-FilePath] <String> [[-Encoding] <Encoding>] [-Append] [-NoClobber] [-Width <Int32>] [-NoNewline]` |
| **Parameters** | `-Append` · `-NoClobber` refuse to overwrite · `-Encoding` (5.1 default **UTF-16 LE**; 7 default UTF-8 without BOM) · `-Width` line width |
| **Example** | <code>Get-Service &#124; Out-File C:\Temp\services.txt -Encoding utf8 -Width 200</code> |
| **Expected output** | None on screen; a UTF-8 text file |
| **Equivalent** | `>` / `>>` in Bash |
| **Common errors** | Linux tools cannot read 5.1 output (UTF-16) · long lines truncated (use `-Width`) · `The file ... already exists` with `-NoClobber` |
| **Use case** | Saving diagnostic output for a ticket in a portable encoding. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/out-file> |

### Tee-Object

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Alias: `tee` (Windows). `-Encoding` is 7.2+ |
| **Description** | Saves pipeline objects to a file or variable **and** passes them on. |
| **Syntax** | `Tee-Object [-FilePath] <String> [-Append]` · `Tee-Object -Variable <String>` |
| **Parameters** | `-FilePath` · `-Append` · `-Variable` · `-Encoding` (7.2+) |
| **Example** | <code>Get-Process &#124; Tee-Object -FilePath procs.txt &#124; Sort-Object CPU -Descending &#124; Select-Object -First 5</code> |
| **Expected output** | Top 5 processes on screen; full list in `procs.txt` |
| **Equivalent** | `tee`, `tee -a` |
| **Common errors** | 5.1 writes UTF-16 LE |
| **Use case** | Keeping an exact record of investigation output while working. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/tee-object> |

### Set-Content / Add-Content

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `sc` (5.1 only), `ac` |
| **Description** | Write or append **string** content (no console formatting). |
| **Syntax** | `Set-Content [-Path] <String[]> [-Value] <Object[]> [-Encoding <Encoding>] [-NoNewline]` · `Add-Content` (same) |
| **Parameters** | `-Value` · `-Encoding` (5.1 default ANSI; 7 default UTF-8 without BOM) · `-NoNewline` |
| **Example** | `Add-Content -Path C:\Logs\job.log -Value "$(Get-Date -Format s) backup finished"` |
| **Expected output** | None; one line appended |
| **Equivalent** | `echo ... > f` / `echo ... >> f` |
| **Common errors** | `Stream was not readable` / file in use by another process |
| **Use case** | Writing configuration or log lines from scripts. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-content> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/add-content> |

### Redirection operators and output streams

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Stream 6 (Information) is 5.0+ |
| **Description** | Redirect streams 1 Success, 2 Error, 3 Warning, 4 Verbose, 5 Debug, 6 Information to files, `$null`, or into the success stream. |
| **Syntax** | `cmd > f` · `cmd >> f` · `cmd 2> f` · `cmd 2>&1` · `cmd 3> f` … `cmd 6> f` · `cmd *> f` · `cmd 2>$null` |
| **Parameters** | `n>` / `n>>` stream n to file · `n>&1` merge into success · `*` all streams. No `<` input redirection |
| **Example** | `.\Deploy.ps1 -Verbose *> deploy-$(Get-Date -Format yyyyMMdd).log` |
| **Expected output** | None on screen; every stream in the log |
| **Equivalent** | Bash `>`, `2>`, `2>&1`, `&>` |
| **Common errors** | `The '<' operator is reserved for future use.` · `Write-Host` output not captured (stream 6; use `6>&1` or `Write-Output`) |
| **Use case** | Capturing complete logs of scheduled scripts. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_output_streams> |

## Searching

### Get-ChildItem (searching)

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. `-Depth` 5.0+ |
| **Description** | Recursively finds files and folders by name, then by any property with `Where-Object`. |
| **Syntax** | `Get-ChildItem [[-Path] <String[]>] [[-Filter] <String>] [-Include <String[]>] [-Exclude <String[]>] [-Recurse] [-Depth <UInt32>] [-File] [-Directory] [-Force]` |
| **Parameters** | `-Filter` fastest single wildcard · `-Include`/`-Exclude` several wildcards · `-File`/`-Directory` · `-Force` include hidden/system · `-ErrorAction SilentlyContinue` hide access errors |
| **Example** | <code>Get-ChildItem $env:TEMP -Recurse -File -Force -ErrorAction SilentlyContinue &#124; Where-Object LastWriteTime -gt (Get-Date).AddHours(-1)</code> |
| **Expected output** | Files changed in the last hour in the temp folder |
| **Equivalent** | `find PATH -type f -mmin -60` |
| **Common errors** | Hidden items missing (add `-Force`) · `-Include` ignored without `-Recurse` or a `\*` path · `-Filter *.htm` also matches `.html` on Windows |
| **Use case** | Sweeping malware drop locations for new files. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-childitem> |

### Select-String

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Alias: `sls`. `-Raw`, `-NoEmphasis` 7.x only |
| **Description** | Searches text in files or input strings with .NET regular expressions. **Case-insensitive by default.** Returns `MatchInfo` objects (`Path`, `LineNumber`, `Line`, `Matches`). |
| **Syntax** | `Select-String [-Pattern] <String[]> [-Path] <String[]> [-SimpleMatch] [-CaseSensitive] [-NotMatch] [-Context <Int32[]>] [-List] [-AllMatches] [-Quiet]` |
| **Parameters** | `-SimpleMatch` literal · `-CaseSensitive` · `-NotMatch` invert · `-Context B,A` · `-List` first match per file · `-AllMatches` · `-Quiet` True/False · `-Include`/`-Exclude` |
| **Example** | <code>Get-ChildItem C:\inetpub\logs -Recurse -Filter &#42;.log &#124; Select-String -Pattern ' 500 ' -List &#124; Select-Object Path</code> |
| **Expected output** | Paths of IIS log files containing HTTP 500 responses (example) |
| **Equivalent** | `grep` (case-sensitive by default) |
| **Common errors** | No `-Recurse` parameter (pipe from `Get-ChildItem`) · regex characters in literal text (use `-SimpleMatch`) · `Unterminated [] set` |
| **Use case** | Error triage and secret scanning across many files. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-string> |

### Where-Object

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `where`, `?`. Simplified syntax 3.0+ |
| **Description** | Keeps only objects for which a condition is true. |
| **Syntax** | `Where-Object [-FilterScript] <ScriptBlock>` · `Where-Object <Property> -<Operator> <Value>` |
| **Parameters** | Operators `-eq -ne -gt -ge -lt -le -like -match -in -contains` (case-sensitive: `-ceq -clike -cmatch`), combined with `-and -or -not` in a script block |
| **Example** | <code>Get-ChildItem D:\Shares -Recurse -File &#124; Where-Object { $PSItem.Length -gt 1GB -and $PSItem.LastWriteTime -lt (Get-Date).AddYears(-1) }</code> |
| **Expected output** | Large files untouched for a year (example) |
| **Equivalent** | `find -size`, `-mtime`; `grep` on text |
| **Common errors** | `where ping` runs `Where-Object`, not `where.exe` · filtering right instead of left (slow) |
| **Use case** | Storage clean-up candidates. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/where-object> |

### where.exe

| Field | Detail |
|---|---|
| **Version / OS** | Windows only (external program, all PowerShell versions) |
| **Description** | Lists executables matching a name in the `PATH` (like `which -a`). |
| **Syntax** | `where.exe [/R dir] [/Q] pattern` |
| **Parameters** | `/R dir` search recursively from `dir` · `/Q` quiet (exit code only) |
| **Example** | `where.exe python` |
| **Expected output** | `C:\Users\student\AppData\Local\Microsoft\WindowsApps\python.exe` (example) |
| **Equivalent** | `which -a`, `command -v`; in PowerShell prefer `Get-Command` |
| **Common errors** | Typing `where` without `.exe` (alias for `Where-Object`) |
| **Use case** | Discovering which copy of a tool is first in `PATH`. |
| **Docs** | <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/where> |

## Pipelines, History & Error Handling

### Get-Member

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Alias: `gm` |
| **Description** | Shows the .NET type name, properties and methods of the objects in the pipeline. |
| **Syntax** | `Get-Member [[-Name] <String[]>] [-MemberType <PSMemberTypes>] [-Static] [-Force]` |
| **Parameters** | `-MemberType Property` / `Method` / `NoteProperty` · `-Name` filter member names · `-Static` static members of the type |
| **Example** | <code>Get-Process &#124; Get-Member -MemberType Property</code> |
| **Expected output** | `TypeName: System.Diagnostics.Process` followed by `CPU`, `Id`, `WorkingSet64` … (example) |
| **Equivalent** | None in Bash (text has no members); read the command's man page for the output format |
| **Common errors** | Piping a `Format-*` result shows `FormatStartData` instead of the real type |
| **Use case** | Finding the property to sort, filter or export on. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-member> |

### Get-History / Invoke-History / Clear-History

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `h`, `history`, `ghy` · `r`, `ihy` · `clhy` |
| **Description** | List, re-run or clear the **current session's** history. Entries are `HistoryInfo` objects with `Id`, `CommandLine`, `ExecutionStatus`, `StartExecutionTime`, `EndExecutionTime`. |
| **Syntax** | `Get-History [[-Id] <Int64[]>] [[-Count] <Int32>]` · `Invoke-History [[-Id] <String>]` · `Clear-History [[-Id] <Int32[]>] [[-Count] <Int32>]` |
| **Parameters** | `-Count N` last N entries · `-Id` specific entries · `Invoke-History` with no Id re-runs the last command |
| **Example** | <code>Get-History -Count 40 &#124; Export-Csv change-1234.csv -NoTypeInformation</code> |
| **Expected output** | A CSV with one row per command (example) |
| **Equivalent** | `history`, `!N`, `history -c` |
| **Common errors** | Empty in a new window (session only) · `Clear-History` does not clear the PSReadLine file |
| **Use case** | Attaching the exact commands of a change to the ticket. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-history> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/invoke-history> |

### PSReadLine history (Get-PSReadLineOption)

| Field | Detail |
|---|---|
| **Version / OS** | PSReadLine module: 2.0 with Windows PowerShell 5.1 on Windows 10/11; 2.x with PowerShell 7 on all OS |
| **Description** | PSReadLine saves command lines from **all** sessions to a text file and provides ++ctrl+r++ / ++f8++ history search. It tries not to save lines containing `password`, `asplaintext`, `token`, `apikey` or `secret` (best effort). |
| **Syntax** | `(Get-PSReadLineOption).HistorySavePath` · `Set-PSReadLineOption -HistorySaveStyle SaveIncrementally` |
| **Parameters** | `HistorySavePath` file location · `MaximumHistoryCount` · `HistorySaveStyle` (`SaveIncrementally`, `SaveAtExit`, `SaveNothing`) |
| **Example** | <code>Get-Content (Get-PSReadLineOption).HistorySavePath &#124; Select-String 'Invoke-WebRequest'</code> |
| **Expected output** | Matching earlier command lines (example) |
| **Equivalent** | `~/.bash_history` |
| **Common errors** | Not available in hosts without PSReadLine (for example the ISE) · secrets saved by older versions |
| **Use case** | Incident responders collecting `ConsoleHost_history.txt` from each user profile. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/psreadline/about/about_psreadline> |

### Group-Object

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Alias: `group` |
| **Description** | Groups objects by one or more property values and counts each group. |
| **Syntax** | `Group-Object [[-Property] <Object[]>] [-NoElement] [-AsHashTable] [-CaseSensitive]` |
| **Parameters** | `-NoElement` omit the `Group` column · `-AsHashTable` lookup table · several properties: `Group-Object IP, Path` |
| **Example** | <code>$requests &#124; Group-Object IP -NoElement &#124; Sort-Object Count -Descending &#124; Select-Object -First 3</code> |
| **Expected output** | `Count Name` / `97 10.0.0.8` / `60 203.0.113.50` / `49 10.0.0.5` (Lab 05 data) |
| **Equivalent** | <code>sort &#124; uniq -c &#124; sort -rn</code> |
| **Common errors** | Grouping strings from native commands (parse into objects first) |
| **Use case** | Top talkers, top error codes, logons per account. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/group-object> |

### Pipeline chain operators (&& ||)

| Field | Detail |
|---|---|
| **Version / OS** | **PowerShell 7.0+ only**, all OS. A parser error in Windows PowerShell 5.1 |
| **Description** | `a && b` runs `b` only if `$?` is `True` after `a`; <code>a &#124;&#124; b</code> runs `b` only if `$?` is `False`. |
| **Syntax** | `<pipeline> && <pipeline>` · <code>&lt;pipeline&gt; &#124;&#124; &lt;pipeline&gt;</code> |
| **Parameters** | — |
| **Example** | <code>Get-Item C:\missing.txt -ErrorAction SilentlyContinue &#124;&#124; 'not found'</code> |
| **Expected output** | `not found` |
| **Equivalent** | Bash `&&` <code>&#124;&#124;</code>; in 5.1 use `a; if ($?) { b }` |
| **Common errors** | `The token '&&' is not a valid statement separator in this version.` (5.1) · `Test-Path x && …` runs anyway (`Test-Path` succeeds and returns `False`) |
| **Use case** | Short success/failure chains in PowerShell 7 scripts and prompts. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pipeline_chain_operators> |

### $? / $LASTEXITCODE / $Error

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS (automatic variables) |
| **Description** | `$?` is `True`/`False` for the last command; `$LASTEXITCODE` is the integer exit code of the last native program or script `exit`; `$Error` holds recent error records (`$Error[0]` newest). |
| **Syntax** | `$?` · `$LASTEXITCODE` · `$Error[0]` · `exit <Int32>` |
| **Parameters** | PowerShell 7.4+: `$PSNativeCommandUseErrorActionPreference = $true` turns non-zero native exit codes into errors |
| **Example** | `ping.exe -n 1 192.0.2.1 > $null; "$? $LASTEXITCODE"` |
| **Expected output** | `False 1` (example) |
| **Equivalent** | Bash `$?` (integer) and `${PIPESTATUS[@]}` |
| **Common errors** | Testing `$LASTEXITCODE` after a cmdlet (it is not updated) · reading `$?` after another command |
| **Use case** | Scripts that call native tools (`git`, `robocopy`, `ping.exe`) and must react to their exit codes. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables> |

### try / catch / finally and -ErrorAction

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS |
| **Description** | `try`/`catch` handles **terminating** errors; `-ErrorAction Stop` makes a cmdlet's non-terminating error terminating; `finally` always runs. |
| **Syntax** | `try { <cmd> -ErrorAction Stop } catch [<ExceptionType>] { <handler> } finally { <cleanup> }` |
| **Parameters** | `-ErrorAction` (`-ea`): `Continue`, `SilentlyContinue`, `Stop`, `Inquire`, `Ignore` · `$ErrorActionPreference` · `-ErrorVariable name` |
| **Example** | `try { Get-Content C:\nope.txt -ErrorAction Stop } catch { "Failed: $($PSItem.Exception.Message)" }` |
| **Expected output** | `Failed: Cannot find path 'C:\nope.txt' because it does not exist.` |
| **Equivalent** | Bash `if ! cmd; then …; fi` and exit-code checks |
| **Common errors** | `catch` never runs without `-ErrorAction Stop` · `SilentlyContinue` hides problems you needed to see |
| **Use case** | Reliable scripts that log a clear message and exit with a code when an input is missing. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters> |

## Users & Groups

All `*-Local*` cmdlets are in the **`Microsoft.PowerShell.LocalAccounts`** module: **Windows only**, built into Windows PowerShell 5.1 (64-bit) and usable from PowerShell 7 on Windows (fall back to 5.1 or `Import-Module Microsoft.PowerShell.LocalAccounts -UseWindowsPowerShell` if the import fails). Changes need an elevated session.

### Get-LocalUser

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Alias: `glu`. No elevation needed |
| **Description** | Lists local accounts as `LocalUser` objects (`Name`, `Enabled`, `Description`, `SID`, `PasswordLastSet`, `LastLogon`, `AccountExpires`…). |
| **Syntax** | `Get-LocalUser [[-Name] <String[]>]` · `Get-LocalUser -SID <SecurityIdentifier[]>` |
| **Parameters** | `-Name` (wildcards) · `-SID` |
| **Example** | <code>Get-LocalUser &#124; Select-Object Name, Enabled, LastLogon, PasswordLastSet</code> |
| **Expected output** | `Administrator False` · `student True 09-11-2026 …` (example) |
| **Equivalent** | `getent passwd` · `cut -d: -f1 /etc/passwd` |
| **Common errors** | `The term 'Get-LocalUser' is not recognized` (Linux/macOS or 32-bit PowerShell) |
| **Use case** | Auditing local accounts on a workstation or server. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/get-localuser> |

### New-LocalUser

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Alias: `nlu`. **Elevation required** |
| **Description** | Creates a local account. `-Password` accepts only a `SecureString`. Names up to 20 characters, descriptions up to 48. |
| **Syntax** | `New-LocalUser [-Name] <String> -Password <SecureString> [-FullName <String>] [-Description <String>] [-AccountExpires <DateTime>] [-PasswordNeverExpires] [-Disabled]` · `New-LocalUser [-Name] <String> -NoPassword` |
| **Parameters** | `-Password` · `-NoPassword` · `-FullName` · `-Description` · `-AccountExpires` / `-AccountNeverExpires` · `-PasswordNeverExpires` · `-UserMayNotChangePassword` · `-Disabled` |
| **Example** | `New-LocalUser -Name lab-alice -Password (Read-Host -AsSecureString 'Password') -Description 'LAB account'` |
| **Expected output** | `Name Enabled Description` / `lab-alice True LAB account` (example) |
| **Equivalent** | `useradd -m` / `adduser` · `net user NAME /add` |
| **Common errors** | `Cannot convert 'System.String' to 'System.Security.SecureString'` (plain-text password) · `Access denied` (not elevated) · password policy errors |
| **Use case** | Creating a local break-glass or lab account. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/new-localuser> |

### Set-LocalUser / Rename-LocalUser

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Aliases: `slu`, `rnlu`. **Elevation required** |
| **Description** | Changes description, password, expiry and password options; `Rename-LocalUser` changes the name and keeps the SID. |
| **Syntax** | `Set-LocalUser [-Name] <String> [-Description <String>] [-Password <SecureString>] [-AccountExpires <DateTime>] [-AccountNeverExpires] [-PasswordNeverExpires <Boolean>] [-UserMayChangePassword <Boolean>]` |
| **Parameters** | `-PasswordNeverExpires` and `-UserMayChangePassword` take `$true`/`$false` (not switches) · `-WhatIf` |
| **Example** | `Set-LocalUser -Name lab-bob -AccountExpires (Get-Date '2026-12-31')` |
| **Expected output** | No output on success |
| **Equivalent** | `usermod -c`, `chage -E`, `passwd` |
| **Common errors** | Passing `-PasswordNeverExpires` without a value |
| **Use case** | Time-limited contractor accounts. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/set-localuser> |

### Disable-LocalUser / Enable-LocalUser

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Aliases: `dlu`, `elu`. **Elevation required** |
| **Description** | Blocks or re-allows sign-in for an account without deleting it. |
| **Syntax** | `Disable-LocalUser [-Name] <String[]>` · `Enable-LocalUser [-Name] <String[]>` |
| **Parameters** | `-Name` · `-SID` · `-InputObject` (pipeline) · `-WhatIf` |
| **Example** | <code>Get-LocalUser lab-&#42; &#124; Disable-LocalUser -WhatIf</code> |
| **Expected output** | `What if: Performing the operation "Disable local user" on target "lab-alice".` (example) |
| **Equivalent** | `usermod -L -e 1` / `passwd -l` plus expiry |
| **Common errors** | Disabling the only administrator account |
| **Use case** | First step of offboarding: disable, keep for the retention period, then delete. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/disable-localuser> |

### Remove-LocalUser

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Alias: `rlu`. **Elevation required** |
| **Description** | Deletes a local account. The profile folder in `C:\Users` and the user's files are **not** removed. |
| **Syntax** | `Remove-LocalUser [-Name] <String[]> [-WhatIf] [-Confirm]` |
| **Parameters** | `-Name` · `-SID` · `-InputObject` · `-WhatIf` |
| **Example** | `Remove-LocalUser -Name lab-bob -WhatIf` |
| **Expected output** | `What if: Performing the operation "Remove local user" on target "lab-bob".` (example) |
| **Equivalent** | `userdel` (home kept unless `-r`) |
| **Common errors** | Files left owned by an unresolvable SID (take ownership or archive first) |
| **Use case** | Final offboarding step after data has been preserved. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/remove-localuser> |

### Get-LocalGroup / New-LocalGroup

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Aliases: `glg`, `nlg`. `New-LocalGroup` needs elevation |
| **Description** | Lists or creates local groups (`Administrators`, `Users`, `Remote Desktop Users`, custom groups). |
| **Syntax** | `Get-LocalGroup [[-Name] <String[]>]` · `New-LocalGroup [-Name] <String> [-Description <String>]` |
| **Parameters** | `-Name` (wildcards for `Get-`) · `-SID` · `-Description` |
| **Example** | `New-LocalGroup -Name lab-devs -Description 'LAB group'` |
| **Expected output** | `Name Description` / `lab-devs LAB group` (example) |
| **Equivalent** | `getent group` · `groupadd` |
| **Common errors** | Name already exists · not elevated |
| **Use case** | Role groups for shared folders (Day 07). |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/get-localgroup> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/new-localgroup> |

### Add-LocalGroupMember / Remove-LocalGroupMember / Get-LocalGroupMember

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Aliases: `algm`, `rlgm`, `glgm`. Changes need elevation |
| **Description** | Add, remove or list members (local users, local groups, domain or Microsoft accounts) of a local group. |
| **Syntax** | `Add-LocalGroupMember [-Group] <String> [-Member] <LocalPrincipal[]>` · `Remove-LocalGroupMember [-Group] <String> [-Member] <LocalPrincipal[]>` · `Get-LocalGroupMember [-Group] <String>` |
| **Parameters** | `-Group` · `-Member` (names or SIDs) · `-WhatIf` |
| **Example** | `Get-LocalGroupMember -Group Administrators` |
| **Expected output** | `ObjectClass Name PrincipalSource` / `User WIN11-LAB\student Local` (example) |
| **Equivalent** | `usermod -aG` / `gpasswd -a` / `gpasswd -d` / `getent group` |
| **Common errors** | `is already a member of group` · listing can fail when the group contains an unresolvable (orphaned) SID; `net localgroup NAME` still works |
| **Use case** | Auditing who has local administrator rights. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/add-localgroupmember> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/get-localgroupmember> |

### whoami /groups · net user · net localgroup

| Field | Detail |
|---|---|
| **Version / OS** | Windows only (external programs, every PowerShell version) |
| **Description** | `whoami /user /groups /priv` shows your SID, group memberships (including integrity level) and privileges; `net user` and `net localgroup` show and change accounts and groups. |
| **Syntax** | `whoami [/user] [/groups] [/priv]` · `net user [NAME]` · `net localgroup [GROUP]` · `net accounts` |
| **Parameters** | `/fo csv` CSV output for `whoami` · `net user NAME /active:no` disable |
| **Example** | <code>whoami /groups /fo csv &#124; ConvertFrom-Csv</code> |
| **Expected output** | Objects with `Group Name`, `Type`, `SID`, `Attributes` (example) |
| **Equivalent** | `id` · `sudo -l` · `getent` · `chage -l` |
| **Common errors** | Passwords typed as `net user NAME P@ss /add` end up in history (use `*` to be prompted) |
| **Use case** | Quick checks on systems without the LocalAccounts module, and checking whether a session is elevated. |
| **Docs** | <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/whoami> · <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/net-user> |

## Permissions

`Get-Acl` and `Set-Acl` are in **Microsoft.PowerShell.Security** and are **Windows only** in PowerShell 7 (the documentation states "This cmdlet is only available on the Windows platform"). `icacls.exe` and `takeown.exe` are native Windows tools and behave the same from 5.1 and 7. Back up ACLs with `icacls /save` before every change.

### Get-Acl

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. FileSystem and Registry providers. No elevation needed except for `-Audit` |
| **Description** | Returns the security descriptor of a file, folder or registry key: `Owner`, `Group`, `Access` (DACL as `FileSystemAccessRule` objects), `AccessToString`, `Sddl`, `AreAccessRulesProtected`, and `Audit` (SACL) with `-Audit`. |
| **Syntax** | `Get-Acl [[-Path] <String[]>] [-Audit] [-Filter <String>] [-Include <String[]>] [-Exclude <String[]>]` · `Get-Acl -LiteralPath <String[]>` · `Get-Acl -InputObject <PSObject>` |
| **Parameters** | `-Path` / `-LiteralPath` · `-Audit` (SACL) · `-Filter` / `-Include` / `-Exclude` · 5.1 only: `-AllCentralAccessPolicies`, `-UseTransaction` |
| **Example** | <code>(Get-Acl C:\Data).Access &#124; Format-Table IdentityReference, FileSystemRights, AccessControlType, IsInherited</code> |
| **Expected output** | `BUILTIN\Administrators Allow FullControl True` · `WIN11-LAB\Team Allow Modify, Synchronize False` (example) |
| **Equivalent** | `ls -l` · `stat` · `getfacl` |
| **Common errors** | `The term 'Get-Acl' is not recognized` (PowerShell on Linux/macOS) · `Attempted to perform an unauthorized operation` with `-Audit` when not elevated |
| **Use case** | Auditing who can write to a share or a service binary; saving `.Sddl` baselines. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-acl> |

### Set-Acl

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Rights to change the DACL (`WRITE_DAC`) required; owner/SACL changes need elevation |
| **Description** | Applies a (modified) security descriptor to items. Pattern: `Get-Acl` → modify in memory → `Set-Acl`. Supports `-WhatIf`/`-Confirm`. |
| **Syntax** | `Set-Acl [-Path] <String[]> [-AclObject] <Object> [-ClearCentralAccessPolicy] [-PassThru] [-Filter <String>] [-Include <String[]>] [-Exclude <String[]>] [-WhatIf] [-Confirm]` · `Set-Acl -LiteralPath ...` · `Set-Acl [-InputObject] <PSObject> ...` |
| **Parameters** | `-AclObject` · `-PassThru` · `-WhatIf` · `-Confirm` · `-ClearCentralAccessPolicy` |
| **Example** | <code>Get-Acl C:\Template &#124; Set-Acl -Path C:\Data</code> · `Set-Acl -Path C:\Data -AclObject $acl -WhatIf` |
| **Expected output** | No output (or the descriptor with `-PassThru`); `What if: Performing the operation "Set-Acl" on target "C:\Data".` |
| **Equivalent** | `chmod` · `setfacl -m` · `icacls /grant` |
| **Common errors** | `The security identifier is not allowed to be the owner of this object` (5.1; use `icacls` or elevate) · `Attempted to perform an unauthorized operation` (not elevated / no WRITE_DAC) |
| **Use case** | Scripted, reviewable ACL changes with `-WhatIf` first. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-acl> |

### FileSystemAccessRule / SetAccessRuleProtection

| Field | Detail |
|---|---|
| **Version / OS** | .NET classes, usable from 5.1 and 7.x on **Windows** (`::new()` needs PowerShell 5.0+) |
| **Description** | Build an ACE and edit the in-memory ACL before `Set-Acl`. Methods: `AddAccessRule` (merge), `SetAccessRule` (replace that identity's Allow rules), `RemoveAccessRule`, `RemoveAccessRuleAll`, `PurgeAccessRules`, `SetAccessRuleProtection(isProtected, preserveInheritance)` (disable inheritance, keep or drop inherited ACEs), `SetOwner`. |
| **Syntax** | `[System.Security.AccessControl.FileSystemAccessRule]::new(identity, rights, inheritanceFlags, propagationFlags, 'Allow'/'Deny')` |
| **Parameters** | Rights: `FullControl`, `Modify`, `ReadAndExecute`, `Read`, `Write`… · InheritanceFlags: `None`, `ContainerInherit`, `ObjectInherit` · PropagationFlags: `None`, `InheritOnly`, `NoPropagateInherit` |
| **Example** | `$acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new('Team','Modify','ContainerInherit,ObjectInherit','None','Allow'))` · `$acl.SetAccessRuleProtection($true, $true)` |
| **Expected output** | No output; changes appear after `Set-Acl` (`IsInherited False`, `AreAccessRulesProtected True`) |
| **Equivalent** | `setfacl -m` / `setfacl -d -m` (default ACL) · `icacls /grant "Team:(OI)(CI)M"` · `icacls /inheritance:d` |
| **Common errors** | `SetAccessRule` unexpectedly removing a user's other rights · forgetting `Set-Acl` (nothing changes on disk) · removing inherited ACEs before granting explicit access |
| **Use case** | Granting a group inheritable Modify on a project folder. |
| **Docs** | <https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemaccessrule> · <https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.objectsecurity.setaccessruleprotection> |

### icacls

| Field | Detail |
|---|---|
| **Version / OS** | Windows (native `icacls.exe`), any PowerShell or cmd. Elevation depends on the object |
| **Description** | Displays and modifies NTFS DACLs, changes inheritance and owner, and **saves/restores** DACLs for whole trees. `(I)` marks inherited ACEs. |
| **Syntax** | <code>icacls name [/grant[:r] Sid:perm] [/deny Sid:perm] [/remove[:g&#124;:d] Sid] [/inheritance:e&#124;d&#124;r] [/setowner user] [/reset] [/t] [/c] [/q]</code> · `icacls name /save file /t /c` · `icacls directory /restore file` |
| **Parameters** | Rights `F M RX R W D N` · inheritance `(OI)(CI)(IO)(NP)` · `/grant` add · `/grant:r` replace explicit · `/remove:g` grants · `/inheritance:d` copy · `:r` remove · `:e` enable · `/t` recurse · `/c` continue · `/findsid` |
| **Example** | `icacls D:\Shares\HR /save C:\Backup\hr-acl.txt /t /c` · `icacls D:\Shares\HR /grant "HR-Staff:(OI)(CI)M"` |
| **Expected output** | `D:\Shares\HR BUILTIN\Administrators:(OI)(CI)(F)` … `Successfully processed 1 files; Failed processing 0 files` (example) |
| **Equivalent** | `chmod` · `setfacl` · `getfacl -R` / `setfacl --restore` |
| **Common errors** | Unquoted `(OI)(CI)` in PowerShell (`The term 'OI' is not recognized`) · `/restore` run on the folder instead of its parent · `/inheritance:r` before granting explicit access (lock-out) |
| **Use case** | Ticket-ready, reversible permission changes on file shares. |
| **Docs** | <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/icacls> |

### takeown

| Field | Detail |
|---|---|
| **Version / OS** | Windows (native `takeown.exe`). Usually needs an elevated prompt |
| **Description** | Makes the current user (or, with `/a`, the Administrators group) the owner of files or folders, so their DACL can be repaired. Ownership alone grants no file access. |
| **Syntax** | <code>takeown [/s computer [/u user [/p [password]]]] /f filename [/a] [/r [/d {Y&#124;N}]]</code> |
| **Parameters** | `/f` target (wildcard `*` allowed) · `/a` give to Administrators · `/r` recursive · `/d Y` answer the prompt for directories you cannot list |
| **Example** | `takeown /f D:\Profiles\jdoe /a /r /d y` followed by `icacls D:\Profiles\jdoe /reset /t /c` |
| **Expected output** | `SUCCESS: The file (or folder): "D:\Profiles\jdoe" now owned by the administrators group.` (example) |
| **Equivalent** | `sudo chown -R root: DIR` |
| **Common errors** | Expecting access immediately after `takeown` (grant it with `icacls`) · running non-elevated |
| **Use case** | Recovering a folder whose DACL locks out administrators. |
| **Docs** | <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/takeown> |

## Processes & Services

`Get-Process`, `Stop-Process`, `Start-Process` and `Wait-Process` work in 5.1 and 7 on every OS. The **service** cmdlets, `Get-CimInstance`, `Get-WinEvent` and `Get-Counter` are **Windows only**. Changing services requires an elevated session.

### Get-Process

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `gps` (all), `ps` (Windows only) |
| **Description** | Returns `System.Diagnostics.Process` objects. Default columns: `NPM(K)`, `PM(M)`, `WS(M)` (working set ≈ RSS), `CPU(s)` (**cumulative processor seconds**, not %), `Id`, `SI` (session). PowerShell 7.x adds `Parent` and `CommandLine` properties. |
| **Syntax** | `Get-Process [[-Name] <String[]>] [-Module] [-FileVersionInfo]` · `Get-Process -Id <Int32[]> [-IncludeUserName]` |
| **Parameters** | `-Name` (wildcards, no `.exe`) · `-Id` · `-IncludeUserName` (elevation required on Windows) · `-Module` · `-FileVersionInfo` (others' processes need elevation) |
| **Example** | <code>Get-Process &#124; Sort-Object CPU -Descending &#124; Select-Object -First 5 Name, Id, CPU, WS</code> |
| **Expected output** | `MsMpEng 3828 402.17 327…` (example) |
| **Equivalent** | `ps -eo pid,user,%cpu,%mem,cmd` · `top -b -n 1` |
| **Common errors** | `Cannot find a process with the name "x.exe"` (drop `.exe`) · `The 'IncludeUserName' parameter requires elevated user rights` · treating `CPU` as a percentage |
| **Use case** | Finding the largest memory consumer on a terminal server. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-process> |

### Stop-Process

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS. Aliases: `spps` (all), `kill` (Windows only) |
| **Description** | Ends processes immediately (`Process.Kill` / TerminateProcess — no clean-up, like `SIGKILL`). Prompts before stopping a process you do not own unless `-Force`. Asynchronous: use `Wait-Process` to confirm. |
| **Syntax** | `Stop-Process [-Id] <Int32[]> [-PassThru] [-Force] [-WhatIf] [-Confirm]` · `Stop-Process -Name <String[]> …` · `Stop-Process [-InputObject] <Process[]> …` |
| **Parameters** | `-Id` · `-Name` · `-InputObject` (pipeline) · `-Force` · `-PassThru` · `-WhatIf` · `-Confirm` |
| **Example** | `Stop-Process -Id 8744 -WhatIf` |
| **Expected output** | `What if: Performing the operation "Stop-Process" on target "powershell (8744)".` |
| **Equivalent** | `kill -KILL PID` · `pkill` · `taskkill /F /PID n` |
| **Common errors** | `Access is denied` (not elevated / protected process) · `Stop-Process -Name svchost` stopping many services |
| **Use case** | Ending one hung application instance after collecting its command line. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/stop-process> |

### Start-Process / Wait-Process

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS (`-Verb`, `-WindowStyle`, `-Credential` with profile options are Windows-oriented). Aliases: `saps`, `start` (Windows only) |
| **Description** | `Start-Process` starts a program, optionally elevated, hidden or waiting; `-PassThru` returns the process object. `Wait-Process` waits until processes exit. |
| **Syntax** | `Start-Process [-FilePath] <String> [[-ArgumentList] <String[]>] [-WorkingDirectory <String>] [-PassThru] [-Wait] [-WindowStyle <ProcessWindowStyle>] [-NoNewWindow] [-Verb <String>]` · <code>Wait-Process [-Name] &lt;String[]&gt; &#124; -Id &lt;Int32[]&gt; [[-Timeout] &lt;Int32&gt;]</code> |
| **Parameters** | `-ArgumentList` · `-PassThru` · `-Wait` · `-WindowStyle Hidden/Minimized` · `-NoNewWindow` · `-RedirectStandardOutput` · `-Verb RunAs` (UAC elevation) · `Wait-Process -Timeout` |
| **Example** | `$p = Start-Process notepad.exe -PassThru; Wait-Process -Id $p.Id -Timeout 60` |
| **Expected output** | No output; `Wait-Process` returns when Notepad closes or errors after 60 s |
| **Equivalent** | `cmd &` · `nohup` · `wait PID` · `sudo` |
| **Common errors** | Arguments with spaces not quoted inside `-ArgumentList` · `-Verb RunAs` with `-NoNewWindow` (not supported together) |
| **Use case** | Launching an installer elevated and waiting for it to finish in a deployment script. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/wait-process> |

### Get-CimInstance Win32_Process

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (CIM/WMI) |
| **Description** | WMI view of processes with `ProcessId`, `ParentProcessId`, `CommandLine`, `ExecutablePath`, `CreationDate` and the `GetOwner()` method — the investigator's process list, and the way to get parent/command line in 5.1. |
| **Syntax** | `Get-CimInstance -ClassName Win32_Process [-Filter <String>] [-Property <String[]>]` · <code>… &#124; Invoke-CimMethod -MethodName GetOwner</code> |
| **Parameters** | `-Filter` (WQL: `"Name = 'powershell.exe'"`, `"CommandLine LIKE '%lab08%'"`) · `-Property` · `-ComputerName`/`-CimSession` for remote |
| **Example** | <code>Get-CimInstance Win32_Process -Filter "ProcessId = $PID" &#124; Select-Object ProcessId, ParentProcessId, CommandLine</code> |
| **Expected output** | `7760 9124 "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"` (example) |
| **Equivalent** | `ps -o pid,ppid,user,cmd -p PID` · `/proc/PID/cmdline` |
| **Common errors** | Empty `CommandLine` for other users' processes when not elevated · WQL uses `%` not `*` as wildcard |
| **Use case** | Spotting `WINWORD.EXE` → `powershell.exe -enc` parent–child chains. |
| **Docs** | <https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process> |

### Get-Service

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Alias: `gsv`. No elevation needed to read |
| **Description** | Lists services as `ServiceController` objects: `Name`, `DisplayName`, `Status`, `StartType`, dependencies. PowerShell 7 (6.0+) adds `UserName`, `Description`, `BinaryPathName`, `StartupType`, `DelayedAutoStart` and removes `-ComputerName`. |
| **Syntax** | `Get-Service [[-Name] <String[]>] [-DisplayName <String[]>] [-DependentServices] [-RequiredServices] [-Include/-Exclude <String[]>]` |
| **Parameters** | `-Name` (wildcards) · `-DisplayName` · `-DependentServices` · `-RequiredServices` · `-ComputerName` (5.1 only) |
| **Example** | <code>Get-Service &#124; Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }</code> |
| **Expected output** | `Name Status StartType` / `edgeupdate Stopped Automatic` (example) |
| **Equivalent** | `systemctl status` · `systemctl list-units --type=service` · `sc.exe query` |
| **Common errors** | Using the display name with `-Name` · `Get-Service` not found in PowerShell on Linux |
| **Use case** | Morning check for automatic services that are not running. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-service> |

### Start-Service / Stop-Service / Restart-Service

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. Aliases: `sasv`, `spsv`. **Elevation required** |
| **Description** | Control services through the Service Control Manager. `Stop-Service`/`Restart-Service` refuse when dependent services are running unless `-Force` (which stops the dependants too). |
| **Syntax** | `Start-Service [-Name] <String[]> [-PassThru] [-WhatIf] [-Confirm]` · `Stop-Service [-Name] <String[]> [-Force] [-NoWait] [-PassThru] [-WhatIf]` · `Restart-Service [-Name] <String[]> [-Force] [-PassThru] [-WhatIf]` |
| **Parameters** | `-Name` / `-DisplayName` / `-InputObject` · `-Force` · `-NoWait` (Stop-Service) · `-PassThru` · `-WhatIf` · `-Confirm` |
| **Example** | `Restart-Service -Name Spooler -WhatIf` |
| **Expected output** | `What if: Performing the operation "Restart-Service" on target "Print Spooler (Spooler)".` |
| **Equivalent** | `sudo systemctl start/stop/restart NAME` |
| **Common errors** | `Cannot open Spooler service on computer '.'` (not elevated) · `Cannot stop service … because it has dependent services` · service disabled |
| **Use case** | Clearing a hung print queue after confirming with users. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/restart-service> · <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/stop-service> |

### Set-Service

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**. **Elevation required** |
| **Description** | Changes start type, display name, description or status of a service. PowerShell 7 adds `AutomaticDelayedStart`, `-Credential`, `-SecurityDescriptorSddl` and `-Force`. |
| **Syntax** | <code>Set-Service [-Name] &lt;String&gt; [-StartupType &lt;Automatic&#124;Manual&#124;Disabled&#124;AutomaticDelayedStart&gt;] [-Status &lt;Running&#124;Stopped&#124;Paused&gt;] [-Description &lt;String&gt;] [-PassThru] [-WhatIf]</code> |
| **Parameters** | `-StartupType` (aliases `StartMode`, `SM`, `ST`) · `-Status` · `-DisplayName` · `-Description` · `-Credential` (7.x) · `-PassThru` · `-WhatIf` |
| **Example** | `Set-Service -Name BITS -StartupType Manual -WhatIf` |
| **Expected output** | `What if: Performing the operation "Set-Service" on target "Background Intelligent Transfer Service (BITS)".` |
| **Equivalent** | `sudo systemctl enable/disable NAME` · `sc.exe config NAME start= demand` |
| **Common errors** | `AutomaticDelayedStart` in 5.1 (not a valid value; use `sc.exe config NAME start= delayed-auto`) · disabling a service other services need |
| **Use case** | Setting an unused service to Manual as part of hardening, with a change record. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-service> |

### sc.exe · tasklist · taskkill

| Field | Detail |
|---|---|
| **Version / OS** | Native Windows tools, usable from cmd, 5.1 and 7. In 5.1 always type **`sc.exe`** (`sc` = `Set-Content`) |
| **Description** | `sc.exe` queries and configures the SCM (config, failure actions, security descriptors); `tasklist` lists processes (`/V` verbose, `/SVC` hosted services); `taskkill` ends processes (`/F` force, `/T` tree). |
| **Syntax** | <code>sc.exe query&#124;qc&#124;qfailure&#124;sdshow NAME</code> · <code>sc.exe config NAME start= auto&#124;demand&#124;disabled&#124;delayed-auto</code> · `tasklist [/V] [/SVC] [/FI "filter"]` · <code>taskkill /PID n &#124; /IM name [/F] [/T]</code> |
| **Parameters** | `start=` (space after `=` is required) · `failure NAME reset= SEC actions= restart/MS` · `/FI "IMAGENAME eq x.exe"` · `/F` · `/T` |
| **Example** | `tasklist /SVC /FI "IMAGENAME eq svchost.exe"` |
| **Expected output** | `svchost.exe 1208 RpcEptMapper, RpcSs` (example) |
| **Equivalent** | `systemctl cat/show` · `ps` · `kill` |
| **Common errors** | `sc query x` in 5.1 creating a file named `query` · `start=demand` without the space |
| **Use case** | Finding which `svchost.exe` hosts a misbehaving service before restarting only that service. |
| **Docs** | <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-query> · <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/tasklist> · <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/taskkill> |

## Storage

`Get-PSDrive`, `System.IO.DriveInfo` and `Get-ChildItem | Measure-Object` work in 5.1 and 7 on every OS. The **Storage module** cmdlets (`Get-Disk`, `Get-Partition`, `Get-Volume`, `Initialize-Disk`, `New-Partition`, `Format-Volume`, `Mount-DiskImage`, `Repair-Volume`…) and `Win32_LogicalDisk` are **Windows only** (5.1 and 7). Changing disks, partitions and volumes requires an elevated session.

### Get-PSDrive

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS (on Linux the file system drive is `/`). Alias: `gdr` |
| **Description** | Lists PowerShell drives; for FileSystem drives the `Used` and `Free` properties are bytes (shown as `Used (GB)` / `Free (GB)`). Also lists `HKLM:`, `Env:`, `Cert:` and other provider drives. |
| **Syntax** | `Get-PSDrive [[-Name] <String[]>] [-PSProvider <String[]>] [-Scope <String>]` |
| **Parameters** | `-PSProvider FileSystem` disk drives only · `-Name C` |
| **Example** | <code>Get-PSDrive -PSProvider FileSystem &#124; Select-Object Name, @{ n = 'FreeGB'; e = { [math]::Round($_.Free / 1GB, 1) } }</code> |
| **Expected output** | `C  162.41  74.12  FileSystem  C:\` (example) |
| **Equivalent** | `df -h` |
| **Common errors** | Network drives mapped in another session (elevated vs normal) not visible · expecting filesystem type (use `Get-Volume`) |
| **Use case** | Quick free-space check that works in any PowerShell, including on Linux. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-psdrive> |

### Get-Volume

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (Storage module, Windows 8 / Server 2012+) |
| **Description** | Returns volumes with `DriveLetter`, `FriendlyName` (label), `FileSystemType`, `DriveType`, `HealthStatus`, `SizeRemaining` and `Size`. Pipes into `Get-Partition` and `Get-Disk`. |
| **Syntax** | `Get-Volume [[-DriveLetter] <Char[]>]` · `Get-Volume -FileSystemLabel <String[]>` · `Get-Volume -FilePath <String>` |
| **Parameters** | `-DriveLetter C` (no colon) · `-FilePath` volume holding a path · `-FileSystemLabel` |
| **Example** | <code>Get-Volume -DriveLetter C &#124; Get-Partition &#124; Get-Disk</code> |
| **Expected output** | `C  Windows  NTFS  Fixed  Healthy  OK  74.12 GB  236.53 GB` (example) |
| **Equivalent** | `df -hT` · `findmnt -T PATH` |
| **Common errors** | `The term 'Get-Volume' is not recognized` on Linux/macOS · passing `C:` instead of `C` |
| **Use case** | Checking label, filesystem and health of every volume before a migration. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/storage/get-volume> |

### Get-Disk / Get-Partition / Get-PhysicalDisk

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (Storage module). Reading usually works non-elevated; if *Access denied*, use an elevated window |
| **Description** | `Get-Disk`: number, model, size, `PartitionStyle` (GPT/MBR/**RAW** = uninitialised), health. `Get-Partition`: disk/partition numbers, letter, offset, size, type (System, Reserved, Basic, Recovery), `AccessPaths`. `Get-PhysicalDisk`: `MediaType` (SSD/HDD), `BusType`, health. |
| **Syntax** | `Get-Disk [[-Number] <UInt32[]>]` · `Get-Partition [-DiskNumber <UInt32[]>] [-DriveLetter <Char[]>]` · `Get-PhysicalDisk` |
| **Parameters** | `-Number` · `-DiskNumber` · `-DriveLetter` |
| **Example** | <code>Get-Disk &#124; Where-Object PartitionStyle -eq 'RAW'</code> |
| **Expected output** | `0  Samsung SSD 980 1TB  …  Healthy  Online  931.51 GB  GPT` (example) |
| **Equivalent** | `lsblk` · `sudo fdisk -l` · `lsblk -d -o NAME,ROTA,TRAN,MODEL` |
| **Common errors** | Confusing disk numbers between `Get-Disk` and Disk Management after adding disks — always re-query |
| **Use case** | Finding the new, empty disk before initialising it. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/storage/get-disk> · <https://learn.microsoft.com/en-us/powershell/module/storage/get-partition> |

### Win32_LogicalDisk / System.IO.DriveInfo

| Field | Detail |
|---|---|
| **Version / OS** | `Win32_LogicalDisk` via `Get-CimInstance`: 5.1, 7.x on Windows (remote-capable). `[System.IO.DriveInfo]::GetDrives()`: 5.1, 7.x on all OS |
| **Description** | Classic WMI view of drives (`DeviceID`, `VolumeName`, `Size`, `FreeSpace`, `DriveType` 2/3/4/5) and the .NET drive list (`TotalSize`, `TotalFreeSpace`, `AvailableFreeSpace`, `DriveFormat`). |
| **Syntax** | `Get-CimInstance -ClassName Win32_LogicalDisk [-Filter <String>] [-ComputerName <String[]>]` · `[System.IO.DriveInfo]::GetDrives()` |
| **Parameters** | `-Filter "DriveType=3"` local fixed disks · `-ComputerName` / `-CimSession` remote |
| **Example** | `Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ComputerName SRV01` |
| **Expected output** | `C:  Windows  236.5  74.1` (example, after a calculated-property `Select-Object`) |
| **Equivalent** | `df -h` · `ssh host df -h` |
| **Common errors** | Dividing by 1GB without rounding · `FreeSpace` vs `AvailableFreeSpace` under quotas |
| **Use case** | Free-space report across many servers (Day 26); the course's `Disk-Monitor.ps1` uses `DriveInfo`. |
| **Docs** | <https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-logicaldisk> · <https://learn.microsoft.com/en-us/dotnet/api/system.io.driveinfo> |

### Folder size: Get-ChildItem + Measure-Object

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · all OS |
| **Description** | PowerShell has no `du` cmdlet; sum `Length` of all files. `Length` is the **logical** size (like `du --apparent-size`); compressed, sparse and cloud placeholder files report their full length. |
| **Syntax** | <code>Get-ChildItem -Path &lt;String&gt; -Recurse -File -Force -ErrorAction SilentlyContinue &#124; Measure-Object -Property Length -Sum</code> |
| **Parameters** | `-File` files only · `-Force` hidden/system · `-ErrorAction SilentlyContinue` skip *Access denied* (incomplete total) · `-Maximum` largest file |
| **Example** | <code>Get-ChildItem C:\Logs -Recurse -File &#124; Sort-Object Length -Descending &#124; Select-Object -First 10 FullName, Length</code> |
| **Expected output** | `Count 200  Sum 1692  Maximum 10` (example) |
| **Equivalent** | `du -sh` · <code>du -xh -d 1 &#124; sort -rh</code> · `find -size +100M` |
| **Common errors** | Forgetting `-Force` · counting junction targets twice in 5.1 · very slow on millions of files |
| **Use case** | Finding the share or profile folder responsible for a full data volume. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/measure-object> |

### Initialize-Disk / New-Partition / Format-Volume / Resize-Partition

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** · **elevated** · **destructive** |
| **Description** | Prepare a RAW disk (partition table), create a partition with a letter, create a filesystem, and grow a partition into free space. |
| **Syntax** | <code>Initialize-Disk -Number &lt;UInt32&gt; [-PartitionStyle GPT&#124;MBR]</code> · <code>New-Partition -DiskNumber &lt;UInt32&gt; (-Size &lt;UInt64&gt; &#124; -UseMaximumSize) [-AssignDriveLetter]</code> · `Format-Volume [-DriveLetter <Char>] -FileSystem NTFS -NewFileSystemLabel <String>` · `Resize-Partition -DriveLetter <Char> -Size <UInt64>` |
| **Parameters** | `-PartitionStyle GPT` · `-UseMaximumSize` · `-AssignDriveLetter` · `-FileSystem NTFS/ReFS/exFAT/FAT32` · `-Confirm:$false` (scripts only) · `Get-PartitionSupportedSize` for `SizeMax` |
| **Example** | <code>New-Partition -DiskNumber 2 -UseMaximumSize -AssignDriveLetter &#124; Format-Volume -FileSystem NTFS -NewFileSystemLabel LAB09</code> |
| **Expected output** | Volume object: `R  LAB09  NTFS  Fixed  Healthy  OK  …` (example) |
| **Equivalent** | `parted`/`fdisk` · `mkfs.ext4` · `growpart` + `resize2fs` / `lvextend -r` |
| **Common errors** | Targeting the wrong disk number · *The disk has not been initialized* (run `Initialize-Disk`) · *Access denied* (not elevated) |
| **Use case** | Preparing a new data disk on a VM; practising on a VHDX file. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/storage/initialize-disk> · <https://learn.microsoft.com/en-us/powershell/module/storage/new-partition> · <https://learn.microsoft.com/en-us/powershell/module/storage/format-volume> · <https://learn.microsoft.com/en-us/powershell/module/storage/resize-partition> |

### Mount-DiskImage / Dismount-DiskImage

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only**; VHD/VHDX need elevation (ISO mounting does not) |
| **Description** | Attaches or detaches ISO, VHD and VHDX files. Create a practice VHDX with `diskpart` (`create vdisk file=… maximum=256 type=expandable`) or *Settings → Storage → Disks & volumes → Create VHD*; `New-VHD` needs the Hyper-V module. |
| **Syntax** | `Mount-DiskImage -ImagePath <String[]>` · `Dismount-DiskImage -ImagePath <String[]>` · <code>Get-DiskImage -ImagePath &lt;String&gt; &#124; Get-Disk</code> |
| **Parameters** | `-ImagePath` full path · `-Access ReadOnly` |
| **Example** | `Mount-DiskImage -ImagePath C:\lab09\lab09.vhdx` |
| **Expected output** | `Attached : True  ImagePath : C:\lab09\lab09.vhdx  …` (example) |
| **Equivalent** | `losetup -f --show FILE` · `mount -o loop` |
| **Common errors** | Relative paths (use full paths) · deleting the file while it is attached |
| **Use case** | Safe practice disk for partitioning and formatting labs. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/storage/mount-diskimage> |

### Repair-Volume / chkdsk / Optimize-Volume

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** · **elevated** |
| **Description** | `Repair-Volume -Scan` scans NTFS online; `-SpotFix` fixes logged problems with a brief dismount; `-OfflineScanAndFix` takes the volume offline. `chkdsk X: /scan` is the native online scan. `Optimize-Volume -Analyze` reports fragmentation; SSDs get TRIM (`-ReTrim`). |
| **Syntax** | <code>Repair-Volume -DriveLetter &lt;Char&gt; (-Scan &#124; -SpotFix &#124; -OfflineScanAndFix)</code> · `chkdsk C: /scan` · `Optimize-Volume -DriveLetter C -Analyze -Verbose` |
| **Parameters** | `-Scan` · `-SpotFix` · `-OfflineScanAndFix` · `chkdsk /f` (fix, exclusive access) |
| **Example** | `Repair-Volume -DriveLetter D -Scan` |
| **Expected output** | `NoErrorsFound` (example) |
| **Equivalent** | `e2fsck -n` (unmounted) · `smartctl -H` (disk health) |
| **Common errors** | Running `chkdsk /f` on evidence (changes data) · interrupting a repair |
| **Use case** | Checking a volume after storage errors appear in the System log. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/storage/repair-volume> · <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/chkdsk> |

## Packages & Software

`winget` is a native Windows tool (Windows 10 1809+ / 11, part of App Installer) and works the same from 5.1, 7 and cmd. The registry inventory, `Get-HotFix` and the DISM feature cmdlets are **Windows only**. PSResourceGet is **built into PowerShell 7.4+** and can be installed on 5.1; PowerShellGet works in both (5.1 ships the old 1.0.0.1).

### winget search / show

| Field | Detail |
|---|---|
| **Version / OS** | Windows 10 1809+ / 11 (App Installer) · from any shell |
| **Description** | Search the `winget` and `msstore` sources; `show` prints the manifest including publisher, license, installer type, **installer URL and SHA-256**. |
| **Syntax** | `winget search <query> [--id <id>] [--source <source>] [-e]` · `winget show --id <id> [-e] [--versions]` |
| **Parameters** | `--id` · `-e` (`--exact`) · `--source winget` · `--versions` |
| **Example** | `winget show --id Git.Git -e` |
| **Expected output** | `Found Git [Git.Git]` / `Installer SHA256: …` (example) |
| **Equivalent** | `apt search` · `apt show` · `apt policy` |
| **Common errors** | `Failed when searching source: msstore` (use `--source winget`) · ambiguous free-text queries |
| **Use case** | Recording the exact package ID and installer hash in a change ticket. |
| **Docs** | <https://learn.microsoft.com/en-us/windows/package-manager/winget/search> · <https://learn.microsoft.com/en-us/windows/package-manager/winget/show> |

### winget install / upgrade / uninstall

| Field | Detail |
|---|---|
| **Version / OS** | Windows 10 1809+ / 11 · machine-wide installers trigger UAC |
| **Description** | Downloads the vendor installer, verifies its SHA-256 against the manifest, installs silently; `upgrade` with no arguments lists available upgrades. Exit code 0 on success, HRESULT-style codes (for example `0x8A150014` no package found) on failure. |
| **Syntax** | <code>winget install --id &lt;id&gt; [-e] [--version &lt;v&gt;] [--scope user&#124;machine] [--source &lt;s&gt;] [--silent] [--accept-package-agreements] [--accept-source-agreements]</code> · <code>winget upgrade [--id &lt;id&gt; -e &#124; --all] [--include-unknown]</code> · `winget uninstall --id <id> -e` |
| **Parameters** | `--id … -e` exact · `--source winget` · `--scope` · `--silent` · `--all` · `--include-unknown` |
| **Example** | `winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements` |
| **Expected output** | `Successfully verified installer hash` / `Successfully installed` (example) |
| **Equivalent** | `apt install` · `apt upgrade` · `apt remove` |
| **Common errors** | `No package found matching input criteria.` · `Installer hash does not match` (do not override) · `winget` not recognised (update App Installer) |
| **Use case** | Scripted workstation builds and monthly application updates. |
| **Docs** | <https://learn.microsoft.com/en-us/windows/package-manager/winget/install> · <https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade> · <https://learn.microsoft.com/en-us/windows/package-manager/winget/uninstall> |

### winget list / export / import / pin

| Field | Detail |
|---|---|
| **Version / OS** | Windows 10 1809+ / 11 · `pin` needs winget 1.5+ |
| **Description** | `list` shows installed apps (also those not installed by winget); `export`/`import` save and restore an app list as JSON; `pin` prevents upgrades of a package. |
| **Syntax** | `winget list [--id <id> -e]` · `winget export -o <file.json>` · `winget import -i <file.json>` · `winget pin add --id <id>` · `winget pin list` · `winget pin remove --id <id>` |
| **Parameters** | `-o` output file · `-i` import file · `--accept-package-agreements` |
| **Example** | `winget export -o $HOME\winget-apps.json` |
| **Expected output** | `Exported package(s) to: C:\Users\student\winget-apps.json` (example) |
| **Equivalent** | <code>apt-mark showmanual &gt; list</code> · `apt-mark hold` |
| **Common errors** | Expecting `list` to match the registry inventory exactly · forgotten pins |
| **Use case** | Rebuilding a role-based workstation in minutes. |
| **Docs** | <https://learn.microsoft.com/en-us/windows/package-manager/winget/export> · <https://learn.microsoft.com/en-us/windows/package-manager/winget/pinning> |

### Uninstall registry keys (software inventory)

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** · no admin needed |
| **Description** | The data behind *Installed apps*. Three locations: 64-bit machine-wide, 32-bit (`WOW6432Node`) and per-user (`HKCU`). Values: `DisplayName`, `DisplayVersion`, `Publisher`, `InstallDate`, `UninstallString`, `EstimatedSize` (KB), `SystemComponent`. **Use instead of `Win32_Product`**, whose enumeration triggers MSI consistency checks and repairs. |
| **Syntax** | <code>Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\&#42;', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\&#42;', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\&#42;' -ErrorAction SilentlyContinue</code> |
| **Parameters** | Filter with `Where-Object { $_.DisplayName -and -not $_.SystemComponent }` |
| **Example** | <code>… &#124; Select-Object DisplayName, DisplayVersion, Publisher &#124; Export-Csv inventory.csv -NoTypeInformation</code> |
| **Expected output** | `Git  2.47.1  The Git Development Community` (example) |
| **Equivalent** | `dpkg -l` · `dpkg-query -W` · `rpm -qa` |
| **Common errors** | Reading only one of the three keys · `Win32_Product` side effects |
| **Use case** | Vulnerability and licence audits across many PCs (with `Invoke-Command`, Day 26). |
| **Docs** | <https://learn.microsoft.com/en-us/windows/win32/msi/uninstall-registry-key> |

### Get-Package (PackageManagement)

| Field | Detail |
|---|---|
| **Version / OS** | 5.1 (Windows) with `msi` and `Programs` providers · 7.x: only NuGet/PowerShellGet providers |
| **Description** | Lists installed software known to PackageManagement providers: MSI products (without `Win32_Product` side effects), Programs (Uninstall entries) and PowerShell modules. |
| **Syntax** | `Get-Package [[-Name] <String[]>] [-ProviderName <String[]>]` |
| **Parameters** | `-ProviderName msi, Programs, PowerShellGet` |
| **Example** | <code>Get-Package -ProviderName Programs, msi &#124; Sort-Object Name</code> |
| **Expected output** | `Name Version Source ProviderName` / `Git 2.47.1  Programs` (example) |
| **Equivalent** | `dpkg -l` |
| **Common errors** | Empty results in PowerShell 7 (providers missing) |
| **Use case** | Quick inventory in Windows PowerShell 5.1 sessions. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/packagemanagement/get-package> |

### Get-HotFix / pending reboot

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (`Win32_QuickFixEngineering`) |
| **Description** | Lists installed Windows updates with `HotFixID`, `Description`, `InstalledOn`. Not every update type appears (Defender definitions, Store apps). Pending reboot: registry keys `…\WindowsUpdate\Auto Update\RebootRequired` and `…\Component Based Servicing\RebootPending`. |
| **Syntax** | `Get-HotFix [[-Id] <String[]>] [-ComputerName <String[]>]` |
| **Parameters** | `-Id KB5046617` · `-ComputerName` |
| **Example** | <code>Get-HotFix &#124; Sort-Object InstalledOn -Descending &#124; Select-Object -First 5</code> |
| **Expected output** | `KB5046617  Security Update  13-11-2026` (example) |
| **Equivalent** | `apt list --upgradable` · `/var/log/apt/history.log` · `/var/run/reboot-required` |
| **Common errors** | `InstalledOn` empty for some entries · treating it as the full update history |
| **Use case** | Confirming a critical KB is installed on all servers. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-hotfix> |

### Get-WindowsOptionalFeature / Get-WindowsCapability

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (DISM module) · **elevated** |
| **Description** | Optional features (Hyper-V, WSL, Telnet client…) and Features on Demand (OpenSSH client/server, RSAT). Windows Server roles use `Get-WindowsFeature` / `Install-WindowsFeature`. |
| **Syntax** | `Get-WindowsOptionalFeature -Online [-FeatureName <String>]` · `Enable-WindowsOptionalFeature -Online -FeatureName <String>` · `Get-WindowsCapability -Online [-Name <String>]` · `Add-WindowsCapability -Online -Name <String>` |
| **Parameters** | `-Online` running OS · `-NoRestart` |
| **Example** | `Get-WindowsCapability -Online -Name OpenSSH*` |
| **Expected output** | `Name : OpenSSH.Client~~~~0.0.1.0  State : Installed` (example) |
| **Equivalent** | `apt install` (on Linux everything is a package) |
| **Common errors** | `The requested operation requires elevation` · forgetting the required restart |
| **Use case** | Hardening: listing and disabling unused features. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/dism/get-windowsoptionalfeature> · <https://learn.microsoft.com/en-us/powershell/module/dism/get-windowscapability> |

### Install-PSResource and PSResourceGet

| Field | Detail |
|---|---|
| **Version / OS** | **Built into PowerShell 7.4+** · 5.1 after `Install-Module Microsoft.PowerShell.PSResourceGet -Scope CurrentUser` · all OS |
| **Description** | The successor to PowerShellGet for finding, installing, updating, saving and removing modules and scripts. Default scope `CurrentUser`; `PSGallery` is untrusted by default (prompt). |
| **Syntax** | `Find-PSResource -Name <String[]>` · <code>Install-PSResource -Name &lt;String[]&gt; [-Version &lt;String&gt;] [-Scope CurrentUser&#124;AllUsers]</code> · `Get-InstalledPSResource` · `Update-PSResource` · `Uninstall-PSResource` · `Save-PSResource -Path <String>` · `Set-PSResourceRepository -Name <String> -Trusted` |
| **Parameters** | `-Version '[1.0,2.0)'` NuGet range · `-Repository` · `-TrustRepository` (this call only) · `-Path` (save) |
| **Example** | `Save-PSResource -Name PSScriptAnalyzer -Path .\review` then `Install-PSResource -Name PSScriptAnalyzer -Scope CurrentUser` |
| **Expected output** | `Untrusted repository … Are you sure you want to install the PSResource from 'PSGallery'?` (example) |
| **Equivalent** | `pip install --user` (language ecosystems) · `apt install` |
| **Common errors** | `Install-PSResource` not recognised in 5.1 · trusting the public Gallery everywhere |
| **Use case** | Installing reviewed, pinned module versions from an internal repository. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/install-psresource> |

### Install-Module and PowerShellGet

| Field | Detail |
|---|---|
| **Version / OS** | 5.1 (ships PowerShellGet **1.0.0.1**: update it first), 7.x (2.2.5) · all OS |
| **Description** | Classic module management from the PowerShell Gallery. Default scope: `AllUsers` in PowerShellGet 1.x (needs elevation), `CurrentUser` in 2.x — always pass `-Scope`. |
| **Syntax** | `Find-Module -Name <String[]>` · <code>Install-Module -Name &lt;String[]&gt; [-Scope CurrentUser&#124;AllUsers] [-RequiredVersion &lt;String&gt;]</code> · `Get-InstalledModule` · `Update-Module` · `Uninstall-Module` · `Save-Module -Path <String>` |
| **Parameters** | `-Scope` · `-RequiredVersion` / `-MinimumVersion` · `-Repository` · `-Force` (reinstall; avoid in production scripts) |
| **Example** | `Install-Module -Name PSScriptAnalyzer -Scope CurrentUser` |
| **Expected output** | `Untrusted repository … Are you sure you want to install the modules from 'PSGallery'?` (example) |
| **Equivalent** | `Install-PSResource` |
| **Common errors** | `Unable to resolve package source` (enable TLS 1.2 in 5.1, update PowerShellGet) · *Administrator rights are required* with `AllUsers` |
| **Use case** | Installing PSScriptAnalyzer for script linting (Days 21–25). |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/powershellget/install-module> |

## Networking

IP configuration (Day 11) and connectivity testing (Day 12). The `Net*` cmdlets come from the **NetTCPIP**, **NetAdapter** and **NetConnection** modules: **Windows only** (Windows 8 / Server 2012+), available in both 5.1 and 7 on Windows. Changing addresses, routes or adapters requires an elevated session. `Test-Connection` differs between 5.1 and 7 (see its entry). Cross-platform alternatives: `[System.Net.NetworkInformation.NetworkInterface]` and `[System.Net.Sockets.TcpClient]`.

### Get-NetIPConfiguration

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (NetTCPIP). Alias: `gip` |
| **Description** | One object per interface with `InterfaceAlias`, `InterfaceIndex`, `NetProfile`, `IPv4Address`, `IPv6Address`, `IPv4DefaultGateway`, `IPv6DefaultGateway` and `DNSServer`. |
| **Syntax** | `Get-NetIPConfiguration [[-InterfaceAlias] <String>] [-InterfaceIndex <Int32>] [-All] [-Detailed]` |
| **Parameters** | `-Detailed` adds MTU, MAC, DHCP and profile category · `-All` includes disconnected adapters |
| **Example** | `(Get-NetIPConfiguration -InterfaceAlias Ethernet).IPv4DefaultGateway.NextHop` |
| **Expected output** | `IPv4Address : 192.168.56.30` / `IPv4DefaultGateway : 192.168.56.1` (example) |
| **Equivalent** | `ip -br addr` + `ip route` · `ipconfig /all` |
| **Common errors** | *The term 'Get-NetIPConfiguration' is not recognized* on PowerShell 7 for Linux/macOS |
| **Use case** | Help-desk summary of a PC's address, gateway and DNS in one command. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netipconfiguration> |

### Get-NetIPAddress

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (NetTCPIP) |
| **Description** | Every IP address with `PrefixLength`, `PrefixOrigin` (`Dhcp`, `Manual`, `WellKnown`, `RouterAdvertisement`), `SuffixOrigin`, `AddressState` (`Preferred`, `Tentative`, `Duplicate`…), lifetimes and `PolicyStore`. |
| **Syntax** | <code>Get-NetIPAddress [[-IPAddress] &lt;String[]&gt;] [-InterfaceAlias &lt;String[]&gt;] [-AddressFamily &lt;IPv4&#124;IPv6&gt;] [-PrefixOrigin &lt;…&gt;] [-AddressState &lt;…&gt;] [-PolicyStore &lt;String&gt;]</code> |
| **Parameters** | `-AddressFamily IPv4` · `-AddressState Duplicate` (conflicts) · `-PrefixOrigin WellKnown` (APIPA `169.254.*`) |
| **Example** | <code>Get-NetIPAddress -AddressFamily IPv4 &#124; Select-Object InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin &#124; Export-Csv ip.csv -NoTypeInformation</code> |
| **Expected output** | `192.168.56.30  24  Dhcp  Dhcp  Preferred  23:41:07` (example) |
| **Equivalent** | `ip addr` (`dynamic`, `valid_lft`) |
| **Common errors** | Treating `169.254.x.x` as a working address |
| **Use case** | Finding all PCs that fell back to APIPA after a DHCP outage. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netipaddress> |

### New-NetIPAddress / Remove-NetIPAddress / Set-NetIPInterface

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** · **elevated** · support `-WhatIf` / `-Confirm` |
| **Description** | Add or remove static addresses (optionally with the default gateway); `Set-NetIPInterface` enables/disables DHCP, sets MTU (`-NlMtuBytes`) and interface metric. Default policy store: active **and** persistent. |
| **Syntax** | `New-NetIPAddress -InterfaceAlias <String> -IPAddress <String> -PrefixLength <Byte> [-DefaultGateway <String>] [-PolicyStore ActiveStore]` · <code>Set-NetIPInterface -InterfaceAlias &lt;String&gt; -AddressFamily IPv4 [-Dhcp Enabled&#124;Disabled] [-InterfaceMetric &lt;UInt32&gt;]</code> |
| **Parameters** | `-PolicyStore ActiveStore` runtime only · `-DefaultGateway` also creates `0.0.0.0/0` · `-Dhcp Enabled` back to DHCP |
| **Example** | `New-NetIPAddress -InterfaceAlias 'Ethernet 2' -IPAddress 192.168.56.20 -PrefixLength 24 -DefaultGateway 192.168.56.1 -WhatIf` |
| **Expected output** | `What if: Performing the operation "Create" on target "IPAddress: 192.168.56.20 PrefixLength 24 ..."` (example) |
| **Equivalent** | `ip addr add` (runtime) · netplan YAML (persistent) |
| **Common errors** | *Inconsistent parameters PolicyStore PersistentStore and Dhcp Enabled* (disable DHCP first) · *Instance DefaultGateway already exists* (remove the old route) · running it on the adapter of your remote session |
| **Use case** | Scripted static configuration of a new Windows server. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/nettcpip/new-netipaddress> · <https://learn.microsoft.com/en-us/powershell/module/nettcpip/set-netipinterface> |

### Get-NetAdapter / Get-NetIPInterface

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (NetAdapter / NetTCPIP) |
| **Description** | `Get-NetAdapter`: name, description, `ifIndex`, `Status` (`Up`, `Disconnected`, `Disabled`), `MacAddress`, `LinkSpeed`. `Get-NetIPInterface`: per-family `Dhcp`, `NlMtu`, `InterfaceMetric`, `ConnectionState`, `Forwarding`. |
| **Syntax** | `Get-NetAdapter [[-Name] <String[]>] [-Physical]` · <code>Get-NetIPInterface [[-InterfaceAlias] &lt;String[]&gt;] [-AddressFamily &lt;IPv4&#124;IPv6&gt;]</code> |
| **Parameters** | `-Physical` hides virtual adapters · `Get-NetAdapterStatistics` for counters |
| **Example** | <code>Get-NetIPInterface -AddressFamily IPv4 &#124; Format-Table InterfaceAlias, Dhcp, NlMtu, InterfaceMetric</code> |
| **Expected output** | `Ethernet  Enabled  1500  25` (example) |
| **Equivalent** | `ip -br link` · `ip link show` (MTU) · `ip route` (metrics) |
| **Common errors** | Expecting the MTU in `Get-NetAdapter` (it is `NlMtu` on the IP interface) |
| **Use case** | Explaining why Windows prefers Wi-Fi over Ethernet (metric). |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapter> · <https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netipinterface> |

### Get-NetRoute / Find-NetRoute

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (NetTCPIP) |
| **Description** | `Get-NetRoute` lists `DestinationPrefix`, `NextHop`, `RouteMetric`, `InterfaceAlias`; `Find-NetRoute -RemoteIPAddress` returns the source address and the route Windows would use. |
| **Syntax** | <code>Get-NetRoute [-DestinationPrefix &lt;String[]&gt;] [-AddressFamily &lt;IPv4&#124;IPv6&gt;] [-InterfaceAlias &lt;String[]&gt;]</code> · `Find-NetRoute -RemoteIPAddress <String>` · `New-NetRoute -DestinationPrefix <String> -NextHop <String> -InterfaceAlias <String>` |
| **Parameters** | `-DestinationPrefix 0.0.0.0/0` default route · `NextHop 0.0.0.0` = on-link |
| **Example** | <code>Find-NetRoute -RemoteIPAddress 10.20.0.20 &#124; Select-Object IPAddress, InterfaceAlias, DestinationPrefix, NextHop</code> |
| **Expected output** | `192.168.56.30  Ethernet` / `Ethernet  0.0.0.0/0  192.168.56.1` (example) |
| **Equivalent** | `ip route` · `ip route get` · `route print` |
| **Common errors** | Forgetting that the effective metric is route metric **plus** interface metric |
| **Use case** | Showing that a VPN's more specific route captures traffic to a home subnet. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netroute> · <https://learn.microsoft.com/en-us/powershell/module/nettcpip/find-netroute> |

### Get-NetNeighbor

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (NetTCPIP) |
| **Description** | ARP / neighbour cache: `IPAddress`, `LinkLayerAddress` (MAC), `State` (`Reachable`, `Stale`, `Permanent`, `Incomplete`, `Unreachable`). |
| **Syntax** | <code>Get-NetNeighbor [[-IPAddress] &lt;String[]&gt;] [-InterfaceAlias &lt;String[]&gt;] [-AddressFamily &lt;IPv4&#124;IPv6&gt;] [-State &lt;…&gt;]</code> |
| **Parameters** | `-IPAddress GW` gateway only · `-State Unreachable` |
| **Example** | `Get-NetNeighbor -IPAddress 192.168.56.1` |
| **Expected output** | `12  192.168.56.1  52-54-00-12-35-02  Reachable  ActiveStore` (example) |
| **Equivalent** | `ip neigh` · `arp -a` |
| **Common errors** | Debugging DNS while the gateway entry is `Unreachable` |
| **Use case** | Confirming layer-2 reachability of the default gateway. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netneighbor> |

### ipconfig / route print / arp (native)

| Field | Detail |
|---|---|
| **Version / OS** | Windows (any shell) |
| **Description** | Classic tools: `ipconfig /all` (addresses, DHCP lease, DNS, MAC, APIPA), `/release` and `/renew` (DHCP), `route print` (routing table, persistent routes), `arp -a` (ARP cache). |
| **Syntax** | <code>ipconfig [/all &#124; /release [ADAPTER] &#124; /renew [ADAPTER] &#124; /release6 &#124; /renew6]</code> · <code>route print [-4&#124;-6]</code> · `arp -a [-N IFADDR]` |
| **Parameters** | `/all` full detail · `route -p add` persistent route |
| **Example** | `ipconfig /renew "Wi-Fi"` |
| **Expected output** | `Autoconfiguration IPv4 Address. . : 169.254.81.177(Preferred)` = DHCP failed (example) |
| **Equivalent** | `ip addr`, `networkctl renew`, `ip route`, `ip neigh` |
| **Common errors** | Parsing the localised text in scripts (use the cmdlets) |
| **Use case** | Instructions for end users that work on every Windows version. |
| **Docs** | <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ipconfig> |

### Test-Connection

| Field | Detail |
|---|---|
| **Version / OS** | **5.1** (Windows, WMI `Win32_PingStatus`, `-ComputerName`) · **7.x** (all OS, .NET, `-TargetName` with `-ComputerName` alias) |
| **Description** | ICMP ping returning objects; in 7.x also `-Traceroute`, `-MtuSize` and `-TcpPort`. `-Quiet` returns `$true`/`$false` in both. |
| **Syntax** | 5.1: `Test-Connection [-ComputerName] <String[]> [-Count <Int32>] [-BufferSize <Int32>] [-TimeToLive <Int32>] [-Quiet]` · 7.x: `Test-Connection [-TargetName] <String[]> [-Count <Int32>] [-TimeoutSeconds <Int32>] [-BufferSize <Int32>] [-DontFragment] [-Quiet] [-Repeat]` · `-Traceroute` · `-MtuSize` · `-TcpPort <Int32>` |
| **Parameters** | `-Count` (default 4) · `-Quiet` · 7.x: `-TcpPort`, `-Traceroute`, `-MtuSize`, `-TimeoutSeconds` (default 5) |
| **Example** | `Test-Connection -TargetName 10.20.0.20 -TcpPort 8080` |
| **Expected output** | `True` · ping table `1 vm 10.20.0.20 0 32 Success` (captured, PowerShell 7.4.6 on Linux) |
| **Equivalent** | `ping` · `nc -zv` · `traceroute` · `tracepath` |
| **Common errors** | *A parameter cannot be found that matches parameter name 'TcpPort'/'TargetName'* in 5.1 · non-terminating errors on failure in 5.1 (use `-Quiet`) |
| **Use case** | Cross-platform reachability checks in scripts with a Boolean result. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-connection> |

### Test-NetConnection

| Field | Detail |
|---|---|
| **Version / OS** | 5.1, 7.x · **Windows only** (NetTCPIP). Alias: `tnc` |
| **Description** | Ping plus TCP port test plus route information: `PingSucceeded`, `PingReplyDetails`, `TcpTestSucceeded`, `SourceAddress`, `InterfaceAlias`, and with `-InformationLevel Detailed` name resolution and next hop. |
| **Syntax** | <code>Test-NetConnection [[-ComputerName] &lt;String&gt;] [-Port &lt;Int32&gt; &#124; -CommonTCPPort &lt;HTTP&#124;RDP&#124;SMB&#124;WINRM&gt;] [-TraceRoute [-Hops &lt;Int32&gt;]] [-InformationLevel &lt;Quiet&#124;Detailed&gt;]</code> |
| **Parameters** | `-Port` · `-CommonTCPPort SMB` · `-InformationLevel Quiet` Boolean · `-TraceRoute` |
| **Example** | `Test-NetConnection -ComputerName fileserver -CommonTCPPort SMB` |
| **Expected output** | `TcpTestSucceeded : True` · `WARNING: TCP connect to (10.20.0.20 : 8443) failed` (example) |
| **Equivalent** | `nc -zv` · `curl -v` · `ip route get` |
| **Common errors** | ~20 s wait against a filtering firewall · ping warning although the port is open (ICMP blocked) · no target = tests a Microsoft internet beacon |
| **Use case** | "Can this PC reach the file server on 445?" in one command. |
| **Docs** | <https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection> |

### ping.exe / tracert / pathping (native)

| Field | Detail |
|---|---|
| **Version / OS** | Windows (any shell) |
| **Description** | Classic ICMP tools: `ping` (`-n` count, `-t` continuous, `-l` size, `-f` DF, `-i` TTL, `-w` timeout ms), `tracert` (ICMP trace), `pathping` (trace + per-hop/per-link loss). |
| **Syntax** | <code>ping [-n N &#124; -t] [-l SIZE] [-f] [-i TTL] [-w MS] [-S SRC] [-4&#124;-6] HOST</code> · `tracert [-d] [-h MAX] [-w MS] HOST` · `pathping [-n] [-q N] [-h MAX] HOST` |
| **Parameters** | `-f -l 1472` MTU test · `-d` / `-n` numeric |
| **Example** | `ping -f -l 1472 10.20.0.20` |
| **Expected output** | `Packet needs to be fragmented but DF set.` (example) |
| **Equivalent** | `ping -M do -s 1472` · `traceroute` · `mtr` |
| **Common errors** | `Reply from <own IP>: Destination host unreachable.` counted as *Received* in the statistics · parsing localised text |
| **Use case** | Per-link loss evidence (`pathping`) for a WAN provider. |
| **Docs** | <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ping> · <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/pathping> |

### .NET NetworkInterface and TcpClient (cross-platform)

| Field | Detail |
|---|---|
| **Version / OS** | 5.1 and 7.x · **all OS** |
| **Description** | `[System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()` lists interfaces and addresses anywhere; `[System.Net.Sockets.TcpClient]` tests a TCP port with your own timeout and exact socket error. |
| **Syntax** | `$nic.GetIPProperties().UnicastAddresses` · `$c = [System.Net.Sockets.TcpClient]::new(); $c.ConnectAsync(HOST, PORT).Wait(MS)` |
| **Parameters** | `GetBaseException().SocketErrorCode` → `ConnectionRefused`, `TimedOut`, `HostUnreachable` |
| **Example** | <code>[System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() &#124; Select-Object Name, OperationalStatus</code> |
| **Expected output** | `lo Up 127.0.0.1 8` / `eth0 Up 192.0.2.2 24` (captured, PowerShell 7.4.6 on Linux) |
| **Equivalent** | `ip -br addr` · `nc -zv -w2` |
| **Common errors** | Reading `InnerException.Message` (an aggregate message) instead of `GetBaseException()` · always `Dispose()` the client |
| **Use case** | Port checks in scripts that must also run on Linux. |
| **Docs** | <https://learn.microsoft.com/en-us/dotnet/api/system.net.networkinformation.networkinterface> · <https://learn.microsoft.com/en-us/dotnet/api/system.net.sockets.tcpclient> |
