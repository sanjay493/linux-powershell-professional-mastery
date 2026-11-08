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
