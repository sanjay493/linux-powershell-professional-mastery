---
description: "Turn two days of web access logs (one rotated and gzip-compressed), a server inventory CSV with quoted commas and a nested JSON alert feed into answers and reports: top clients, status codes and error rate, a vulnerability scanner, a brute force that ended in a successful login, a 5xx outage hour, a 3.5 GiB download, disks over 90 %, alert owners; a previewed sed/-replace config change; summary.csv and findings.json built with awk, sort, jq and PowerShell objects."
---

# Lab 24: Access Log Report

| Field | Value |
|---|---|
| **Lab ID** | LAB-24 |
| **Related lesson** | [Day 24: Text and Data Processing](../course/module-5/day-24.md) |
| **Difficulty** | Intermediate |
| **Time** | 90–120 minutes |
| **Risk level** | None to low. All data is generated into `~/lab24` / `$HOME\lab24` by a setup script you read first. The analysis is **read-only**; the only file you change is the lab's own `config/report.conf`, after a preview and with a backup. No network access, no root/Administrator rights. All IP addresses are from the documentation ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24). |

## Objective

It is the morning of 19 November. The web team asks the operations and security teams for a report on the last two days of the public web server, because "something odd happened yesterday". You have:

- `logs/access.log` (18 November) and `logs/access.log.1.gz` (17 November, rotated and compressed) in the combined log format;
- `inventory/servers.csv` — the server inventory, whose `notes` column contains **quoted commas**;
- `alerts/alerts.json` — the monitoring system's current alerts, as **nested JSON**;
- `config/report.conf` — thresholds for the report.

Produce the answers below, then two machine-readable deliverables, `report/summary.csv` and `report/findings.json`, using text tools in Bash and objects in PowerShell:

1. How many requests and distinct clients; who are the top talkers?
2. What is the status-code distribution and the error rate for 18 November?
3. Is anyone scanning for vulnerabilities? Which paths did they probe?
4. Was there a brute-force attack, and did it **succeed**? Which client only *looks* suspicious?
5. When did the 5xx outage happen, and who downloaded gigabytes?
6. Which servers are above 90 % disk, which alerts are critical, and who owns each alerted host?

## Required Environment

- **Linux:** Ubuntu 24.04 LTS (VM, WSL2 or physical) with Bash 5.x, coreutils, GNU sed, `awk` (mawk is fine), gzip and **jq** (`sudo apt install jq`). Normal user.
- **Windows:** Windows 11 with Windows PowerShell 5.1 and/or PowerShell 7.4+. Normal user. The PowerShell solution also runs in PowerShell 7 on Linux.
- About 1 MB of disk space.

## Initial Conditions

- `~/lab24` / `$HOME\lab24` does not exist (rename an old one first).
- Save the setup script for your platform from the [Solution](#solution) section ("Lab setup scripts") into your home directory, **read it**, then run it:

=== "Linux"

    ```bash
    cd ~ && bash lab24-setup.sh
    cd ~/lab24 && sha256sum logs/access.log inventory/servers.csv alerts/alerts.json config/report.conf
    zcat logs/access.log.1.gz | sha256sum
    ```

=== "Windows"

    ```powershell
    Set-Location $HOME
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Lab24-Setup.ps1
    Set-Location $HOME\lab24
    Get-FileHash .\logs\access.log, .\inventory\servers.csv, .\alerts\alerts.json, .\config\report.conf |
        Select-Object Hash, @{N = 'File'; E = { Split-Path $_.Path -Leaf }}
    ```

    The PowerShell setup script writes the same data as the Bash script (LF line endings, UTF-8 without BOM). If you have WSL2, you can instead run the **Bash** setup script there and copy `~/lab24` to Windows; either way, the hashes should match the values below. The `.gz` file itself can differ byte for byte between gzip implementations — compare the **decompressed** content.

Expected SHA-256 values of the Bash setup output (captured on 2026-11-18):

```text
2ec3e6c98705c36d1169579a5c9c968459535f1100c3db47ff4cb3fc766259c8  logs/access.log
fa486d1e6797477599120f27c21cf28af0a6e740bdf08423d0bb220876c1bd33  inventory/servers.csv
2f3e1d497a9a1124a4fc275f5c784c2e62825049160b931ff065a9f44a1fe35e  alerts/alerts.json
241fcbff4b3341bc822ef835aed6bb128d96461feefbdc78039f85d87b0b3515  config/report.conf
37d57117a4b59006b8be7a52466eeb1eea4dd4c9eac9bcaa50787486adae4216  -   (decompressed access.log.1.gz)
```

The data set:

```text
lab24/
├── alerts/alerts.json        6 alerts, nested "details" objects and "tags" arrays
├── config/report.conf        retention_days, top_n, scanner/bruteforce thresholds
├── inventory/servers.csv     7 servers; the notes column has quoted commas
├── logs/access.log           18 Nov 2026, 461 lines
├── logs/access.log.1.gz      17 Nov 2026, 306 lines (gzip)
└── report/                   empty: your deliverables go here
```

## Step-by-Step Instructions

Work in `~/lab24` / `$HOME\lab24`. For every task, first look at a few raw lines (`head`, `zcat … | head`, `Get-Content -TotalCount`), then build the answer one pipeline stage at a time.

### Task 1 — Volume and top talkers (both files)

Count all requests in both files together, the number of distinct client IPs, and the top 5 clients by request count (ties ordered by IP). Read the compressed file **without** decompressing it to disk.

### Task 2 — Status codes and error rate (18 November)

For `access.log` only: count requests per status code, largest first, and compute the error rate (status ≥ 400) as a percentage with one decimal.

### Task 3 — Scanner detection

Using both files, list client IPs with at least `scanner_404_threshold` (from `report.conf`) responses with status 404. For the scanner, list every path it requested with a count. Note what else (not 404) it received.

### Task 4 — Brute force and success after failure

In `access.log`, find clients with at least `bruteforce_401_threshold` failed logins (`POST /login` → 401). Then find the client whose failures were **followed by a successful login** (`POST /login` → 200), with the failure count and the time of the success. What did that client do immediately afterwards? Which other client crosses the failure threshold, and why is it not an attack?

### Task 5 — Outage hour and big downloads

In `access.log`, count 5xx responses per hour and name the peak hour and path. Across both files, list the top 3 clients by bytes transferred, in MiB with one decimal.

### Task 6 — Inventory and alerts

1. Show the `notes` column with a naive `cut -d, -f7` (or `-split ','`) and explain the output.
2. List the servers with `disk_pct` ≥ 90 with their owner, using a method that is correct for this file.
3. From `alerts.json`: list the critical alerts (host, check, value), count alerts per severity, and print the `details.mount` of every disk alert.
4. Join every non-info alert to the server owner from the inventory.

### Task 7 — Change a report setting safely

Change `retention_days` in `config/report.conf` from 7 to 30: preview the change as a diff, apply it with a backup, verify, and then **restore** the original (the lab hashes assume the original).

### Task 8 — Deliverables

Write:

- `report/summary.csv` with header `ip,requests,errors,mib` — one row per client across both files, sorted by requests (descending), then IP; `mib` with one decimal.
- `report/findings.json` with: `generated` (UTC ISO 8601), `top_clients` (top `top_n` as `{ip, requests}`), `scanners`, `bruteforce_success` (`{ip, failures, success_at}`), `peak_5xx_hour` (`{hour, count}`), `disk_over_90` and `critical_alerts` (host names).

Read the thresholds and `top_n` from `config/report.conf` instead of hard-coding them.

## Commands to Execute

Try each task yourself first; the complete commands are in the [Solution](#solution). Building blocks:

| Need | Bash | PowerShell |
|---|---|---|
| Read plain + gzip logs | `zcat -f logs/access.log.1.gz logs/access.log` | `Get-GzipContent` helper (solution) + `Get-Content` |
| Field / count | <code>awk '{print $1}' &#124; sort &#124; uniq -c</code> | `ConvertFrom-AccessLog` (regex → objects) + `Group-Object` |
| Per-key sums | `awk '{b[$1] += $10} END {…}'` | `Group-Object IP` + `Measure-Object Bytes -Sum` |
| Hour of a request | `split($4, t, ":"); t[2]` | `$_.Time.Hour` |
| CSV with quotes | `awk -F,` only on columns **before** `notes` | `Import-Csv` |
| JSON | <code>jq -r '.alerts[] &#124; …'</code> | <code>(Get-Content -Raw … &#124; ConvertFrom-Json).alerts</code> |
| Join | `join -t,` on sorted files | hashtable lookup |
| Config value | `sed -n -E 's/^key[[:space:]]*=[[:space:]]*([^[:space:]#]+).*/\1/p'` | `-match '^key\s*=\s*(\S+)'` |
| Build JSON | `jq -n --arg … --argjson … '{…}'` | <code>[pscustomobject]@{…} &#124; ConvertTo-Json -Depth 4</code> |

## Expected Results

The values below were **captured** on 2026-11-18 by running the Bash setup script and the Bash solution commands in this lab with Bash 5.2.21, GNU coreutils 9.4, GNU sed 4.9, mawk 1.3.4 and jq 1.7 on Ubuntu 24.04.5 (container, `C` locale). The PowerShell solution was **not executed** (no PowerShell on the release host); it is written to produce the same values.

| Task | Answer |
|---|---|
| 1 | **767** requests, **11** distinct clients. Top 5: `198.51.100.11`, `.12`, `.13`, `.14` with 88 each, `198.51.100.15` with 87 |
| 2 | `200` 351 · `500` 40 · `401` 39 · `404` 28 · `403` 3 — 461 requests, 110 errors, **23.9 %** error rate |
| 3 | Scanner **203.0.113.66** (27 × 404 across both days; nobody else has more than 4). Paths: `/.env`, `/.git/config`, `/admin`, `/backup.zip`, `/phpmyadmin/`, `/wp-login.php` 4 each, `/config.php` and `/server-status` 3 each; `/server-status` returned **403** (3 times) |
| 4 | **192.0.2.77**: 30 failures between 03:12:01 and 03:13:00, then success at **18/Nov/2026:03:13:01**, then `GET /admin/export` (5 MiB) two seconds later. `198.51.100.11` also has 9 failures, but spread over the whole day (00:30 … 20:57) and never a success — a user mistyping, not an attack |
| 5 | Peak **10:00** with 40 × `500`, all on `GET /api/orders` (10:00–10:39). Top bytes: `198.51.100.200` **3500.0 MiB** (five downloads of `/downloads/dataset.tar.gz` at 14:00–14:08), `192.0.2.77` 5.0 MiB, `198.51.100.13` 0.3 MiB |
| 6 | `cut -d, -f7` prints `notes`, `"frontend`, `"frontend`… (split inside the quotes). Disk ≥ 90: `web-02` 93 % ops, `file-01` 97 % wintel, `backup-01` 91 % ops. Critical: `web-02 disk 93`, `file-01 disk 97`, `api-01 http_5xx 40`. Per severity: critical 3, info 1, warning 2. Owners: `api-01,critical,dev` · `backup-01,warning,ops` · `db-01,warning,dba` · `file-01,critical,wintel` · `web-02,critical,ops` |
| 7 | `diff` shows `< retention_days = 7` / `> retention_days = 30`; `report.conf.bak` is identical to the original (`cmp` silent); after restoring, `grep retention` shows 7 again |
| 8 | `summary.csv`: 11 data rows; first `198.51.100.11,88,22,0.2`, last three `192.0.2.77,32,30,5.0` · `203.0.113.66,30,30,0.0` · `198.51.100.200,5,0,3500.0`. `findings.json` as shown in the Bash solution |

The `api-01` 5xx alert in `alerts.json` (value 40) agrees with the 40 × 500 in the log — two independent sources confirming the outage.

## Verification Steps

=== "Bash"

    ```bash
    cd ~/lab24
    zcat -f logs/access.log.1.gz logs/access.log | wc -l                          # 767
    head -1 report/summary.csv && tail -n +2 report/summary.csv | wc -l          # header; 11
    awk -F, 'NR > 1 {s += $2} END {print s}' report/summary.csv                  # 767 (rows add up)
    jq -e '.bruteforce_success[0].ip == "192.0.2.77"' report/findings.json       # true, exit 0
    jq -r '.scanners[], .peak_5xx_hour.hour' report/findings.json                # 203.0.113.66 / 10
    grep -c '^retention_days = 7$' config/report.conf                            # 1 (restored)
    sha256sum logs/access.log                                                     # unchanged hash
    ```

=== "PowerShell"

    ```powershell
    Set-Location $HOME\lab24
    $s = Import-Csv .\report\summary.csv
    $s.Count                                                              # 11
    ($s | Measure-Object -Property requests -Sum).Sum                     # 767
    $f = Get-Content .\report\findings.json -Raw | ConvertFrom-Json
    $f.bruteforce_success[0].ip; $f.scanners; $f.peak_5xx_hour.hour       # 192.0.2.77 / 203.0.113.66 / 10
    (Select-String -Path .\config\report.conf -Pattern '^retention_days = 7$').Count   # 1
    (Get-FileHash .\logs\access.log).Hash                                 # unchanged
    ```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `gzip: stdin: not in gzip format` | `zcat` without `-f` on the plain file, or a corrupt download | `zcat -f` reads plain files unchanged |
| Counts are about 300 too low | Only `access.log` read | Include `access.log.1.gz` (Tasks 1, 3, 5, 8 use both) |
| Brute-force rule finds two clients | Count-only rule | Add the "followed by a 200" condition (Task 4) |
| `awk` prints the CSV header as a match | String comparison with the header row | `NR > 1 &&` |
| Disk list misses or includes the wrong server | Comparing text, or splitting inside quotes | Bash: fields 1–6 are before the quoted column, so `awk -F,` on `$5` is safe here; PowerShell: `[int]$_.disk_pct` |
| `jq: error … Cannot index array with "severity"` | Forgot `.alerts[]` | The alerts are inside the top-level object |
| `join: file 1 is not in sorted order` | Inputs not sorted on field 1 | `sort -t, -k1,1` both inputs (same locale) |
| Ties in the top-5 come out in a different order | Locale or missing secondary key | `sort -k1,1nr -k2,2` / two-key `Sort-Object` |
| Hash of `access.log` differs on Windows | CRLF line endings or BOM (file opened and saved in an editor) | Re-run the setup script; never edit the evidence files |
| PowerShell: `Exception calling "ParseExact"` | Locale-dependent month names | Pass `[cultureinfo]::InvariantCulture` |
| PowerShell: `summary.csv` shows `0,2` instead of `0.2` | Number formatted with a culture that uses decimal commas | `.ToString('0.0', [cultureinfo]::InvariantCulture)` |
| PowerShell 5.1: `findings.json` has `"System.Object[]"` values | `-Depth` too low | `ConvertTo-Json -Depth 4` |

## Questions

1. Why must the brute-force rule check for a success *after* failures rather than just count failures? Use the two clients from Task 4 in your answer.
2. Why is `awk -F, '$5 >= 90'` safe for `servers.csv` even though the file has quoted commas, and when would it stop being safe?
3. `alerts.json` reports a critical `http_5xx` alert for `api-01` with value 40. How does the access log corroborate it, and why does corroboration from two sources matter in an incident report?
4. In Task 1, why do the four clients with 88 requests come out in IP order with `sort -k1,1nr -k2,2` but possibly in a different order with just `sort -rn`?
5. What is the risk of reading `/admin/export` 5 MiB as "just a download", and what would you check next on the server (think Days 17–20)?
6. Why does the PowerShell solution convert each log line into an object with typed properties before answering any question?
7. Why do you restore `report.conf` in Task 7, and what does `cmp` prove that `diff` output alone does not?

## Solution

??? success "Lab setup scripts (Bash: `lab24-setup.sh`)"
    ```bash
    #!/usr/bin/env bash
    # lab24-setup.sh - create the Lab 24 data set in ~/lab24 (deterministic; safe to re-run)
    set -o errexit -o nounset -o pipefail
    LAB=${LAB:-$HOME/lab24}
    mkdir -p "$LAB"/{logs,inventory,alerts,config,report}

    ua_linux='Mozilla/5.0 (X11; Linux x86_64)'
    ua_win='Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    paths=(/ /index.html /products /cart /images/logo.png /api/orders)
    scan=(/wp-login.php /.env /admin /phpmyadmin/ /.git/config /backup.zip /config.php /server-status)

    # line SECONDS DAY IP METHOD PATH STATUS BYTES UA -> "SECONDS<TAB>log line"
    line() {
        local s=$1
        printf '%05d\t%s - - [%s/Nov/2026:%02d:%02d:%02d +0000] "%s %s HTTP/1.1" %s %s "-" "%s"\n' \
            "$s" "$3" "$2" $((s / 3600)) $((s % 3600 / 60)) $((s % 60)) "$4" "$5" "$6" "$7" "$8"
    }

    normal() {   # normal DAY COUNT STEP
        local day=$1 n=$2 step=$3 i ip path method status bytes
        for (( i = 0; i < n; i++ )); do
            ip="198.51.100.$(( 11 + i % 8 ))"
            path=${paths[i % 6]} method=GET status=200 bytes=$(( 1000 + (i * 37) % 5000 ))
            if   (( i % 50 == 49 )); then path=/favicon.ico status=404 bytes=162
            elif (( i % 40 == 7 ));  then path=/login method=POST
            elif (( i % 40 == 8 ));  then path=/login method=POST status=401 bytes=512
            fi
            line $(( i * step )) "$day" "$ip" "$method" "$path" "$status" "$bytes" "$ua_linux"
        done
    }

    {
        normal 18 360 230
        for (( k = 0; k < 24; k++ )); do                       # A: scanner 02:14
            p=${scan[k % 8]} st=404; [[ $p == /server-status ]] && st=403
            line $(( 8041 + 2 * k )) 18 203.0.113.66 GET "$p" "$st" 162 'python-requests/2.31.0'
        done
        for (( k = 0; k < 30; k++ )); do                       # B: brute force 03:12
            line $(( 11521 + 2 * k )) 18 192.0.2.77 POST /login 401 512 "$ua_win"
        done
        line 11581 18 192.0.2.77 POST /login 200 1024 "$ua_win"
        line 11583 18 192.0.2.77 GET /admin/export 200 5242880 "$ua_win"
        for (( k = 0; k < 40; k++ )); do                       # C: 500 burst 10:00-10:39
            line $(( 36001 + 60 * k )) 18 "198.51.100.$(( 11 + k % 8 ))" GET /api/orders 500 128 "$ua_linux"
        done
        for (( k = 0; k < 5; k++ )); do                        # D: bulk download 14:00
            line $(( 50401 + 120 * k )) 18 198.51.100.200 GET /downloads/dataset.tar.gz 200 734003200 'Wget/1.21.4'
        done
    } | sort -n | cut -f2- > "$LAB/logs/access.log"

    {
        normal 17 300 287
        for (( k = 0; k < 6; k++ )); do
            line $(( 85801 + 2 * k )) 17 203.0.113.66 GET "${scan[k]}" 404 162 'python-requests/2.31.0'
        done
    } | sort -n | cut -f2- | gzip -n > "$LAB/logs/access.log.1.gz"

    cat > "$LAB/inventory/servers.csv" <<'CSV'
    name,role,ip,os,disk_pct,owner,notes
    web-01,web,10.0.1.11,ubuntu-24.04,71,ops,"frontend, pool A"
    web-02,web,10.0.1.12,ubuntu-24.04,93,ops,"frontend, pool B"
    api-01,api,10.0.1.21,ubuntu-24.04,58,dev,orders API
    db-01,database,10.0.2.21,ubuntu-22.04,88,dba,"primary, replicated"
    dc-01,domain,10.0.3.5,windows-2022,64,wintel,PDC emulator
    file-01,file,10.0.3.9,windows-2019,97,wintel,"shares: finance, hr"
    backup-01,backup,10.0.4.2,ubuntu-24.04,91,ops,nightly jobs
    CSV

    cat > "$LAB/alerts/alerts.json" <<'JSON'
    {
      "generated": "2026-11-18T15:00:00Z",
      "source": "lab-monitor",
      "alerts": [
        {"id": 501, "host": "web-02", "severity": "critical", "check": "disk", "value": 93, "details": {"mount": "/var"}, "tags": ["prod", "web"]},
        {"id": 502, "host": "db-01", "severity": "warning", "check": "disk", "value": 88, "details": {"mount": "/var/lib/postgresql"}, "tags": ["prod"]},
        {"id": 503, "host": "file-01", "severity": "critical", "check": "disk", "value": 97, "details": {"mount": "D:"}, "tags": ["prod", "smb"]},
        {"id": 504, "host": "api-01", "severity": "critical", "check": "http_5xx", "value": 40, "details": {"path": "/api/orders"}, "tags": ["prod", "api"]},
        {"id": 505, "host": "web-01", "severity": "info", "check": "cert_days", "value": 41, "details": {"cn": "www.example.com"}, "tags": []},
        {"id": 506, "host": "backup-01", "severity": "warning", "check": "disk", "value": 91, "details": {"mount": "/srv/backup"}, "tags": ["internal"]}
      ]
    }
    JSON

    cat > "$LAB/config/report.conf" <<'CONF'
    # report.conf - Lab 24 report settings
    retention_days = 7
    top_n = 5
    scanner_404_threshold = 10
    bruteforce_401_threshold = 5
    output_format = csv
    CONF

    printf 'Lab 24 data created in %s\n' "$LAB"
    find "$LAB" -type f | sort | sed "s|^$LAB/|  |"
    ```

    Every event gets a unique "seconds since midnight" key (normal traffic on even seconds, events on odd seconds), so `sort -n` merges them into one chronological log; `cut -f2-` then drops the key. `gzip -n` omits the file name and time stamp, which makes the compressed file reproducible. The script is `bash -n`- and ShellCheck-clean.

??? success "Lab setup scripts (PowerShell: `Lab24-Setup.ps1`)"
    ```powershell
    # Lab24-Setup.ps1 - create the Lab 24 data set in $HOME\lab24 (same data as lab24-setup.sh)
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $lab = Join-Path -Path $HOME -ChildPath 'lab24'
    foreach ($d in 'logs', 'inventory', 'alerts', 'config', 'report') {
        New-Item -Path (Join-Path $lab $d) -ItemType Directory -Force | Out-Null
    }
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false     # UTF-8 without BOM
    $uaLinux = 'Mozilla/5.0 (X11; Linux x86_64)'
    $uaWin   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    $paths = '/', '/index.html', '/products', '/cart', '/images/logo.png', '/api/orders'
    $scan  = '/wp-login.php', '/.env', '/admin', '/phpmyadmin/', '/.git/config', '/backup.zip', '/config.php', '/server-status'

    function New-LogLine {
        param([int]$Sec, [int]$Day, [string]$IP, [string]$Method, [string]$Path, [int]$Status, [long]$Bytes, [string]$Agent)
        $h = [int](($Sec - $Sec % 3600) / 3600)
        $m = [int](($Sec % 3600 - $Sec % 60) / 60)
        [pscustomobject]@{
            Sec  = $Sec
            Text = '{0} - - [{1}/Nov/2026:{2:D2}:{3:D2}:{4:D2} +0000] "{5} {6} HTTP/1.1" {7} {8} "-" "{9}"' -f `
                   $IP, $Day, $h, $m, ($Sec % 60), $Method, $Path, $Status, $Bytes, $Agent
        }
    }

    function Get-NormalTraffic {
        param([int]$Day, [int]$Count, [int]$Step)
        for ($i = 0; $i -lt $Count; $i++) {
            $ip = '198.51.100.{0}' -f (11 + $i % 8)
            $path = $paths[$i % 6]; $method = 'GET'; $status = 200; $bytes = 1000 + ($i * 37) % 5000
            if     ($i % 50 -eq 49) { $path = '/favicon.ico'; $status = 404; $bytes = 162 }
            elseif ($i % 40 -eq 7)  { $path = '/login'; $method = 'POST' }
            elseif ($i % 40 -eq 8)  { $path = '/login'; $method = 'POST'; $status = 401; $bytes = 512 }
            New-LogLine -Sec ($i * $Step) -Day $Day -IP $ip -Method $method -Path $path -Status $status -Bytes $bytes -Agent $uaLinux
        }
    }

    function ConvertTo-LogText {
        param([object[]]$Lines)
        (($Lines | Sort-Object -Property Sec | ForEach-Object { $_.Text }) -join "`n") + "`n"
    }

    # 18 November
    $day18 = @(Get-NormalTraffic -Day 18 -Count 360 -Step 230)
    for ($k = 0; $k -lt 24; $k++) {
        $p = $scan[$k % 8]; $st = if ($p -eq '/server-status') { 403 } else { 404 }
        $day18 += New-LogLine -Sec (8041 + 2 * $k) -Day 18 -IP '203.0.113.66' -Method GET -Path $p -Status $st -Bytes 162 -Agent 'python-requests/2.31.0'
    }
    for ($k = 0; $k -lt 30; $k++) {
        $day18 += New-LogLine -Sec (11521 + 2 * $k) -Day 18 -IP '192.0.2.77' -Method POST -Path '/login' -Status 401 -Bytes 512 -Agent $uaWin
    }
    $day18 += New-LogLine -Sec 11581 -Day 18 -IP '192.0.2.77' -Method POST -Path '/login' -Status 200 -Bytes 1024 -Agent $uaWin
    $day18 += New-LogLine -Sec 11583 -Day 18 -IP '192.0.2.77' -Method GET -Path '/admin/export' -Status 200 -Bytes 5242880 -Agent $uaWin
    for ($k = 0; $k -lt 40; $k++) {
        $day18 += New-LogLine -Sec (36001 + 60 * $k) -Day 18 -IP ('198.51.100.{0}' -f (11 + $k % 8)) -Method GET -Path '/api/orders' -Status 500 -Bytes 128 -Agent $uaLinux
    }
    for ($k = 0; $k -lt 5; $k++) {
        $day18 += New-LogLine -Sec (50401 + 120 * $k) -Day 18 -IP '198.51.100.200' -Method GET -Path '/downloads/dataset.tar.gz' -Status 200 -Bytes 734003200 -Agent 'Wget/1.21.4'
    }
    [System.IO.File]::WriteAllText((Join-Path $lab 'logs\access.log'), (ConvertTo-LogText $day18), $utf8)

    # 17 November (rotated, gzip-compressed)
    $day17 = @(Get-NormalTraffic -Day 17 -Count 300 -Step 287)
    for ($k = 0; $k -lt 6; $k++) {
        $day17 += New-LogLine -Sec (85801 + 2 * $k) -Day 17 -IP '203.0.113.66' -Method GET -Path $scan[$k] -Status 404 -Bytes 162 -Agent 'python-requests/2.31.0'
    }
    $bytes = $utf8.GetBytes((ConvertTo-LogText $day17))
    $fs = [System.IO.File]::Create((Join-Path $lab 'logs\access.log.1.gz'))
    $gz = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $fs, ([System.IO.Compression.CompressionMode]::Compress)
    $gz.Write($bytes, 0, $bytes.Length); $gz.Dispose(); $fs.Dispose()

    function Write-LabFile {
        param([string]$RelativePath, [string]$Content)
        $text = ($Content -replace "`r`n", "`n").TrimEnd("`n") + "`n"     # LF endings, one final newline
        [System.IO.File]::WriteAllText((Join-Path $lab $RelativePath), $text, $utf8)
    }

    Write-LabFile 'inventory\servers.csv' @'
    name,role,ip,os,disk_pct,owner,notes
    web-01,web,10.0.1.11,ubuntu-24.04,71,ops,"frontend, pool A"
    web-02,web,10.0.1.12,ubuntu-24.04,93,ops,"frontend, pool B"
    api-01,api,10.0.1.21,ubuntu-24.04,58,dev,orders API
    db-01,database,10.0.2.21,ubuntu-22.04,88,dba,"primary, replicated"
    dc-01,domain,10.0.3.5,windows-2022,64,wintel,PDC emulator
    file-01,file,10.0.3.9,windows-2019,97,wintel,"shares: finance, hr"
    backup-01,backup,10.0.4.2,ubuntu-24.04,91,ops,nightly jobs
    '@

    Write-LabFile 'alerts\alerts.json' @'
    {
      "generated": "2026-11-18T15:00:00Z",
      "source": "lab-monitor",
      "alerts": [
        {"id": 501, "host": "web-02", "severity": "critical", "check": "disk", "value": 93, "details": {"mount": "/var"}, "tags": ["prod", "web"]},
        {"id": 502, "host": "db-01", "severity": "warning", "check": "disk", "value": 88, "details": {"mount": "/var/lib/postgresql"}, "tags": ["prod"]},
        {"id": 503, "host": "file-01", "severity": "critical", "check": "disk", "value": 97, "details": {"mount": "D:"}, "tags": ["prod", "smb"]},
        {"id": 504, "host": "api-01", "severity": "critical", "check": "http_5xx", "value": 40, "details": {"path": "/api/orders"}, "tags": ["prod", "api"]},
        {"id": 505, "host": "web-01", "severity": "info", "check": "cert_days", "value": 41, "details": {"cn": "www.example.com"}, "tags": []},
        {"id": 506, "host": "backup-01", "severity": "warning", "check": "disk", "value": 91, "details": {"mount": "/srv/backup"}, "tags": ["internal"]}
      ]
    }
    '@

    Write-LabFile 'config\report.conf' @'
    # report.conf - Lab 24 report settings
    retention_days = 7
    top_n = 5
    scanner_404_threshold = 10
    bruteforce_401_threshold = 5
    output_format = csv
    '@

    "Lab 24 data created in $lab"
    Get-ChildItem -Path $lab -Recurse -File | ForEach-Object { '  ' + $_.FullName.Substring($lab.Length + 1) }
    ```

    The here-strings must start at the beginning of a line in your saved file (`@'` at the end of a line, `'@` at the start of a line). **Not executed before release** — if your hashes differ from the Bash values, generate the data in WSL2 with `lab24-setup.sh` instead; the analysis steps are the same.

??? success "Bash solution: Tasks 1–7"
    ```bash
    cd ~/lab24
    all() { zcat -f logs/access.log.1.gz logs/access.log; }

    # Task 1
    all | wc -l
    all | awk '{print $1}' | sort -u | wc -l
    all | awk '{print $1}' | sort | uniq -c | sort -k1,1nr -k2,2 | head -5

    # Task 2
    awk '{print $9}' logs/access.log | sort | uniq -c | sort -k1,1nr
    awk '{n++; if ($9 >= 400) e++} END {printf "%d requests, %d errors, %.1f%% error rate\n", n, e, 100*e/n}' logs/access.log

    # Task 3
    all | awk '$9 == 404 {c[$1]++} END {for (ip in c) if (c[ip] >= 10) print c[ip], ip}' | sort -rn
    all | awk '$1 == "203.0.113.66" {print $7}' | sort | uniq -c | sort -k1,1nr -k2
    all | awk '$1 == "203.0.113.66" {print $9}' | sort | uniq -c

    # Task 4
    awk '$6 == "\"POST" && $7 == "/login" && $9 == 401 {c[$1]++} END {for (ip in c) print c[ip], ip}' logs/access.log | sort -k1,1nr
    awk '$6 == "\"POST" && $7 == "/login" {
           if ($9 == 401) fail[$1]++
           else if ($9 == 200 && fail[$1] >= 5) printf "%s: %d failures then success at %s\n", $1, fail[$1], substr($4, 2) }' logs/access.log
    grep -F '192.0.2.77' logs/access.log | tail -2 | cut -c1-90
    awk '$1 == "198.51.100.11" && $9 == 401 {print substr($4, 14, 5)}' logs/access.log | tr '\n' ' '; echo

    # Task 5
    awk '$9 >= 500 {split($4, t, ":"); c[t[2]]++} END {for (h in c) print h ":00", c[h]}' logs/access.log | sort
    awk '$9 >= 500 {print $6, $7}' logs/access.log | sort | uniq -c
    all | awk '{b[$1] += $10} END {for (ip in b) printf "%-16s %10.1f MiB\n", ip, b[ip]/1048576}' | sort -k2,2nr | head -3

    # Task 6
    cut -d, -f7 inventory/servers.csv | head -3
    awk -F, 'NR > 1 && $5 >= 90 {print $1, $5 "%", $6}' inventory/servers.csv
    jq -r '.alerts[] | select(.severity == "critical") | [.host, .check, .value] | @tsv' alerts/alerts.json
    jq -r '.alerts | group_by(.severity)[] | "\(.[0].severity) \(length)"' alerts/alerts.json
    jq -r '.alerts[] | select(.check == "disk") | "\(.host) \(.details.mount)"' alerts/alerts.json
    jq -r '.alerts[] | select(.severity != "info") | [.host, .severity] | @csv' alerts/alerts.json | tr -d '"' | sort -t, -k1,1 > /tmp/lab24-sev.csv
    awk -F, 'NR > 1 {print $1 "," $6}' inventory/servers.csv | sort -t, -k1,1 > /tmp/lab24-own.csv
    join -t, /tmp/lab24-sev.csv /tmp/lab24-own.csv
    rm -f /tmp/lab24-sev.csv /tmp/lab24-own.csv

    # Task 7
    cp config/report.conf /tmp/report.conf.orig
    sed -E 's/^(retention_days[[:space:]]*=[[:space:]]*)[0-9]+/\130/' config/report.conf | diff config/report.conf -
    sed -i.bak -E 's/^(retention_days[[:space:]]*=[[:space:]]*)[0-9]+/\130/' config/report.conf
    grep -H retention config/report.conf*
    cmp config/report.conf.bak /tmp/report.conf.orig && echo "backup identical to original"
    mv config/report.conf.bak config/report.conf && grep retention config/report.conf
    rm -f /tmp/report.conf.orig
    ```

    **Expected output (captured, Tasks 1–5):**

    ```text
    767
    11
         88 198.51.100.11
         88 198.51.100.12
         88 198.51.100.13
         88 198.51.100.14
         87 198.51.100.15
        351 200
         40 500
         39 401
         28 404
          3 403
    461 requests, 110 errors, 23.9% error rate
    27 203.0.113.66
          4 /.env
          4 /.git/config
          4 /admin
          4 /backup.zip
          4 /phpmyadmin/
          4 /wp-login.php
          3 /config.php
          3 /server-status
          3 403
         27 404
    30 192.0.2.77
    9 198.51.100.11
    192.0.2.77: 30 failures then success at 18/Nov/2026:03:13:01
    192.0.2.77 - - [18/Nov/2026:03:13:01 +0000] "POST /login HTTP/1.1" 200 1024 "-" "Mozilla/5
    192.0.2.77 - - [18/Nov/2026:03:13:03 +0000] "GET /admin/export HTTP/1.1" 200 5242880 "-" "
    00:30 03:04 05:37 08:10 10:44 13:17 15:50 18:24 20:57
    10:00 40
         40 "GET /api/orders
    198.51.100.200       3500.0 MiB
    192.0.2.77              5.0 MiB
    198.51.100.13           0.3 MiB
    ```

    **Expected output (captured, Tasks 6–7; tabs shown as spaces):**

    ```text
    notes
    "frontend
    "frontend
    web-02 93% ops
    file-01 97% wintel
    backup-01 91% ops
    web-02      disk    93
    file-01     disk    97
    api-01      http_5xx        40
    critical 3
    info 1
    warning 2
    web-02 /var
    db-01 /var/lib/postgresql
    file-01 D:
    backup-01 /srv/backup
    api-01,critical,dev
    backup-01,warning,ops
    db-01,warning,dba
    file-01,critical,wintel
    web-02,critical,ops
    2c2
    < retention_days = 7
    ---
    > retention_days = 30
    config/report.conf:retention_days = 30
    config/report.conf.bak:retention_days = 7
    backup identical to original
    retention_days = 7
    ```

    Why `awk -F, '$5'` is safe here: the only quoted field (`notes`) is the **last** column, so fields 1–6 never contain a quoted comma. Why `$6 == "\"POST"`: with default splitting, the method field still carries the opening quote of the request line.

??? success "Bash solution: Task 8 (`lab24-report.sh`)"
    ```bash
    #!/usr/bin/env bash
    # lab24-report.sh - Lab 24 Bash solution: build summary.csv and findings.json (read-only on the inputs)
    set -o errexit -o nounset -o pipefail
    LAB=${LAB:-$HOME/lab24}
    cd "$LAB"
    command -v jq >/dev/null || { echo "jq is required: sudo apt install jq" >&2; exit 1; }

    conf() { sed -n -E "s/^$1[[:space:]]*=[[:space:]]*([^[:space:]#]+).*/\1/p" config/report.conf; }
    scan_min=$(conf scanner_404_threshold)
    brute_min=$(conf bruteforce_401_threshold)
    top_n=$(conf top_n)

    all_logs() { zcat -f logs/access.log.1.gz logs/access.log; }

    # 1. per-IP summary across both files -> report/summary.csv (sorted by requests, then IP)
    {
        echo "ip,requests,errors,mib"
        all_logs | awk '{ n[$1]++; b[$1] += $10; if ($9 >= 400) e[$1]++ }
            END { for (ip in n) printf "%s,%d,%d,%.1f\n", ip, n[ip], e[ip], b[ip] / 1048576 }' |
            sort -t, -k2,2nr -k1,1
    } > report/summary.csv

    # 2. findings
    scanners=$(all_logs | awk -v min="$scan_min" '$9 == 404 { c[$1]++ }
        END { for (ip in c) if (c[ip] >= min) print ip }' | sort)
    brute=$(awk -v min="$brute_min" '$6 == "\"POST" && $7 == "/login" {
            if ($9 == 401) fail[$1]++
            else if ($9 == 200 && fail[$1] >= min) print $1 "," fail[$1] "," substr($4, 2) }' logs/access.log)
    peak=$(awk '$9 >= 500 { split($4, t, ":"); c[t[2]]++ }
        END { for (h in c) print c[h], h }' logs/access.log | sort -k1,1nr | head -n 1)
    full=$(awk -F, 'NR > 1 && $5 >= 90 { print $1 }' inventory/servers.csv)

    jq -n \
      --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg scanners "$scanners" \
      --arg brute "$brute" \
      --arg peak "$peak" \
      --arg full "$full" \
      --argjson top "$(tail -n +2 report/summary.csv | head -n "$top_n" |
                       jq -R -s 'split("\n") | map(select(length > 0) | split(",") |
                                 {ip: .[0], requests: (.[1] | tonumber)})')" \
      --slurpfile alerts alerts/alerts.json \
      '{
         generated: $generated,
         top_clients: $top,
         scanners: ($scanners | split("\n") | map(select(length > 0))),
         bruteforce_success: ($brute | split("\n") | map(select(length > 0) | split(",") |
                              {ip: .[0], failures: (.[1] | tonumber), success_at: .[2]})),
         peak_5xx_hour: {hour: ($peak | split(" ")[1]), count: ($peak | split(" ")[0] | tonumber)},
         disk_over_90: ($full | split("\n") | map(select(length > 0))),
         critical_alerts: [$alerts[0].alerts[] | select(.severity == "critical") | .host]
       }' > report/findings.json

    echo "report/summary.csv: $(( $(wc -l < report/summary.csv) - 1 )) clients"
    jq . report/findings.json
    ```

    Run it with `bash lab24-report.sh`, then `cat report/summary.csv`.

    **Expected output (captured; `generated` is the time of your run):**

    ```text
    report/summary.csv: 11 clients
    {
      "generated": "2026-11-18T16:44:22Z",
      "top_clients": [
        {
          "ip": "198.51.100.11",
          "requests": 88
        },
        {
          "ip": "198.51.100.12",
          "requests": 88
        },
        {
          "ip": "198.51.100.13",
          "requests": 88
        },
        {
          "ip": "198.51.100.14",
          "requests": 88
        },
        {
          "ip": "198.51.100.15",
          "requests": 87
        }
      ],
      "scanners": [
        "203.0.113.66"
      ],
      "bruteforce_success": [
        {
          "ip": "192.0.2.77",
          "failures": 30,
          "success_at": "18/Nov/2026:03:13:01"
        }
      ],
      "peak_5xx_hour": {
        "hour": "10",
        "count": 40
      },
      "disk_over_90": [
        "web-02",
        "file-01",
        "backup-01"
      ],
      "critical_alerts": [
        "web-02",
        "file-01",
        "api-01"
      ]
    }
    ```

    `report/summary.csv` (captured):

    ```text
    ip,requests,errors,mib
    198.51.100.11,88,22,0.2
    198.51.100.12,88,9,0.2
    198.51.100.13,88,5,0.3
    198.51.100.14,88,9,0.2
    198.51.100.15,87,5,0.3
    198.51.100.16,87,8,0.3
    198.51.100.17,87,5,0.3
    198.51.100.18,87,7,0.3
    192.0.2.77,32,30,5.0
    203.0.113.66,30,30,0.0
    198.51.100.200,5,0,3500.0
    ```

    Design notes: shell variables reach `jq` only through `--arg`/`--argjson`/`--slurpfile`, never by string concatenation, so the JSON is always valid. The script reads its thresholds from `report.conf` with one `sed -n …p` helper. It is ShellCheck-clean.

??? success "PowerShell solution (`Lab24-Report.ps1`, all tasks)"
    ```powershell
    # Lab24-Report.ps1 - Lab 24 PowerShell solution (read-only on the inputs). 5.1 and 7.
    [CmdletBinding()]
    param([string]$Lab = (Join-Path $HOME 'lab24'))
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Set-Location -Path $Lab
    $inv = [cultureinfo]::InvariantCulture

    function Get-GzipContent {
        param([Parameter(Mandatory)][string]$Path)
        $file = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $Path).ProviderPath)
        $reader = $null
        try {
            $gzip = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $file, ([System.IO.Compression.CompressionMode]::Decompress)
            $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $gzip
            while ($null -ne ($line = $reader.ReadLine())) { $line }
        }
        finally {
            if ($reader) { $reader.Dispose() }
            $file.Dispose()
        }
    }

    $rx = '^(?<ip>\S+) \S+ \S+ \[(?<time>[^\]]+)\] "(?<method>\S+) (?<path>\S+) [^"]*" (?<status>\d{3}) (?<bytes>\d+|-) "[^"]*" "(?<ua>[^"]*)"$'
    function ConvertFrom-AccessLog {
        [CmdletBinding()]
        param([Parameter(Mandatory, ValueFromPipeline)][AllowEmptyString()][string]$Line)
        process {
            if ($Line -match $rx) {
                [pscustomobject]@{
                    IP     = $Matches.ip
                    Time   = [datetime]::ParseExact(($Matches.time -split ' ')[0], 'dd/MMM/yyyy:HH:mm:ss', $inv)
                    Stamp  = ($Matches.time -split ' ')[0]
                    Method = $Matches.method
                    Path   = $Matches.path
                    Status = [int]$Matches.status
                    Bytes  = if ($Matches.bytes -eq '-') { [long]0 } else { [long]$Matches.bytes }
                }
            }
            elseif ($Line) { Write-Warning "unparsed line: $Line" }
        }
    }

    function Get-ConfValue([string]$Key) {
        foreach ($l in Get-Content -Path .\config\report.conf) {
            if ($l -match "^$Key\s*=\s*(\S+)") { return $Matches[1] }
        }
        throw "setting $Key not found"
    }
    $scanMin  = [int](Get-ConfValue 'scanner_404_threshold')
    $bruteMin = [int](Get-ConfValue 'bruteforce_401_threshold')
    $topN     = [int](Get-ConfValue 'top_n')

    $current = @(Get-Content -Path .\logs\access.log | ConvertFrom-AccessLog)
    $all     = @(Get-GzipContent -Path .\logs\access.log.1.gz | ConvertFrom-AccessLog) + $current
    $byCountThenName = @{Expression = 'Count'; Descending = $true}, @{Expression = 'Name'; Descending = $false}

    '--- Task 1'
    $all.Count
    @($all | Select-Object -ExpandProperty IP -Unique).Count
    $all | Group-Object IP -NoElement | Sort-Object $byCountThenName | Select-Object -First $topN Count, Name

    '--- Task 2'
    $current | Group-Object Status -NoElement | Sort-Object Count -Descending | Select-Object Count, Name
    $err = @($current | Where-Object Status -ge 400).Count
    '{0} requests, {1} errors, {2}% error rate' -f $current.Count, $err, (100 * $err / $current.Count).ToString('0.0', $inv)

    '--- Task 3'
    $scanners = @($all | Where-Object Status -eq 404 | Group-Object IP | Where-Object Count -ge $scanMin)
    $scanners | Select-Object Count, Name
    $all | Where-Object IP -eq '203.0.113.66' | Group-Object Path -NoElement | Sort-Object $byCountThenName | Select-Object Count, Name
    $all | Where-Object IP -eq '203.0.113.66' | Group-Object Status -NoElement | Select-Object Count, Name

    '--- Task 4'
    $logins = $current | Where-Object { $_.Method -eq 'POST' -and $_.Path -eq '/login' }
    $logins | Where-Object Status -eq 401 | Group-Object IP -NoElement | Where-Object Count -ge $bruteMin | Sort-Object Count -Descending
    $fail = @{}
    $brute = foreach ($r in $logins) {
        if ($r.Status -eq 401) { $fail[$r.IP] = 1 + [int]$fail[$r.IP] }
        elseif ($r.Status -eq 200 -and [int]$fail[$r.IP] -ge $bruteMin) {
            [pscustomobject]@{ ip = $r.IP; failures = $fail[$r.IP]; success_at = $r.Stamp }
        }
    }
    $brute
    $current | Where-Object IP -eq '192.0.2.77' | Select-Object -Last 2 Time, Method, Path, Status, Bytes

    '--- Task 5'
    $peak = $current | Where-Object Status -ge 500 | Group-Object { $_.Time.Hour } | Sort-Object Count -Descending | Select-Object -First 1
    '{0:D2}:00 {1}' -f [int]$peak.Name, $peak.Count
    $current | Where-Object Status -ge 500 | Group-Object { "$($_.Method) $($_.Path)" } -NoElement
    $all | Group-Object IP | ForEach-Object {
        [pscustomobject]@{ IP = $_.Name; MiB = [math]::Round(($_.Group | Measure-Object Bytes -Sum).Sum / 1MB, 1) }
    } | Sort-Object MiB -Descending | Select-Object -First 3

    '--- Task 6'
    (Get-Content .\inventory\servers.csv -TotalCount 3) | ForEach-Object { ($_ -split ',')[6] }
    $servers = Import-Csv .\inventory\servers.csv
    $servers | Where-Object { [int]$_.disk_pct -ge 90 } | Select-Object name, disk_pct, owner, notes
    $alerts = (Get-Content .\alerts\alerts.json -Raw | ConvertFrom-Json).alerts
    $alerts | Where-Object severity -eq 'critical' | Select-Object host, check, value
    $alerts | Group-Object severity -NoElement | Sort-Object Name | Select-Object Name, Count
    $alerts | Where-Object check -eq 'disk' | Select-Object host, @{N = 'mount'; E = { $_.details.mount }}
    $owner = @{}; $servers | ForEach-Object { $owner[$_.name] = $_.owner }
    $alerts | Where-Object severity -ne 'info' | Sort-Object host |
        Select-Object host, severity, @{N = 'owner'; E = { $owner[$_.host] }}

    '--- Task 7'
    $conf = '.\config\report.conf'
    $new = (Get-Content $conf) -replace '^(retention_days\s*=\s*)\d+', '${1}30'
    Compare-Object (Get-Content $conf) $new
    Copy-Item $conf "$conf.bak"
    $orig = (Get-FileHash $conf).Hash
    [System.IO.File]::WriteAllText((Resolve-Path $conf).ProviderPath, (($new -join "`n") + "`n"))
    Select-String -Path $conf, "$conf.bak" -Pattern 'retention' | ForEach-Object { '{0}:{1}' -f $_.Filename, $_.Line }
    if ((Get-FileHash "$conf.bak").Hash -eq $orig) { 'backup identical to original' }
    Move-Item "$conf.bak" $conf -Force
    Select-String -Path $conf -Pattern 'retention' | ForEach-Object Line

    '--- Task 8'
    $summary = $all | Group-Object IP | ForEach-Object {
        [pscustomobject]@{
            ip       = $_.Name
            requests = $_.Count
            errors   = @($_.Group | Where-Object Status -ge 400).Count
            mib      = (($_.Group | Measure-Object Bytes -Sum).Sum / 1MB).ToString('0.0', $inv)
        }
    } | Sort-Object @{Expression = 'requests'; Descending = $true}, @{Expression = 'ip'; Descending = $false}
    $summary | Export-Csv .\report\summary.csv -NoTypeInformation -Encoding UTF8
    $findings = [ordered]@{
        generated          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        top_clients        = @($summary | Select-Object -First $topN | ForEach-Object { [ordered]@{ ip = $_.ip; requests = $_.requests } })
        scanners           = @($scanners | ForEach-Object Name | Sort-Object)
        bruteforce_success = @($brute)
        peak_5xx_hour      = [ordered]@{ hour = '{0:D2}' -f [int]$peak.Name; count = $peak.Count }
        disk_over_90       = @($servers | Where-Object { [int]$_.disk_pct -ge 90 } | ForEach-Object name)
        critical_alerts    = @($alerts | Where-Object severity -eq 'critical' | ForEach-Object host)
    }
    [pscustomobject]$findings | ConvertTo-Json -Depth 4 | Set-Content .\report\findings.json -Encoding UTF8
    "report\summary.csv: $(@($summary).Count) clients"
    Get-Content .\report\findings.json
    ```

    **Expected output (example — derived from the captured Bash results, not executed):** the same numbers as the Expected Results table. Differences you will see: PowerShell prints objects as tables (`Count Name`), the Task 7 preview is a `Compare-Object` table with `=>`/`<=` indicators, `summary.csv` quotes every field (`"198.51.100.11","88","22","0.2"`) because `Export-Csv` does so by default in both 5.1 and 7, and `findings.json` from 5.1 is indented differently. Group order for equal counts can differ from Bash unless sorted on a second key, which the script does.

    Why some choices were made:

    - `[ordered]@{}` keeps the JSON keys in the order of the specification.
    - `-Depth 4` because `top_clients` and `bruteforce_success` are objects inside arrays inside the top-level object (the default depth of 2 would flatten them).
    - The Task 7 write uses `[System.IO.File]::WriteAllText` with LF endings so the restored-file hash logic is not affected by `Set-Content`'s CRLF line endings on Windows. Restoring from the backup returns the original bytes either way.
    - `.ToString('0.0', $inv)` avoids decimal commas in locales such as `de-DE`.

??? success "Answers to questions"
    1. A count-only rule flags both `192.0.2.77` (30 failures in one minute) and `198.51.100.11` (9 failures spread from 00:30 to 20:57, never followed by a success). Only the first is an attack, and only the first **succeeded**: the success after failure is the event that turns "noise" into "compromised account". The time window (one minute vs a whole day) is the second discriminator; a production rule would combine count, window and outcome.
    2. The only quoted field is the **last** column, so the first six comma-separated fields are always correct. It stops being safe as soon as a quoted field with commas appears before or in the column you need — for example if a `location` column `"Mumbai, DC2"` were inserted before `disk_pct`. Then use a CSV-aware parser.
    3. The log shows 40 × `500` on `GET /api/orders` between 10:00 and 10:39, the same number as the alert value. Two independent sources (the application's own log and the monitoring system) agreeing on time and size makes the incident timeline defensible and rules out a monitoring false alarm.
    4. With `-k1,1nr -k2,2`, equal counts are ordered by the second field (the IP) ascending. With plain `-rn`, GNU sort breaks the tie by the whole line and `-r` reverses that last-resort comparison too, so equal counts can appear in descending IP order.
    5. `/admin/export` two seconds after a brute-forced login is likely **data exfiltration** with a compromised account. Next: identify the account used (application log), check what the export contained, look for further activity from `192.0.2.77` (firewall and authentication logs, Days 17–18), reset the account's password and sessions, consider blocking the address, and check the server for persistence (Days 19–20).
    6. Parsing once with a tested regular expression gives every later question typed properties (`Status` as `[int]`, `Time` as `[datetime]`, `Bytes` as `[long]`). Sorting, grouping by hour, summing bytes and comparing status codes then work without fragile text positions, and the same objects feed `Export-Csv` and `ConvertTo-Json`.
    7. The lab hashes (and later labs) assume the original file; leaving an edited copy would make your environment differ from the expected results. `cmp` proves the backup is **byte-for-byte** identical to the original, so the rollback is exact; `diff` only shows the textual change you made and would ignore, for example, line-ending differences in some modes.

??? success "Clean-up"
    ```bash
    rm -rI ~/lab24        # or keep it: Day 25 schedules a nightly report job
    ```

    ```powershell
    Remove-Item -Path $HOME\lab24 -Recurse -WhatIf    # preview first
    Remove-Item -Path $HOME\lab24 -Recurse
    ```
