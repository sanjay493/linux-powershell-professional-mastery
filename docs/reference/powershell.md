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
