---
description: "Respond to a disk-full alert on file-backed practice disks: confirm it with disk-monitor, drill down with du and Measure-Object, release space held by a deleted-but-open log, fix inode exhaustion, clean up with archives and checksums, and add a UUID + nofail fstab entry verified with findmnt --verify."
---

# Lab 09: Disk Full

| Field | Value |
|---|---|
| **Lab ID** | LAB-09 |
| **Related lesson** | [Day 09: Disk and Storage Management](../course/module-2/day-09.md) |
| **Difficulty** | Intermediate |
| **Time** | 75–90 minutes |
| **Risk level** | Medium. You create, format and mount **file-backed practice disks only** (Linux loop devices backed by files in `/opt/lab09`; a 256 MB VHDX in `C:\lab09` on Windows) and you temporarily add one line to `/etc/fstab`. Take a **VM snapshot** first, back up `/etc/fstab` as instructed, and never point `mkfs`, `Format-Volume` or `Initialize-Disk` at any other device. |

## Objective

At 09:20 UTC the monitoring system raised two alerts for the lab server **ubuntu-lab**:

- **DISK-1:** */srv/lab09 is 95% full* (the application data filesystem).
- **DISK-2:** *mail spool /srv/lab09-spool: "No space left on device"* — although the dashboard shows the spool only one-third full.

On Windows, the matching alert is *volume LAB09 above 90%*. Your job, as the on-call administrator:

1. Confirm both alerts with a repeatable measurement (`df`/`Get-Volume` and the course's `disk-monitor` script, exit code 3).
2. Find **what** is using the space, down to individual files, without deleting anything yet.
3. Explain why `df` and `du` disagree on `/srv/lab09`, and release the space held by a deleted log.
4. Diagnose the spool problem (inodes), archive the old messages and remove them safely.
5. Clean up the data filesystem following the team policy below, then prove the alerts are clear (exit code 0).
6. Make the data filesystem mount persistently by **UUID** with `nofail`, verify the fstab entry **before** any reboot, and restore everything at the end.

**Team cleanup policy** (given by your manager):

- `debug.log` may be emptied, but keep its **last 1,000 lines** in `/opt/lab09/archive/` for the developers.
- Keep only the **newest** database backup on the server. Older backups must be copied to `/opt/lab09/offload/` (the "backup server") and verified with **SHA-256 checksums** before the originals are deleted.
- `*.tmp` files under `app/cache` are disposable.
- Spool messages older than **7 days** must be archived to `/opt/lab09/archive/` before they are deleted.
- `reports/` is business data: **do not touch it**.

## Required Environment

- **Linux:** Ubuntu 24.04 LTS VM (or WSL2) with `sudo` rights, GNU coreutils, util-linux (`losetup`, `findmnt`, `lsblk`), e2fsprogs (`mkfs.ext4`) and `lsof` — all installed by default on Ubuntu Server and Desktop. About 300 MB free on the root filesystem.
- **Windows:** Windows 11 lab VM or PC with an **elevated** Windows PowerShell 5.1 or PowerShell 7 window, about 300 MB free on `C:` and a free drive letter.
- The course repository (for `scripts/linux/disk-monitor.sh` and `scripts/powershell/Disk-Monitor.ps1`), or copies of those two files.
- Day 09 read; Day 04 (`find`) and Day 08 (processes) completed.

## Initial Conditions

- A VM snapshot exists and you know how to revert it.
- Nothing from a previous attempt exists:
    - Bash: `ls -d /opt/lab09 /srv/lab09 /srv/lab09-spool; losetup -a | grep lab09; grep -n lab09 /etc/fstab` — three `No such file or directory` messages and no other output.
    - PowerShell: `Test-Path C:\lab09` returns `False`.
- You are in the repository root (`cd ~/linux-powershell-professional-mastery`), so `scripts/linux/disk-monitor.sh` resolves.

### Set up the scenario (the "incident")

Run this **once**. It plays the role of the misbehaving application — read it, but then investigate as if you had not seen it.

=== "Linux"

    ```bash
    sudo mkdir -p /opt/lab09 /srv/lab09 /srv/lab09-spool
    sudo truncate -s 256M /opt/lab09/data.img          # practice disk 1 (a sparse file)
    sudo truncate -s 32M /opt/lab09/spool.img          # practice disk 2
    LOOP_DATA=$(sudo losetup -f --show /opt/lab09/data.img)
    LOOP_SPOOL=$(sudo losetup -f --show /opt/lab09/spool.img)
    printf 'data=%s\nspool=%s\n' "$LOOP_DATA" "$LOOP_SPOOL" | sudo tee /opt/lab09/devices.txt
    lsblk "$LOOP_DATA" "$LOOP_SPOOL"                   # CHECK: two 'loop' devices, 256M and 32M
    sudo mkfs.ext4 -q -L lab09data "$LOOP_DATA"
    sudo mkfs.ext4 -q -N 2048 -L lab09spool "$LOOP_SPOOL"   # deliberately few inodes
    sudo mount "$LOOP_DATA" /srv/lab09
    sudo mount "$LOOP_SPOOL" /srv/lab09-spool
    sudo mkdir -p /srv/lab09/app/logs /srv/lab09/app/cache /srv/lab09/backups /srv/lab09/reports
    # 1. a debug log left enabled (110 MiB of text)
    yes '2026-11-11T09:15:02Z DEBUG worker=7 cache refresh ok items=0512' | head -c 110M |
        sudo tee /srv/lab09/app/logs/debug.log > /dev/null
    # 2. three nightly backups of 15 MiB each
    for d in 01 02 03; do
        sudo dd if=/dev/urandom of=/srv/lab09/backups/db-2026-11-$d.tar.gz bs=1M count=15 status=none
    done
    # 3. forty temporary cache chunks
    for i in $(seq 1 40); do
        sudo dd if=/dev/urandom of=/srv/lab09/app/cache/chunk-$i.tmp bs=256K count=1 status=none
    done
    echo "quarterly summary - keep" | sudo tee /srv/lab09/reports/q3-summary.txt > /dev/null
    # 4. a 30 MiB trace log, deleted while a "writer" process still holds it open
    sudo dd if=/dev/zero of=/srv/lab09/app/logs/trace-old.log bs=1M count=30 status=none
    sudo setsid bash -c 'exec 3</srv/lab09/app/logs/trace-old.log; exec -a lab09-writer sleep 7200' \
        < /dev/null > /dev/null 2>&1 &
    sleep 1
    sudo rm /srv/lab09/app/logs/trace-old.log
    # 5. a mail spool that runs out of inodes
    sudo bash -c 'mkdir -p /srv/lab09-spool/queue; cd /srv/lab09-spool/queue
      for i in $(seq 1 3000); do { printf "msg %s\n" "$i" > "msg-$i.eml"; } 2>/dev/null || break; done
      touch -d "2026-11-01 08:00" msg-{1..1500}.eml'
    echo "Lab 09 scenario ready."
    ```

    Paste the block in pieces if you prefer, and read every output line. If `lsblk` shows anything other than two new `loop` devices of 256M and 32M, **stop** before `mkfs` and revert the snapshot.

=== "Windows (elevated)"

    ```powershell
    $ErrorActionPreference = 'Stop'
    $lab = 'C:\lab09'
    $vhd = Join-Path $lab 'lab09.vhdx'
    New-Item -ItemType Directory -Path $lab -Force | Out-Null
    # 1. practice disk: a 256 MB expandable VHDX created with diskpart (no Hyper-V needed)
    "create vdisk file=`"$vhd`" maximum=256 type=expandable" | Set-Content -Path "$lab\create.txt" -Encoding Ascii
    diskpart.exe /s "$lab\create.txt"
    Mount-DiskImage -ImagePath $vhd | Out-Null
    $disk = Get-DiskImage -ImagePath $vhd | Get-Disk
    $disk | Select-Object Number, FriendlyName, PartitionStyle, Size    # CHECK: RAW, about 256 MB
    # The destructive steps run ONLY for a RAW (empty) disk of at most 300 MB - the new VHDX.
    if ($disk.PartitionStyle -eq 'RAW' -and $disk.Size -le 300MB) {
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT
        New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter |
            Format-Volume -FileSystem NTFS -NewFileSystemLabel LAB09 -Confirm:$false | Out-Null
    }
    else { Write-Warning 'This is not the new, empty VHDX - nothing was formatted. Stop here.' }
    $L = (Get-Partition -DiskNumber $disk.Number | Where-Object DriveLetter).DriveLetter
    $root = "$($L):\"
    "Practice volume is $root" | Tee-Object -FilePath "$lab\letter.txt"
    'app\logs', 'app\cache', 'backups', 'reports', 'spool\queue' |
        ForEach-Object { New-Item -ItemType Directory -Path (Join-Path $root $_) -Force | Out-Null }
    # 2. a 135 MiB text debug log (1 MiB chunk written 135 times)
    $chunk = ('2026-11-11T09:15:02Z DEBUG worker=7 cache refresh ok items=0512' + "`r`n") * 16000
    1..135 | ForEach-Object { [System.IO.File]::AppendAllText("$root\app\logs\debug.log", $chunk) }
    # 3. three 15 MiB backups and forty 256 KiB cache chunks of random data
    $rng = New-Object System.Random 9
    foreach ($d in '01', '02', '03') {
        $bytes = New-Object byte[] (15MB); $rng.NextBytes($bytes)
        [System.IO.File]::WriteAllBytes("$root\backups\db-2026-11-$d.zip", $bytes)
    }
    1..40 | ForEach-Object {
        $bytes = New-Object byte[] (256KB); $rng.NextBytes($bytes)
        [System.IO.File]::WriteAllBytes("$root\app\cache\chunk-$_.tmp", $bytes)
    }
    Set-Content -Path "$root\reports\q3-summary.txt" -Value 'quarterly summary - keep'
    # 4. a 30 MiB trace log held open (exclusively) by this PowerShell session - the "writer"
    fsutil file createnew "$root\app\logs\trace-old.log" 31457280 | Out-Null
    $writer = [System.IO.File]::Open("$root\app\logs\trace-old.log", 'Open', 'Read', 'None')
    # 5. 2,036 small spool messages; the first 1,500 dated 2026-11-01
    1..2036 | ForEach-Object { Set-Content -Path "$root\spool\queue\msg-$_.eml" -Value "msg $_" }
    1..1500 | ForEach-Object { (Get-Item "$root\spool\queue\msg-$_.eml").LastWriteTime = Get-Date '2026-11-01 08:00' }
    $ErrorActionPreference = 'Continue'
    'Lab 09 scenario ready.'
    ```

    **Keep this window open**: `$writer` (the open file), `$root`, `$L`, `$lab` and `$vhd` are used later. If you see the warning, or the `CHECK` line does not show a new RAW disk of about 256 MB, run `Dismount-DiskImage -ImagePath $vhd` and stop.

## Step-by-Step Instructions

### Task 1 — Confirm the alerts

1. Show space **and** inodes for both lab filesystems (Linux) or the LAB09 volume (Windows).
2. Run the course script against each filesystem and record its **exit code**:
    - Linux: `bash scripts/linux/disk-monitor.sh -m /srv/lab09 -p /srv/lab09 -n 5`, then the same with `-m /srv/lab09-spool`.
    - Windows: `.\scripts\powershell\Disk-Monitor.ps1 -DriveName $L -FolderPath $root -Top 5` (from the repository root).
3. Write the UTC time and the measured values in `/opt/lab09/incident.txt` (Linux: use `sudo tee -a`) or `C:\lab09\incident.txt`.

### Task 2 — Find what uses the space

1. Drill down from the mount point / drive root to the largest directories, then to the largest files (> 10 MB).
2. Look at the last two lines of the biggest file without opening it in an editor.
3. Note the total that `du` (or `Measure-Object`) reports and compare it with `df` (or `Get-Volume`).

### Task 3 — Explain the gap and release the held space

1. Linux: find deleted files that are still open, the PID that holds the file and its command line. Windows: try to delete `app\logs\trace-old.log` and read the error.
2. "Restart the writer": end the `lab09-writer` process (Linux) — it is your own lab process, not a system service — or close `$writer` (Windows).
3. Re-measure: how much space came back?

### Task 4 — Fix the spool

1. Show why the spool reports *No space left on device* although `df -h` shows free space.
2. Find the directory with the most files.
3. Count the messages older than 7 days, archive **exactly those** to `/opt/lab09/archive/spool-old.tar.gz` (Windows: `C:\lab09\archive\spool-old.zip`), verify the archive's file count, then delete them with a preview first.

### Task 5 — Clean up the data filesystem by policy

1. Save the last 1,000 lines of `debug.log` to the archive folder, then **empty** the log (do not delete it).
2. Copy the two older backups to the offload folder, create and verify SHA-256 checksums, and only then delete the originals.
3. Preview, then delete the `*.tmp` files in `app/cache`.
4. Confirm `reports/q3-summary.txt` is untouched.
5. Re-run `disk-monitor` for both filesystems: both must exit **0**.

### Task 6 — Persistent mount, verified (Linux) / letter check (Windows)

1. Linux: back up `/etc/fstab`, append an entry for `/srv/lab09` using its **UUID** and `nofail` (with a comment line above it), run `sudo findmnt --verify`, `sudo systemctl daemon-reload`, unmount `/srv/lab09`, and prove that `sudo mount -a` mounts it again from fstab.
2. Windows: list the partitions of the VHDX disk with their drive letters and preview a letter change with `-WhatIf` (do not apply it).
3. Explain in one sentence what would happen at the next boot if the entry had **no** `nofail` and the loop device did not exist.

### Task 7 — Incident note and clean-up

1. Add to the incident note: root causes, actions, before/after percentages, and one prevention measure per cause.
2. Restore `/etc/fstab` from the backup and prove it with `diff`; unmount and detach the practice disks; remove the lab folders. Windows: dismount the VHDX and remove `C:\lab09` (preview first). See [Clean-up](#clean-up).

## Commands to Execute

Work out each task yourself first, using the lesson. The complete commands, in order, are in the [Solution](#solution).

## Expected Results

Values below were **captured** when the Linux setup and solution were executed end to end on Ubuntu 24.04.5 (GNU coreutils 9.4, util-linux 2.39.3, e2fsprogs) as root in a container on 2026-11-11 (host renamed `ubuntu-lab`; PIDs and UUIDs will differ). Windows values are **expected approximations**: the Windows steps were reviewed against the Storage module and .NET documentation but not executed before release.

| Check | Linux (captured) | Windows (expected) |
|---|---|---|
| Task 1 data filesystem | `df -h`: `224M  196M  11M  95% /srv/lab09`; `disk-monitor` Status `CRITICAL`, **exit 3** | LAB09 about 90–95% used; `Disk-Monitor.ps1` Status `CRITICAL` or `WARNING`, **exit 3** |
| Task 1 spool | `df -h` 32% used, but `df -i` `2048 2048 0 100%`; `disk-monitor` level `INODES`, **exit 3** | NTFS does not run out of inodes; 2,036 files counted |
| Task 2 largest items | `app` 121M (`debug.log` 110M), `backups` 46M (3 × 15M), `app/cache` 11M | `app\logs\debug.log` about 135 MB, three 15 MB backups |
| Task 2/3 gap | `du -sxh` 166M vs `df` 196M: 30 MiB held by the deleted `trace-old.log` (`NLINK 0`, `SIZE/OFF 31457280`) | `Remove-Item` fails: *being used by another process* |
| Task 3 after ending the writer | `224M  166M  41M  81%` | File can be deleted after `$writer.Close()` |
| Task 4 spool | 2036 files in `queue`; 1500 older than 7 days archived (<code>tar -tzf … &#124; wc -l</code> → 1500) and deleted; `df -i` → `548 used, 1500 free, 27%` | 1500 files in `spool-old.zip`, 536 remain |
| Task 5 after cleanup | `224M  16M  191M  8%`; `disk-monitor` Status `OK`, both runs **exit 0** | Status `OK`, **exit 0** (unless another volume on the PC is above 80%) |
| Task 6 | `findmnt --verify`: `Success, no errors or warnings detected`, exit 0; after `umount`, `mount -a` mounts `/dev/loop0` on `/srv/lab09` | `Set-Partition … -WhatIf` prints a *What if* line; nothing changes |
| Task 7 | `diff` prints nothing; `/opt/lab09`, `/srv/lab09*` gone; `losetup -a` shows no lab09 device | `C:\lab09` gone; `Get-DiskImage` reports the VHDX not attached (or the file no longer exists) |

## Verification Steps

=== "Bash"

    ```bash
    df -h /srv/lab09 /srv/lab09-spool                          # expect about 8% and 32%
    df -i /srv/lab09-spool                                     # expect IUse% well below 90%
    bash scripts/linux/disk-monitor.sh -m /srv/lab09 > /dev/null; echo "data exit: $?"        # 0
    bash scripts/linux/disk-monitor.sh -m /srv/lab09-spool > /dev/null; echo "spool exit: $?" # 0
    sudo lsof +L1 2>/dev/null | grep -c lab09                  # 0: nothing deleted-but-open
    sudo tar -tzf /opt/lab09/archive/spool-old.tar.gz | wc -l  # 1500
    wc -l < /opt/lab09/archive/debug-tail.log                  # 1000
    (cd /opt/lab09/offload && sha256sum -c SHA256SUMS)         # two lines ending in OK
    ls /srv/lab09/backups                                      # only db-2026-11-03.tar.gz
    cat /srv/lab09/reports/q3-summary.txt                      # quarterly summary - keep
    ```

=== "PowerShell"

    ```powershell
    Get-Volume -DriveLetter $L | Select-Object DriveLetter, FileSystemLabel, SizeRemaining, Size
    .\scripts\powershell\Disk-Monitor.ps1 -DriveName $L | Out-Null; "exit: $LASTEXITCODE"      # 0
    (Get-ChildItem "$root\spool\queue" -File).Count                                            # 536
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    ([System.IO.Compression.ZipFile]::OpenRead("$lab\archive\spool-old.zip")).Entries.Count    # 1500
    (Get-Content "$lab\archive\debug-tail.log").Count                                          # 1000
    Get-ChildItem "$root\backups" -Name                                                        # db-2026-11-03.zip
    Get-Content "$root\reports\q3-summary.txt"                                                 # quarterly summary - keep
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `losetup: cannot find an unused loop device` | All loop devices busy (many snaps) or no loop module | `sudo losetup -a`; `sudo modprobe loop`; on WSL2 use a VM instead |
| `mount: /srv/lab09: wrong fs type, bad option…` | `mkfs` was skipped or ran on the other device | `sudo blkid /dev/loopN`; re-run the setup after clean-up |
| `lsof +L1` shows nothing | The writer already exited, or you ran it without `sudo` | `pgrep -af '^lab09-writer'`; use `sudo lsof +L1` |
| `pkill -f lab09-writer` also matches the `sudo setsid` parent | `-f` matches full command lines | Anchor the pattern: `pkill -f '^lab09-writer'` |
| `tar: Removing leading '/' from member names` | You archived absolute paths | Harmless, but the solution `cd`s first and archives relative paths |
| `sha256sum: WARNING: 1 computed checksum did NOT match` | Copy incomplete or modified | Do **not** delete the original; copy again and re-verify |
| `findmnt --verify` reports `unreachable on boot required source` | Wrong UUID, or the loop device is detached | `sudo blkid -s UUID -o value /dev/loopN`; fix the line; keep `nofail` |
| `mount -a` does nothing for `/srv/lab09` | It was still mounted | `sudo umount /srv/lab09` first, then `sudo mount -a` |
| `diskpart` *Virtual Disk Service error: The file exists* | Leftover VHDX from an earlier attempt | Dismount and delete it (Clean-up), then repeat the setup |
| `Initialize-Disk` *Access denied* | Window not elevated | Run PowerShell as Administrator |
| `Disk-Monitor.ps1` exits 3 after cleanup on Windows | Another volume (often `C:`) is above 80% | Use `-DriveName $L`, as in the verification steps |
| `running scripts is disabled on this system` | Execution policy | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\powershell\Disk-Monitor.ps1 -DriveName R` (process scope only) |

## Questions

1. Why did `df` and `du` disagree on `/srv/lab09` by about 30 MiB, and why was ending the writer the correct fix rather than deleting more files?
2. Why could the spool not accept new messages while `df -h` showed 68% free? What long-term fix would you propose?
3. Why does the cleanup policy require checksums **before** deleting the original backups? What would `mv` across filesystems have done differently?
4. Why is emptying `debug.log` with `truncate -s 0` better than `rm debug.log` while the application may still be running?
5. What does `nofail` protect against, and why should you run `findmnt --verify` and `mount -a` before rebooting?
6. Which of your actions changed the system, and how would you roll each one back?
7. Name one monitoring improvement that would have caught each problem earlier.

## Solution

??? success "Bash solution"
    ```bash
    cd ~/linux-powershell-professional-mastery
    note() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | sudo tee -a /opt/lab09/incident.txt; }

    # ---- Task 1: confirm ----
    df -h /srv/lab09 /srv/lab09-spool
    df -i /srv/lab09 /srv/lab09-spool
    bash scripts/linux/disk-monitor.sh -m /srv/lab09 -p /srv/lab09 -n 5; echo "exit: $?"
    bash scripts/linux/disk-monitor.sh -m /srv/lab09-spool; echo "exit: $?"
    note "DISK-1 confirmed: /srv/lab09 95% used (disk-monitor CRITICAL, exit 3)"
    note "DISK-2 confirmed: /srv/lab09-spool 32% space but 100% inodes (exit 3)"

    # ---- Task 2: drill down ----
    sudo du -xh -d 1 /srv/lab09 | sort -rh
    sudo du -xh -d 1 /srv/lab09/app | sort -rh
    sudo find /srv/lab09 -xdev -type f -size +10M -exec ls -lh {} +
    sudo tail -n 2 /srv/lab09/app/logs/debug.log
    sudo du -sxh /srv/lab09            # 166M, while df says 196M used

    # ---- Task 3: the gap ----
    sudo lsof +L1 | grep -E 'COMMAND|lab09'
    pgrep -af '^lab09-writer'
    ps -o pid,user,etime,args -p "$(pgrep -f '^lab09-writer')"
    sudo pkill -f '^lab09-writer'      # our own lab process; on a server: restart/reload the service
    sleep 1; df -h /srv/lab09          # 81%
    note "30 MiB held by deleted trace-old.log (PID of lab09-writer); writer ended, space released"

    # ---- Task 4: spool ----
    sudo find /srv/lab09-spool -xdev -type f | cut -d/ -f1-4 | sort | uniq -c | sort -rn | head -3
    sudo find /srv/lab09-spool/queue -type f -mtime +7 | wc -l          # 1500
    sudo find /srv/lab09-spool/queue -type f -mtime +7 | head -3        # preview
    sudo mkdir -p /opt/lab09/archive
    ( cd /srv/lab09-spool &&
      sudo find queue -type f -mtime +7 -print0 |
      sudo tar --null -czf /opt/lab09/archive/spool-old.tar.gz --files-from=- )
    sudo tar -tzf /opt/lab09/archive/spool-old.tar.gz | wc -l           # 1500 - matches
    sudo find /srv/lab09-spool/queue -type f -mtime +7 -delete
    df -i /srv/lab09-spool
    note "Spool: 1500 messages older than 7 days archived to /opt/lab09/archive/spool-old.tar.gz and removed; IUse% 27%"

    # ---- Task 5: policy cleanup ----
    sudo tail -n 1000 /srv/lab09/app/logs/debug.log | sudo tee /opt/lab09/archive/debug-tail.log > /dev/null
    wc -l < /opt/lab09/archive/debug-tail.log                           # 1000
    sudo truncate -s 0 /srv/lab09/app/logs/debug.log
    sudo mkdir -p /opt/lab09/offload
    sudo cp -a /srv/lab09/backups/db-2026-11-0{1,2}.tar.gz /opt/lab09/offload/
    ( cd /srv/lab09/backups && sha256sum db-2026-11-0{1,2}.tar.gz ) | sudo tee /opt/lab09/offload/SHA256SUMS
    ( cd /opt/lab09/offload && sha256sum -c SHA256SUMS ) &&
        sudo rm -v /srv/lab09/backups/db-2026-11-0{1,2}.tar.gz
    sudo find /srv/lab09/app/cache -type f -name '*.tmp' | wc -l         # 40 - preview
    sudo find /srv/lab09/app/cache -type f -name '*.tmp' -delete
    cat /srv/lab09/reports/q3-summary.txt
    df -h /srv/lab09                                                    # 8%
    bash scripts/linux/disk-monitor.sh -m /srv/lab09 > /dev/null; echo "data exit: $?"
    bash scripts/linux/disk-monitor.sh -m /srv/lab09-spool > /dev/null; echo "spool exit: $?"
    note "Cleanup per policy done: /srv/lab09 8%, spool inodes 27%, disk-monitor exit 0 for both"

    # ---- Task 6: persistent mount by UUID, verified ----
    sudo cp -a /etc/fstab /etc/fstab.bak.lab09
    LOOP_DATA=$(sudo sed -n 's/^data=//p' /opt/lab09/devices.txt)
    uuid=$(sudo blkid -s UUID -o value "$LOOP_DATA"); echo "$uuid"
    printf '# LAB09 practice disk - remove after the lab\nUUID=%s  /srv/lab09  ext4  defaults,nofail  0  2\n' "$uuid" |
        sudo tee -a /etc/fstab
    sudo findmnt --verify; echo "verify exit: $?"
    sudo systemctl daemon-reload
    sudo umount /srv/lab09
    findmnt /srv/lab09; echo "mounted? exit: $?"       # 1 = not mounted
    sudo mount -a
    findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /srv/lab09
    ```

    **Captured output (key lines, Ubuntu 24.04.5 container, 2026-11-11):**

    ```text
    Filesystem      Size  Used Avail Use% Mounted on
    /dev/loop0      224M  196M   11M  95% /srv/lab09
    /dev/loop1       28M  8.1M   18M  32% /srv/lab09-spool
    Filesystem     Inodes IUsed IFree IUse% Mounted on
    /dev/loop0      65536    62 65474    1% /srv/lab09
    /dev/loop1       2048  2048     0  100% /srv/lab09-spool
    FILESYSTEM             TYPE         SIZE     USED    AVAIL  USE%  IUSE% LEVEL           MOUNTED_ON
    /dev/loop0             ext4       223.7M   195.0M    10.8M    95      1 CRITICAL        /srv/lab09
    --- Largest directories under /srv/lab09 (du -x, one level) ---
        165.0M  /srv/lab09 (total)
        120.0M  /srv/lab09/app
         45.0M  /srv/lab09/backups
           16K  /srv/lab09/lost+found
            8K  /srv/lab09/reports
    exit: 3
    /dev/loop1             ext4        27.5M     8.0M    17.2M    32    100 INODES          /srv/lab09-spool
    exit: 3
    -rw-r--r-- 1 root root 110M Nov 11 17:00 /srv/lab09/app/logs/debug.log
    -rw-r--r-- 1 root root  15M Nov 11 17:00 /srv/lab09/backups/db-2026-11-01.tar.gz
    -rw-r--r-- 1 root root  15M Nov 11 17:00 /srv/lab09/backups/db-2026-11-02.tar.gz
    -rw-r--r-- 1 root root  15M Nov 11 17:00 /srv/lab09/backups/db-2026-11-03.tar.gz
    166M    /srv/lab09
    COMMAND  PID     USER   FD   TYPE DEVICE SIZE/OFF NLINK NODE NAME
    sleep   1865     root    3r   REG    7,0 31457280     0   60 /srv/lab09/app/logs/trace-old.log (deleted)
    1865 lab09-writer 7200
    /dev/loop0      224M  166M   41M  81% /srv/lab09
       2036 /srv/lab09-spool/queue
    1500
    1500
    /dev/loop1       2048   548  1500   27% /srv/lab09-spool
    db-2026-11-01.tar.gz: OK
    db-2026-11-02.tar.gz: OK
    removed '/srv/lab09/backups/db-2026-11-01.tar.gz'
    removed '/srv/lab09/backups/db-2026-11-02.tar.gz'
    /dev/loop0      224M   16M  191M   8% /srv/lab09
    data exit: 0
    spool exit: 0
    Success, no errors or warnings detected
    verify exit: 0
    mounted? exit: 1
    TARGET     SOURCE     FSTYPE OPTIONS
    /srv/lab09 /dev/loop0 ext4   rw,relatime
    ```

    `lsof` shows the command as `sleep` (the kernel's process name), while `pgrep -a` shows the renamed command line `lab09-writer 7200` — another reason to look at both.

??? success "PowerShell solution"
    Run in the **same elevated window** as the setup (it needs `$writer`, `$root`, `$L`, `$lab` and `$vhd`), from the repository root.

    ```powershell
    Set-Location ~\linux-powershell-professional-mastery
    function Add-Note([string]$Text) { "{0} {1}" -f (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'), $Text |
        Tee-Object -FilePath "$lab\incident.txt" -Append }

    # ---- Task 1: confirm ----
    Get-Volume -DriveLetter $L | Select-Object DriveLetter, FileSystemLabel,
        @{ n = 'UsedPct'; e = { [math]::Round(100 - $_.SizeRemaining / $_.Size * 100, 1) } }, SizeRemaining, Size
    .\scripts\powershell\Disk-Monitor.ps1 -DriveName $L -FolderPath $root -Top 5; "exit: $LASTEXITCODE"
    Add-Note "LAB09 volume $L confirmed above threshold (Disk-Monitor exit 3)"

    # ---- Task 2: drill down ----
    Get-ChildItem -Path $root -Directory -Force | ForEach-Object {
        $sum = (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        [pscustomobject]@{ Folder = $_.Name; SizeMB = [math]::Round($sum / 1MB, 1) }
    } | Sort-Object SizeMB -Descending
    Get-ChildItem -Path $root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object Length -gt 10MB | Sort-Object Length -Descending |
        Select-Object FullName, @{ n = 'SizeMB'; e = { [math]::Round($_.Length / 1MB, 1) } }
    Get-Content -Path "$root\app\logs\debug.log" -Tail 2

    # ---- Task 3: the locked file ----
    Remove-Item -Path "$root\app\logs\trace-old.log"        # fails: being used by another process
    $writer.Close()                                         # "restart the writer"
    Remove-Item -Path "$root\app\logs\trace-old.log" -WhatIf
    Remove-Item -Path "$root\app\logs\trace-old.log"
    Add-Note 'trace-old.log was locked by the writer; writer closed, file removed (30 MB)'

    # ---- Task 4: spool ----
    $cutoff = (Get-Date).AddDays(-7)
    $old = @(Get-ChildItem "$root\spool\queue" -File | Where-Object LastWriteTime -lt $cutoff)
    $old.Count                                               # 1500
    New-Item -ItemType Directory -Path "$lab\archive" -Force | Out-Null
    Compress-Archive -Path $old.FullName -DestinationPath "$lab\archive\spool-old.zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead("$lab\archive\spool-old.zip")
    $zip.Entries.Count; $zip.Dispose()                        # 1500 - matches
    $old | Select-Object -First 5 FullName, LastWriteTime     # preview a sample
    $old | Remove-Item
    Add-Note 'Spool: 1500 messages older than 7 days archived to C:\lab09\archive\spool-old.zip and removed'

    # ---- Task 5: policy cleanup ----
    Get-Content "$root\app\logs\debug.log" -Tail 1000 | Set-Content "$lab\archive\debug-tail.log"
    Clear-Content -Path "$root\app\logs\debug.log"          # empty the log, keep the file
    New-Item -ItemType Directory -Path "$lab\offload" -Force | Out-Null
    $older = Get-ChildItem -Path "$root\backups\db-2026-11-0[12].zip"   # -Path supports [12]; -Filter does not
    $older | Copy-Item -Destination "$lab\offload"
    $verified = foreach ($f in $older) {
        $src = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        $dst = (Get-FileHash -LiteralPath (Join-Path "$lab\offload" $f.Name) -Algorithm SHA256).Hash
        [pscustomobject]@{ File = $f.Name; Match = ($src -eq $dst) }
    }
    $verified
    if (@($verified | Where-Object { -not $_.Match }).Count -eq 0) { $older | Remove-Item -Verbose }
    Get-ChildItem "$root\app\cache" -Filter *.tmp | Remove-Item -WhatIf      # 40 'What if' lines
    Get-ChildItem "$root\app\cache" -Filter *.tmp | Remove-Item
    Get-Content "$root\reports\q3-summary.txt"
    .\scripts\powershell\Disk-Monitor.ps1 -DriveName $L | Out-Null; "exit: $LASTEXITCODE"   # 0
    Add-Note "Cleanup per policy done; Disk-Monitor exit $LASTEXITCODE"

    # ---- Task 6: letters, preview only ----
    Get-Partition -DiskNumber (Get-DiskImage -ImagePath $vhd | Get-Disk).Number |
        Select-Object PartitionNumber, DriveLetter, Type, Size
    Get-Partition -DriveLetter $L | Set-Partition -NewDriveLetter Q -WhatIf
    ```

    For 1,500 files a full `-WhatIf` listing is too long to read; previewing the count plus a sample (`Select-Object -First 5`) of the **same** `$old` collection you are about to delete is the practical equivalent.

??? success "Answers to questions"
    1. The 30 MiB `trace-old.log` had been deleted (its name removed, link count 0) but `lab09-writer` still held it open on descriptor 3, so its blocks stayed allocated: `df` counts them, `du` cannot see a file without a name. Deleting other files would only hide the problem; ending/restarting the holder releases the space and keeps the remaining data. On Windows the same file simply could not be deleted while open.
    2. All 2,048 inodes were used by tiny messages: each file needs an inode, regardless of free blocks. Long term: fix or schedule spool expiry (the application or a timer running the archive-and-delete), alert on `IUse%`, and recreate the filesystem with more inodes (`mkfs.ext4 -i 4096` or `-N`) or use XFS, whose inodes are dynamic.
    3. Deleting the only copy before proving the new copy is identical risks losing the backup if the copy was incomplete or corrupt. `mv` across filesystems copies and then deletes automatically — without a checksum step you would not notice a silent corruption, and an interrupted `mv` can leave you guessing which copy is complete.
    4. A running application keeps writing to the open file. `rm` would remove the name but not free the space (the Task 3 problem again), and the application would keep writing to an invisible file. `truncate -s 0` (or `Clear-Content`) frees the blocks immediately and keeps the same file, so the application continues logging normally.
    5. `nofail` lets the boot continue if the device is missing (here: the loop device does not exist after a reboot because nothing re-attaches it). Without it the filesystem is *required* and the server stops in emergency mode. `findmnt --verify` catches syntax, UUID and mount-point errors, and `mount -a` proves the line actually works, both **before** a reboot turns a mistake into an outage.
    6. Changes: ended a process (lab-only, no rollback needed), archived and deleted spool messages (restore with `tar -xzf … -C /srv/lab09-spool`), emptied `debug.log` (tail saved), moved two backups (copies with checksums in offload), deleted cache files (disposable by policy), edited `/etc/fstab` (restore from `/etc/fstab.bak.lab09`, verified with `diff`).
    7. Alert on inode usage as well as space; alert on the *gap* between `df` and `du` or on `lsof +L1` results; set log level and logrotate/size limits for `debug.log`; enforce backup retention on the server (keep 1) with off-host copies; expire spool messages automatically; trend usage daily (`disk-monitor -o` reports) to see growth before 95%.

## Clean-up

Run this when you have finished (also after a failed attempt). Preview first, then remove.

```bash
sudo cp -a /etc/fstab.bak.lab09 /etc/fstab && diff /etc/fstab.bak.lab09 /etc/fstab && echo "fstab restored"
sudo systemctl daemon-reload
sudo pkill -f '^lab09-writer'
sudo umount /srv/lab09 /srv/lab09-spool
sudo losetup -a | grep lab09                     # preview the devices to detach
for dev in $(sudo losetup -j /opt/lab09/data.img -O NAME -n) $(sudo losetup -j /opt/lab09/spool.img -O NAME -n); do
    sudo losetup -d "$dev"
done
ls -la /opt/lab09                                # preview
sudo rm -r /opt/lab09 && sudo rmdir /srv/lab09 /srv/lab09-spool && sudo rm /etc/fstab.bak.lab09
grep -c lab09 /etc/fstab                         # 0
```

```powershell
if ($writer) { $writer.Close() }
Dismount-DiskImage -ImagePath C:\lab09\lab09.vhdx
Remove-Item C:\lab09 -Recurse -WhatIf
Remove-Item C:\lab09 -Recurse
Test-Path C:\lab09                               # False
```
