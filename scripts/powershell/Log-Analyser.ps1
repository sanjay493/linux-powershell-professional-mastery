<#
.SYNOPSIS
    Read-only summary of critical, error and warning events for the last N hours:
    counts per level, top sources, top event IDs, top messages (normalised) and
    failed logons.

.DESCRIPTION
    On Windows the script queries the event logs named in -LogName (default System and
    Application) with Get-WinEvent -FilterHashtable for levels 1 (Critical), 2 (Error)
    and 3 (Warning) since -Hours ago, and reports:

      - the number of events per log and per level,
      - the top providers (sources), the top "provider / event ID" pairs and the top
        messages (first line; digits -> N, hex -> X so that similar messages group),
      - kernel and storage driver errors (Kernel-*, disk, Ntfs, volmgr, WHEA-Logger),
      - failed logons (Security event 4625) when the Security log is readable
        (Administrator only; otherwise n/a; details in Day 17).

    When the number of Critical + Error events is greater than -MaxErrors the script exits
    with code 3, so it can be used by Task Scheduler, cron or a monitoring agent. The script
    only READS logs; it never clears, exports over or changes them.

    -Path analyses a saved file instead: an exported .evtx file (Windows), or a Linux
    syslog-format text file (plain or .gz) whose severity is INFERRED from keywords
    (error/fail/critical/panic/fatal/segfault = error, warn = warning). In PowerShell 7 on
    Linux without -Path, the systemd journal is read with journalctl -o json (warning and
    worse), which carries a real PRIORITY.

    Course : Linux & PowerShell Professional Mastery (Day 16)
    Target : Windows 11 with Windows PowerShell 5.1 or PowerShell 7.x
             (also runs in PowerShell 7 on Linux with journalctl or -Path)
    Needs  : No administrator rights for System and Application. The Security log needs an
             elevated session; logs that cannot be read are reported as n/a.

.PARAMETER LogName
    Windows event logs to query (default System, Application). Examples: Security,
    'Microsoft-Windows-PowerShell/Operational', Setup.

.PARAMETER Hours
    Time window in hours (default 24, 0-8760). 0 = the whole log or file.

.PARAMETER Top
    Number of entries in the "top" lists (default 10, 1-100).

.PARAMETER MaxErrors
    Maximum number of Critical + Error events before the threshold is breached (default 50).

.PARAMETER Path
    Analyse a saved .evtx file (Windows) or a syslog-format text file (.log, .gz) instead.

.PARAMETER Format
    Output format: Text (default), Csv or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    Log-Analyser-<COMPUTER>-<UTC timestamp>.<txt|csv|json>.

.EXAMPLE
    .\Log-Analyser.ps1

.EXAMPLE
    .\Log-Analyser.ps1 -LogName System -Hours 2 -Top 5

.EXAMPLE
    .\Log-Analyser.ps1 -Path $HOME\lpm-lab\System-export.evtx -Hours 0 -Format Csv -OutputPath $HOME\lpm-lab\reports

.NOTES
    Exit codes: 0 OK (also when no log could be read: reported as n/a), 1 invalid arguments,
    2 output file problem, 3 more than -MaxErrors Critical + Error events.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string[]]$LogName = @('System', 'Application'),

    [ValidateRange(0, 8760)]
    [int]$Hours = 24,

    [ValidateRange(1, 100)]
    [int]$Top = 10,

    [ValidateRange(0, 2147483647)]
    [int]$MaxErrors = 50,

    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSBoundParameters.ContainsKey('Path') -and -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-Error "-Path '$Path' is not an existing file." -ErrorAction Continue
    exit 1
}

# $IsWindows exists only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
$startTime = $null
if ($Hours -gt 0) { $startTime = (Get-Date).AddHours(-$Hours) }
$maxEventsPerLog = 20000
$levelNames = @{ 1 = 'Critical'; 2 = 'Error'; 3 = 'Warning' }

# Every source is turned into records: Log, Level (1 Critical, 2 Error, 3 Warning), Source, Id, Message.
$records = New-Object System.Collections.Generic.List[object]
$logStatus = New-Object System.Collections.Generic.List[object]
$severityMode = 'Windows event Level'
$sourceText = 'n/a'
$truncated = $false

function ConvertTo-NormalMessage {
    <# First line only; hex values -> X, numbers not preceded by a letter -> N; at most 120 characters. #>
    param([string]$Text)
    if (-not $Text) { return '(no message text)' }
    $line = ($Text -split "`r?`n")[0].Trim()
    $line = $line -replace '0x[0-9A-Fa-f]+', 'X'
    $line = $line -replace '\b[0-9A-Fa-f]{8,}\b', 'X'
    $line = $line -replace '(?<![A-Za-z0-9])\d+', 'N'
    if ($line.Length -gt 120) { $line = $line.Substring(0, 120) }
    return $line
}

function Get-InferredLevel {
    <# Keyword-based severity for text logs that carry no priority field. #>
    param([string]$Text)
    if ($Text -match 'error|fail|critical|panic|fatal|segfault') { return 2 }
    if ($Text -match 'warn') { return 3 }
    return 4
}

function Get-JsonField {
    <# Reads one field of a journal JSON object without tripping StrictMode on missing fields. #>
    param($Object, [string]$Name)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    if ($prop.Value -is [array]) { return '[binary message]' }
    return [string]$prop.Value
}

function Read-TextLog {
    <# Parses RFC 3339 and classic syslog lines (plain or .gz); returns objects with Time, Program, Message. #>
    param([string]$File)
    $stream = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $File).ProviderPath)
    try {
        if ($File -like '*.gz') {
            $inner = New-Object System.IO.Compression.GZipStream($stream, [System.IO.Compression.CompressionMode]::Decompress)
            $reader = New-Object System.IO.StreamReader($inner)
        }
        else {
            $reader = New-Object System.IO.StreamReader($stream)
        }
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        $now = Get-Date
        while ($null -ne ($line = $reader.ReadLine())) {
            $time = $null; $program = $null; $message = $null
            if ($line -match '^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)\S*\s+\S+\s+([^\s\[:]+)(\[\d+\])?:\s?(.*)$') {
                $program = $Matches[2]; $message = $Matches[4]
                try { $time = [datetime]::ParseExact($Matches[1], 'yyyy-MM-ddTHH:mm:ss', $culture) } catch { continue }
            }
            elseif ($line -match '^([A-Z][a-z]{2})\s+(\d{1,2})\s(\d\d:\d\d:\d\d)\s+\S+\s+([^\s\[:]+)(\[\d+\])?:\s?(.*)$') {
                $program = $Matches[4]; $message = $Matches[6]
                try { $time = [datetime]::ParseExact(('{0} {1} {2} {3}' -f $now.Year, $Matches[1], $Matches[2], $Matches[3]), 'yyyy MMM d HH:mm:ss', $culture) } catch { continue }
                if ($time -gt $now.AddDays(1)) { $time = $time.AddYears(-1) }
            }
            else { continue }
            [pscustomobject]@{ Time = $time; Program = $program; Message = $message }
        }
        $reader.Dispose()
    }
    finally {
        $stream.Dispose()
    }
}

# ---------------- collect ----------------
$authRecords = @()
$failedLogons = 'n/a'
try {
    if ($PSBoundParameters.ContainsKey('Path') -and $Path -like '*.evtx' -and $runningOnWindows) {
        $sourceText = $Path
        $filter = @{ Path = (Resolve-Path -LiteralPath $Path).ProviderPath; Level = 1, 2, 3 }
        if ($null -ne $startTime) { $filter['StartTime'] = $startTime }
        try {
            foreach ($e in @(Get-WinEvent -FilterHashtable $filter -MaxEvents $maxEventsPerLog -ErrorAction Stop)) {
                $records.Add([pscustomobject]@{ Log = [string]$e.LogName; Level = [int]$e.Level; Source = [string]$e.ProviderName; Id = [int]$e.Id; Message = [string]$e.Message })
            }
            $logStatus.Add([pscustomobject]@{ Log = $Path; Status = 'read' })
        }
        catch {
            if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*' -or $_.Exception.Message -match 'No events were found') { $logStatus.Add([pscustomobject]@{ Log = $Path; Status = 'read (no matching events)' }) }
            else { throw }
        }
    }
    elseif ($PSBoundParameters.ContainsKey('Path')) {
        $sourceText = $Path
        $severityMode = 'inferred from keywords (text file)'
        foreach ($r in @(Read-TextLog -File $Path)) {
            if ($null -ne $startTime -and $r.Time -lt $startTime) { continue }
            $level = Get-InferredLevel -Text $r.Message
            $authRecords += [pscustomobject]@{ Program = $r.Program; Message = $r.Message }
            if ($level -le 3) {
                $records.Add([pscustomobject]@{ Log = 'file'; Level = $level; Source = $r.Program; Id = 0; Message = $r.Message })
            }
        }
        $logStatus.Add([pscustomobject]@{ Log = $Path; Status = 'read' })
    }
    elseif ($runningOnWindows) {
        $sourceText = 'Windows event logs: ' + ($LogName -join ', ')
        foreach ($log in $LogName) {
            $filter = @{ LogName = $log; Level = 1, 2, 3 }
            if ($null -ne $startTime) { $filter['StartTime'] = $startTime }
            try {
                $events = @(Get-WinEvent -FilterHashtable $filter -MaxEvents $maxEventsPerLog -ErrorAction Stop)
                if ($events.Count -ge $maxEventsPerLog) { $truncated = $true }
                foreach ($e in $events) {
                    $records.Add([pscustomobject]@{ Log = $log; Level = [int]$e.Level; Source = [string]$e.ProviderName; Id = [int]$e.Id; Message = [string]$e.Message })
                }
                $logStatus.Add([pscustomobject]@{ Log = $log; Status = 'read' })
            }
            catch {
                $msg = $_.Exception.Message
                if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*' -or $msg -match 'No events were found') { $logStatus.Add([pscustomobject]@{ Log = $log; Status = 'read (no matching events)' }) }
                elseif ($_.Exception -is [System.UnauthorizedAccessException] -or $msg -match 'unauthorized|access is denied') {
                    $logStatus.Add([pscustomobject]@{ Log = $log; Status = 'n/a (access denied: run elevated)' })
                }
                elseif ($msg -match 'There is not an event log') { $logStatus.Add([pscustomobject]@{ Log = $log; Status = 'n/a (log does not exist)' }) }
                else { $logStatus.Add([pscustomobject]@{ Log = $log; Status = "n/a ($msg)" }) }
            }
        }
        # Failed logons (Security 4625) need an elevated session.
        $secFilter = @{ LogName = 'Security'; Id = 4625 }
        if ($null -ne $startTime) { $secFilter['StartTime'] = $startTime }
        try {
            $failedLogons = @(Get-WinEvent -FilterHashtable $secFilter -MaxEvents $maxEventsPerLog -ErrorAction Stop).Count
        }
        catch {
            if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*' -or $_.Exception.Message -match 'No events were found') { $failedLogons = 0 }
            else { $failedLogons = 'n/a (Security log needs an elevated session)' }
        }
    }
    elseif ($null -ne (Get-Command -Name journalctl -ErrorAction SilentlyContinue)) {
        $sourceText = 'systemd journal (journalctl, priority warning and worse)'
        $severityMode = 'journal PRIORITY field'
        $since = @()
        if ($null -ne $startTime) { $since = @('--since', $startTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        $priorityLevel = @{ '0' = 1; '1' = 1; '2' = 1; '3' = 2; '4' = 3 }
        foreach ($line in @(& journalctl -q --no-pager -o json -p warning @since 2>$null)) {
            if (-not $line) { continue }
            try { $j = $line | ConvertFrom-Json } catch { continue }
            $prio = Get-JsonField -Object $j -Name 'PRIORITY'
            if ($null -eq $prio -or -not $priorityLevel.ContainsKey($prio)) { continue }
            $prog = Get-JsonField -Object $j -Name 'SYSLOG_IDENTIFIER'
            if (-not $prog) { $prog = Get-JsonField -Object $j -Name '_COMM' }
            if (-not $prog) { $prog = 'unknown' }
            $records.Add([pscustomobject]@{ Log = 'journal'; Level = $priorityLevel[$prio]; Source = $prog; Id = 0; Message = (Get-JsonField -Object $j -Name 'MESSAGE') })
        }
        foreach ($line in @(& journalctl -q --no-pager -o json -t sshd -t sudo @since 2>$null)) {
            if (-not $line) { continue }
            try { $j = $line | ConvertFrom-Json } catch { continue }
            $authRecords += [pscustomobject]@{ Program = (Get-JsonField -Object $j -Name 'SYSLOG_IDENTIFIER'); Message = (Get-JsonField -Object $j -Name 'MESSAGE') }
        }
        if ($records.Count -eq 0 -and $authRecords.Count -eq 0) { $logStatus.Add([pscustomobject]@{ Log = 'journal'; Status = 'read (no matching entries, or no permission)' }) }
        else { $logStatus.Add([pscustomobject]@{ Log = 'journal'; Status = 'read' }) }
    }
    else {
        $logStatus.Add([pscustomobject]@{ Log = 'n/a'; Status = 'n/a (no Windows event log, no journalctl; use -Path)' })
    }
}
catch {
    Write-Error "Could not read the logs: $($_.Exception.Message)" -ErrorAction Continue
    $logStatus.Add([pscustomobject]@{ Log = $sourceText; Status = "n/a ($($_.Exception.Message))" })
}

if (-not $runningOnWindows -or $PSBoundParameters.ContainsKey('Path')) {
    if ($authRecords.Count -gt 0) {
        $ssh = @($authRecords | Where-Object { $_.Program -like 'sshd*' })
        $failedLogons = '{0} SSH failed password/key, {1} SSH invalid user, {2} sudo authentication failures' -f
            @($ssh | Where-Object { $_.Message -match 'Failed (password|publickey) for' }).Count,
            @($ssh | Where-Object { $_.Message -match '^[Ii]nvalid user ' }).Count,
            @($authRecords | Where-Object { $_.Program -eq 'sudo' -and $_.Message -match 'authentication failure|incorrect password attempt' }).Count
    }
    elseif ($sourceText -ne 'n/a') { $failedLogons = '0' }
}

# ---------------- summarise ----------------
$all = @($records.ToArray())
$errorCount = @($all | Where-Object { $_.Level -le 2 }).Count
$kernelErrors = @($all | Where-Object { $_.Level -le 2 -and ($_.Source -like 'Microsoft-Windows-Kernel*' -or $_.Source -in @('kernel', 'disk', 'Ntfs', 'volmgr', 'storahci', 'stornvme', 'Microsoft-Windows-WHEA-Logger')) }).Count
$byLevel = @($all | Group-Object -Property Level | Sort-Object -Property Name |
        Select-Object @{ n = 'Level'; e = { $levelNames[[int]$_.Name] } }, Count)
$topSources = @($all | Group-Object -Property Source | Sort-Object -Property @{ e = 'Count'; Descending = $true }, @{ e = 'Name'; Descending = $false } |
        Select-Object -First $Top @{ n = 'Source'; e = { $_.Name } }, Count)
$topIds = @($all | Where-Object { $_.Id -ne 0 } | Group-Object -Property { '{0} / {1}' -f $_.Source, $_.Id } |
        Sort-Object -Property @{ e = 'Count'; Descending = $true }, @{ e = 'Name'; Descending = $false } |
        Select-Object -First $Top @{ n = 'SourceId'; e = { $_.Name } }, Count)
$topMessages = @($all | Group-Object -Property { "{0}`t{1}: {2}" -f $levelNames[$_.Level], $_.Source, (ConvertTo-NormalMessage -Text $_.Message) } |
        Sort-Object -Property @{ e = 'Count'; Descending = $true }, @{ e = 'Name'; Descending = $false } |
        Select-Object -First $Top @{ n = 'Level'; e = { ($_.Name -split "`t")[0] } }, @{ n = 'Message'; e = { ($_.Name -split "`t", 2)[1] } }, Count)

$readable = @($logStatus | Where-Object { $_.Status -like 'read*' }).Count
$status = 'OK'
if ($readable -eq 0) { $status = 'n/a (no readable log source)' }
elseif ($errorCount -gt $MaxErrors) { $status = 'ALERT' }

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$computerName = $(if ($runningOnWindows) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() })
$windowText = $(if ($null -ne $startTime) { 'last {0} h (since {1} local time)' -f $Hours, $startTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'all entries' })

$summary = [ordered]@{
    'Report time (UTC)'      = $timestamp
    'Computer name'          = $computerName
    'Source'                 = $sourceText
    'Window'                 = $windowText
    'Severity'               = $severityMode
    'Events (warning+)'      = $all.Count
    'Critical + Error'       = '{0} (threshold {1})' -f $errorCount, $MaxErrors
    'Kernel/driver errors'   = $kernelErrors
    'Failed logons'          = $failedLogons
    'Status'                 = $status
    'PowerShell'             = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
}
if ($truncated) { $summary['Note'] = "at least one log returned $maxEventsPerLog events (the per-log limit): counts are a minimum" }

# ---------------- rendering ----------------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
                   ' Log Analyser Report',
                   '==============================================')
        foreach ($key in $summary.Keys) { $lines += ('{0,-22} : {1}' -f $key, $summary[$key]) }
        $lines += '', '--- Logs ---'
        foreach ($l in $logStatus) { $lines += ('{0,-40} {1}' -f $l.Log, $l.Status) }
        $lines += '', '--- Events by level ---'
        if ($byLevel.Count -eq 0) { $lines += '(none)' }
        foreach ($b in $byLevel) { $lines += ('{0,7}  {1}' -f $b.Count, $b.Level) }
        $lines += '', "--- Top $Top sources ---"
        if ($topSources.Count -eq 0) { $lines += '(none)' }
        foreach ($s in $topSources) { $lines += ('{0,7}  {1}' -f $s.Count, $s.Source) }
        if ($topIds.Count -gt 0) {
            $lines += '', "--- Top $Top source / event ID ---"
            foreach ($i in $topIds) { $lines += ('{0,7}  {1}' -f $i.Count, $i.SourceId) }
        }
        $lines += '', "--- Top $Top messages (digits -> N, hex -> X) ---"
        if ($topMessages.Count -eq 0) { $lines += '(none)' }
        foreach ($m in $topMessages) { $lines += ('{0,7}  {1,-8} {2}' -f $m.Count, $m.Level, $m.Message) }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $rows = New-Object System.Collections.Generic.List[object]
        $rows.Add([pscustomobject]@{ Section = 'summary'; Item = 'events_warning_or_worse'; Count = $all.Count })
        $rows.Add([pscustomobject]@{ Section = 'summary'; Item = 'critical_and_error'; Count = $errorCount })
        $rows.Add([pscustomobject]@{ Section = 'summary'; Item = 'kernel_driver_errors'; Count = $kernelErrors })
        $rows.Add([pscustomobject]@{ Section = 'summary'; Item = 'threshold'; Count = $MaxErrors })
        $rows.Add([pscustomobject]@{ Section = 'auth'; Item = 'failed_logons'; Count = $failedLogons })
        foreach ($b in $byLevel) { $rows.Add([pscustomobject]@{ Section = 'level'; Item = $b.Level; Count = $b.Count }) }
        foreach ($s in $topSources) { $rows.Add([pscustomobject]@{ Section = 'source'; Item = $s.Source; Count = $s.Count }) }
        foreach ($i in $topIds) { $rows.Add([pscustomobject]@{ Section = 'source_id'; Item = $i.SourceId; Count = $i.Count }) }
        foreach ($m in $topMessages) { $rows.Add([pscustomobject]@{ Section = 'message_' + $m.Level.ToLower(); Item = $m.Message; Count = $m.Count }) }
        $output = ($rows | Select-Object @{ n = 'TimestampUtc'; e = { $timestamp } }, @{ n = 'Computer'; e = { $computerName } }, Section, Item, Count |
                ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]@{
            Summary     = [pscustomobject]$summary
            Logs        = $logStatus.ToArray()
            ByLevel     = $byLevel
            TopSources  = $topSources
            TopEventIds = $topIds
            TopMessages = $topMessages
        } | ConvertTo-Json -Depth 4
        $extension = 'json'
    }
}

Write-Output $output

if ($PSBoundParameters.ContainsKey('OutputPath')) {
    try {
        if (-not (Test-Path -LiteralPath $OutputPath -PathType Container)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $safeName = $computerName -replace '[^A-Za-z0-9._-]', '_'
        $file = Join-Path $OutputPath ('Log-Analyser-{0}-{1}.{2}' -f $safeName, $stamp, $extension)
        $output | Out-File -LiteralPath $file -Encoding utf8
        Write-Information "Report saved to: $file" -InformationAction Continue
    }
    catch {
        Write-Error "Could not write report to '$OutputPath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}

if ($status -eq 'ALERT') { exit 3 }
exit 0
