---
description: "Linux/Bash command reference for Ubuntu 24.04: syntax, parameters, examples, expected output, equivalents, common errors and documentation."
---

# Linux Command Reference

Platform: **Ubuntu 24.04 LTS**, Bash 5.2, GNU coreutils 9.4. Commands marked *GNU* may differ on macOS/BSD.

## Navigation & System Information

### whoami

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Prints the effective user name of the current process. |
| **Syntax** | `whoami` |
| **Parameters** | `--help`, `--version` |
| **Example** | `whoami` |
| **Expected output** | `student` |
| **Equivalent** | PowerShell: `whoami` (prints `HOST\user`), `$env:USERNAME` |
| **Common errors** | None in practice. Under `sudo` it prints `root`, which is expected. |
| **Use case** | Confirm the account before administrative work, or during incident triage. |
| **Docs** | <https://man7.org/linux/man-pages/man1/whoami.1.html> |

### hostname

| Field | Detail |
|---|---|
| **OS** | All Linux |
| **Description** | Shows (or, as root, temporarily sets) the system host name. |
| **Syntax** | <code>hostname [-s &#124; -f &#124; -I]</code> |
| **Parameters** | `-s` short name · `-f` FQDN · `-I` all IP addresses (Linux) |
| **Example** | `hostname -I` |
| **Expected output** | `192.168.56.10 10.0.2.15` |
| **Equivalent** | PowerShell: `hostname`, `$env:COMPUTERNAME` |
| **Common errors** | `hostname -f` returning just the short name means DNS/`/etc/hosts` has no FQDN. Use `hostnamectl set-hostname` for a permanent change. |
| **Use case** | Confirm you are on the correct server before a restart. |
| **Docs** | <https://man7.org/linux/man-pages/man1/hostname.1.html> |

### pwd

| Field | Detail |
|---|---|
| **OS** | Bash built-in and coreutils |
| **Description** | Prints the absolute path of the current working directory. |
| **Syntax** | <code>pwd [-L &#124; -P]</code> |
| **Parameters** | `-L` logical (default, keeps symlinks) · `-P` physical (resolves symlinks) |
| **Example** | `cd /bin && pwd -P` |
| **Expected output** | `/usr/bin` |
| **Equivalent** | `Get-Location` |
| **Common errors** | None |
| **Use case** | Check location before relative-path operations such as deletes. |
| **Docs** | <https://man7.org/linux/man-pages/man1/pwd.1.html> |

### ls

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Lists directory contents. |
| **Syntax** | `ls [OPTION]... [FILE]...` |
| **Parameters** | `-l` long · `-a` all/hidden · `-h` human sizes · `-t` by time · `-S` by size · `-r` reverse · `-R` recursive · `-d` the directory itself · `-i` inode |
| **Example** | <code>ls -lht /var/log &#124; head -5</code> |
| **Expected output** | `-rw-r----- 1 syslog adm 38K Nov  8 09:17 auth.log` … |
| **Equivalent** | `Get-ChildItem` (`-Force` for hidden) |
| **Common errors** | `ls: cannot open directory '/root': Permission denied`, because you need rights on the directory. |
| **Use case** | Find the most recently modified log files. |
| **Docs** | <https://man7.org/linux/man-pages/man1/ls.1.html> |

### uname

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Prints kernel and machine information. |
| **Syntax** | `uname [-a] [-s] [-n] [-r] [-v] [-m] [-o]` |
| **Parameters** | `-a` all · `-r` kernel release · `-m` architecture · `-n` node name · `-o` OS |
| **Example** | `uname -r` |
| **Expected output** | `6.8.0-48-generic` |
| **Equivalent** | `Get-ComputerInfo -Property OsName,OsVersion,OsArchitecture` (Windows), `[Environment]::OSVersion` |
| **Common errors** | Treating the kernel release as the distribution version. Use `/etc/os-release` for that. |
| **Use case** | Check kernel version against a vulnerability advisory. |
| **Docs** | <https://man7.org/linux/man-pages/man1/uname.1.html> |

### date

| Field | Detail |
|---|---|
| **OS** | All Linux (GNU coreutils; `-d` is GNU-specific) |
| **Description** | Prints or sets the system date and time; formats and calculates dates. |
| **Syntax** | `date [-u] [-d STRING] [+FORMAT]` |
| **Parameters** | `-u` UTC · `-d 'yesterday'` arbitrary date · `-I[seconds]` ISO 8601 · `+%F` YYYY-MM-DD · `+%s` epoch |
| **Example** | `date -u -Iseconds` |
| **Expected output** | `2026-11-08T10:05:43+00:00` |
| **Equivalent** | `Get-Date`, `(Get-Date).ToUniversalTime()`, `Get-Date -Format o` |
| **Common errors** | Forgetting quotes around formats with spaces: `date +%F %T` fails, `date '+%F %T'` works. |
| **Use case** | Timestamped file names: `backup-$(date +%F).tar.gz`. |
| **Docs** | <https://man7.org/linux/man-pages/man1/date.1.html> |

### hostnamectl / timedatectl

| Field | Detail |
|---|---|
| **OS** | systemd-based distributions (Ubuntu 15.04+) |
| **Description** | Query or change host name and OS details / time zone and NTP status. |
| **Syntax** | <code>hostnamectl [status &#124; set-hostname NAME]</code> · <code>timedatectl [status &#124; set-timezone ZONE &#124; list-timezones]</code> |
| **Example** | `timedatectl` |
| **Expected output** | `Time zone: Asia/Kolkata (IST, +0530)` … `System clock synchronized: yes` |
| **Equivalent** | `Get-TimeZone`, `w32tm /query /status`, `Rename-Computer` |
| **Common errors** | `Failed to connect to bus` in containers without systemd. |
| **Use case** | Fix clock drift that breaks authentication or log correlation. |
| **Docs** | <https://man7.org/linux/man-pages/man1/timedatectl.1.html> |

## Help & Discovery

### man

| Field | Detail |
|---|---|
| **OS** | Ubuntu (man-db) |
| **Description** | Displays the manual page for a command, file format or system call. |
| **Syntax** | `man [SECTION] PAGE` · `man -k KEYWORD` |
| **Parameters** | `-k` search descriptions (= `apropos`) · `-f` one-line description (= `whatis`) |
| **Example** | `man 5 passwd` |
| **Expected output** | The manual page for the `/etc/passwd` file format, in a pager (`q` to quit) |
| **Equivalent** | `Get-Help <cmdlet> -Full` |
| **Common errors** | `No manual entry for X` on minimal images: `sudo apt install man-db manpages` (and `unminimize` on servers). |
| **Use case** | Working on air-gapped servers without internet. |
| **Docs** | <https://man7.org/linux/man-pages/man1/man.1.html> |

### type / which / help

| Field | Detail |
|---|---|
| **OS** | Bash built-ins (`type`, `help`); `which` from debianutils |
| **Description** | `type` shows how Bash resolves a name; `which` shows the executable path; `help` documents built-ins. |
| **Syntax** | `type [-a] NAME` · `which NAME` · `help BUILTIN` |
| **Example** | `type -a ls` |
| **Expected output** | `ls is aliased to 'ls --color=auto'` / `ls is /usr/bin/ls` / `ls is /bin/ls` |
| **Equivalent** | `Get-Command NAME` (`-All`) |
| **Common errors** | `which cd` prints nothing, because `cd` is a built-in. Use `type`. |
| **Use case** | Detect a malicious alias or a PATH hijack (`type -a sudo`). |
| **Docs** | <https://www.gnu.org/software/bash/manual/bash.html#Bash-Builtins> |

## Files & Directories

### cd

| Field | Detail |
|---|---|
| **OS** | Bash built-in |
| **Description** | Changes the shell's current directory. |
| **Syntax** | <code>cd [DIR &#124; - &#124; ~ &#124; ..]</code> |
| **Example** | `cd /var/log && cd -` |
| **Expected output** | `cd -` prints the directory it returns to, e.g. `/home/student` |
| **Equivalent** | `Set-Location` (`cd`); `Set-Location -` in 6.2+ |
| **Common errors** | `bash: cd: too many arguments` (unquoted spaces) · `No such file or directory` · `Permission denied` (no `x` permission on the directory) |
| **Use case** | Fast navigation; `cd -` toggles between two working directories. |
| **Docs** | `help cd` |

### mkdir

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Creates directories. |
| **Syntax** | `mkdir [-p] [-v] [-m MODE] DIR...` |
| **Parameters** | `-p` create parents, no error if existing · `-v` verbose · `-m 750` set permissions |
| **Example** | `mkdir -pv /tmp/app/{logs,conf}` |
| **Expected output** | `mkdir: created directory '/tmp/app'` … `'/tmp/app/logs'` … `'/tmp/app/conf'` |
| **Equivalent** | `New-Item -ItemType Directory -Force` (`mkdir` function on Windows) |
| **Common errors** | `File exists` (add `-p`) · `Permission denied` (parent not writable) |
| **Use case** | Idempotent setup of application directory trees. |
| **Docs** | <https://man7.org/linux/man-pages/man1/mkdir.1.html> |

### touch

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Creates an empty file, or updates the timestamps of an existing file without changing its content. |
| **Syntax** | <code>touch [-c] [-a&#124;-m] [-d DATE] FILE...</code> |
| **Parameters** | `-c` do not create · `-a`/`-m` access/modify time only · `-d '2026-01-01 09:00'` set a specific time |
| **Example** | `touch report.txt && ls -l report.txt` |
| **Expected output** | `-rw-rw-r-- 1 student student 0 Nov  8 16:02 report.txt` |
| **Equivalent** | `New-Item -ItemType File` (new) · `(Get-Item f).LastWriteTime = Get-Date` (update) |
| **Common errors** | `Permission denied` in directories you cannot write to |
| **Use case** | Create marker/lock files; reproduce time-based test conditions. |
| **Docs** | <https://man7.org/linux/man-pages/man1/touch.1.html> |

### cp

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Copies files and directories. |
| **Syntax** | <code>cp [-r] [-i&#124;-n] [-v] [-p&#124;-a] [-u] SOURCE... DEST</code> |
| **Parameters** | `-r` recursive · `-a` archive (preserve all, recursive) · `-p` preserve attributes · `-i` prompt · `-n` no-clobber · `-u` only newer · `-v` verbose |
| **Example** | `sudo cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%F)` |
| **Expected output** | No output on success (add `-v` to see `'a' -> 'b'`) |
| **Equivalent** | `Copy-Item` (`-Recurse`), `robocopy` for attribute-preserving copies |
| **Common errors** | `-r not specified; omitting directory` · nested-folder surprise when the destination exists |
| **Use case** | Timestamped backups before configuration changes. |
| **Docs** | <https://man7.org/linux/man-pages/man1/cp.1.html> |

### mv

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Moves or renames files and directories. |
| **Syntax** | <code>mv [-i&#124;-n] [-v] [-u] SOURCE... DEST</code> |
| **Parameters** | `-i` prompt before overwrite · `-n` never overwrite · `-v` verbose · `-u` only if newer |
| **Example** | `mv -v app.log app.log.1` |
| **Expected output** | `renamed 'app.log' -> 'app.log.1'` |
| **Equivalent** | `Move-Item`, `Rename-Item` |
| **Common errors** | Silent overwrite of an existing destination (use `-i`/`-n`) · `cannot stat` (source missing) |
| **Use case** | Manual log rotation; archiving processed files. |
| **Docs** | <https://man7.org/linux/man-pages/man1/mv.1.html> |

### rm

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Removes files and (with `-r`) directory trees. **Permanent: no trash.** |
| **Syntax** | <code>rm [-i&#124;-I] [-r] [-f] [-v] [--] FILE...</code> |
| **Parameters** | `-i` prompt each · `-I` prompt once · `-r` recursive · `-f` force (no prompts) · `-v` verbose · `--` end of options |
| **Example** | `rm -Iv *.tmp` |
| **Expected output** | `rm: remove 4 arguments?` then `removed 'a.tmp'` … |
| **Equivalent** | `Remove-Item` (`-Recurse`, `-Force`, `-WhatIf`, `-Confirm`) |
| **Common errors** | `Is a directory` (needs `-r`) · `Permission denied` (no write permission on the parent directory) |
| **Use case** | Cleaning build artefacts after previewing with `ls`. |
| **Docs** | <https://man7.org/linux/man-pages/man1/rm.1.html> |

### rmdir

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Removes **empty** directories only. |
| **Syntax** | `rmdir [-p] [-v] DIR...` |
| **Example** | `rmdir -v old-empty-dir` |
| **Expected output** | `rmdir: removing directory, 'old-empty-dir'` |
| **Equivalent** | `Remove-Item DIR` (prompts if not empty) |
| **Common errors** | `Directory not empty`, which is the intended safety behaviour |
| **Use case** | Safe cleanup scripts that must never delete content. |
| **Docs** | <https://man7.org/linux/man-pages/man1/rmdir.1.html> |

### file / stat

| Field | Detail |
|---|---|
| **OS** | All Linux |
| **Description** | `file` identifies content type by inspecting bytes; `stat` shows full metadata. |
| **Syntax** | `file FILE...` · `stat FILE...` |
| **Example** | `file /usr/bin/ls` |
| **Expected output** | `/usr/bin/ls: ELF 64-bit LSB pie executable, x86-64, ...` |
| **Equivalent** | <code>Get-Item f &#124; Format-List *</code> (metadata); first bytes via `Get-Content -Encoding Byte -TotalCount 4` (5.1) / `-AsByteStream` (7) |
| **Common errors** | None common |
| **Use case** | Spot executables disguised with document extensions. |
| **Docs** | <https://man7.org/linux/man-pages/man1/file.1.html> · <https://man7.org/linux/man-pages/man1/stat.1.html> |

## Reading Files & Redirection

### cat / tac

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils). `-A`, `-b`, `-s` are GNU options |
| **Description** | `cat` prints and concatenates files; `tac` prints them last line first. |
| **Syntax** | `cat [-n] [-b] [-A] [-s] [FILE]...` · `tac [FILE]...` |
| **Parameters** | `-n` number all lines · `-b` number non-blank lines · `-A` show `$` line ends, `^I` tabs, `^M` carriage returns · `-s` squeeze blank lines |
| **Example** | `cat -A deploy.sh` |
| **Expected output** | `#!/bin/bash^M$` (example: a script with Windows CRLF line endings) |
| **Equivalent** | `Get-Content` (aliases `cat`, `type`, `gc` on Windows) |
| **Common errors** | `Permission denied` (protected log: use `sudo` or the `adm` group) · `Is a directory` · garbled terminal after printing a binary file (run `reset`) |
| **Use case** | Diagnose `bad interpreter: /bin/bash^M` errors in scripts copied from Windows. |
| **Docs** | <https://man7.org/linux/man-pages/man1/cat.1.html> · <https://man7.org/linux/man-pages/man1/tac.1.html> |

### less / more

| Field | Detail |
|---|---|
| **OS** | All Linux. `less` package (installed on Ubuntu); `more` from util-linux |
| **Description** | Pagers: show a file one screen at a time. `less` scrolls both ways, searches and follows, and opens huge files instantly. |
| **Syntax** | `less [-N] [-S] [-R] [-X] [+F] [+G] [FILE]...` · `more [+NUM] [FILE]...` |
| **Parameters** | `-N` line numbers · `-S` chop long lines · `-R` keep colours · `+F` start following · `+G` start at end. Keys: `/` search, `n`/`N` next/previous, `g`/`G` top/bottom, `&pattern` filter, `F` follow, `q` quit |
| **Example** | `less +G /var/log/syslog` |
| **Expected output** | Interactive view positioned at the last line of the log |
| **Equivalent** | <code>Get-Content f &#124; Out-Host -Paging</code> (forward only, no search) |
| **Common errors** | `"file" may be a binary file. See it anyway?` (answer `n`) |
| **Use case** | Reading and searching a multi-gigabyte log without loading it into memory. |
| **Docs** | <https://man7.org/linux/man-pages/man1/less.1.html> · <https://man7.org/linux/man-pages/man1/more.1.html> |

### head

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils). Negative counts are GNU |
| **Description** | Prints the first lines (default 10) or bytes of a file. |
| **Syntax** | `head [-n [-]NUM] [-c [-]NUM] [-q] [FILE]...` |
| **Parameters** | `-n N` first N lines · `-n -N` all but the last N lines · `-c N` first N bytes · `-q` no file-name headers |
| **Example** | `head -n 1 data.csv` |
| **Expected output** | `timestamp,host,status` (example header line) |
| **Equivalent** | `Get-Content f -TotalCount N` (aliases `-First`, `-Head`) |
| **Common errors** | `head: invalid number of lines: 'x'` |
| **Use case** | Check a CSV's header, or a file's signature bytes with <code>head -c 4 f &#124; od -c</code>. |
| **Docs** | <https://man7.org/linux/man-pages/man1/head.1.html> |

### tail

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils). `-F`, `--pid` are GNU |
| **Description** | Prints the last lines (default 10) or bytes, and can follow a growing file. |
| **Syntax** | <code>tail [-n [+]NUM] [-c [+]NUM] [-f&#124;-F] [--pid=PID] [-s SEC] [FILE]...</code> |
| **Parameters** | `-n N` last N lines · `-n +N` from line N to the end · `-f` follow the open file · `-F` follow by name and retry (survives log rotation) · `--pid=PID` stop when PID exits |
| **Example** | `sudo tail -n 0 -F /var/log/auth.log` |
| **Expected output** | Nothing until a new line is written, then e.g. `Nov  8 10:12:01 web01 sshd[2051]: Accepted publickey for deploy from 10.0.0.5 ...` |
| **Equivalent** | `Get-Content f -Tail N` · `Get-Content f -Tail 0 -Wait` |
| **Common errors** | Following stops after rotation (use `-F`) · `inotify cannot be used, reverting to polling` (harmless) |
| **Use case** | Watching a log live while reproducing a fault. |
| **Docs** | <https://man7.org/linux/man-pages/man1/tail.1.html> |

### wc

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils). `-L` is GNU |
| **Description** | Counts newlines, words, bytes and characters. |
| **Syntax** | `wc [-l] [-w] [-c] [-m] [-L] [FILE]...` |
| **Parameters** | `-l` lines (newline characters) · `-w` words · `-c` bytes · `-m` characters · `-L` longest line length |
| **Example** | `wc -l < /etc/passwd` |
| **Expected output** | `38` (example; number only, because input came from stdin) |
| **Equivalent** | `(Get-Content f).Count` · <code>Get-Content f &#124; Measure-Object -Line -Word -Character</code> |
| **Common errors** | One line "missing": the last line has no trailing newline |
| **Use case** | Quantifying log growth or the number of accounts on a system. |
| **Docs** | <https://man7.org/linux/man-pages/man1/wc.1.html> |

### tee

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | Copies standard input to one or more files **and** to standard output. |
| **Syntax** | `tee [-a] FILE...` |
| **Parameters** | `-a` append instead of overwrite |
| **Example** | <code>echo '10.0.0.5 db01' &#124; sudo tee -a /etc/hosts</code> |
| **Expected output** | `10.0.0.5 db01` (also appended to the file) |
| **Equivalent** | `Tee-Object` |
| **Common errors** | `sudo echo x >> file` fails with `Permission denied`; `tee` run with `sudo` is the fix |
| **Use case** | Saving evidence while still seeing it; privileged appends. Back up the file first. |
| **Docs** | <https://man7.org/linux/man-pages/man1/tee.1.html> |

### Redirection operators (Bash)

| Field | Detail |
|---|---|
| **OS** | Bash (and POSIX shells, except `&>` and <code>&#124;&amp;</code>, which are Bash-only) |
| **Description** | Send stdout (1) and stderr (2) to files, or read stdin (0) from a file. |
| **Syntax** | `cmd > f` · `cmd >> f` · `cmd 2> f` · `cmd > f 2>&1` · `cmd &> f` · `cmd < f` · `cmd 2>/dev/null` · <code>cmd &gt;&#124; f</code> |
| **Parameters** | `>` overwrite · `>>` append · `2>` errors · `2>&1` errors to wherever stdout points **now** · `set -o noclobber` refuse overwrite · <code>&gt;&#124;</code> override noclobber |
| **Example** | `/opt/backup/run.sh >> /var/log/backup.log 2>&1` |
| **Expected output** | Nothing on screen; output and errors are appended to the log |
| **Equivalent** | PowerShell `>`, `>>`, `2>`, `2>&1`, `*>`, `2>$null` |
| **Common errors** | `cmd 2>&1 > f` (wrong order: errors still on screen) · `sort f > f` empties `f` · `cannot overwrite existing file` (noclobber on) |
| **Use case** | Logging scheduled jobs; discarding expected permission errors from `find`. |
| **Docs** | <https://www.gnu.org/software/bash/manual/bash.html#Redirections> |

### zcat / zless

| Field | Detail |
|---|---|
| **OS** | All Linux (gzip package) |
| **Description** | Read gzip-compressed files without decompressing them to disk. |
| **Syntax** | `zcat FILE.gz...` · `zless FILE.gz` |
| **Parameters** | Same as `cat` / `less` |
| **Example** | <code>zcat /var/log/syslog.2.gz &#124; tail -n 20</code> |
| **Expected output** | The last 20 lines of the rotated log |
| **Equivalent** | No built-in cmdlet; expand the archive first |
| **Common errors** | `not in gzip format` (file is not compressed; use `cat`) |
| **Use case** | Reviewing older rotated logs during an investigation. |
| **Docs** | <https://man7.org/linux/man-pages/man1/gzip.1.html> |

## Searching

### find

| Field | Detail |
|---|---|
| **OS** | All Linux (GNU findutils). `-newermt`, `-delete`, `-maxdepth` are GNU/BSD extensions |
| **Description** | Searches the filesystem **live** by name, type, size, time, owner and permissions, and can act on the results. |
| **Syntax** | `find [PATH...] [-maxdepth N] [TESTS] [ACTIONS]` |
| **Parameters** | `-name`/`-iname` wildcard · `-type f/d/l` · `-size +100M` · `-mtime -1` · `-mmin -30` · `-newermt DATE` · `-empty` · `-user` · `-perm` · `-xdev` · `-exec cmd {} +` · `-ok` · `-delete` (last!) · `-print0` |
| **Example** | `find /var/log -xdev -type f -size +100M -exec ls -lh {} + 2>/dev/null` |
| **Expected output** | `-rw-r----- 1 syslog adm 412M Nov  8 10:15 /var/log/syslog` (example) |
| **Equivalent** | <code>Get-ChildItem -Recurse -File &#124; Where-Object Length -gt 100MB</code> |
| **Common errors** | `paths must precede expression` (unquoted wildcard) · `Permission denied` (add `2>/dev/null`) · `-delete` placed first deletes everything |
| **Use case** | Finding large or recently modified files during disk or security incidents. |
| **Docs** | <https://man7.org/linux/man-pages/man1/find.1.html> |

### grep

| Field | Detail |
|---|---|
| **OS** | All Linux (GNU grep 3.11 on Ubuntu 24.04). `-r`, `-P`, `--include` are GNU |
| **Description** | Prints lines matching a pattern (regular expression or fixed string). Case-sensitive by default. Exit code 0 = match, 1 = none, 2 = error. |
| **Syntax** | `grep [OPTIONS] PATTERN [FILE...]` |
| **Parameters** | `-i` ignore case · `-n` line numbers · `-v` invert · `-c` count · `-l`/`-L` files with/without matches · `-r`/`-R` recursive · `-w` word · `-o` only match · `-E` extended regex · `-F` fixed string · `-A`/`-B`/`-C N` context · `-q` quiet · `--include=GLOB` |
| **Example** | <code>sudo grep 'Failed password' /var/log/auth.log &#124; grep -Eo 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' &#124; sort &#124; uniq -c &#124; sort -rn</code> |
| **Expected output** | Count and address per line, e.g. `80 from 203.0.113.50` (example) |
| **Equivalent** | `Select-String` (case-insensitive by default) |
| **Common errors** | `Is a directory` (add `-r`) · `binary file matches` (UTF-16 or binary; `-a` or `iconv`) · `\d` not supported with `-E` (use `[0-9]` or `-P`) |
| **Use case** | Ranking brute-force sources; finding hard-coded secrets in code. |
| **Docs** | <https://man7.org/linux/man-pages/man1/grep.1.html> · <https://www.gnu.org/software/grep/manual/grep.html> |

### xargs

| Field | Detail |
|---|---|
| **OS** | All Linux (findutils). `-r` is GNU |
| **Description** | Builds and runs command lines from items read on standard input. |
| **Syntax** | `xargs [-0] [-r] [-n N] [-p] COMMAND [ARGS]` |
| **Parameters** | `-0` NUL-separated input (pair with `find -print0`) · `-r` do nothing if input is empty · `-n N` at most N items per command · `-p` prompt before each run |
| **Example** | <code>find . -name '*.tmp' -print0 &#124; xargs -0 -r rm -v</code> |
| **Expected output** | `removed './tmp/cache.tmp'` |
| **Equivalent** | <code>&#124; ForEach-Object { ... }</code> / <code>&#124; Remove-Item</code> |
| **Common errors** | Names with spaces split into pieces (use `-print0` / `-0`) |
| **Use case** | Acting on large `find` result sets efficiently. |
| **Docs** | <https://man7.org/linux/man-pages/man1/xargs.1.html> |

### locate (plocate)

| Field | Detail |
|---|---|
| **OS** | Ubuntu 24.04: package `plocate` (may need `sudo apt install plocate`). Other distributions may use `mlocate` |
| **Description** | Searches a pre-built index of file names. Instant, but only as current as the last `updatedb` (daily timer). |
| **Syntax** | `locate [-i] [-c] [-l N] [-b] [-r REGEX] PATTERN...` |
| **Parameters** | `-i` ignore case · `-c` count only · `-l N` limit results · `-b` match base name only · `-r` regex · `sudo updatedb` refresh the index |
| **Example** | `locate -i sshd_config` |
| **Expected output** | `/etc/ssh/sshd_config` · `/usr/share/man/man5/sshd_config.5.gz` (example) |
| **Equivalent** | None built in; `Get-ChildItem -Recurse -Filter name` reads the disk live |
| **Common errors** | New files not found (database not updated) · `Command 'locate' not found` (install `plocate`) |
| **Use case** | Quickly finding where a package put its files. Not for investigations (stale data). |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man1/plocate.1.html> |

### command -v / whereis

| Field | Detail |
|---|---|
| **OS** | `command` is a POSIX shell built-in; `whereis` is from util-linux |
| **Description** | `command -v` prints the path (or name, for built-ins and aliases) of what would run; `whereis` shows binary, source and man page locations. |
| **Syntax** | `command -v NAME` · `whereis [-b] [-m] NAME` |
| **Parameters** | `-v` short description · `-V` verbose · `whereis -b` binaries only · `-m` manuals only |
| **Example** | <code>command -v nmap &gt;/dev/null &#124;&#124; echo 'nmap not installed'</code> |
| **Expected output** | `nmap not installed` (when absent) |
| **Equivalent** | `Get-Command name -ErrorAction SilentlyContinue` · `where.exe name` |
| **Common errors** | Using `which` in portable scripts (behaviour varies; ignores aliases and built-ins) |
| **Use case** | Dependency checks at the start of scripts. |
| **Docs** | <https://www.gnu.org/software/bash/manual/bash.html#Bash-Builtins> · <https://man7.org/linux/man-pages/man1/whereis.1.html> |
