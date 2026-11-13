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
| **Equivalent** | <code>Get-Item f &#124; Format-List &#42;</code> (metadata); first bytes via `Get-Content -Encoding Byte -TotalCount 4` (5.1) / `-AsByteStream` (7) |
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
| **Example** | <code>find . -name '&#42;.tmp' -print0 &#124; xargs -0 -r rm -v</code> |
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

## Pipelines, History & Exit Codes

### whatis / apropos (man -f / man -k)

| Field | Detail |
|---|---|
| **OS** | All Linux (man-db). Minimized Ubuntu images and containers ship without manual pages |
| **Description** | `whatis` prints the one-line description of pages with that exact name; `apropos` searches all page names and descriptions (regular expressions by default). |
| **Syntax** | `whatis NAME...` · `apropos [-s SECTION] KEYWORD...` · `man -f NAME` · `man -k KEYWORD` |
| **Parameters** | `-s 8` limit to a section · `-a` all keywords must match · `-e` exact word (apropos) |
| **Example** | `man -k '^user'` |
| **Expected output** | `useradd (8) - create a new user or update default new user information` … (example) |
| **Equivalent** | `Get-Command *user*` · `Get-Help user` |
| **Common errors** | `nothing appropriate` (database not built: `sudo mandb`) · "This system has been minimized…" (`sudo unminimize`) |
| **Use case** | Discovering which command does a job on an offline server. |
| **Docs** | <https://man7.org/linux/man-pages/man1/apropos.1.html> · <https://man7.org/linux/man-pages/man1/whatis.1.html> |

### history / fc

| Field | Detail |
|---|---|
| **OS** | Bash built-ins (interactive shells). Ubuntu's `~/.bashrc` sets `HISTCONTROL=ignoreboth`, `HISTSIZE=1000`, `HISTFILESIZE=2000`, `histappend` |
| **Description** | Lists and manages the command history kept in memory and in `~/.bash_history`. `fc` lists or edits and re-runs entries. |
| **Syntax** | `history [N]` · `history -d OFFSET` · `history -c` · `history -a` · `history -w` · `fc -l [FIRST [LAST]]` |
| **Parameters** | `N` last N entries · `-d` delete an entry · `-c` clear memory list · `-a` append new lines to the file · `-w` write the whole list · variables `HISTFILE`, `HISTSIZE`, `HISTFILESIZE`, `HISTCONTROL`, `HISTIGNORE`, `HISTTIMEFORMAT` |
| **Example** | `export HISTTIMEFORMAT='%F %T  '; history 5` |
| **Expected output** | `8  2026-11-09 16:42:21  echo one` (example; entries are right-aligned) |
| **Equivalent** | `Get-History` (session) · `(Get-PSReadLineOption).HistorySavePath` (file) |
| **Common errors** | Other terminals' commands missing (written on exit; use `history -a`/`-n`) · secrets typed on the command line are stored in plain text |
| **Use case** | Documenting a change window; incident responders reviewing user activity. |
| **Docs** | <https://www.gnu.org/software/bash/manual/html_node/Bash-History-Builtins.html> |

### History expansion (!! !n !$ ^a^b)

| Field | Detail |
|---|---|
| **OS** | Bash, interactive shells only (disabled in scripts; `set +H` turns it off) |
| **Description** | Re-uses earlier commands or their arguments. |
| **Syntax** | `!!` · `!N` · `!-N` · `!string` · `!$` · `!*` · `^old^new` · append `:p` to print only |
| **Parameters** | `!!` previous command · `!N` entry N · `!-N` N commands back · `!string` most recent starting with string · `!$` last argument · `!*` all arguments · `:p` print without running |
| **Example** | `sudo !!` |
| **Expected output** | The previous command is printed, then run with `sudo` |
| **Equivalent** | `Invoke-History` / `r` (whole command lines only) |
| **Common errors** | `event not found` (`!` inside double quotes; use single quotes) · running an unexpected old command (check with `:p`) |
| **Use case** | Re-running a command that failed for lack of privileges. |
| **Docs** | <https://www.gnu.org/software/bash/manual/html_node/History-Interaction.html> |

### Pipes and control operators (| |& ; && ||)

| Field | Detail |
|---|---|
| **OS** | Bash (POSIX shells; <code>&#124;&amp;</code> is Bash 4+) |
| **Description** | <code>&#124;</code> connects stdout to the next command's stdin; <code>&#124;&amp;</code> pipes stdout and stderr; `;` runs in sequence; `&&` runs the next only on success; <code>&#124;&#124;</code> only on failure. |
| **Syntax** | <code>cmd1 &#124; cmd2</code> · <code>cmd1 &#124;&amp; cmd2</code> · `cmd1 ; cmd2` · `cmd1 && cmd2` · <code>cmd1 &#124;&#124; cmd2</code> |
| **Parameters** | Group with `{ cmd1; cmd2; }` or run in a subshell with `( … )` |
| **Example** | <code>cut -d' ' -f1 access.log &#124; sort &#124; uniq -c &#124; sort -rn &#124; head -n 3</code> |
| **Expected output** | `97 10.0.0.8` / `60 203.0.113.50` / `49 10.0.0.5` (Lab 05 data) |
| **Equivalent** | PowerShell <code>&#124;</code> (objects) · `;` · `&&` <code>&#124;&#124;</code> in PowerShell 7+ only |
| **Common errors** | <code>a &amp;&amp; b &#124;&#124; c</code> is not if/else (`c` runs if `b` fails) · `uniq -c` without `sort` · stderr not piped without `2>&1` |
| **Use case** | `cd /srv/app/tmp && rm -f ./*.tmp` so the deletion never runs in the wrong directory. |
| **Docs** | <https://www.gnu.org/software/bash/manual/html_node/Pipelines.html> · <https://www.gnu.org/software/bash/manual/html_node/Lists.html> |

### Exit status ($? PIPESTATUS pipefail)

| Field | Detail |
|---|---|
| **OS** | Bash. `$?` is POSIX; `PIPESTATUS` and `pipefail` are Bash (`pipefail` is also in POSIX 2024) |
| **Description** | Every command returns 0–255: 0 success, 1 general failure, 2 misuse, 126 not executable, 127 not found, 128+N killed by signal N. |
| **Syntax** | `echo $?` · `echo "${PIPESTATUS[@]}"` · `set -o pipefail` · `exit N` |
| **Parameters** | `rc=$?` save immediately · `if ! cmd; then …` test a command · `set -o pipefail` pipeline fails if any stage fails |
| **Example** | <code>false &#124; true; echo "$? ${PIPESTATUS[&#42;]}"</code> |
| **Expected output** | `0 1 0` |
| **Equivalent** | `$?` (Boolean) and `$LASTEXITCODE` (integer) in PowerShell |
| **Common errors** | Reading `$?` after another command · ignoring failures hidden inside pipelines · scripts that always `exit 0` |
| **Use case** | Monitoring checks that return 0 OK, 2 UNKNOWN, 3 threshold breached. |
| **Docs** | <https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html> · <https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html> |

## Users & Groups

### id / groups

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils) |
| **Description** | `id` prints the UID, primary GID and supplementary groups of a user; `groups` prints only group names. |
| **Syntax** | `id [-u] [-g] [-G] [-n] [USER]` · `groups [USER]` |
| **Parameters** | `-u` UID · `-g` primary GID · `-G` all group IDs · `-n` names instead of numbers |
| **Example** | `id student` |
| **Expected output** | `uid=1000(student) gid=1000(student) groups=1000(student),4(adm),27(sudo)` (example, shortened) |
| **Equivalent** | `whoami /user /groups` · `Get-LocalGroupMember` |
| **Common errors** | New group membership not shown in the current session (log out and in, or `newgrp`) |
| **Use case** | Checking whether an account has `sudo` before granting access. |
| **Docs** | <https://man7.org/linux/man-pages/man1/id.1.html> · <https://man7.org/linux/man-pages/man1/groups.1.html> |

### getent

| Field | Detail |
|---|---|
| **OS** | All Linux (glibc). Reads every configured source (files, LDAP, SSSD) via NSS |
| **Description** | Queries the account databases (`passwd`, `group`, `shadow`, `hosts`) the way the system sees them. |
| **Syntax** | `getent DATABASE [KEY...]` |
| **Parameters** | `passwd NAME` · `group NAME` · `shadow NAME` (root) · exit 2 = key not found |
| **Example** | `getent group sudo` |
| **Expected output** | `sudo:x:27:student` (example) |
| **Equivalent** | `Get-LocalUser` · `Get-LocalGroup` · `Get-LocalGroupMember` |
| **Common errors** | Using `grep /etc/passwd` and missing directory (LDAP/AD) users |
| **Use case** | Verifying that a user exists before and after offboarding. |
| **Docs** | <https://man7.org/linux/man-pages/man1/getent.1.html> |

### useradd / adduser

| Field | Detail |
|---|---|
| **OS** | `useradd`: all Linux (shadow). `adduser`: **Debian/Ubuntu-specific** friendly wrapper (interactive). Root required |
| **Description** | Creates a local account. `useradd` does exactly what its options say (no home directory without `-m` on Ubuntu); `adduser` creates the home, copies `/etc/skel` and asks for a password. |
| **Syntax** | `useradd [-m] [-s SHELL] [-c COMMENT] [-G GROUPS] [-e YYYY-MM-DD] NAME` · `adduser [--disabled-password] [--comment TEXT] NAME` |
| **Parameters** | `-m` create home · `-s /bin/bash` shell · `-c` comment · `-G` supplementary groups · `-e` expiry date · `-u` UID · `-r` system account |
| **Example** | `sudo useradd -m -s /bin/bash -c 'Lab Alice' lab-alice` |
| **Expected output** | No output on success; `id lab-alice` → `uid=1001(lab-alice) gid=1001(lab-alice) groups=1001(lab-alice)` (example) |
| **Equivalent** | `New-LocalUser` · `net user NAME /add` |
| **Common errors** | `user 'x' already exists` · account without home or with `/bin/sh` (forgot `-m`/`-s`) · `Permission denied` (needs `sudo`) |
| **Use case** | Onboarding a new team member or service account. |
| **Docs** | <https://man7.org/linux/man-pages/man8/useradd.8.html> · <https://manpages.ubuntu.com/manpages/noble/man8/adduser.8.html> |

### usermod

| Field | Detail |
|---|---|
| **OS** | All Linux (shadow). Root required |
| **Description** | Changes an existing account: groups, shell, comment, expiry, lock state, login name. |
| **Syntax** | `usermod [-a -G GROUPS] [-s SHELL] [-c COMMENT] [-e DATE] [-L] [-U] [-l NEWNAME] NAME` |
| **Parameters** | `-aG` **append** to supplementary groups · `-G` alone **replaces** them · `-L`/`-U` lock/unlock password · `-e 1` expire immediately · `-s /usr/sbin/nologin` |
| **Example** | `sudo usermod -aG lab-devs lab-alice` |
| **Expected output** | No output; `id -nG lab-alice` → `lab-alice lab-devs` (example) |
| **Equivalent** | `Add-LocalGroupMember` · `Set-LocalUser` · `Disable-LocalUser` |
| **Common errors** | `-G` without `-a` silently removes other groups (including `sudo`) · `user X is currently used by process N` when renaming |
| **Use case** | Granting a team group; disabling an account during offboarding. |
| **Docs** | <https://man7.org/linux/man-pages/man8/usermod.8.html> |

### passwd / chage

| Field | Detail |
|---|---|
| **OS** | All Linux (shadow). Changing another user's settings requires root |
| **Description** | `passwd` sets, locks, unlocks, expires and reports passwords; `chage` sets password ageing and account expiry. |
| **Syntax** | `passwd [-l] [-u] [-e] [-S] [USER]` · `chage [-l] [-M DAYS] [-W DAYS] [-E YYYY-MM-DD] USER` |
| **Parameters** | `-l` lock · `-u` unlock · `-e` force change at next login · `-S` status (`P`, `L`, `NP`) · `chage -l` list · `-M` maximum age · `-W` warning days · `-E` account expiry (`-1` = never) |
| **Example** | `sudo chage -E 2026-12-31 lab-bob; sudo chage -l lab-bob` |
| **Expected output** | `Account expires : Dec 31, 2026` (example) |
| **Equivalent** | `Set-LocalUser -AccountExpires` · `-PasswordNeverExpires` · `Disable-LocalUser` · `net accounts` |
| **Common errors** | `passwd -l` does not block SSH key logins (also expire the account or set `nologin`) · typing passwords as arguments to scripts |
| **Use case** | Contractor accounts that end on a fixed date. |
| **Docs** | <https://man7.org/linux/man-pages/man1/passwd.1.html> · <https://man7.org/linux/man-pages/man1/chage.1.html> |

### userdel

| Field | Detail |
|---|---|
| **OS** | All Linux (shadow). Root required |
| **Description** | Deletes an account. By default the home directory and mail spool are **kept**; `-r` removes them. |
| **Syntax** | `userdel [-r] NAME` |
| **Parameters** | `-r` remove home and mail spool · `-f` force (even if logged in; avoid) |
| **Example** | `sudo userdel lab-bob` (after archiving `/home/lab-bob`) |
| **Expected output** | No output; `getent passwd lab-bob` returns nothing (exit 2) |
| **Equivalent** | `Remove-LocalUser` (profile folder is kept) |
| **Common errors** | `user lab-bob is currently used by process N` · deleting with `-r` before preserving data · orphaned files (`find / -nouser`) |
| **Use case** | Final step of offboarding, after a disable period. |
| **Docs** | <https://man7.org/linux/man-pages/man8/userdel.8.html> |

### groupadd / groupdel / gpasswd

| Field | Detail |
|---|---|
| **OS** | All Linux (shadow). Root required to change groups |
| **Description** | Create and delete groups; add or remove single members, or set the full member list. |
| **Syntax** | `groupadd [-g GID] NAME` · `groupdel NAME` · `gpasswd -a USER GROUP` · `gpasswd -d USER GROUP` · `gpasswd -M USER1,USER2 GROUP` |
| **Parameters** | `-g` choose GID · `-a` add · `-d` delete · `-M` set members (replaces the list) |
| **Example** | `sudo groupadd lab-devs && sudo gpasswd -a lab-bob lab-devs` |
| **Expected output** | `Adding user lab-bob to group lab-devs` |
| **Equivalent** | `New-LocalGroup` · `Add-LocalGroupMember` · `Remove-LocalGroupMember` |
| **Common errors** | `groupdel: cannot remove the primary group of user 'x'` · `group 'x' already exists` |
| **Use case** | Role-based access: grant a team group instead of individual users. |
| **Docs** | <https://man7.org/linux/man-pages/man8/groupadd.8.html> · <https://man7.org/linux/man-pages/man1/gpasswd.1.html> |

## Permissions

### chmod

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils). Owner of the file or root |
| **Description** | Changes mode bits: read/write/execute for user, group and others, plus setuid, setgid and sticky. Numeric modes set every bit; symbolic modes change only the bits named. |
| **Syntax** | `chmod [-R] [-v] [-c] MODE[,MODE]... FILE...` · `chmod --reference=RFILE FILE...` |
| **Parameters** | Numeric `640`, `2770` · symbolic `[ugoa][+-=][rwxXst]` · `-R` recursive · `-c` report changes · `-v` verbose · `--preserve-root` · `X` = execute for directories (and already-executable files) only |
| **Example** | `chmod -R u=rwX,go=rX /srv/site` · `chmod 600 ~/.ssh/id_ed25519` |
| **Expected output** | No output; with `-c`: `mode of 'backup.sh' changed from 0700 (rwx------) to 0740 (rwxr-----)` |
| **Equivalent** | `icacls FILE /grant` · `Set-Acl` (NTFS ACEs; no execute bit model) |
| **Common errors** | `chmod -R 644 dir` removes `x` from directories · `chmod 770` does **not** clear setgid on a directory (use `g-s` or `00770`) · `Operation not permitted` when you are not the owner |
| **Use case** | Making a script executable; locking down a secrets file. |
| **Docs** | <https://man7.org/linux/man-pages/man1/chmod.1.html> |

### chown / chgrp

| Field | Detail |
|---|---|
| **OS** | All Linux (coreutils). Changing the owner needs root; `chgrp` to one of your own groups is allowed for the owner |
| **Description** | Change the owning user and/or group of files and directories. |
| **Syntax** | `chown [-R] [-h] [-v] [OWNER][:[GROUP]] FILE...` · `chgrp [-R] [-h] [-v] GROUP FILE...` |
| **Parameters** | `user:group` · `:group` (group only) · `-R` recursive · `-h` change a symlink itself · `--reference=RFILE` · `-c`/`-v` |
| **Example** | `sudo chown -R www-data:www-data /var/www/site/uploads` |
| **Expected output** | No output; with `-v`: `changed ownership of 'app.conf' from student:root to :lab-devs` |
| **Equivalent** | `icacls FILE /setowner USER` · `takeown /f FILE` |
| **Common errors** | `chown: changing ownership of 'f': Operation not permitted` (not root) · `invalid user` / `invalid group` (typo or account missing) |
| **Use case** | Giving a service account ownership of only its writable data directory. |
| **Docs** | <https://man7.org/linux/man-pages/man1/chown.1.html> · <https://man7.org/linux/man-pages/man1/chgrp.1.html> |

### umask

| Field | Detail |
|---|---|
| **OS** | All Linux (shell built-in). Ubuntu 24.04: `UMASK 022` in `/etc/login.defs`; `pam_umask` with `USERGROUPS_ENAB yes` gives `0002` to non-root users whose user name equals their primary group |
| **Description** | Shows or sets the mask of permission bits removed from newly created files (from `666`) and directories (from `777`) in the current shell and its children. |
| **Syntax** | `umask [-S] [MODE]` |
| **Parameters** | `-S` symbolic output (allowed bits) · `MODE` octal (`027`) or symbolic (`u=rwx,g=rx,o=`) |
| **Example** | `umask 027; touch f; mkdir d; ls -ld f d` |
| **Expected output** | `0002` · `u=rwx,g=rwx,o=rx` (with `-S`) · new file `640`, new directory `750` after `umask 027` |
| **Equivalent** | Windows has no umask; new items inherit `(OI)(CI)` ACEs from the parent folder |
| **Common errors** | Setting it in an interactive shell and expecting it to persist · default ACLs override the umask |
| **Use case** | `umask 077` at the top of a script that writes credentials. |
| **Docs** | <https://man7.org/linux/man-pages/man2/umask.2.html> · <https://man7.org/linux/man-pages/man8/pam_umask.8.html> |

### Special bits (setuid / setgid / sticky) and find -perm

| Field | Detail |
|---|---|
| **OS** | All Linux. Setting them needs ownership; auditing system paths needs root |
| **Description** | setuid (`4000`, `s` in user x) runs a program as its owner; setgid (`2000`) runs as its group or, on a directory, makes new entries inherit the group; sticky (`1000`, `t`) restricts deletion in shared directories. `find -perm` audits them. |
| **Syntax** | `chmod u+s / g+s / +t FILE` · `chmod 4755 / 2770 / 1777 FILE` · `find PATH -xdev -perm -4000` · `-perm /6000` · `-perm -o+w` |
| **Parameters** | `-perm MODE` exact · `-perm -MODE` all bits set · `-perm /MODE` any bit set · `-xdev` one filesystem · `-type f/d` |
| **Example** | <code>sudo find / -xdev -type f -perm /6000 2&gt;/dev/null &#124; sort</code> · <code>sudo chgrp devs /srv/team &amp;&amp; sudo chmod 2770 /srv/team</code> |
| **Expected output** | `/usr/bin/passwd`, `/usr/bin/sudo`, `/usr/bin/su`, `/usr/bin/chage`… (example list) · `drwxrws--- 2 root devs 4096 … /srv/team` |
| **Equivalent** | No setuid on Windows (services and UAC instead) · team folder = inheritable group ACE `(OI)(CI)M` |
| **Common errors** | Capital `S`/`T` (special bit without `x`) · setuid on shell scripts is ignored by Linux · numeric `chmod` keeps setgid on directories |
| **Use case** | Building a team directory; SUID baseline during hardening and incident response. |
| **Docs** | <https://man7.org/linux/man-pages/man1/chmod.1.html> · <https://man7.org/linux/man-pages/man1/find.1.html> · <https://man7.org/linux/man-pages/man7/inode.7.html> |

### getfacl / setfacl

| Field | Detail |
|---|---|
| **OS** | Linux with the `acl` package (installed on standard Ubuntu; `sudo apt install acl` on minimal images) and an ACL-capable filesystem (ext4, XFS, Btrfs) |
| **Description** | POSIX ACLs add named users and groups to a file's permissions, plus default ACLs that new files in a directory inherit. `getfacl -R` / `setfacl --restore` back up and restore owner, group, mode and ACLs. |
| **Syntax** | `getfacl [-R] [-p] [--omit-header] FILE...` · `setfacl [-R] [-d] -m ENTRIES FILE...` · `setfacl -x ENTRIES FILE` · `setfacl -b FILE` · `setfacl --restore=FILE` |
| **Parameters** | Entries `u:NAME:rwx`, `g:NAME:r-x`, `m::rw-`, `o::---`, `d:` prefix = default · `-m` modify · `-x` remove · `-b` remove all · `-k` remove default · `-d` default · `-R` recursive · `--test` dry run |
| **Example** | `sudo setfacl -R -m u:lab-audit:rX /srv/reports` · `getfacl -R project > perms.acl` |
| **Expected output** | `user::rw-` / `user:lab-audit:r--` / `group::r--` / `mask::r--` / `other::---` (example) |
| **Equivalent** | `icacls FILE /grant "USER:(R)"` · `Get-Acl` / `Set-Acl` · `icacls /save` and `/restore` |
| **Common errors** | `chmod g=` lowers the **mask** and silently reduces named entries (`#effective:`) · restoring from a different working directory · `Operation not supported` on filesystems without ACLs |
| **Use case** | Read-only access for an auditor without adding them to the team group. |
| **Docs** | <https://man7.org/linux/man-pages/man1/getfacl.1.html> · <https://man7.org/linux/man-pages/man1/setfacl.1.html> · <https://man7.org/linux/man-pages/man5/acl.5.html> |

### stat / namei / lsattr / chattr

| Field | Detail |
|---|---|
| **OS** | All Linux (`stat`: coreutils; `namei`: util-linux; `lsattr`/`chattr`: e2fsprogs, ext4-specific attributes) |
| **Description** | `stat` prints the exact octal mode and owner; `namei -l` shows permissions of every directory on a path; `lsattr`/`chattr` show and set attributes such as immutable (`i`) and append-only (`a`). |
| **Syntax** | `stat [-c FORMAT] FILE` · `namei -l PATH` · `lsattr FILE` · `chattr [+-=]ATTRS FILE` |
| **Parameters** | `stat -c '%a %A %U:%G %n'` · `chattr +i` immutable (root) · `chattr +a` append-only |
| **Example** | `stat -c '%a %U:%G %n' /etc/shadow` |
| **Expected output** | `640 root:shadow /etc/shadow` · `----i---------e------- locked.conf` (lsattr) |
| **Equivalent** | `Get-Acl` · <code>Get-Item FILE &#124; Select-Object Attributes</code> (read-only/hidden attributes) |
| **Common errors** | `rm: cannot remove 'f': Operation not permitted` as root (immutable flag set) |
| **Use case** | Finding the one directory on a path that lacks `x`; spotting attacker-set immutable files. |
| **Docs** | <https://man7.org/linux/man-pages/man1/stat.1.html> · <https://man7.org/linux/man-pages/man1/namei.1.html> · <https://man7.org/linux/man-pages/man1/chattr.1.html> |

## Processes & Services

### ps

| Field | Detail |
|---|---|
| **OS** | All Linux (procps-ng). Accepts BSD (`aux`), POSIX (`-ef`) and GNU (`--sort`) option styles |
| **Description** | Prints a one-time snapshot of processes read from `/proc`. `%CPU` is the average since the process started, not current usage. |
| **Syntax** | <code>ps [aux &#124; -ef] [-o FORMAT] [--sort=[-]KEY] [-p PID] [-u USER] [-C NAME] [--ppid PID]</code> |
| **Parameters** | `-e` every process · `-f` full format (PPID) · `-o pid,ppid,user,%cpu,%mem,stat,etime,cmd` custom columns · `--sort=-%cpu` sort descending · `-p` PIDs · `-u` user · `-C` command name · `--ppid` children |
| **Example** | <code>ps -eo pid,ppid,user,%cpu,%mem,stat,etime,cmd --sort=-%cpu &#124; head -5</code> |
| **Expected output** | `PID PPID USER %CPU %MEM STAT ELAPSED CMD` / `3322 3317 student 98.0 0.0 R 00:02 lab-cpu-hog …` (example) |
| **Equivalent** | `Get-Process` · `Get-CimInstance Win32_Process` · `tasklist` |
| **Common errors** | Reading `%CPU` as current usage · mixing styles (`ps -aux` warns or behaves differently) · `grep` matching itself (use `pgrep` or `grep [p]attern`) |
| **Use case** | Recording owner, parent and command line of a suspicious process in an incident ticket. |
| **Docs** | <https://man7.org/linux/man-pages/man1/ps.1.html> |

### top / htop

| Field | Detail |
|---|---|
| **OS** | `top`: all Linux (procps-ng). `htop`: separate package (in Ubuntu Server's `ubuntu-server` metapackage; otherwise `sudo apt install htop`) |
| **Description** | Live, sorted process view with load average, CPU and memory summary. `%CPU` is per core (Irix mode): 200% = two cores. |
| **Syntax** | `top [-b] [-n N] [-d SECONDS] [-p PID] [-u USER] [-o FIELD]` · `htop` |
| **Parameters** | `-b` batch (plain text) · `-n` iterations · `-d` delay · `-o %MEM` sort field · keys: `P` CPU, `M` memory, `1` per-CPU, `c` command line, `k` kill, `r` renice, `q` quit |
| **Example** | <code>top -b -n 1 -o %MEM &#124; head -15</code> |
| **Expected output** | Header (`top - 16:55:02 up 7:52, load average: 1.02, 0.61, 0.33`, Tasks, %Cpu(s), MiB Mem) then the process table (example) |
| **Equivalent** | Task Manager · Resource Monitor · two samples of `Get-Process` CPU |
| **Common errors** | First batch iteration shows averages; use `-n 2 -d 1` and read the second frame for current values |
| **Use case** | Confirming which process causes a high-load alert. |
| **Docs** | <https://man7.org/linux/man-pages/man1/top.1.html> · <https://htop.dev/> |

### pgrep / pkill

| Field | Detail |
|---|---|
| **OS** | All Linux (procps-ng) |
| **Description** | `pgrep` lists PIDs of processes matching a pattern; `pkill` sends them a signal (default `SIGTERM`). Patterns are extended regular expressions. Exit status 0 = match, 1 = none. |
| **Syntax** | <code>pgrep [-l &#124; -a] [-f] [-x] [-u USER] [-n &#124; -o] [-c] PATTERN</code> · `pkill [-SIGNAL] [-e] [-f] [-x] [-u USER] PATTERN` |
| **Parameters** | `-a` full command line · `-l` name · `-f` match full command line · `-x` exact name · `-u` effective user · `-n`/`-o` newest/oldest · `-c` count · `-e` (pkill) echo what was signalled |
| **Example** | `pgrep -af lab08-report.sh` then `pkill -f lab08-report.sh` |
| **Expected output** | `3561 bash /home/student/lab08/lab08-report.sh` (captured, user renamed) |
| **Equivalent** | `Get-Process -Name` · <code>Get-CimInstance Win32_Process &#124; Where-Object CommandLine -like '&#42;x&#42;'</code> · `Stop-Process` |
| **Common errors** | Broad `-f` patterns matching other users' or unrelated processes; always preview with `pgrep -a` |
| **Use case** | Stopping one runaway job by script name without touching others. |
| **Docs** | <https://man7.org/linux/man-pages/man1/pgrep.1.html> |

### kill / killall and signals

| Field | Detail |
|---|---|
| **OS** | All Linux. `kill` is a Bash built-in (also `/usr/bin/kill`, procps); `killall` is in psmisc |
| **Description** | Sends a signal to processes or jobs. `SIGTERM` (15, default) asks for a clean exit; `SIGKILL` (9) cannot be caught; `SIGHUP` (1) often means "reload"; `SIGSTOP`/`SIGCONT` freeze/resume. Killed processes exit with 128 + signal (143, 137). |
| **Syntax** | <code>kill [-s SIGNAL &#124; -SIGNAL] PID&#124;%JOB...</code> · `kill -l [N]` · `kill -0 PID` · `killall [-i] [-SIGNAL] NAME` |
| **Parameters** | `-TERM` `-HUP` `-KILL` `-STOP` `-CONT` `-USR1` · `-l` list/translate signals · `-0` existence and permission test · `killall -i` confirm |
| **Example** | `kill -TERM 3561; sleep 5; kill -0 3561 && kill -KILL 3561` |
| **Expected output** | No output on success; `kill: (3561) - No such process` if already gone |
| **Equivalent** | `Stop-Process -Id` (always forced) · `taskkill /PID n [/F] [/T]` |
| **Common errors** | `Operation not permitted` (another user's process) · `kill -9` first, losing clean-up · trying to kill a zombie (`Z`) or `D`-state process |
| **Use case** | Graceful-then-forced termination of a hung worker. |
| **Docs** | <https://man7.org/linux/man-pages/man1/kill.1.html> · <https://man7.org/linux/man-pages/man7/signal.7.html> · <https://man7.org/linux/man-pages/man1/killall.1.html> |

### jobs / bg / fg / nohup / timeout

| Field | Detail |
|---|---|
| **OS** | `jobs`, `bg`, `fg`, `disown`: Bash built-ins (interactive job control). `nohup`, `timeout`: coreutils |
| **Description** | `&` starts a background job; ++ctrl+z++ stops the foreground job; `bg`/`fg` resume it; `nohup`/`disown` keep jobs alive after logout; `timeout` limits run time. |
| **Syntax** | `cmd &` · `jobs [-l]` · `fg [%N]` · `bg [%N]` · `disown [%N]` · `nohup cmd > log 2>&1 &` · `timeout [-k D] DURATION cmd` |
| **Parameters** | `%N` job number · `%+`/`%-` current/previous job · `$!` last background PID · `timeout -k 5` add `SIGKILL` after 5 s; exit 124 = timed out |
| **Example** | `sleep 600 & jobs -l` |
| **Expected output** | `[1] 1230` / `[1]+  1230 Running                 sleep 600 &` (captured) |
| **Equivalent** | `Start-Job` · `Get-Job` · `Receive-Job` · `Stop-Job` · `cmd &` (PowerShell 7) |
| **Common errors** | Job lost when the SSH session closes (use `nohup`, `tmux` or a systemd unit) · `nohup.out` filling the disk |
| **Use case** | Running a long copy or capture over SSH safely. |
| **Docs** | <https://www.gnu.org/software/bash/manual/bash.html#Job-Control> · <https://man7.org/linux/man-pages/man1/nohup.1.html> · <https://man7.org/linux/man-pages/man1/timeout.1.html> |

### nice / renice

| Field | Detail |
|---|---|
| **OS** | All Linux. `nice`: coreutils; `renice`: util-linux (bsdutils on Ubuntu) |
| **Description** | Start a command with, or change, a nice value from −20 (highest priority) to 19 (lowest). Normal users can only increase the value of their own processes. |
| **Syntax** | `nice [-n N] cmd` · <code>renice [-n] N [-p PID... &#124; -u USER... &#124; -g PGRP...]</code> |
| **Parameters** | `-n` value/adjustment · `-p` process · `-u` all processes of a user · `-g` process group |
| **Example** | `renice -n 19 -p 3561` |
| **Expected output** | `3561 (process ID) old priority 0, new priority 19` (captured) |
| **Equivalent** | `(Get-Process -Id n).PriorityClass = 'BelowNormal'` |
| **Common errors** | `renice: failed to set priority for N (process ID): Permission denied` when lowering the value as a normal user |
| **Use case** | Keeping backups and report jobs from slowing interactive users. |
| **Docs** | <https://man7.org/linux/man-pages/man1/nice.1.html> · <https://man7.org/linux/man-pages/man1/renice.1.html> |

### systemctl

| Field | Detail |
|---|---|
| **OS** | systemd-based distributions (Ubuntu 15.04+, RHEL 7+). Needs systemd as PID 1 (not most containers; WSL2 only with `systemd=true`). Changes need root |
| **Description** | Inspects and controls systemd units: current state (active/inactive/failed) and boot-time enablement (enabled/disabled/static/masked). |
| **Syntax** | <code>systemctl [--now] {status&#124;start&#124;stop&#124;restart&#124;reload&#124;enable&#124;disable&#124;is-active&#124;is-enabled&#124;mask&#124;unmask&#124;cat&#124;show} UNIT</code> · `systemctl list-units --type=service [--state=failed]` · `systemctl --failed` · `systemctl daemon-reload` |
| **Parameters** | `--now` start/stop together with enable/disable · `--no-pager` · `-l`/`--full` full lines · `-p PROP` with `show` · `--type`, `--state` filters |
| **Example** | `systemctl status cron --no-pager` |
| **Expected output** | `● cron.service - Regular background program processing daemon` / `Loaded: loaded (…; enabled; preset: enabled)` / `Active: active (running) since …` (example) |
| **Equivalent** | `Get-Service` · `Start-/Stop-/Restart-Service` · `Set-Service -StartupType` · `sc.exe` |
| **Common errors** | `Unit X.service not found` (Ubuntu uses `ssh`, not `sshd`) · forgetting `daemon-reload` after editing · `disable` without `--now` · forgotten `mask` · `System has not been booted with systemd as init system` |
| **Use case** | Diagnosing and restarting a failed web service after a configuration change. |
| **Docs** | <https://man7.org/linux/man-pages/man1/systemctl.1.html> · <https://man7.org/linux/man-pages/man5/systemd.service.5.html> |

### journalctl -u

| Field | Detail |
|---|---|
| **OS** | systemd-based distributions. Full system journal needs `adm`/`systemd-journal` membership or root |
| **Description** | Reads the systemd journal; `-u` filters one service's messages, including systemd's own start/stop/failure lines. |
| **Syntax** | `journalctl [-u UNIT] [-n N] [-f] [-b [-1]] [--since T] [--until T] [-p PRIO] [-x] [-o FORMAT] [--no-pager]` |
| **Parameters** | `-u` unit · `-n` last N lines · `-f` follow · `-e` end of pager · `-b` this boot (`-b -1` previous) · `--since "1 hour ago"` · `-p err` priority and above · `-x` explanations · `-o short-iso`/`json` |
| **Example** | `journalctl -u lab08-web -n 20 --no-pager` |
| **Expected output** | `… lab08-web.service: Failed to locate executable /usr/bin/pyhton3: No such file or directory` / `… Main process exited, code=exited, status=203/EXEC` (example) |
| **Equivalent** | `Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'}` |
| **Common errors** | `No journal files were found` / partial output without group membership · forgetting `--no-pager` in scripts |
| **Use case** | Finding why a service failed to start. |
| **Docs** | <https://man7.org/linux/man-pages/man1/journalctl.1.html> |

## Storage

### df

| Field | Detail |
|---|---|
| **OS** | All Linux (GNU coreutils). `--output` is GNU-only and cannot be combined with `-P` |
| **Description** | Reports size, used, available space and use% (or inodes with `-i`) for each mounted filesystem, by asking the filesystem itself (`statfs`). `Use%` = Used ÷ (Used + Avail), rounded up; ext4's 5% root reserve is not in `Avail`. |
| **Syntax** | <code>df [-h &#124; -H] [-T] [-i] [-t TYPE] [-x TYPE] [-l] [--output=FIELDS] [FILE...]</code> |
| **Parameters** | `-h` human (1024) · `-H` (1000) · `-T` type · `-i` inodes · `-x tmpfs -x squashfs` exclude types · `-l` local only · `FILE` = only the filesystem holding it |
| **Example** | `df -hT -x tmpfs -x squashfs` · `df -i /var` |
| **Expected output** | `/dev/loop0  ext4  172M  24K  158M  1% /mnt/lab09` (captured, practice loop device) |
| **Equivalent** | `Get-Volume` · `Get-PSDrive -PSProvider FileSystem` · `Win32_LogicalDisk` |
| **Common errors** | Alerting on squashfs `/snap/*` (always 100%) · hanging on a dead NFS mount (use `df -l` or `timeout`) · forgetting inodes |
| **Use case** | First check for a "disk full" alert. |
| **Docs** | <https://man7.org/linux/man-pages/man1/df.1.html> |

### du

| Field | Detail |
|---|---|
| **OS** | All Linux (GNU coreutils) |
| **Description** | Walks directories and adds up the **allocated** size of the files it can read. Slow on large trees; incomplete without read permission. |
| **Syntax** | `du [-s] [-h] [-a] [-c] [-x] [-d N] [-t SIZE] [--apparent-size] [--exclude=PATTERN] [FILE...]` |
| **Parameters** | `-s` summary · `-h` human · `-d 1` one level · `-x` one filesystem · `-a` include files · `-t 100M` threshold · `--apparent-size` file length instead of blocks |
| **Example** | <code>sudo du -xh -d 1 /var 2&gt;/dev/null &#124; sort -rh &#124; head</code> |
| **Expected output** | `98M /mnt/lab09` · `73M /mnt/lab09/app` · `26M /mnt/lab09/backups` (captured) |
| **Equivalent** | <code>Get-ChildItem -Recurse -File -Force &#124; Measure-Object Length -Sum</code> |
| **Common errors** | `du /` without `-x` (counts `/proc` and other mounts) · `Permission denied` noise (run with `sudo`) · comparing with `ls -l` for sparse files |
| **Use case** | Drilling down from a full mount point to the directory and file responsible. |
| **Docs** | <https://man7.org/linux/man-pages/man1/du.1.html> |

### lsblk / blkid

| Field | Detail |
|---|---|
| **OS** | All Linux (util-linux). `lsblk` filesystem columns come from udev (may be empty in containers); `blkid` reads devices (root for uncached ones) |
| **Description** | `lsblk` prints disks, partitions, LVM volumes and loop devices as a tree with size, type and mount points; `blkid` prints filesystem `TYPE`, `UUID`, `LABEL` and `PARTUUID`. |
| **Syntax** | `lsblk [-f] [-d] [-p] [-o COLUMNS] [DEVICE...]` · `blkid [-s TAG] [-o value] [DEVICE...]` |
| **Parameters** | `-f` FSTYPE/LABEL/UUID/FSAVAIL/FSUSE% · `-d` disks only · `-o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,ROTA,MODEL` · `blkid -s UUID -o value DEV` UUID only |
| **Example** | `lsblk -f` · `sudo blkid -s UUID -o value /dev/sdb1` |
| **Expected output** | `/dev/loop0: LABEL="lab09data" UUID="68ba8b44-…" BLOCK_SIZE="4096" TYPE="ext4"` (captured) |
| **Equivalent** | `Get-Disk` · `Get-Partition` · `Get-Volume` |
| **Common errors** | Confusing a disk (`sda`) with a partition (`sda1`) before `mkfs` · NVMe partition names need `p` (`nvme0n1p1`) |
| **Use case** | Identifying a newly attached disk safely before partitioning it. |
| **Docs** | <https://man7.org/linux/man-pages/man8/lsblk.8.html> · <https://man7.org/linux/man-pages/man8/blkid.8.html> |

### findmnt

| Field | Detail |
|---|---|
| **OS** | All Linux (util-linux). `--real` needs util-linux 2.38+ (Ubuntu 24.04 has 2.39) |
| **Description** | Shows mounted filesystems as a tree from `/proc/self/mountinfo`; finds the filesystem holding a path; `--verify` checks `/etc/fstab`. |
| **Syntax** | `findmnt [-T PATH] [-t TYPES] [--real] [-o COLUMNS] [-n] [-r] [TARGET]` · `findmnt --verify [--tab-file FILE]` |
| **Parameters** | `-T` (`--target`) path · `-t ext4,xfs` types · `-o TARGET,SOURCE,FSTYPE,OPTIONS` · `-n` no header · `--verify` fstab check (exit 1 on errors) |
| **Example** | `findmnt -T /var/log` · `sudo findmnt --verify` |
| **Expected output** | `Success, no errors or warnings detected` (captured) · `[E] unreachable on boot required source: UUID=0000-bad` (captured, deliberately wrong line) |
| **Equivalent** | `Get-Volume -FilePath PATH` · `Get-Partition` (`AccessPaths`) · `mountvol` |
| **Common errors** | Rebooting after an fstab edit without `--verify` and `mount -a` |
| **Use case** | Confirming mount options such as `nodev,nosuid,noexec` on `/tmp` during a hardening audit. |
| **Docs** | <https://man7.org/linux/man-pages/man8/findmnt.8.html> |

### mount / umount / fstab

| Field | Detail |
|---|---|
| **OS** | All Linux (util-linux; systemd generates `.mount` units from `/etc/fstab`) |
| **Description** | `mount` attaches a filesystem to a directory, `umount` detaches it. `/etc/fstab` lists mounts for every boot: spec, mount point, type, options, dump, pass. |
| **Syntax** | `mount [-t TYPE] [-o OPTIONS] DEVICE DIR` · `mount -o remount,OPTIONS DIR` · `mount -a` · `umount DIR` |
| **Parameters** | `-o ro,noexec,nosuid,nodev` · `remount` · `-a` all fstab entries · fstab options `defaults`, `nofail`, `x-systemd.device-timeout=10s` |
| **Example** | `sudo mount -o ro,noexec /dev/sdb1 /mnt/evidence` · fstab: `UUID=…  /srv/data  ext4  defaults,nofail  0  2` |
| **Expected output** | `umount: /mnt/lab09: target is busy.` (captured; find the user with `fuser -vm`) |
| **Equivalent** | Drive letters (`Set-Partition -NewDriveLetter`) · `Mount-DiskImage` · `Add-PartitionAccessPath` |
| **Common errors** | fstab by `/dev/sdX` without `nofail` (emergency mode) · forgetting `systemctl daemon-reload` · `umount -l` hiding a busy filesystem |
| **Use case** | Adding a data disk that survives reboots and device renaming. |
| **Docs** | <https://man7.org/linux/man-pages/man8/mount.8.html> · <https://man7.org/linux/man-pages/man5/fstab.5.html> |

### lsof +L1 / fuser -vm

| Field | Detail |
|---|---|
| **OS** | All Linux (`lsof` package; `fuser` in psmisc) — both installed by default on Ubuntu |
| **Description** | `lsof +L1` lists open files with link count < 1 (**deleted but still open**), which keep using disk space; `fuser -vm DIR` lists processes using a mounted filesystem. |
| **Syntax** | `lsof +L1 [PATH]` · `lsof PATH` · `fuser -vm DIR` |
| **Parameters** | `+L1` link count below 1 · `-p PID` · `fuser -v` verbose · `-m` whole mounted filesystem |
| **Example** | <code>sudo lsof +L1 &#124; grep -E 'COMMAND&#124;/var/log'</code> |
| **Expected output** | `sleep 1055 root 3r REG 7,0 62914560 0 16 /mnt/lab09/app/logs/app.log (deleted)` (captured) |
| **Equivalent** | Resource Monitor → Associated Handles · Sysinternals `handle.exe` |
| **Common errors** | Running without `sudo` (other users' processes invisible) · deleting more files instead of restarting the owner |
| **Use case** | Explaining why deleting a 20 GB log freed no space. |
| **Docs** | <https://man7.org/linux/man-pages/man8/lsof.8.html> · <https://man7.org/linux/man-pages/man1/fuser.1.html> |

### pvs / vgs / lvs / lvextend

| Field | Detail |
|---|---|
| **OS** | Linux with LVM2 (default layout of the Ubuntu Server installer: `ubuntu-vg/ubuntu-lv`) |
| **Description** | Show physical volumes, volume groups (with free space `VFree`) and logical volumes; `lvextend -r` grows an LV and its filesystem online. |
| **Syntax** | `pvs` · `vgs` · `lvs` · <code>lvextend -r (-L +SIZE &#124; -l +100%FREE) VG/LV</code> |
| **Parameters** | `-r` (`--resizefs`) also resize the filesystem · `-L +10G` add size · `-l +100%FREE` all free extents |
| **Example** | `sudo vgs` then `sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv` |
| **Expected output** | `VG #PV #LV #SN Attr VSize VFree` / `ubuntu-vg 1 1 0 wz--n- <97.00g <48.50g` (example) |
| **Equivalent** | Storage Spaces (`Get-StoragePool`, `Get-VirtualDisk`) · `Resize-Partition` |
| **Common errors** | Growing the LV without `-r` (filesystem still small) · trying to shrink XFS (impossible) |
| **Use case** | Giving a new server's root filesystem the disk space the installer left unallocated. |
| **Docs** | <https://man7.org/linux/man-pages/man8/lvextend.8.html> · <https://man7.org/linux/man-pages/man8/vgs.8.html> |

### losetup / mkfs.ext4 / tune2fs / e2fsck

| Field | Detail |
|---|---|
| **OS** | All Linux (util-linux, e2fsprogs) |
| **Description** | `losetup` turns a file into a block device for safe practice; `mkfs.ext4` creates a filesystem (**destroys data**); `tune2fs -l` shows superblock data (reserved blocks, inode count); `e2fsck -n` checks an **unmounted** filesystem read-only. |
| **Syntax** | `losetup -f --show FILE` · `losetup -d DEV` · `mkfs.ext4 [-L LABEL] [-m PCT] [-N INODES] DEV` · `tune2fs -l DEV` · `e2fsck -n DEV` |
| **Parameters** | `-f --show` first free device, print it · `-L` label · `-m 1` 1% reserve · `-N` inode count · `-n` no changes |
| **Example** | `truncate -s 200M lab.img && sudo losetup -f --show lab.img` → `sudo mkfs.ext4 -L lab /dev/loop0` |
| **Expected output** | `/dev/loop0` · `Reserved block count: 2560` (captured) |
| **Equivalent** | VHDX + `Initialize-Disk`/`New-Partition`/`Format-Volume` · `Repair-Volume -Scan` · `chkdsk /scan` |
| **Common errors** | `mkfs` on the wrong device · `fsck` on a mounted filesystem · inode count cannot be raised later |
| **Use case** | Practising partitioning, formatting and fstab without risking a real disk. |
| **Docs** | <https://man7.org/linux/man-pages/man8/losetup.8.html> · <https://man7.org/linux/man-pages/man8/mke2fs.8.html> · <https://man7.org/linux/man-pages/man8/tune2fs.8.html> · <https://man7.org/linux/man-pages/man8/e2fsck.8.html> |

## Packages

### apt update / upgrade / full-upgrade

| Field | Detail |
|---|---|
| **OS** | Debian, Ubuntu (APT 2.8 on 24.04). Use `apt-get` in scripts (stable output) |
| **Description** | `update` refreshes and verifies repository indexes (installs nothing); `upgrade` installs newer versions without removing packages; `full-upgrade` may add or remove packages. |
| **Syntax** | `apt update` · `apt list --upgradable` · `apt upgrade [-s] [-y]` · `apt full-upgrade [-s] [-y]` |
| **Parameters** | `-s` simulate · `-y` assume yes · `apt-get -s upgrade` script preview |
| **Example** | <code>sudo apt update &amp;&amp; apt list --upgradable 2&gt;/dev/null &#124; grep -c -- -security</code> |
| **Expected output** | `apt/noble-updates,noble-security 2.8.4ubuntu0.1 amd64 [upgradable from: 2.8.3]` (captured) |
| **Equivalent** | `winget upgrade` · Windows Update · `dnf check-update` / `dnf upgrade` |
| **Common errors** | `Could not get lock /var/lib/dpkg/lock-frontend` (unattended-upgrades running: wait) · `NO_PUBKEY` · *kept back* / phased updates |
| **Use case** | Weekly patch review with a security-update count. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man8/apt.8.html> · <https://documentation.ubuntu.com/server/how-to/software/package-management/> |

### apt install / remove / purge / autoremove

| Field | Detail |
|---|---|
| **OS** | Debian, Ubuntu |
| **Description** | Install packages with dependencies (also local `./file.deb`); `remove` keeps conffiles (`rc`), `purge` deletes them; `autoremove` removes automatic dependencies nothing needs (and old kernels). |
| **Syntax** | <code>apt install [-s] [-y] [--no-install-recommends] PKG[=VER]... &#124; ./FILE.deb</code> · <code>apt remove &#124; purge &#124; autoremove [-s] [PKG]</code> |
| **Parameters** | `-s` simulate · `PKG=VERSION` exact version · `--only-upgrade` · `--no-install-recommends` |
| **Example** | `apt-get -s install tree && sudo apt install tree` |
| **Expected output** | `Inst tree (2.1.1-2ubuntu3.24.04.2 Ubuntu:24.04/noble-updates [amd64])` (captured) |
| **Equivalent** | `winget install` / `winget uninstall` · `dnf install` / `dnf remove` |
| **Common errors** | `dpkg -i` without dependency resolution · blind `autoremove -y` · `remove` instead of `purge` to reset configs |
| **Use case** | Installing a diagnostic tool with a simulated preview in a change ticket. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man8/apt-get.8.html> |

### apt search / show / policy

| Field | Detail |
|---|---|
| **OS** | Debian, Ubuntu (`apt-cache` equivalents for scripts) |
| **Description** | Find packages, show metadata (size, dependencies, `APT-Sources`), and show installed/candidate versions with their repositories and priorities. |
| **Syntax** | `apt search [--names-only] REGEX` · `apt show PKG` · `apt policy [PKG]` · `apt-cache madison PKG` · <code>apt-cache depends &#124; rdepends PKG</code> |
| **Parameters** | `--names-only` · `rdepends --installed` |
| **Example** | `apt policy openssh-server` |
| **Expected output** | `Installed: (none)` / `Candidate: 2.1.1-2ubuntu3.24.04.2` / `500 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 Packages` (captured for `tree`) |
| **Equivalent** | `winget search` · `winget show --id ID -e` · `dnf info` |
| **Common errors** | Piping `apt` output in scripts (unstable CLI warning) · package in a disabled component (`universe`) |
| **Use case** | Checking which repository a security fix will come from. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man8/apt.8.html> · <https://manpages.ubuntu.com/manpages/noble/man8/apt-cache.8.html> |

### apt-mark

| Field | Detail |
|---|---|
| **OS** | Debian, Ubuntu |
| **Description** | Holds packages at their version and sets or shows the manual/automatic install reason that `autoremove` uses. |
| **Syntax** | <code>apt-mark hold &#124; unhold &#124; showhold &#124; showmanual &#124; showauto &#124; manual &#124; auto [PKG...]</code> |
| **Parameters** | `hold` freeze · `showhold` list holds · `showmanual` baseline list · `auto`/`manual` change reason |
| **Example** | `sudo apt-mark hold postgresql-16` · `apt-mark showmanual > manual-packages.txt` |
| **Expected output** | `tree set on hold.` · `dpkg -l` status `hi` (captured) |
| **Equivalent** | `winget pin add --id ID` · `dnf versionlock` (plugin) |
| **Common errors** | Forgotten holds becoming unpatched packages · a needed tool marked `auto` and autoremoved |
| **Use case** | Freezing a database version until a planned upgrade window. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man8/apt-mark.8.html> |

### dpkg -l / -L / -S / -s / --verify

| Field | Detail |
|---|---|
| **OS** | Debian, Ubuntu (dpkg 1.22 on 24.04) |
| **Description** | Queries the installed-package database: list with status, files of a package, owner of a file, metadata, and checksum verification of installed files. |
| **Syntax** | `dpkg -l [PATTERN]` · `dpkg -L PKG` · `dpkg -S PATH` · `dpkg -s PKG` · `dpkg --verify [PKG]` · `dpkg-query -W -f='${Package}\t${Version}\n'` |
| **Parameters** | Status letters `ii`, `rc`, `hi`, `iU`/`iF` · `--verify` flags `??5??????` (checksum) and `c` (conffile) |
| **Example** | `dpkg -S /usr/bin/ls` · `dpkg --verify openssh-server` |
| **Expected output** | `coreutils: /usr/bin/ls` · `??5?????? c /etc/lab10-hello/hello.conf` (captured) |
| **Equivalent** | Uninstall registry keys · `Get-AuthenticodeSignature` · `rpm -qa / -ql / -qf / -V` |
| **Common errors** | `dpkg -L` with a path (it takes a package name) · `--verify` exits 0 even when it prints differences |
| **Use case** | Spotting a modified binary or an executable that no package owns during an investigation. |
| **Docs** | <https://man7.org/linux/man-pages/man1/dpkg.1.html> · <https://man7.org/linux/man-pages/man1/dpkg-query.1.html> |

### snap

| Field | Detail |
|---|---|
| **OS** | Ubuntu (snapd installed by default); available on other distributions |
| **Description** | Self-contained, confined packages from the Snap Store that update automatically and keep previous revisions; mounted read-only (squashfs) under `/snap`. |
| **Syntax** | `snap list` · `snap info NAME` · `snap install NAME` · `snap refresh [--list]` · `snap revert NAME` · `snap remove NAME` · `snap changes` |
| **Parameters** | `--channel=stable` · `refresh --hold=24h` · `list --all` (old revisions) |
| **Example** | `snap list` · `sudo snap revert firefox` |
| **Expected output** | `Name Version Rev Tracking Publisher Notes` / `firefox 132.0 5187 latest/stable mozilla✓ -` (example) |
| **Equivalent** | `winget` / Microsoft Store apps (`Get-AppxPackage`) |
| **Common errors** | Disk alerts on `/snap/*` squashfs mounts · expecting `apt` to manage snaps |
| **Use case** | Rolling back a snap after a broken automatic refresh. |
| **Docs** | <https://snapcraft.io/docs> |

### dnf / rpm (RHEL family)

| Field | Detail |
|---|---|
| **OS** | RHEL 8/9, Rocky, AlmaLinux, Fedora (`yum` on RHEL 7) — **not Ubuntu** |
| **Description** | `dnf` resolves dependencies from repositories, keeps a transaction history with undo; `rpm` queries and verifies the installed-package database. |
| **Syntax** | `dnf check-update` · `dnf upgrade` · <code>dnf install &#124; remove PKG</code> · `dnf info PKG` · `dnf provides PATH` · `dnf history [undo N]` · <code>rpm -qa &#124; -qi PKG &#124; -ql PKG &#124; -qf PATH &#124; -V PKG</code> |
| **Parameters** | `check-update` exits **100** when updates exist · `--security` (with update info) |
| **Example** | `rpm -qf /usr/sbin/sshd` |
| **Expected output** | `openssh-server-8.7p1-38.el9.x86_64` (example) |
| **Equivalent** | `apt list --upgradable`, `dpkg -S`, `dpkg -L` · `winget` |
| **Common errors** | Treating exit code 100 from `check-update` as a failure in scripts |
| **Use case** | Patching a mixed Ubuntu/RHEL estate with the same process. |
| **Docs** | <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_software_with_the_dnf_tool/index> |

## Networking

IP configuration (Day 11) and connectivity testing (Day 12). `ip` comes from **iproute2** (always installed). `traceroute` and `mtr-tiny` may need `sudo apt install traceroute mtr-tiny`. `ifconfig`, `route`, `arp` and `netstat` (net-tools) are obsolete and not installed by default on Ubuntu 24.04.

### ip addr

| Field | Detail |
|---|---|
| **OS** | All modern Linux (iproute2) |
| **Description** | Shows, adds and removes IP addresses per interface, with prefix, scope, `dynamic` (DHCP/SLAAC) flag and lifetimes. Changes are **runtime only**. |
| **Syntax** | <code>ip [-4 &#124; -6] [-br] [-o] [-j] addr show [dev IFACE]</code> · `ip addr add ADDR/PREFIX dev IFACE` · `ip addr del ADDR/PREFIX dev IFACE` |
| **Parameters** | `-br` one line per interface · `-o` one line per address · `-j` JSON · `-4`/`-6` family · `secondary`, `dynamic`, `valid_lft` in output |
| **Example** | `ip -br addr` · `sudo ip addr add 192.168.56.21/24 dev enp0s8` |
| **Expected output** | `eth0@if7  UP  192.168.50.10/24` (captured) |
| **Equivalent** | `Get-NetIPAddress` · `ipconfig` |
| **Common errors** | Forgetting `/PREFIX` (address becomes `/32`) · `Error: ipv4: Address already assigned.` · expecting the change to survive a reboot |
| **Use case** | First command of every network ticket: which addresses does this host really have? |
| **Docs** | <https://man7.org/linux/man-pages/man8/ip-address.8.html> |

### ip link

| Field | Detail |
|---|---|
| **OS** | All modern Linux (iproute2) |
| **Description** | Interface names, state (`UP`, `LOWER_UP` = carrier), MAC, MTU; with `-s` counters (errors, drops); with `-d` driver/VLAN details. Can set links up/down and change the MTU (runtime). |
| **Syntax** | `ip [-br] [-s] [-d] link show [dev IFACE]` · <code>ip link set dev IFACE up&#124;down&#124;mtu N</code> |
| **Parameters** | `-br` brief · `-s` statistics · `-d` details · `mtu N` |
| **Example** | `ip -s link show dev enp0s3` |
| **Expected output** | `RX: bytes packets errors dropped missed mcast` / `378 5 0 0 0 0` (captured) |
| **Equivalent** | `Get-NetAdapter` · `Get-NetAdapterStatistics` |
| **Common errors** | Running `ip link set ... down` on the interface you are connected through (lockout) |
| **Use case** | Separating cabling/driver problems (errors, no carrier) from IP problems. |
| **Docs** | <https://man7.org/linux/man-pages/man8/ip-link.8.html> |

### ip route / ip route get

| Field | Detail |
|---|---|
| **OS** | All modern Linux (iproute2) |
| **Description** | Shows and changes the routing table (`default via GW`, connected routes `proto kernel`, metrics); `ip route get ADDR` prints the kernel's decision: next hop, interface and source address. |
| **Syntax** | `ip [-6] route [show [table T]]` · `ip route get ADDR` · <code>ip route add &#124; replace &#124; del PREFIX via GW [dev IFACE] [metric N]</code> |
| **Parameters** | `via` next hop · `dev` interface · `metric` preference · `replace` add-or-overwrite · `table local` local/broadcast entries |
| **Example** | `ip route get 10.20.0.20` · `sudo ip route replace default via 192.168.50.1` |
| **Expected output** | `10.20.0.20 via 192.168.50.1 dev eth0 src 192.168.50.10 uid 1000` (format captured) |
| **Equivalent** | `Get-NetRoute` · `Find-NetRoute -RemoteIPAddress` · `route print` |
| **Common errors** | `Error: Nexthop has invalid gateway.` (gateway not on a connected subnet) · `RTNETLINK answers: Network is unreachable` (no route) · `RTNETLINK answers: File exists` (use `replace`) |
| **Use case** | Proving which interface and source address a VPN-connected laptop uses for a destination. |
| **Docs** | <https://man7.org/linux/man-pages/man8/ip-route.8.html> |

### ip neigh

| Field | Detail |
|---|---|
| **OS** | All modern Linux (iproute2) |
| **Description** | ARP (IPv4) / neighbour discovery (IPv6) cache: IP → MAC with state `REACHABLE`, `STALE`, `DELAY`, `INCOMPLETE`, `FAILED`, `PERMANENT`. |
| **Syntax** | <code>ip [-4 &#124; -6] neigh show [dev IFACE] [ADDR]</code> · `ip neigh flush dev IFACE` |
| **Parameters** | `show ADDR` one entry · `flush` clear dynamic entries (root) |
| **Example** | `ip neigh show 192.168.50.1` |
| **Expected output** | `192.168.50.1 dev eth0 lladdr 4e:48:a5:bb:48:6e REACHABLE` (captured) |
| **Equivalent** | `Get-NetNeighbor` · `arp -a` |
| **Common errors** | Ignoring `FAILED` for the gateway and debugging DNS instead |
| **Use case** | Spotting a wrong gateway address, a wrong VLAN or ARP spoofing (gateway MAC changes). |
| **Docs** | <https://man7.org/linux/man-pages/man8/ip-neighbour.8.html> |

### netplan

| Field | Detail |
|---|---|
| **OS** | Ubuntu (netplan.io; 1.1 on 24.04) |
| **Description** | Persistent network configuration from YAML in `/etc/netplan/*.yaml`, rendered for systemd-networkd (servers) or NetworkManager (desktops). |
| **Syntax** | `netplan get [KEY]` · `netplan generate [--root-dir DIR]` · `netplan try [--timeout N]` · `netplan apply` · `netplan status` |
| **Parameters** | `try` applies with automatic rollback (default 120 s) · `generate --root-dir` validates a file in a scratch tree |
| **Example** | `sudo netplan generate && sudo netplan try` |
| **Expected output** | `Error in network definition: address '192.168.56.20' is missing /prefixlength` for a bad file (captured) |
| **Equivalent** | `New-NetIPAddress` / `Set-NetIPInterface` (persistent store) |
| **Common errors** | Tabs/uneven indentation · missing prefix · deprecated `gateway4:` · `Permissions ... are too open` (use mode 600) · `apply` over SSH without `try` |
| **Use case** | Giving a new server its static address so that it survives reboots. |
| **Docs** | <https://netplan.readthedocs.io/en/stable/> · <https://documentation.ubuntu.com/server/explanation/networking/about-netplan/> |

### nmcli / networkctl

| Field | Detail |
|---|---|
| **OS** | `nmcli`: Ubuntu Desktop (NetworkManager) · `networkctl`: Ubuntu Server (systemd-networkd) |
| **Description** | Show and control the network service that owns an interface: devices, connection profiles, DHCP renew. |
| **Syntax** | `nmcli device status` · `nmcli connection show` · `nmcli connection modify ID ipv4.method manual ipv4.addresses A/P ipv4.gateway G` · `networkctl status [IFACE]` · `networkctl renew IFACE` |
| **Parameters** | `-f IP4` fields (nmcli) · `renew` new DHCP lease (networkctl) |
| **Example** | `nmcli -f IP4 device show enp0s3` |
| **Expected output** | `IP4.ADDRESS[1]: 10.0.2.15/24` / `IP4.GATEWAY: 10.0.2.2` (example) |
| **Equivalent** | `Get-NetIPConfiguration` · `ipconfig /renew` |
| **Common errors** | Using netplan on a desktop device managed by NetworkManager (or nmcli on a server) |
| **Use case** | Renewing a laptop's DHCP lease without rebooting. |
| **Docs** | <https://networkmanager.dev/docs/api/latest/nmcli.html> · <https://man7.org/linux/man-pages/man1/networkctl.1.html> |

### ping

| Field | Detail |
|---|---|
| **OS** | All Linux (iputils-ping 20240117 on 24.04; not setuid, uses `cap_net_raw`) |
| **Description** | Sends ICMP echo requests; reports replies, TTL, RTT, loss and `mdev` jitter. Exit status 0 = reply received, 1 = no reply, 2 = other error. |
| **Syntax** | <code>ping [-c N] [-i SEC] [-W SEC] [-w SEC] [-s BYTES] [-M do&#124;want&#124;dont] [-t TTL] [-I IFACE&#124;ADDR] [-4&#124;-6] [-q] HOST</code> |
| **Parameters** | `-c` count · `-W` per-reply timeout · `-w` deadline · `-M do -s 1472` MTU test · `-t 1` first router · `-q` summary |
| **Example** | `ping -c1 -W1 -q 10.20.0.20 >/dev/null && echo up` |
| **Expected output** | `64 bytes from 10.20.0.20: icmp_seq=1 ttl=63 time=0.045 ms` (captured) |
| **Equivalent** | `Test-Connection` · `ping.exe` |
| **Common errors** | No `-c` in scripts (never ends) · declaring a host down because ICMP is filtered · `Temporary failure in name resolution` is DNS (exit 2) |
| **Use case** | Gateway and end-to-end reachability check at the start of a ticket. |
| **Docs** | <https://man7.org/linux/man-pages/man8/ping.8.html> |

### traceroute / tracepath

| Field | Detail |
|---|---|
| **OS** | `traceroute` 2.1.5 (package traceroute) · `tracepath` (iputils-tracepath) |
| **Description** | List the routers on the path using increasing TTLs. `traceroute` uses UDP by default (`-I` ICMP, `-T` TCP SYN, both usually need root); `tracepath` needs no root and reports the **path MTU**. |
| **Syntax** | <code>traceroute [-n] [-I&#124;-T&#124;-U] [-p PORT] [-q N] [-w SEC] [-m MAX] HOST</code> · `tracepath [-n] [-m MAX] HOST` |
| **Parameters** | `-n` numeric · `-T -p 443` TCP to the service port · `-q 1` one probe per hop · annotations `!H !N !X !F` |
| **Example** | `sudo traceroute -n -T -p 443 HOST` · `tracepath -n HOST` |
| **Expected output** | `Resume: pmtu 1400 hops 2 back 2` (captured) |
| **Equivalent** | `tracert` · `Test-Connection -Traceroute` (7) · `Test-NetConnection -TraceRoute` |
| **Common errors** | Treating `* * *` on an intermediate hop as an outage · *You do not have enough privileges to use this traceroute method* (use sudo) |
| **Use case** | Showing where a path stops or where the MTU drops. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man8/traceroute.db.8.html> · <https://man7.org/linux/man-pages/man8/tracepath.8.html> |

### mtr

| Field | Detail |
|---|---|
| **OS** | Linux (mtr-tiny on servers, mtr on desktops; 0.95 on 24.04) |
| **Description** | Continuous traceroute with per-hop loss, latency and deviation; report mode gives static text for tickets. |
| **Syntax** | <code>mtr [-r&#124;--report] [-w] [-c N] [-n] [-b] [-T&#124;-u] [-P PORT] HOST</code> |
| **Parameters** | `-r -c 100` report with 100 cycles · `-n` numeric · `-T -P 443` TCP · `-w` wide · `-z` AS numbers |
| **Example** | `mtr -rn -c 100 HOST` |
| **Expected output** | <code>2.&#124;-- 10.20.0.20  22.0%  50  0.1  0.1  0.1  0.1  0.0</code> (captured, induced loss) |
| **Equivalent** | `pathping` |
| **Common errors** | Escalating loss that appears only at an intermediate hop (rate limiting) |
| **Use case** | Evidence for an ISP escalation. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man8/mtr.8.html> |

### nc -zv / curl (connection tests)

| Field | Detail |
|---|---|
| **OS** | Ubuntu (netcat-openbsd and curl installed by default) |
| **Description** | `nc -zv` tests whether a TCP port accepts connections (succeeded / refused / timed out). `curl -v` tests the application (DNS, connect, TLS, HTTP); `-w` prints per-phase timings. |
| **Syntax** | `nc -zv [-w SEC] [-u] HOST PORT` · `curl [-v] [-I] [-sS] [-o FILE] [--connect-timeout SEC] [-m SEC] [-w FORMAT] URL` |
| **Parameters** | `-z` connect only · `-w` timeout (nc) · `%{time_connect}`, `%{time_starttransfer}`, `%{http_code}` (curl) |
| **Example** | `nc -zv -w2 10.20.0.20 8080` |
| **Expected output** | `Connection to 10.20.0.20 8080 port [tcp/http-alt] succeeded!` · `nc: connect to 10.20.0.20 port 8443 (tcp) failed: Connection refused` (captured) |
| **Equivalent** | `Test-NetConnection -Port` · `Test-Connection -TcpPort` (7) · `Invoke-WebRequest` / `curl.exe` |
| **Common errors** | Trusting UDP "success" (`-u`) · confusing refused (nothing listening) with timed out (filtered) |
| **Use case** | Proving that the path works and the problem is the service (refused) or a firewall (timeout). |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man1/nc_openbsd.1.html> · <https://curl.se/docs/manpage.html> |

## DNS

### dig

| Field | Detail |
|---|---|
| **OS** | All Linux (package `bind9-dnsutils`; BIND 9.18 on Ubuntu 24.04) |
| **Description** | Sends one DNS query and prints the full response: status, flags (`qr aa tc rd ra ad cd`), answer/authority/additional sections, server and query time. Ignores `/etc/hosts` and the `search` list (unless `+search`). |
| **Syntax** | `dig [@SERVER] [-x ADDR] NAME [TYPE] [+short] [+noall +answer +comments +authority +stats] [+norecurse] [+trace] [+tcp] [+dnssec] [+search] [+timeout=SEC] [+tries=N]` |
| **Parameters** | `@SERVER` · `TYPE` (A, AAAA, MX, NS, SOA, TXT, SRV, CAA, PTR) · `-x` reverse · `+short` · `+norecurse` (authority/cache test) · `+trace` · `+tcp` |
| **Example** | `dig @192.168.13.54 www.corp.example +norecurse +noall +comments +answer` |
| **Expected output** | `;; flags: qr aa; …` / `www.corp.example. 300 IN A 192.168.13.80` (captured, Lab 13) |
| **Equivalent** | `Resolve-DnsName -Server … -DnsOnly` · `nslookup` |
| **Common errors** | Treating exit code 0 as success (NXDOMAIN and SERVFAIL also exit 0; exit 9 = no reply) · `dig www` without `+search` · forgetting `dig` bypasses `/etc/hosts` |
| **Use case** | Proving which server returns which answer, with status and TTL, for a ticket. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man1/dig.1.html> |

### host

| Field | Detail |
|---|---|
| **OS** | All Linux (package `bind9-host`, pulled in by `bind9-dnsutils`) |
| **Description** | Short, readable forward and reverse lookups; uses the `search` list; exits 1 when the name is not found. Ignores `/etc/hosts`. |
| **Syntax** | <code>host [-t TYPE] [-W SEC] [-v] NAME&#124;ADDRESS [SERVER]</code> |
| **Parameters** | `-t MX` type · `-W` timeout · `-v` verbose (dig-like) |
| **Example** | `host -t mx corp.example` |
| **Expected output** | `corp.example mail is handled by 10 mail.corp.example.` · `Host nosuch.corp.example not found: 3(NXDOMAIN)` (captured) |
| **Equivalent** | `Resolve-DnsName NAME -Type MX` |
| **Common errors** | Assuming it shows what applications see (it does not read `/etc/hosts`) |
| **Use case** | Quick checks and simple scripts. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man1/host.1.html> |

### nslookup

| Field | Detail |
|---|---|
| **OS** | Linux (`bind9-dnsutils`) and Windows (`nslookup.exe`) |
| **Description** | One-shot or interactive DNS lookups; "Non-authoritative answer" = from a resolver. Ignores the hosts file and the system cache. |
| **Syntax** | <code>nslookup [-type=TYPE] [-timeout=SEC] NAME&#124;ADDRESS [SERVER]</code> |
| **Parameters** | `-type=soa`, `-type=mx`, `-type=caa` · optional server |
| **Example** | `nslookup -type=soa corp.example` |
| **Expected output** | `origin = ns1.corp.example` · `serial = 2026111301` · `minimum = 60` (captured) |
| **Equivalent** | `dig` · `Resolve-DnsName` |
| **Common errors** | Parsing its text in scripts · reading `Server: UnKnown` (Windows) as a fault — it only means the server has no PTR |
| **Use case** | A command that works the same on Linux and Windows in mixed teams. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man1/nslookup.1.html> |

### resolvectl

| Field | Detail |
|---|---|
| **OS** | Linux with systemd-resolved (Ubuntu default; systemd 255 on 24.04). Not present in many containers or on Alpine |
| **Description** | Shows the real DNS servers, search domains and resolv.conf mode per link; resolves through resolved; flushes and inspects its cache. |
| **Syntax** | `resolvectl status [LINK]` · `resolvectl dns` · `resolvectl domain` · `resolvectl query [-t TYPE] [--cache=no] NAME` · `resolvectl flush-caches` · `resolvectl statistics` · `resolvectl show-cache` (254+) |
| **Parameters** | `-t` type · `--cache=no` bypass the cache · `flush-caches`/`show-cache` need sudo |
| **Example** | `resolvectl status` |
| **Expected output** | `resolv.conf mode: stub` · `Current DNS Server: 192.168.13.53` (example) |
| **Equivalent** | `Get-DnsClientServerAddress` · `Clear-DnsClientCache` · `Get-DnsClientCache` |
| **Common errors** | Reading `/etc/resolv.conf` (`127.0.0.53`) and thinking it is the real server · *command not found* where systemd-resolved is not used |
| **Use case** | Finding which upstream servers an Ubuntu machine really uses. |
| **Docs** | <https://man7.org/linux/man-pages/man1/resolvectl.1.html> · <https://man7.org/linux/man-pages/man8/systemd-resolved.service.8.html> |

### getent hosts / ahosts

| Field | Detail |
|---|---|
| **OS** | All glibc Linux (libc-bin) |
| **Description** | Resolves through the Name Service Switch exactly like applications (`/etc/hosts`, mDNS, DNS). `ahosts` uses `getaddrinfo()` and lists every address. Exit 0 found, 2 not found. |
| **Syntax** | <code>getent hosts&#124;ahosts&#124;ahostsv4&#124;ahostsv6 NAME&#124;ADDRESS</code> |
| **Parameters** | `hosts` first match · `ahosts` all · `ahostsv4`/`ahostsv6` one family |
| **Example** | `getent ahosts app.corp.example` |
| **Expected output** | `192.168.13.99 app.corp.example app` while `dig` says `192.168.13.80` (captured, stale hosts entry) |
| **Equivalent** | `Resolve-DnsName NAME` (default path) · `[System.Net.Dns]::GetHostAddresses()` |
| **Common errors** | Expecting it to report NXDOMAIN vs SERVFAIL (it only says found / not found) · AAAA missing on IPv4-only hosts (`AI_ADDRCONFIG`) |
| **Use case** | Explaining why the application and `dig` disagree. |
| **Docs** | <https://man7.org/linux/man-pages/man1/getent.1.html> |

### /etc/hosts and /etc/nsswitch.conf

| Field | Detail |
|---|---|
| **OS** | All Linux |
| **Description** | `/etc/hosts` maps names to addresses statically and is checked before DNS when `nsswitch.conf` says `hosts: files … dns`. |
| **Syntax** | hosts: `ADDRESS NAME [ALIAS...]` · nsswitch: `hosts: files mdns4_minimal [NOTFOUND=return] dns` (Ubuntu desktop) / `files dns` (server) |
| **Parameters** | First matching hosts line wins · `[NOTFOUND=return]` stops after mDNS for `.local` |
| **Example** | `grep app /etc/hosts ; grep '^hosts:' /etc/nsswitch.conf` |
| **Expected output** | `192.168.13.99 app.corp.example app   # added during the 2025 migration` (captured, lab fault) |
| **Equivalent** | `C:\Windows\System32\drivers\etc\hosts` |
| **Common errors** | Forgotten test entries overriding DNS · editing without a backup |
| **Use case** | Temporary, documented overrides; detecting tampering (`sha256sum /etc/hosts`). |
| **Docs** | <https://man7.org/linux/man-pages/man5/hosts.5.html> · <https://man7.org/linux/man-pages/man5/nsswitch.conf.5.html> |

### /etc/resolv.conf

| Field | Detail |
|---|---|
| **OS** | All Linux; on Ubuntu a symlink managed by systemd-resolved |
| **Description** | `nameserver`, `search` and `options` for the resolver library. On Ubuntu it links to `stub-resolv.conf` (`127.0.0.53`, stub mode); other modes: uplink (`/run/systemd/resolve/resolv.conf`), static (`/usr/lib/systemd/resolv.conf`), foreign (a regular file). |
| **Syntax** | `nameserver ADDR` (max 3) · `search DOMAIN...` · `options timeout:N attempts:N edns0 trust-ad` |
| **Parameters** | `ls -l /etc/resolv.conf` shows the mode |
| **Example** | `ls -l /etc/resolv.conf ; grep -v '^#' /etc/resolv.conf` |
| **Expected output** | `/etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf` · `nameserver 127.0.0.53` (example) |
| **Equivalent** | `Get-DnsClientServerAddress` · `Get-DnsClientGlobalSetting` |
| **Common errors** | Editing it by hand on Ubuntu (change lost) — use Netplan `nameservers:` |
| **Use case** | Knowing which server `dig` asks by default. |
| **Docs** | <https://man7.org/linux/man-pages/man5/resolv.conf.5.html> |

## Ports & Sockets

### ss (socket statistics)

| Field | Detail |
|---|---|
| **OS** | Ubuntu 24.04 (iproute2, installed by default) · any modern Linux |
| **Description** | Lists sockets from the kernel (netlink sock_diag): listeners, connections, TCP states, owning processes, timers and TCP internals. Replaces `netstat`. |
| **Syntax** | <code>ss [-t] [-u] [-l&#124;-a] [-n] [-p] [-4&#124;-6] [-H] [-o] [-e] [-i] [-s] [-K] [state STATE] [EXPRESSION]</code> |
| **Parameters** | `-tulnp` listeners with owners · `state established` / `close-wait` / `time-wait` · `'( dport = :443 or sport = :443 )'` · `'dst 10.0.0.0/8'` · `-H` no header · `-o` timers · `-e` uid/inode · `-i` RTT/cwnd · `-s` summary · `-K` force-close (root, destructive) |
| **Example** | `sudo ss -ltnp 'sport = :443'` |
| **Expected output** | <code>LISTEN 0      5            0.0.0.0:443       0.0.0.0:*    users:(("python3",pid=1125,fd=3))</code> (captured, Lab 14) |
| **Equivalent** | `Get-NetTCPConnection` · `Get-NetUDPEndpoint` · `netstat -ano` |
| **Common errors** | Empty process column without `sudo` · forgetting `-n` · unquoted expressions · with a state filter the State column is omitted (field numbers shift) |
| **Use case** | "Who owns port 443?", exposure audits, CLOSE-WAIT leaks, accept-queue overflows (LISTEN `Recv-Q` ≥ `Send-Q`). |
| **Docs** | <https://man7.org/linux/man-pages/man8/ss.8.html> |

### netstat (net-tools, legacy)

| Field | Detail |
|---|---|
| **OS** | Linux, package net-tools — **not installed** by default on Ubuntu 24.04 (`sudo apt install net-tools`) |
| **Description** | Legacy socket listing that reads `/proc/net/*`; states are written with underscores (`TIME_WAIT`). Windows `netstat.exe` is a different program with different options. |
| **Syntax** | <code>netstat [-t] [-u] [-l&#124;-a] [-n] [-p] [-s]</code> |
| **Parameters** | `-tulnp` listeners with PID/program · `-tan` all TCP · `-s` protocol statistics |
| **Example** | `sudo netstat -tlnp` |
| **Expected output** | `tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      1125/python3` (captured) |
| **Equivalent** | `ss -tulnp` · `netstat -ano` (Windows) |
| **Common errors** | `netstat: command not found` on Ubuntu 24.04 · slow with many sockets |
| **Use case** | Reading old runbooks and other Unix systems; prefer `ss`. |
| **Docs** | <https://man7.org/linux/man-pages/man8/netstat.8.html> |

### lsof -i

| Field | Detail |
|---|---|
| **OS** | Ubuntu 24.04 (package lsof) |
| **Description** | Lists network sockets as open files of processes: find the process behind a port, or all sockets of a process. |
| **Syntax** | <code>lsof [-n] [-P] -i &#91;4&#124;6&#93;&#91;PROTO&#93;&#91;@HOST&#93;&#91;:PORT&#93; [-sTCP:STATE] [-a -p PID]</code> |
| **Parameters** | `-nP` numeric · `-iTCP:443 -sTCP:LISTEN` listeners on 443 · `-i @10.14.0.20` sockets to a host · `-a -p PID -i` sockets of one process |
| **Example** | `sudo lsof -nP -iTCP:443 -sTCP:LISTEN` |
| **Expected output** | `python3 1125 nobody    3u  IPv4   5581      0t0  TCP *:443 (LISTEN)` (captured) |
| **Equivalent** | `Get-NetTCPConnection -LocalPort 443` + `Get-Process` |
| **Common errors** | No output without `sudo` for other users' processes · slow on busy hosts |
| **Use case** | Mapping an outbound connection (`local->remote`) to its process during an investigation. |
| **Docs** | <https://manpages.ubuntu.com/manpages/noble/man8/lsof.8.html> |

### fuser

| Field | Detail |
|---|---|
| **OS** | Ubuntu 24.04 (package psmisc) |
| **Description** | Shows which processes use a port (or a file / mount). |
| **Syntax** | <code>fuser [-v] -n tcp&#124;udp PORT</code> · `fuser [-v] PORT/tcp` |
| **Parameters** | `-v` verbose (USER, PID, ACCESS, COMMAND) · `-n tcp` namespace · `-k` **kills** the processes (never during an investigation) |
| **Example** | `sudo fuser -v -n tcp 443` |
| **Expected output** | `443/tcp:             nobody     1125 F.... python3` (captured) |
| **Equivalent** | `Get-NetTCPConnection -LocalPort 443` (`OwningProcess`) |
| **Common errors** | `fuser: command not found` (install psmisc) · using `-k` and destroying evidence |
| **Use case** | Quick PID lookup in scripts (`fuser -n tcp 443` prints PIDs only). |
| **Docs** | <https://man7.org/linux/man-pages/man1/fuser.1.html> |

### /etc/services, /proc/net/tcp and ip_local_port_range

| Field | Detail |
|---|---|
| **OS** | Any Linux (`/etc/services` from package netbase) |
| **Description** | `/etc/services` maps port numbers to conventional names; `/proc/net/tcp`, `tcp6`, `udp`, `udp6` are the kernel's raw socket tables (hex address:port, state, uid, inode); `net.ipv4.ip_local_port_range` is the ephemeral port range (32768–60999). |
| **Syntax** | <code>getent services NAME&#124;PORT[/PROTO]</code> · `cat /proc/net/tcp` · `sysctl net.ipv4.ip_local_port_range` |
| **Parameters** | `/proc/net/tcp` states: `01` ESTABLISHED, `06` TIME_WAIT, `08` CLOSE_WAIT, `0A` LISTEN; IPv4 address little-endian (`0100007F` = 127.0.0.1); port plain hex (`01BB` = 443) |
| **Example** | `getent services 443/tcp` · `sysctl net.ipv4.ip_local_port_range` |
| **Expected output** | `https                 443/tcp` · `net.ipv4.ip_local_port_range = 32768 60999` (captured; the two numbers are tab-separated) |
| **Equivalent** | `C:\Windows\System32\drivers\etc\services` · `netsh int ipv4 show dynamicport tcp` |
| **Common errors** | Treating a service name as proof of the program · `getent` exit code 2 = not found |
| **Use case** | Decoding sockets in minimal containers without `ss`; capacity planning for outbound connections. |
| **Docs** | <https://man7.org/linux/man-pages/man5/services.5.html> · <https://man7.org/linux/man-pages/man5/proc_net.5.html> · <https://man7.org/linux/man-pages/man7/ip.7.html> |
