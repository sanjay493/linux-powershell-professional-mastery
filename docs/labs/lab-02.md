---
description: "Build, back up, reorganise and safely clean a project folder tree in Bash and PowerShell."
---

# Lab 02: Project Workspace

| Field | Value |
|---|---|
| **Lab ID** | LAB-02 |
| **Related lesson** | [Day 02: File and Directory Management](../course/module-1/day-02.md) |
| **Difficulty** | Beginner |
| **Time** | 60–75 minutes |
| **Risk level** | Low. All changes stay inside `~/lab02`. Do **not** run any command outside that folder. |

## Objective

Create a standard project workspace, populate it with sample files, take a correct backup, reorganise files with wildcards, and perform a safe, previewed cleanup in **both** Bash and PowerShell.

## Required Environment

- Ubuntu 24.04 LTS terminal (normal user) and/or Windows 11 PowerShell (5.1 or 7, **not** elevated).
- About 1 MB free disk space.

## Initial Conditions

- `~/lab02` (Linux) / `$HOME\lab02` (Windows) **must not exist**. Check first:
    - Bash: `ls -d ~/lab02` should report `No such file or directory`.
    - PowerShell: `Test-Path $HOME\lab02` should return `False`.
- If it exists from an earlier attempt, rename it (`mv ~/lab02 ~/lab02.old`) rather than deleting it.

## Step-by-Step Instructions

1. **Create the tree** `lab02/webapp/{config,logs,src,docs}` plus `lab02/backups`, using **one** command per shell.
2. **Create files**:
    - `config/app.conf`, `config/db.conf`
    - `logs/access-2026-11-01.log`, `logs/access-2026-11-02.log`, `logs/error-2026-11-02.log`, `logs/debug.tmp`, `logs/cache.tmp`
    - `src/main.sh` (Linux) / `src/Main.ps1` (Windows)
    - `docs/README.txt` containing the text `Webapp documentation`
3. **Back up the config folder** to `backups/config-YYYY-MM-DD` (today's date) so that the backup folder **directly** contains `app.conf` and `db.conf`, not a nested `config` folder.
4. **Reorganise logs**: create `logs/archive` and move only the `access-*` logs from **2026-11-01** into it.
5. **Rename** `docs/README.txt` to `docs/README.md`.
6. **Preview and then delete** all `*.tmp` files in `logs`.
7. **Attempt to remove** `webapp/src` with the "only if empty" command and observe that it refuses.
8. **Display the final tree.**

## Commands to Execute

Try each step yourself first. Commands are in the [Solution](#solution).

## Expected Results

Final structure (both platforms, apart from the script file name):

```text
lab02
├── backups
│   └── config-2026-11-08
│       ├── app.conf
│       └── db.conf
└── webapp
    ├── config
    │   ├── app.conf
    │   └── db.conf
    ├── docs
    │   └── README.md
    ├── logs
    │   ├── access-2026-11-02.log
    │   ├── archive
    │   │   └── access-2026-11-01.log
    │   └── error-2026-11-02.log
    └── src
        └── main.sh
```

## Verification Steps

=== "Bash"

    ```bash
    cd ~/lab02
    find . | sort
    ls webapp/logs/*.tmp 2>/dev/null | wc -l          # expect 0
    ls backups/config-*/                               # expect app.conf db.conf
    cat webapp/docs/README.md                          # expect "Webapp documentation"
    ```

=== "PowerShell"

    ```powershell
    Set-Location $HOME\lab02
    Get-ChildItem -Recurse | Select-Object -ExpandProperty FullName | Sort-Object
    (Get-ChildItem webapp\logs -Filter *.tmp).Count    # expect 0
    Get-ChildItem backups\config-* | Get-ChildItem -Name   # expect app.conf db.conf
    Get-Content webapp\docs\README.md                  # expect "Webapp documentation"
    ```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Backup contains `config-.../config/app.conf` | Destination folder already existed when you copied the directory | Delete that backup folder (preview first) and copy the **contents**: `cp -r webapp/config/. backups/config-$(date +%F)/` |
| `mv: cannot stat 'webapp/logs/access-2026-11-01*'` | Wrong directory or typo | `pwd`; use tab completion |
| PowerShell `Rename-Item` error about the path | `-NewName` given a path | Use only `README.md` as the new name |
| `rmdir` succeeded on `src` | `src` was empty because step 2 was skipped | Recreate the file and repeat step 7 |
| Files show up in `C:\Windows\System32` | You opened an elevated PowerShell, which starts there | Close it; use a normal window; `Set-Location ~` |

## Questions

1. Why did step 3 require copying the folder's **contents**?
2. What would have happened in step 6 if you had typed `rm logs/*.tmp *` by accident? How does previewing protect you?
3. Why does `rmdir` (and `Remove-Item` without `-Recurse`) refuse to delete `src`, and why is that useful?
4. Which PowerShell parameter showed you what would be deleted without deleting it?
5. How would you make step 1 safe to run twice?

## Solution

??? success "Bash solution"
    ```bash
    # 1. tree (idempotent)
    mkdir -p ~/lab02/webapp/{config,logs,src,docs} ~/lab02/backups
    cd ~/lab02/webapp

    # 2. files
    touch config/{app,db}.conf
    touch logs/access-2026-11-0{1,2}.log logs/error-2026-11-02.log logs/{debug,cache}.tmp
    touch src/main.sh
    echo "Webapp documentation" > docs/README.txt

    # 3. backup the CONTENTS of config into a dated folder
    backup_dir=~/lab02/backups/config-$(date +%F)
    mkdir -p "$backup_dir"
    cp -av config/. "$backup_dir"/

    # 4. reorganise logs
    mkdir -p logs/archive
    mv -v logs/access-2026-11-01*.log logs/archive/

    # 5. rename
    mv -v docs/README.txt docs/README.md

    # 6. preview, then delete
    ls logs/*.tmp
    rm -iv logs/*.tmp

    # 7. refuses because src is not empty
    rmdir src          # rmdir: failed to remove 'src': Directory not empty

    # 8. final tree
    cd ~/lab02 && (tree 2>/dev/null || find . | sort)
    ```

??? success "PowerShell solution"
    ```powershell
    # 1. tree (idempotent with -Force for directories)
    $base = Join-Path $HOME 'lab02'
    'webapp\config','webapp\logs','webapp\src','webapp\docs','backups' |
        ForEach-Object { New-Item -Path (Join-Path $base $_) -ItemType Directory -Force | Out-Null }
    Set-Location (Join-Path $base 'webapp')

    # 2. files
    'config\app.conf','config\db.conf',
    'logs\access-2026-11-01.log','logs\access-2026-11-02.log','logs\error-2026-11-02.log',
    'logs\debug.tmp','logs\cache.tmp','src\Main.ps1' |
        ForEach-Object { New-Item -Path $_ -ItemType File | Out-Null }
    New-Item -Path docs\README.txt -ItemType File -Value 'Webapp documentation' | Out-Null

    # 3. backup the CONTENTS of config
    $backupDir = Join-Path $base ("backups\config-{0}" -f (Get-Date -Format 'yyyy-MM-dd'))
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    Copy-Item -Path config\* -Destination $backupDir -PassThru | Select-Object Name

    # 4. reorganise logs
    New-Item -Path logs\archive -ItemType Directory -Force | Out-Null
    Move-Item -Path logs\access-2026-11-01*.log -Destination logs\archive -PassThru

    # 5. rename (name only, not a path)
    Rename-Item -Path docs\README.txt -NewName README.md

    # 6. preview, simulate, delete
    Get-ChildItem logs -Filter *.tmp
    Remove-Item -Path logs\*.tmp -WhatIf
    Remove-Item -Path logs\*.tmp

    # 7. Remove-Item on a non-empty folder without -Recurse asks for confirmation. Answer N.
    Remove-Item -Path src

    # 8. final tree
    Set-Location $base
    Get-ChildItem -Recurse | Select-Object -ExpandProperty FullName
    ```

??? success "Answers to questions"
    1. The backup folder already existed (we created it first). Copying a *directory* into an existing directory nests it. Copying `config/.` (Bash) or `config\*` (PowerShell) copies only the contents.
    2. The extra `*` would expand to **every** file in the current directory, and `rm` would delete them all. Running `ls` with the exact same pattern first shows the full list before anything is deleted.
    3. They only remove empty directories by default. That makes cleanup safe: if something unexpected is inside, nothing is lost.
    4. `-WhatIf`.
    5. Use `mkdir -p` / `New-Item -ItemType Directory -Force`. Both succeed silently if the directories already exist.

## Clean-up (optional)

```bash
ls -R ~/lab02 && rm -rI ~/lab02
```

```powershell
Remove-Item $HOME\lab02 -Recurse -WhatIf
Remove-Item $HOME\lab02 -Recurse
```
