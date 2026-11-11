---
description: "Prepare for a software audit: inventory installed packages and applications, report patch status and pending reboots, install a tool with inspect-simulate-install-verify, build and install a local .deb, compare remove and purge, use holds and pins, read package history, and export a reproducible baseline with apt-mark, winget export and PSResourceGet."
---

# Lab 10: Software Inventory

| Field | Value |
|---|---|
| **Lab ID** | LAB-10 |
| **Related lesson** | [Day 10: Software and Package Management](../course/module-2/day-10.md) |
| **Difficulty** | Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Low–Medium. You install and remove **only** the small packages named in this lab (`tree` and the locally built `lab10-hello` on Linux; 7-Zip and the PSScriptAnalyzer module on Windows) and you do **not** apply system-wide upgrades. Take a **VM snapshot** first. Read every `autoremove` list before confirming. |

## Objective

The security team will audit the lab servers **ubuntu-lab** and **WIN11-LAB** next week and has asked you for:

1. A **software inventory**: what is installed, how many packages, the biggest ones, exported to files.
2. The **patch status**: pending updates (security separately), pending reboot, holds/pins, last installed Windows updates.
3. Evidence that you install software **the right way**: inspect → simulate → install → verify, using exact names/IDs from trusted sources.
4. A demonstration that removed software leaves no unexpected traces: `remove` versus `purge`, and dependency clean-up.
5. The **change history** for today's work from the package logs.
6. A reproducible **baseline** so the servers can be rebuilt: manual packages, winget export, PowerShell module list.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS VM (or WSL2) with `sudo` rights and internet access to the Ubuntu archive. Tools used (`apt`, `dpkg`, `dpkg-deb`, `apt-mark`) are installed by default.
- **Windows:** Windows 11 lab VM or PC with **winget** (`winget --version` works) and internet access; Windows PowerShell 5.1 or PowerShell 7.4+. A normal window for most tasks; winget shows a UAC prompt for the machine-wide 7-Zip install.
- Day 10 read; Days 05 (pipelines) and 06 (`sudo`) completed.

## Initial Conditions

- A snapshot exists and you know how to revert it.
- Record whether the lab packages are already installed — you must not remove anything you did not install:
    - Bash: `dpkg -s tree lab10-hello 2>&1 | grep -E '^(Package|Status)|not installed'` — on a fresh Ubuntu install both report `is not installed`. If `tree` **is** installed, note it and skip its removal in the clean-up.
    - PowerShell: `winget list --id 7zip.7zip -e` and `Get-InstalledPSResource PSScriptAnalyzer -ErrorAction SilentlyContinue` (PowerShell 7.4) / `Get-InstalledModule PSScriptAnalyzer -ErrorAction SilentlyContinue` (5.1). Note what is already there.
- Create the evidence folder: `mkdir -p ~/lab10` / `New-Item -ItemType Directory $HOME\lab10 -Force`.
- No other `apt` or `dpkg` process is running (`pgrep -a 'apt|dpkg|unattended'` prints nothing). If unattended-upgrades is running, wait.

## Step-by-Step Instructions

### Task 1 — Inventory

1. Count installed packages (status `ii`) and **manually** installed packages.
2. List the five largest installed packages in MiB.
3. Export `Package<TAB>Version<TAB>Architecture` for all packages to `~/lab10/packages.tsv`.
4. Windows: build the inventory from the three Uninstall registry keys (name, version, publisher, install date), export it to `$HOME\lab10\software-inventory.csv`, and compare its count with `winget list`. **Do not use `Win32_Product`.**

### Task 2 — Patch status

1. Refresh the package indexes; count upgradable packages and, separately, those from `noble-security`.
2. Report whether a reboot is required and list held packages. Check whether unattended-upgrades is enabled.
3. Windows: list available winget upgrades, the three most recent hotfixes, and whether a reboot is pending. **Do not upgrade anything** in this lab.
4. Save all numbers in `~/lab10/audit.txt` / `$HOME\lab10\audit.txt` with a UTC timestamp.

### Task 3 — Install a tool the right way, then hold it

1. Linux: inspect `tree` (`apt policy`, `apt show`), simulate the install, install it, verify the owner of the `tree` binary, and run it on `/etc/apt`.
2. Put `tree` on **hold**, show the hold and the effect on an upgrade attempt, then remove the hold.
3. Windows: inspect 7-Zip with `winget show --id 7zip.7zip -e` (note the installer URL and SHA-256), install it by exact ID from the `winget` source, verify with `winget list` and the registry, record the signature status of `7z.exe`, then **pin** and unpin it.

### Task 4 — Build, inspect and install a local package; remove versus purge (Linux)

1. Build the `lab10-hello` package with the script below, inspect it with `dpkg-deb --info` and `--contents` **before** installing.
2. Install it with `apt install ./…deb`, run `lab10-hello`, then mark `tree` as automatically installed (so it counts as a dependency).
3. Edit `/etc/lab10-hello/hello.conf` and detect the change with `dpkg --verify`.
4. `remove` the package and prove the configuration survived (`rc` status). Simulate `autoremove` and read the list.
5. `purge` the package and prove the configuration is gone. Run `autoremove` **only if** its list contains nothing but `tree`; otherwise remove `tree` explicitly.

```bash
mkdir -p ~/lab10/pkg/lab10-hello/DEBIAN ~/lab10/pkg/lab10-hello/usr/bin ~/lab10/pkg/lab10-hello/etc/lab10-hello
cd ~/lab10/pkg
cat > lab10-hello/DEBIAN/control <<'CTL'
Package: lab10-hello
Version: 1.0-1
Section: misc
Priority: optional
Architecture: all
Depends: tree
Maintainer: Course Lab <lab@example.invalid>
Description: Lab 10 demo package
 Prints a greeting. Used to practise install, remove and purge.
CTL
echo /etc/lab10-hello/hello.conf > lab10-hello/DEBIAN/conffiles
echo 'greeting="Hello from Lab 10"' > lab10-hello/etc/lab10-hello/hello.conf
printf '#!/bin/sh\n. /etc/lab10-hello/hello.conf\necho "$greeting"\n' > lab10-hello/usr/bin/lab10-hello
chmod 0755 lab10-hello/usr/bin/lab10-hello
dpkg-deb --root-owner-group --build lab10-hello lab10-hello_1.0-1_all.deb
```

The `DEBIAN/conffiles` file declares `hello.conf` as a configuration file — that is what makes `remove` keep it and `purge` delete it. `--root-owner-group` makes every file in the package owned by root, even though you built it as a normal user.

### Task 5 — Change history

1. Show today's `lab10-hello` and `tree` transactions from `/var/log/apt/history.log` and `/var/log/dpkg.log`.
2. Windows: list the newest `MsiInstaller` 1033/1034 events in the Application log and explain why the 7-Zip install may not appear there.

### Task 6 — Baseline export

1. Save `apt-mark showmanual` to `~/lab10/manual-packages.txt` and `snap list` to `~/lab10/snaps.txt`.
2. Windows: `winget export` to `$HOME\lab10\winget-apps.json`.
3. Windows: download PSScriptAnalyzer for review with `Save-PSResource` (7.4+) or `Save-Module` (5.1), look at its manifest, then install it with `-Scope CurrentUser` and list installed modules to `$HOME\lab10\modules.txt`.

### Task 7 — Audit summary and clean-up

1. Append to `audit.txt`: the inventory counts, the patch numbers, what you installed and removed today (with timestamps from the logs), and one recommendation.
2. Clean up exactly what this lab added (see [Clean-up](#clean-up)).

## Commands to Execute

Work out each task yourself first, using the lesson. The complete commands, in order, are in the [Solution](#solution).

## Expected Results

Linux values were **captured** on 2026-11-11 by executing every Linux task as root on Ubuntu 24.04.5 in a minimized container with access to the Ubuntu archive (counts reflect that container; a normal Ubuntu Server shows more packages). Windows results are **expected approximations** — the Windows steps were checked against the winget and PowerShell documentation but not executed before release.

| Check | Linux (captured) | Windows (expected) |
|---|---|---|
| Task 1 counts | `837` packages with status `ii`, `836` manual; largest `openjdk-21-jre-headless` 193.6 MiB; `packages.tsv` has 837 lines | 50–200 inventory entries; `winget list` shows a similar but **not identical** number |
| Task 2 patch status | `22` upgradable, `19` from `noble-security`, `reboot=no`, `0` holds; `20auto-upgrades` present on a normal install (missing in the minimized container) | A few winget upgrades; three hotfixes with `KB…` IDs; reboot pending `False` or `True` |
| Task 3 install | Simulation: one `Inst tree` + one `Conf tree` line; `ii tree 2.1.1-2ubuntu3.24.04.2`; `dpkg -S` → `tree: /usr/bin/tree` | `Successfully verified installer hash`, `Successfully installed`; registry entry `7-Zip …` |
| Task 3 hold | `tree set on hold.`; `dpkg -l` status `hi`; `Canceled hold on tree.` | `Pin added successfully` / `Pin removed successfully` |
| Task 4 package | `Depends: tree`; seven entries in `--contents`; `Hello from Lab 10`; after the edit `??5?????? c /etc/lab10-hello/hello.conf` | — |
| Task 4 remove / purge | `rc  lab10-hello  1.0-1`, config still says `Edited by admin`; simulation `Remv tree`; after purge `/etc/lab10-hello` is gone and `no packages found matching lab10-hello` | — |
| Task 5 logs | `dpkg.log`: `install tree`, `install lab10-hello`, `remove lab10-hello`, `purge lab10-hello`, `remove tree` lines with timestamps | `MsiInstaller` events exist only for MSI installs |
| Task 6 baseline | `manual-packages.txt` with one package per line | `winget-apps.json` with a `Packages` array; `modules.txt` lists PSScriptAnalyzer |

## Verification Steps

=== "Bash"

    ```bash
    wc -l ~/lab10/packages.tsv ~/lab10/manual-packages.txt     # non-zero line counts
    cat ~/lab10/audit.txt                                      # timestamps, counts, actions
    dpkg -l lab10-hello 2>&1 | tail -1                         # no packages found (purged)
    ls /etc/lab10-hello 2>&1                                   # No such file or directory
    apt-mark showhold | grep -c tree                           # 0: no hold left behind
    grep -cE ' (install|remove|purge) lab10-hello' /var/log/dpkg.log   # 3 or more
    ```

=== "PowerShell"

    ```powershell
    Import-Csv $HOME\lab10\software-inventory.csv | Measure-Object | Select-Object Count
    (Get-Content $HOME\lab10\winget-apps.json -Raw | ConvertFrom-Json).Sources.Packages.Count
    Get-Content $HOME\lab10\audit.txt
    winget pin list                                            # 7zip.7zip not listed
    Get-Content $HOME\lab10\modules.txt | Select-String PSScriptAnalyzer
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Could not get lock /var/lib/dpkg/lock-frontend … (unattended-upgr)` | Automatic updates running | Wait; check `/var/log/unattended-upgrades/`; never delete lock files |
| `E: Unable to locate package tree` | `universe` not enabled or no `apt update` | `sudo apt update`; check `Components:` in `/etc/apt/sources.list.d/ubuntu.sources` |
| `dpkg-deb: error: … control file … missing value for 'Description'` | Heredoc mangled when pasted (indentation, missing space before the long description) | The long-description line must start with **one space**; rebuild |
| `N: Download is performed unsandboxed as root as file '…/lab10-hello_1.0-1_all.deb' couldn't be accessed by user '_apt'` | The `_apt` user cannot read your home folder | Harmless notice for local files; or copy the `.deb` to `/tmp` first |
| `autoremove` lists more than `tree` | Other unneeded packages on your VM (often old kernels) | Do **not** run it for this lab; `sudo apt remove tree` instead |
| `winget` not found | App Installer missing/outdated | Update *App Installer* from the Microsoft Store |
| `Failed when searching source: msstore` | Store source unreachable or agreements not accepted | Add `--source winget` |
| `Installer hash does not match` | Manifest and download differ | Stop; do not override; retry later and report |
| `Save-PSResource` / `Install-PSResource` not recognized | Windows PowerShell 5.1 without PSResourceGet | Use `Save-Module` / `Install-Module -Scope CurrentUser`, or install PSResourceGet first |
| `Get-AuthenticodeSignature` shows `NotSigned` | Not every open-source binary is Authenticode-signed | Record it; rely on the winget hash verification and the publisher's checksums |

## Questions

1. Why does the registry inventory not match `winget list` exactly?
2. Why did you simulate the `tree` install, and what would the simulation have shown if `tree` required ten new libraries?
3. What did `dpkg --verify` tell you after the config edit, and why is that a normal result here but alarming for `/usr/bin/lab10-hello`?
4. Explain, with evidence from your terminal, the difference between `remove` and `purge`.
5. Why did `autoremove` want to remove `tree` after the purge, and why was it safe in this lab but potentially unsafe on a real server?
6. What does a hold (or pin) protect against, and what risk does it create?
7. Which baseline files would you use to rebuild these machines, and what would still be missing?

## Solution

??? success "Bash solution"
    ```bash
    mkdir -p ~/lab10
    note() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a ~/lab10/audit.txt; }

    # ---- Task 1: inventory ----
    total=$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' | grep -c '^ii')
    manual=$(apt-mark showmanual | wc -l)
    dpkg-query -W -f='${Installed-Size}\t${Package}\n' | sort -rn | head -5 |
        awk -F'\t' '{ printf "%8.1f MiB  %s\n", $1 / 1024, $2 }'
    dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' > ~/lab10/packages.tsv
    note "inventory: installed=$total manual=$manual (packages.tsv)"

    # ---- Task 2: patch status (no upgrades) ----
    sudo apt update
    upg=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    sec=$(apt list --upgradable 2>/dev/null | grep -c -- '-security')
    reboot=$([ -f /var/run/reboot-required ] && echo yes || echo no)
    holds=$(apt-mark showhold | wc -l)
    cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || echo "20auto-upgrades not found"
    note "patch status: upgradable=$upg security=$sec reboot=$reboot holds=$holds"

    # ---- Task 3: install the right way, then hold ----
    apt policy tree
    apt show tree 2>/dev/null | grep -E '^(Version|Section|Depends|APT-Sources)'
    apt-get -s install tree | grep -E '^(Inst|Conf)'
    sudo apt install -y tree
    dpkg -l tree | tail -1
    dpkg -S "$(command -v tree)"
    tree -L 1 /etc/apt
    sudo apt-mark hold tree
    apt-mark showhold
    dpkg -l tree | tail -1                         # status hi
    apt-get -s install --only-upgrade tree | tail -2
    sudo apt-mark unhold tree
    note "installed tree (simulated first); hold set and removed"

    # ---- Task 4: local package ----
    # (build script from Task 4 above)
    cd ~/lab10/pkg
    dpkg-deb --info lab10-hello_1.0-1_all.deb
    dpkg-deb --contents lab10-hello_1.0-1_all.deb
    sudo apt install -y ./lab10-hello_1.0-1_all.deb
    lab10-hello
    sudo apt-mark auto tree
    echo 'greeting="Edited by admin"' | sudo tee /etc/lab10-hello/hello.conf
    lab10-hello
    dpkg --verify lab10-hello
    sudo apt remove -y lab10-hello
    dpkg -l lab10-hello | tail -1
    cat /etc/lab10-hello/hello.conf
    apt-get -s autoremove | grep '^Remv'             # read it: only tree?
    sudo apt purge -y lab10-hello
    ls /etc/lab10-hello; dpkg -l lab10-hello
    if [ "$(apt-get -s autoremove | grep -c '^Remv')" -eq 1 ] && apt-get -s autoremove | grep -q '^Remv tree '; then
        sudo apt autoremove -y
    else
        sudo apt remove -y tree
    fi
    note "lab10-hello installed, verified, removed (rc), purged; tree removed as unneeded dependency"

    # ---- Task 5: history ----
    grep -E '^(Start-Date|Commandline|Install|Remove|Purge)' /var/log/apt/history.log | tail -20
    grep -E ' (install|remove|purge) (lab10-hello|tree)' /var/log/dpkg.log | tail -6 | tee -a ~/lab10/audit.txt

    # ---- Task 6: baseline ----
    apt-mark showmanual > ~/lab10/manual-packages.txt
    snap list > ~/lab10/snaps.txt 2>&1
    note "baseline: manual-packages.txt ($(wc -l < ~/lab10/manual-packages.txt) lines), snaps.txt"
    note "recommendation: patch the $sec pending security updates in the next window; keep unattended-upgrades enabled"
    ```

    **Captured output (key lines; Ubuntu 24.04.5 container, 2026-11-11):**

    ```text
       193.6 MiB  openjdk-21-jre-headless
       190.0 MiB  pandoc
       144.4 MiB  libreoffice-core
       137.0 MiB  libllvm20
       118.0 MiB  libllvm17t64
    installed=837 manual=836
    upgradable=22 security=19 reboot=no holds=0
    tree:
      Installed: (none)
      Candidate: 2.1.1-2ubuntu3.24.04.2
    Inst tree (2.1.1-2ubuntu3.24.04.2 Ubuntu:24.04/noble-updates [amd64])
    Conf tree (2.1.1-2ubuntu3.24.04.2 Ubuntu:24.04/noble-updates [amd64])
    Unpacking tree (2.1.1-2ubuntu3.24.04.2) ...
    Setting up tree (2.1.1-2ubuntu3.24.04.2) ...
    ii  tree           2.1.1-2ubuntu3.24.04.2 amd64        displays an indented directory tree, in color
    tree: /usr/bin/tree
    /etc/apt
    |-- apt.conf.d
    |-- auth.conf.d
    |-- keyrings
    |-- preferences.d
    |-- sources.list
    |-- sources.list.d
    `-- trusted.gpg.d

    7 directories, 1 file
    tree set on hold.
    tree
    hi  tree           2.1.1-2ubuntu3.24.04.2 amd64        displays an indented directory tree, in color
    tree is already the newest version (2.1.1-2ubuntu3.24.04.2).
    Canceled hold on tree.
     new Debian package, version 2.0.
     size 748 bytes: control archive=329 bytes.
          28 bytes,     1 lines      conffiles
     Package: lab10-hello
     Version: 1.0-1
     Architecture: all
     Depends: tree
    -rw-r--r-- root/root        29 2026-11-11 17:17 ./etc/lab10-hello/hello.conf
    -rwxr-xr-x root/root        57 2026-11-11 17:17 ./usr/bin/lab10-hello
    Setting up lab10-hello (1.0-1) ...
    Hello from Lab 10
    tree set to automatically installed.
    Edited by admin
    ??5?????? c /etc/lab10-hello/hello.conf
    Removing lab10-hello (1.0-1) ...
    rc  lab10-hello    1.0-1        all          Lab 10 demo package
    greeting="Edited by admin"
    Remv tree [2.1.1-2ubuntu3.24.04.2]
    Purging configuration files for lab10-hello (1.0-1) ...
    ls: cannot access '/etc/lab10-hello': No such file or directory
    dpkg-query: no packages found matching lab10-hello
    Removing tree (2.1.1-2ubuntu3.24.04.2) ...
    2026-11-11 17:14:13 install tree:amd64 <none> 2.1.1-2ubuntu3.24.04.2
    2026-11-11 17:14:28 install lab10-hello:all <none> 1.0-1
    2026-11-11 17:14:31 remove lab10-hello:all 1.0-1 <none>
    2026-11-11 17:14:37 purge lab10-hello:all 1.0-1 <none>
    2026-11-11 17:14:39 remove tree:amd64 2.1.1-2ubuntu3.24.04.2 <none>
    ```

    `tree` printed ASCII connectors because the container had no UTF-8 locale; on a desktop terminal you see `├──` and `└──`. The `--contents` listing has seven lines (five directories, two files); only the two files are shown above. The first two lines show the values the `note` calls recorded (each `note` line also starts with a UTC timestamp); the `dpkg.log` lines are as captured. The lines were captured in more than one run of the same steps, so the clock times differ slightly between blocks.

??? success "PowerShell solution"
    ```powershell
    New-Item -ItemType Directory -Path $HOME\lab10 -Force | Out-Null
    function Add-Note([string]$Text) {
        '{0} {1}' -f (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'), $Text |
            Tee-Object -FilePath $HOME\lab10\audit.txt -Append
    }

    # ---- Task 1: inventory (never Win32_Product) ----
    $paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
             'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
             'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $inventory = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate,
            @{ n = 'Scope'; e = { if ($_.PSPath -like '*HKEY_CURRENT_USER*') { 'User' } elseif ($_.PSPath -like '*WOW6432Node*') { 'Machine-32bit' } else { 'Machine' } } } |
        Sort-Object DisplayName
    $inventory | Export-Csv -Path $HOME\lab10\software-inventory.csv -NoTypeInformation
    $wingetLines = @(winget list --accept-source-agreements | Select-String -Pattern '^\S' | Select-Object -Skip 2).Count
    Add-Note ("inventory: registry={0} wingetList~{1} (software-inventory.csv)" -f $inventory.Count, $wingetLines)
    if ($PSVersionTable.PSEdition -eq 'Desktop') {          # Windows PowerShell 5.1 only
        Add-Note ("Get-Package Programs+msi: {0}" -f @(Get-Package -ProviderName Programs, msi -ErrorAction SilentlyContinue).Count)
    }

    # ---- Task 2: patch status (no upgrades) ----
    winget upgrade --accept-source-agreements
    $hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 3 HotFixID, Description, InstalledOn
    $hotfixes
    $rebootKeys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
                  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $pending = @($rebootKeys | Where-Object { Test-Path $_ }).Count -gt 0
    Add-Note ("patch status: newestHotfix={0} rebootPending={1}" -f $hotfixes[0].HotFixID, $pending)

    # ---- Task 3: install the right way, then pin ----
    winget show --id 7zip.7zip -e                      # note Installer Url and Installer SHA256
    winget install --id 7zip.7zip -e --source winget --accept-package-agreements --accept-source-agreements
    "winget exit code: $LASTEXITCODE"
    winget list --id 7zip.7zip -e
    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object DisplayName -like '7-Zip*' |
        Select-Object DisplayName, DisplayVersion, InstallLocation
    $exe = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
    Get-AuthenticodeSignature -FilePath $exe | Select-Object Status, @{ n = 'Signer'; e = { $_.SignerCertificate.Subject } }
    Get-FileHash -Path $exe -Algorithm SHA256 | Select-Object Hash
    winget pin add --id 7zip.7zip
    winget pin list
    winget pin remove --id 7zip.7zip
    Add-Note 'installed 7-Zip by exact ID (hash verified by winget); pin added and removed'

    # ---- Task 5: history ----
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'MsiInstaller'; Id = 1033, 1034 } -MaxEvents 5 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, @{ n = 'Message'; e = { $_.Message.Substring(0, [math]::Min(90, $_.Message.Length)) } }

    # ---- Task 6: baseline and a module, reviewed first ----
    winget export -o $HOME\lab10\winget-apps.json --accept-source-agreements
    if (Get-Command Save-PSResource -ErrorAction SilentlyContinue) {          # PowerShell 7.4+
        Save-PSResource -Name PSScriptAnalyzer -Path $HOME\lab10\review -TrustRepository
        Get-ChildItem $HOME\lab10\review -Recurse -Filter *.psd1 | Select-Object -First 1 FullName
        Install-PSResource -Name PSScriptAnalyzer -Scope CurrentUser       # answer Y at the untrusted prompt
        Get-InstalledPSResource | Select-Object Name, Version | Out-File $HOME\lab10\modules.txt
    }
    else {                                                                 # Windows PowerShell 5.1
        Save-Module -Name PSScriptAnalyzer -Path $HOME\lab10\review
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
        Get-InstalledModule | Select-Object Name, Version | Out-File $HOME\lab10\modules.txt
    }
    Add-Note 'baseline: winget-apps.json, modules.txt; PSScriptAnalyzer installed for CurrentUser after review'
    Add-Note 'recommendation: apply pending winget upgrades and Windows updates in the next window'
    ```

    The 7-Zip manifest currently uses an EXE or MSI installer depending on the version; if it is an MSI, Task 5 shows an `MsiInstaller` 1033 event for it, otherwise only `winget`'s own log (`winget --info` shows the log folder) records the install.

??? success "Answers to questions"
    1. The registry lists every program that registered an Uninstall entry (including per-user and 32-bit ones, and some that winget cannot map to a package ID); `winget list` also includes Store/MSIX apps and correlates entries with its sources, merging or labelling some differently. Different data sources, different counts — record both.
    2. To see exactly what would change (packages, versions, sources) without changing anything. With ten new libraries the simulation would print ten extra `Inst`/`Conf` lines and `11 newly installed` — a signal to review whether the tool is worth that footprint on a server.
    3. `??5?????? c /etc/lab10-hello/hello.conf`: the MD5 checksum differs and it is a **conffile**, which admins are expected to edit. The same flag on an executable such as `/usr/bin/lab10-hello` means a program file was modified after installation — a possible compromise or corruption to investigate before reinstalling.
    4. After `remove`, `dpkg -l` showed `rc` and `/etc/lab10-hello/hello.conf` still contained `Edited by admin`. After `purge`, `/etc/lab10-hello` did not exist and `dpkg -l` found no package.
    5. `tree` had been marked **automatic** and the only package depending on it (`lab10-hello`) was gone, so nothing needed it. On a real server the same list can include tools people use directly, old kernels or packages from other teams — read the list and keep what you need with `apt-mark manual`.
    6. A hold or pin prevents an unplanned upgrade from breaking a dependent application. The risk is that the held version silently misses security fixes — so every hold needs an owner, a reason and a review date.
    7. `manual-packages.txt` (+ `snaps.txt`) and `winget-apps.json` + `modules.txt` rebuild the software. Still missing: configuration (`/etc`, registry settings, app settings), data, repository and key configuration (`/etc/apt/sources.list.d`, keyrings), Windows features/capabilities, licences and anything installed outside the package managers.

## Clean-up

Remove only what this lab added. Preview first.

```bash
dpkg -l lab10-hello tree 2>&1 | tail -n +6           # preview what is installed
sudo apt-mark unhold tree 2>/dev/null
sudo apt purge -y lab10-hello 2>/dev/null
sudo apt purge -y tree                               # SKIP if tree was installed before the lab
ls -la ~/lab10                                       # preview; copy audit.txt elsewhere if you need it
rm -r ~/lab10
```

```powershell
winget pin remove --id 7zip.7zip 2>$null
winget uninstall --id 7zip.7zip -e                   # SKIP if 7-Zip was installed before the lab
if (Get-Command Uninstall-PSResource -ErrorAction SilentlyContinue) { Uninstall-PSResource -Name PSScriptAnalyzer }
else { Uninstall-Module -Name PSScriptAnalyzer }     # SKIP if it was installed before the lab
Remove-Item $HOME\lab10 -Recurse -WhatIf
Remove-Item $HOME\lab10 -Recurse
```
