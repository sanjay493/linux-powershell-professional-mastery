<#
.SYNOPSIS
    Read-only, thresholded health check designed to be run by Task Scheduler or cron.

.DESCRIPTION
    Checks CPU load, memory, page file (swap), fixed-drive space, the services you name,
    pending reboot and uptime. Every check is reported as OK, WARNING (threshold reached)
    or n/a (cannot be measured on this system). When any check is WARNING the overall
    status is WARNING and the script exits with code 3, so a scheduler or monitoring agent
    can alert on it. With -Quiet nothing is printed when everything is OK. The script only
    READS; it never starts, stops or changes anything.

    Course : Linux & PowerShell Professional Mastery (Day 25)
    Target : Windows 11 / Windows Server with Windows PowerShell 5.1 or PowerShell 7.x
             (also runs in PowerShell 7 on Linux: /proc/loadavg, /proc/meminfo, systemctl
             and /var/run/reboot-required are used there)
    Needs  : No administrator rights. Windows data comes from CIM (Win32_Processor,
             Win32_OperatingSystem, Win32_PageFileUsage), .NET System.IO.DriveInfo,
             Get-Service and three registry locations under HKLM that users can read.

    Windows checks:
      cpu      Average Win32_Processor.LoadPercentage (0-100) of all processors.
      memory   (TotalVisibleMemorySize - FreePhysicalMemory) / TotalVisibleMemorySize.
      swap     Win32_PageFileUsage CurrentUsage / AllocatedBaseSize (n/a without a page file).
      disk     Every ready Fixed drive: used / (used + available), as df calculates it.
      service  Each -Service name: WARNING when not found or not Running.
      reboot   CBS RebootPending, WindowsUpdate\Auto Update\RebootRequired, or
               Session Manager PendingFileRenameOperations present.
      uptime   From Win32_OperatingSystem.LastBootUpTime (information only).
    On Linux, cpu is the 1-minute load average / logical CPUs in percent, memory and swap
    come from /proc/meminfo (MemTotal - MemAvailable), disk excludes pseudo filesystems,
    service uses 'systemctl is-active', failed-units counts 'systemctl --failed' and reboot
    tests /var/run/reboot-required. systemd checks are n/a when systemd is not running.

.PARAMETER CpuPercent
    CPU warning threshold in percent (1-1000). Default 90. On Windows LoadPercentage never
    exceeds 100; on Linux the load per CPU can (100 = one runnable task per CPU).

.PARAMETER MemoryPercent
    Memory and page file (swap) warning threshold in percent used (1-100). Default 90.

.PARAMETER DiskPercent
    Drive (filesystem) space warning threshold in percent used (1-100). Default 90.

.PARAMETER Service
    Optional service names that must be running (Windows service Name, wildcards allowed,
    e.g. 'Spooler', 'W32Time'), or systemd units that must be active on Linux ('ssh', 'cron').

.PARAMETER Format
    Output format: Text (default), Csv (Check,Item,Value,Threshold,Status) or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    System-Health-<COMPUTER>-<UTC timestamp>.<txt|csv|json> (also when -Quiet prints nothing).

.PARAMETER Quiet
    Print nothing when the overall status is OK (useful for scheduled runs that e-mail output).

.EXAMPLE
    .\System-Health.ps1

.EXAMPLE
    .\System-Health.ps1 -DiskPercent 80 -Service Spooler, W32Time

.EXAMPLE
    .\System-Health.ps1 -Quiet -Format Csv -OutputPath $HOME\lpm-lab\reports

.NOTES
    Exit codes: 0 OK, 1 invalid arguments, 2 output folder problem,
    3 at least one check is WARNING.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 1000)]
    [int]$CpuPercent = 90,

    [ValidateRange(1, 100)]
    [int]$MemoryPercent = 90,

    [ValidateRange(1, 100)]
    [int]$DiskPercent = 90,

    [ValidateNotNullOrEmpty()]
    [string[]]$Service,

    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $IsWindows / $IsLinux exist only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
$runningOnLinux = (Test-Path variable:IsLinux) -and $IsLinux

$serviceNames = @()
if ($PSBoundParameters.ContainsKey('Service')) {
    # Accept both -Service a, b and -Service 'a,b' (the form that survives powershell.exe -File).
    $serviceNames = @($Service | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}
if (-not $runningOnWindows) {
    foreach ($name in $serviceNames) {
        if ($name -notmatch '^[A-Za-z0-9:_.@\\-]+$') {
            Write-Error "Invalid systemd unit name '$name' in -Service." -ErrorAction Continue
            exit 1
        }
    }
}

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    <# Appends one check result (all values are stored as strings). #>
    param([string]$Check, [string]$Item, [string]$Value, [string]$Threshold, [string]$Status)
    $results.Add([pscustomobject]@{
            Check     = $Check
            Item      = $Item
            Value     = $Value
            Threshold = $Threshold
            Status    = $Status
        })
}

function Get-Level {
    <# Returns WARNING when Value >= Threshold, OK otherwise, n/a when Value is $null. #>
    param($Value, [double]$Threshold)
    if ($null -eq $Value) { return 'n/a' }
    if ([double]$Value -ge $Threshold) { return 'WARNING' }
    return 'OK'
}

function Format-Percent {
    <# 12.345 -> '12.3%' (culture-invariant), $null -> 'n/a'. #>
    param($Value)
    if ($null -eq $Value) { return 'n/a' }
    $rounded = [math]::Round([double]$Value, 1)
    return "$rounded%"
}

function Invoke-Systemctl {
    <#
        Runs systemctl with the given arguments and returns its standard output lines and
        exit code. Standard error is discarded; native errors never stop the script.
    #>
    param([string[]]$ArgumentList)
    $ErrorActionPreference = 'Continue'
    $lines = @()
    $code = 1
    try {
        $lines = @(& systemctl @ArgumentList 2>$null)
        $code = $LASTEXITCODE
    }
    catch {
        Write-Verbose "systemctl $($ArgumentList -join ' ') failed: $($_.Exception.Message)"
    }
    [pscustomobject]@{ Output = $lines; ExitCode = $code }
}

function Get-MemInfo {
    <# Reads /proc/meminfo into a hashtable of kB values (Linux only). #>
    $table = @{}
    foreach ($line in Get-Content -LiteralPath '/proc/meminfo') {
        $parts = $line -split '\s+'
        if ($parts.Count -ge 2) { $table[$parts[0].TrimEnd(':')] = [double]$parts[1] }
    }
    $table
}

$cpuThresholdText = ">= $CpuPercent%"
$memThresholdText = ">= $MemoryPercent%"
$diskThresholdText = ">= $DiskPercent%"

# ---------- CPU ----------
try {
    if ($runningOnWindows) {
        $loads = @(Get-CimInstance -ClassName Win32_Processor | ForEach-Object {
                if ($null -ne $_.LoadPercentage) { [double]$_.LoadPercentage }
            })
        if ($loads.Count -gt 0) {
            $cpuValue = ($loads | Measure-Object -Average).Average
            Add-Result 'cpu' ("average LoadPercentage of {0} processor(s), {1} logical CPU(s)" -f $loads.Count, [Environment]::ProcessorCount) (Format-Percent $cpuValue) $cpuThresholdText (Get-Level $cpuValue $CpuPercent)
        }
        else {
            Add-Result 'cpu' 'Win32_Processor LoadPercentage not reported' 'n/a' $cpuThresholdText 'n/a'
        }
    }
    elseif (Test-Path -LiteralPath '/proc/loadavg') {
        $load = (Get-Content -LiteralPath '/proc/loadavg' -TotalCount 1) -split '\s+'
        $cores = [Environment]::ProcessorCount
        $cpuValue = [double]$load[0] / $cores * 100
        Add-Result 'cpu' ('load 1/5/15 min {0} {1} {2} on {3} CPU(s)' -f $load[0], $load[1], $load[2], $cores) (Format-Percent $cpuValue) $cpuThresholdText (Get-Level $cpuValue $CpuPercent)
    }
    else {
        Add-Result 'cpu' 'load average' 'n/a' $cpuThresholdText 'n/a'
    }
}
catch {
    Write-Verbose "CPU check failed: $($_.Exception.Message)"
    Add-Result 'cpu' 'load' 'n/a' $cpuThresholdText 'n/a'
}

# ---------- memory, swap / page file and uptime source ----------
$os = $null
$memInfo = @{}
try {
    if ($runningOnWindows) { $os = Get-CimInstance -ClassName Win32_OperatingSystem }
    elseif (Test-Path -LiteralPath '/proc/meminfo') { $memInfo = Get-MemInfo }
}
catch { Write-Verbose "Memory information unavailable: $($_.Exception.Message)" }

$memTotalKB = $null
$memUsedKB = $null
if ($null -ne $os -and $os.TotalVisibleMemorySize -gt 0) {
    $memTotalKB = [double]$os.TotalVisibleMemorySize
    $memUsedKB = $memTotalKB - [double]$os.FreePhysicalMemory
}
elseif ($memInfo.ContainsKey('MemTotal') -and $memInfo.ContainsKey('MemAvailable') -and $memInfo['MemTotal'] -gt 0) {
    $memTotalKB = $memInfo['MemTotal']
    $memUsedKB = $memTotalKB - $memInfo['MemAvailable']
}
if ($null -ne $memTotalKB) {
    $memValue = $memUsedKB / $memTotalKB * 100
    $memItem = "used of $([math]::Round($memTotalKB / 1MB, 1)) GiB"
    if (-not $runningOnWindows) { $memItem += ' (MemTotal - MemAvailable)' }
    Add-Result 'memory' $memItem (Format-Percent $memValue) $memThresholdText (Get-Level $memValue $MemoryPercent)
}
else {
    Add-Result 'memory' 'used' 'n/a' $memThresholdText 'n/a'
}

if ($runningOnWindows) {
    try {
        # AllocatedBaseSize and CurrentUsage are in MB.
        $pageFiles = @(Get-CimInstance -ClassName Win32_PageFileUsage)
        $allocated = [double]0
        $inUse = [double]0
        foreach ($pf in $pageFiles) { $allocated += $pf.AllocatedBaseSize; $inUse += $pf.CurrentUsage }
        if ($pageFiles.Count -gt 0 -and $allocated -gt 0) {
            $swapValue = $inUse / $allocated * 100
            $names = ($pageFiles | ForEach-Object { $_.Name }) -join ', '
            Add-Result 'swap' ('page file {0} ({1} MB)' -f $names, $allocated) (Format-Percent $swapValue) $memThresholdText (Get-Level $swapValue $MemoryPercent)
        }
        else {
            Add-Result 'swap' 'no page file configured' 'n/a' $memThresholdText 'n/a'
        }
    }
    catch {
        Write-Verbose "Page file check failed: $($_.Exception.Message)"
        Add-Result 'swap' 'page file' 'n/a' $memThresholdText 'n/a'
    }
}
elseif ($memInfo.ContainsKey('SwapTotal') -and $memInfo.ContainsKey('SwapFree') -and $memInfo['SwapTotal'] -gt 0) {
    $swapValue = ($memInfo['SwapTotal'] - $memInfo['SwapFree']) / $memInfo['SwapTotal'] * 100
    Add-Result 'swap' "used of $([math]::Round($memInfo['SwapTotal'] / 1MB, 1)) GiB" (Format-Percent $swapValue) $memThresholdText (Get-Level $swapValue $MemoryPercent)
}
else {
    Add-Result 'swap' 'no swap configured' 'n/a' $memThresholdText 'n/a'
}

# ---------- drives ----------
# Filesystem types that are memory, packages or kernel interfaces on Linux (same list as the Bash script).
$pseudoTypes = @('tmpfs', 'devtmpfs', 'squashfs', 'overlay', 'proc', 'sysfs', 'cgroup', 'cgroup2', 'devpts',
    'mqueue', 'debugfs', 'tracefs', 'securityfs', 'pstore', 'efivarfs', 'bpf', 'autofs', 'fusectl', 'configfs',
    'hugetlbfs', 'ramfs', 'nsfs', 'binfmt_misc', 'rpc_pipefs', 'fuse.portal', 'fuse.gvfsd-fuse', 'fuse.snapfuse')
$driveCount = 0
try {
    $drives = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq [System.IO.DriveType]::Fixed })
}
catch {
    Write-Verbose "Could not enumerate drives: $($_.Exception.Message)"
    $drives = @()
}
foreach ($drive in ($drives | Sort-Object -Property Name)) {
    try {
        if (-not $drive.IsReady) { Write-Verbose "Skipping $($drive.Name): not ready"; continue }
        $fsFormat = $drive.DriveFormat
        $size = [double]$drive.TotalSize
        $used = $size - [double]$drive.TotalFreeSpace
        $available = [double]$drive.AvailableFreeSpace
    }
    catch {
        Write-Verbose "Skipping $($drive.Name): $($_.Exception.Message)"
        continue
    }
    if ($size -le 0) { continue }
    if (-not $runningOnWindows -and $pseudoTypes -contains $fsFormat) { continue }
    $diskValue = $null
    if (($used + $available) -gt 0) { $diskValue = $used / ($used + $available) * 100 }
    $sizeGiB = [math]::Round($size / 1GB, 1)
    Add-Result 'disk' "$($drive.Name) ($fsFormat, $sizeGiB GiB)" (Format-Percent $diskValue) $diskThresholdText (Get-Level $diskValue $DiskPercent)
    $driveCount++
}
if ($driveCount -eq 0) { Add-Result 'disk' 'no fixed drive found' 'n/a' $diskThresholdText 'n/a' }

# ---------- services ----------
$systemdUsable = $false
$systemdNote = 'not applicable (Windows)'
if (-not $runningOnWindows) {
    if (-not (Get-Command -Name systemctl -CommandType Application -ErrorAction SilentlyContinue)) {
        $systemdNote = 'systemctl not installed'
    }
    elseif (Test-Path -LiteralPath '/run/systemd/system' -PathType Container) {
        $systemdUsable = $true
        $systemdNote = 'running'
    }
    else {
        $systemdNote = 'not booted with systemd'
    }
}

foreach ($name in $serviceNames) {
    if ($runningOnWindows) {
        $found = @(Get-Service -Name $name -ErrorAction SilentlyContinue)
        if ($found.Count -eq 0) {
            Add-Result 'service' $name 'not found' 'Running' 'WARNING'
            continue
        }
        foreach ($svc in $found) {
            $state = $svc.Status.ToString()
            $level = 'WARNING'
            if ($state -eq 'Running') { $level = 'OK' }
            Add-Result 'service' ('{0} ({1})' -f $svc.Name, $svc.DisplayName) $state 'Running' $level
        }
    }
    elseif ($systemdUsable) {
        $answer = Invoke-Systemctl -ArgumentList @('is-active', '--', $name)
        $state = 'unknown'
        if ($answer.Output.Count -gt 0 -and "$($answer.Output[0])".Trim() -ne '') { $state = "$($answer.Output[0])".Trim() }
        $level = 'WARNING'
        if ($state -eq 'active') { $level = 'OK' }
        Add-Result 'service' $name $state 'active' $level
    }
    else {
        Add-Result 'service' $name 'n/a' 'active' 'n/a'
    }
}

# ---------- failed systemd units (Linux only) ----------
if (-not $runningOnWindows) {
    $failedItem = 'systemctl --failed (systemd not running)'
    $failedValue = 'n/a'
    $failedLevel = 'n/a'
    if ($systemdUsable) {
        $answer = Invoke-Systemctl -ArgumentList @('--failed', '--no-legend', '--plain')
        if ($answer.ExitCode -eq 0) {
            $failedUnits = @($answer.Output | Where-Object { "$_".Trim() -ne '' } | ForEach-Object { ("$_".Trim() -split '\s+')[0] })
            $failedValue = "$($failedUnits.Count)"
            $failedItem = 'systemctl --failed'
            $failedLevel = 'OK'
            if ($failedUnits.Count -gt 0) {
                $failedItem = 'systemctl --failed ({0})' -f ($failedUnits -join ', ')
                $failedLevel = 'WARNING'
            }
        }
        else {
            $failedItem = 'systemctl --failed (no answer from systemd)'
        }
    }
    Add-Result 'failed-units' $failedItem $failedValue '0' $failedLevel
}

# ---------- pending reboot ----------
try {
    if ($runningOnWindows) {
        $reasons = @()
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
            $reasons += 'CBS RebootPending'
        }
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
            $reasons += 'Windows Update RebootRequired'
        }
        $sessionManager = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
        if ($null -ne $sessionManager -and $null -ne $sessionManager.PSObject.Properties['PendingFileRenameOperations']) {
            $reasons += 'PendingFileRenameOperations'
        }
        if ($reasons.Count -gt 0) {
            Add-Result 'reboot' ('pending: {0}' -f ($reasons -join ', ')) 'yes' 'no' 'WARNING'
        }
        else {
            Add-Result 'reboot' 'CBS, Windows Update and Session Manager keys' 'no' 'no' 'OK'
        }
    }
    elseif (Test-Path -LiteralPath '/var/run/reboot-required') {
        $item = '/var/run/reboot-required'
        if (Test-Path -LiteralPath '/var/run/reboot-required.pkgs') {
            $packages = @(Get-Content -LiteralPath '/var/run/reboot-required.pkgs' | Where-Object { $_.Trim() -ne '' } | Sort-Object -Unique)
            if ($packages.Count -gt 0) { $item += ' (packages: {0})' -f ($packages -join ', ') }
        }
        Add-Result 'reboot' $item 'yes' 'no' 'WARNING'
    }
    else {
        Add-Result 'reboot' '/var/run/reboot-required' 'no' 'no' 'OK'
    }
}
catch {
    Write-Verbose "Pending reboot check failed: $($_.Exception.Message)"
    Add-Result 'reboot' 'pending reboot' 'n/a' 'no' 'n/a'
}

# ---------- uptime (information) ----------
$bootUtc = $null
try {
    if ($null -ne $os -and $null -ne $os.LastBootUpTime) {
        $bootUtc = ([datetime]$os.LastBootUpTime).ToUniversalTime()
    }
    elseif (Test-Path -LiteralPath '/proc/uptime') {
        $upSeconds = [double]((Get-Content -LiteralPath '/proc/uptime' -TotalCount 1) -split '\s+')[0]
        $bootUtc = (Get-Date).ToUniversalTime().AddSeconds(-$upSeconds)
    }
}
catch { Write-Verbose "Uptime unavailable: $($_.Exception.Message)" }
if ($null -ne $bootUtc) {
    $span = (Get-Date).ToUniversalTime() - $bootUtc
    Add-Result 'uptime' ('booted {0}' -f $bootUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')) ('{0}d {1:00}h {2:00}m' -f $span.Days, $span.Hours, $span.Minutes) '-' 'OK'
}
else {
    Add-Result 'uptime' 'last boot time' 'n/a' '-' 'n/a'
}

# ---------- summary ----------
$warnings = @($results | Where-Object { $_.Status -eq 'WARNING' })
$status = 'OK'
if ($warnings.Count -gt 0) { $status = 'WARNING' }
$okCount = @($results | Where-Object { $_.Status -eq 'OK' }).Count
$naCount = @($results | Where-Object { $_.Status -eq 'n/a' }).Count

$summary = [ordered]@{
    'Report time (UTC)' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    'Computer name'     = $(if ($runningOnWindows) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() })
    'Thresholds'        = 'CPU >= {0}%, memory/page file >= {1}%, disk >= {2}%' -f $CpuPercent, $MemoryPercent, $DiskPercent
    'systemd'           = $systemdNote
    'Checks'            = '{0} OK, {1} WARNING, {2} n/a' -f $okCount, $warnings.Count, $naCount
    'Status'            = $status
    'PowerShell'        = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
}
if ($runningOnWindows) { $summary.Remove('systemd') }
elseif (-not $runningOnLinux) { $summary['systemd'] = "$systemdNote (not Linux)" }

# ---------- rendering ----------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
                   ' System Health Report',
                   '==============================================')
        foreach ($key in $summary.Keys) { $lines += ('{0,-20} : {1}' -f $key, $summary[$key]) }
        $lines += '', '--- Checks ---'
        $lines += '{0,-13} {1,-8} {2,-11} {3,-9} {4}' -f 'CHECK', 'STATUS', 'VALUE', 'THRESHOLD', 'ITEM'
        foreach ($r in $results) {
            $lines += '{0,-13} {1,-8} {2,-11} {3,-9} {4}' -f $r.Check, $r.Status, $r.Value, $r.Threshold, $r.Item
        }
        $lines += '', '--- Warnings ---'
        if ($warnings.Count -eq 0) { $lines += 'none' }
        foreach ($w in $warnings) {
            $word = 'expected'
            if ($w.Threshold.StartsWith('>=')) { $word = 'threshold' }
            $lines += '{0,-13} {1}: {2} ({3} {4})' -f $w.Check, $w.Item, $w.Value, $word, $w.Threshold
        }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $output = ($results | Select-Object -Property Check, Item, Value, Threshold, Status | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]@{
            Summary  = [pscustomobject]$summary
            Checks   = @($results)
            Warnings = $warnings
        } | ConvertTo-Json -Depth 4
        $extension = 'json'
    }
}

# -Quiet: stay silent when everything is OK, so a scheduled run only produces output on problems.
if (-not $Quiet -or $status -ne 'OK') { Write-Output $output }

if ($PSBoundParameters.ContainsKey('OutputPath')) {
    try {
        if (-not (Test-Path -LiteralPath $OutputPath -PathType Container)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $safeName = $summary['Computer name'] -replace '[^A-Za-z0-9._-]', '_'
        $file = Join-Path $OutputPath ('System-Health-{0}-{1}.{2}' -f $safeName, $stamp, $extension)
        $output | Out-File -LiteralPath $file -Encoding utf8
        if (-not $Quiet) { Write-Information "Report saved to: $file" -InformationAction Continue }
    }
    catch {
        Write-Error "Could not write report to '$OutputPath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}

if ($status -eq 'OK') { exit 0 }
exit 3
