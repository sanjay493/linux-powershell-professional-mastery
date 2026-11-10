<#
.SYNOPSIS
    Read-only report of the top CPU and memory processes, with warning thresholds.

.DESCRIPTION
    Samples every process twice, SampleSeconds apart, and calculates CPU usage as a
    percentage of ONE logical processor (the same convention as Linux top), then lists
    the top processes by CPU and by working-set memory. Processes at or above the CPU
    or memory threshold are reported and the script exits with code 3, so it can be
    used by a scheduler or monitoring agent. The script only READS process information;
    it never stops or changes a process.

    Course : Linux & PowerShell Professional Mastery (Day 08)
    Target : Windows 11 with Windows PowerShell 5.1 or PowerShell 7.x
             (also runs in PowerShell 7 on Linux, without user names and command lines)
    Needs  : No administrator rights. Without elevation, user names come from CIM
             (Win32_Process.GetOwner) and some protected processes show 'n/a'.

.PARAMETER Top
    Number of processes to show in each list (1-100). Default 10.

.PARAMETER CpuThreshold
    CPU warning threshold in percent of one logical processor (1-10000). Default 90.

.PARAMETER MemoryThreshold
    Memory warning threshold in percent of physical RAM (1-100). Default 50.

.PARAMETER SampleSeconds
    Seconds between the two CPU samples (0-60). Default 1. With 0 the script reports
    average CPU since each process started (CPU seconds / run time).

.PARAMETER Format
    Output format: Text (default), Csv or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    Process-Monitor-<COMPUTER>-<UTC timestamp>.<txt|csv|json>.

.EXAMPLE
    .\Process-Monitor.ps1

.EXAMPLE
    .\Process-Monitor.ps1 -Top 5 -CpuThreshold 50 -Format Csv -OutputPath $HOME\lpm-lab\reports

.NOTES
    Exit codes: 0 OK, 1 invalid arguments, 2 output folder problem,
    3 at least one process is at or above a threshold.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 100)]
    [int]$Top = 10,

    [ValidateRange(1, 10000)]
    [int]$CpuThreshold = 90,

    [ValidateRange(1, 100)]
    [int]$MemoryThreshold = 50,

    [ValidateRange(0, 60)]
    [int]$SampleSeconds = 1,

    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $IsWindows exists only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)

function Get-CpuSecond {
    <# Returns total CPU seconds of a process, or $null when access is denied. #>
    param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)
    try { $Process.TotalProcessorTime.TotalSeconds } catch { $null }
}

function Format-Value {
    <# Converts $null / empty values to 'n/a' for display. #>
    param($Value)
    if ($null -eq $Value -or "$Value".Trim() -eq '') { 'n/a' } else { "$Value" }
}

# ---------- total physical memory ----------
$totalMemoryBytes = $null
try {
    if ($runningOnWindows) {
        $totalMemoryBytes = [double](Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
    }
    elseif (Test-Path -LiteralPath '/proc/meminfo') {
        $line = Get-Content -LiteralPath '/proc/meminfo' | Where-Object { $_ -like 'MemTotal:*' } | Select-Object -First 1
        if ($line) { $totalMemoryBytes = [double](($line -split '\s+')[1]) * 1KB }
    }
}
catch { Write-Verbose "Total memory unavailable: $($_.Exception.Message)" }

# ---------- CPU sampling ----------
try {
    # The stopwatch covers both read loops, so the interval is never under-estimated
    # (which would push values above the real usage).
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $first = @{}
    foreach ($p in Get-Process) {
        $cpu = Get-CpuSecond -Process $p
        if ($null -ne $cpu) { $first[$p.Id] = $cpu }
    }
    if ($SampleSeconds -gt 0) { Start-Sleep -Seconds $SampleSeconds }
    $processes = @(Get-Process)
    $second = @{}
    foreach ($p in $processes) { $second[$p.Id] = Get-CpuSecond -Process $p }
    $watch.Stop()
    $elapsed = $watch.Elapsed.TotalSeconds
}
catch {
    Write-Error "Could not read the process list: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}

$now = Get-Date
$rows = foreach ($p in $processes) {
    if ($p.Id -eq $PID) { continue }               # skip this script's own host process
    if ($p.Id -eq 0) { continue }                  # Windows 'Idle' pseudo-process: its CPU time is idle time
    $cpuNow = $second[$p.Id]
    $cpuPct = $null
    if ($null -ne $cpuNow) {
        if ($SampleSeconds -gt 0 -and $first.ContainsKey($p.Id) -and $elapsed -gt 0) {
            $cpuPct = [math]::Round((($cpuNow - $first[$p.Id]) / $elapsed) * 100, 1)
        }
        elseif ($SampleSeconds -eq 0) {
            $start = $null
            try { $start = $p.StartTime } catch { $start = $null }
            if ($start) {
                $runSeconds = ($now - $start).TotalSeconds
                if ($runSeconds -gt 0) { $cpuPct = [math]::Round(($cpuNow / $runSeconds) * 100, 1) }
            }
        }
        if ($null -ne $cpuPct -and $cpuPct -lt 0) { $cpuPct = 0 }
    }
    $memPct = $null
    if ($totalMemoryBytes) { $memPct = [math]::Round(($p.WorkingSet64 / $totalMemoryBytes) * 100, 1) }

    [pscustomobject]@{
        Id           = $p.Id
        Name         = $p.ProcessName
        User         = $null
        CpuPercent   = $cpuPct
        CpuSeconds   = $(if ($null -ne $cpuNow) { [math]::Round($cpuNow, 1) })
        WorkingSetMB = [math]::Round($p.WorkingSet64 / 1MB, 1)
        MemPercent   = $memPct
        CommandLine  = $null
    }
}
$rows = @($rows)

$topCpu = @($rows | Sort-Object -Property @{ Expression = { if ($null -eq $_.CpuPercent) { -1 } else { $_.CpuPercent } } }, CpuSeconds -Descending | Select-Object -First $Top)
$topMem = @($rows | Sort-Object -Property WorkingSetMB -Descending | Select-Object -First $Top)
$breaches = @($rows | Where-Object {
        ($null -ne $_.CpuPercent -and $_.CpuPercent -ge $CpuThreshold) -or
        ($null -ne $_.MemPercent -and $_.MemPercent -ge $MemoryThreshold) })

# ---------- enrich only the rows we show (owner and command line) ----------
$shown = @($topCpu + $topMem + $breaches | Sort-Object -Property Id -Unique)
if ($runningOnWindows -and $shown.Count -gt 0) {
    foreach ($row in $shown) {
        try {
            $cim = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($row.Id)"
            if ($cim) {
                $row.CommandLine = $cim.CommandLine
                $owner = Invoke-CimMethod -InputObject $cim -MethodName GetOwner
                if ($owner -and $owner.ReturnValue -eq 0) { $row.User = '{0}\{1}' -f $owner.Domain, $owner.User }
            }
        }
        catch { Write-Verbose "Owner/command line unavailable for PID $($row.Id): $($_.Exception.Message)" }
    }
}
elseif ($shown.Count -gt 0) {
    foreach ($row in $shown) {
        try { $row.CommandLine = ((Get-Content -LiteralPath "/proc/$($row.Id)/cmdline" -Raw) -replace "`0", ' ').Trim() }
        catch { Write-Verbose "Command line unavailable for PID $($row.Id)" }
    }
}
foreach ($row in $shown) {
    $row.User = Format-Value $row.User
    $row.CommandLine = Format-Value $row.CommandLine
}

$status = if ($breaches.Count -gt 0) { 'WARNING' } else { 'OK' }
$cpuMethod = if ($SampleSeconds -gt 0) { '{0}s sample of TotalProcessorTime' -f $SampleSeconds } else { 'average since process start' }
$summary = [ordered]@{
    'Report time (UTC)' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    'Computer name'     = $(if ($runningOnWindows) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() })
    'Processes'         = $rows.Count
    'Logical CPUs'      = [Environment]::ProcessorCount
    'Total memory (MB)' = Format-Value $(if ($totalMemoryBytes) { [math]::Round($totalMemoryBytes / 1MB) })
    'CPU method'        = $cpuMethod
    'Thresholds'        = 'CPU >= {0}% of one CPU, memory >= {1}% of RAM' -f $CpuThreshold, $MemoryThreshold
    'Status'            = $status
    'PowerShell'        = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
}

function Format-Row {
    param($Row)
    $cmd = Format-Value $Row.CommandLine
    if ($cmd.Length -gt 60) { $cmd = $cmd.Substring(0, 60) }
    '{0,7} {1,-18} {2,7} {3,9} {4,6} {5,-20} {6}' -f $Row.Id, $Row.Name, (Format-Value $Row.CpuPercent),
        $Row.WorkingSetMB, (Format-Value $Row.MemPercent), (Format-Value $Row.User), $cmd
}

# ---------- rendering ----------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
                   ' Process Monitor Report',
                   '==============================================')
        foreach ($key in $summary.Keys) { $lines += ('{0,-20} : {1}' -f $key, $summary[$key]) }
        $header = '{0,7} {1,-18} {2,7} {3,9} {4,6} {5,-20} {6}' -f 'Id', 'Name', 'CPU%', 'WS(MB)', 'Mem%', 'User', 'CommandLine'
        $lines += '', "--- Top $Top by CPU ---", $header
        foreach ($r in $topCpu) { $lines += Format-Row $r }
        $lines += '', "--- Top $Top by memory ---", $header
        foreach ($r in $topMem) { $lines += Format-Row $r }
        $lines += '', '--- Threshold breaches ---'
        if ($breaches.Count -eq 0) { $lines += 'none' }
        foreach ($r in $breaches) {
            $lines += 'PID {0} {1}: CPU {2}%, memory {3}%' -f $r.Id, $r.Name, (Format-Value $r.CpuPercent), (Format-Value $r.MemPercent)
        }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $csvRows = @($topCpu | Select-Object @{ n = 'List'; e = { 'cpu' } }, *) +
                   @($topMem | Select-Object @{ n = 'List'; e = { 'memory' } }, *)
        $output = ($csvRows | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]@{
            Summary   = [pscustomobject]$summary
            TopCpu    = $topCpu
            TopMemory = $topMem
            Breaches  = $breaches
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
        $safeName = $summary['Computer name'] -replace '[^A-Za-z0-9._-]', '_'
        $file = Join-Path $OutputPath ('Process-Monitor-{0}-{1}.{2}' -f $safeName, $stamp, $extension)
        $output | Out-File -LiteralPath $file -Encoding utf8
        Write-Information "Report saved to: $file" -InformationAction Continue
    }
    catch {
        Write-Error "Could not write report to '$OutputPath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}

if ($status -eq 'OK') { exit 0 }
exit 3
