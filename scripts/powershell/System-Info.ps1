<#
.SYNOPSIS
    Read-only system identity and inventory report for Windows.

.DESCRIPTION
    Collects host, user, OS, CPU, memory, disk, network and uptime information
    and writes it to the console as text, CSV or JSON. Optionally saves the
    report to a folder. The script only READS information and changes nothing.

    Course : Linux & PowerShell Professional Mastery (Day 01)
    Target : Windows 11 with Windows PowerShell 5.1 or PowerShell 7.x
    Needs  : CIM/WMI access (default for local users). No administrator rights required.

.PARAMETER Format
    Output format: Text (default), Csv or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    System-Info-<COMPUTER>-<UTC timestamp>.<txt|csv|json>.

.EXAMPLE
    .\System-Info.ps1

.EXAMPLE
    .\System-Info.ps1 -Format Csv -OutputPath $HOME\lpm-lab\reports

.NOTES
    Exit codes: 0 success, 1 unsupported platform, 2 output folder problem.
#>
[CmdletBinding()]
param(
    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $IsWindows exists only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
if (-not $runningOnWindows) {
    Write-Error 'System-Info.ps1 targets Windows. On Linux use scripts/linux/system-info.sh.' -ErrorAction Continue
    exit 1
}

function Invoke-Safely {
    <# Runs a script block; returns $null instead of throwing so one failed query never stops the report. #>
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock)
    try { & $ScriptBlock }
    catch {
        Write-Verbose "Value unavailable: $($_.Exception.Message)"
        $null
    }
}

function Format-Value {
    <# Converts $null / empty values to 'n/a' for display. #>
    param($Value)
    if ($null -eq $Value -or "$Value".Trim() -eq '') { 'n/a' } else { "$Value" }
}

# ---------- data collection (CIM works in both 5.1 and 7) ----------
$os   = Invoke-Safely { Get-CimInstance -ClassName Win32_OperatingSystem }
$cs   = Invoke-Safely { Get-CimInstance -ClassName Win32_ComputerSystem }
$cpu  = Invoke-Safely { Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1 }
$disk = Invoke-Safely { Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" }

$memTotalMB = $null; $memFreeMB = $null; $memUsedMB = $null
if ($os) {
    # Win32_OperatingSystem reports memory in KB
    $memTotalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB)
    $memFreeMB  = [math]::Round($os.FreePhysicalMemory / 1KB)
    $memUsedMB  = $memTotalMB - $memFreeMB
}

$systemDrive = $null
if ($disk -and $disk.Size) {
    $sizeGB  = [math]::Round($disk.Size / 1GB, 1)
    $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 1)
    $pctUsed = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100)
    $systemDrive = '{0} {1} GB used of {2} GB ({3}%), {4} GB free' -f $disk.DeviceID, ($sizeGB - $freeGB), $sizeGB, $pctUsed, $freeGB
}

$ipv4 = Invoke-Safely {
    (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        ForEach-Object { '{0}={1}/{2}' -f $_.InterfaceAlias, $_.IPAddress, $_.PrefixLength }) -join ' '
}
$gateway = Invoke-Safely {
    Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
        Sort-Object RouteMetric | Select-Object -First 1 |
        ForEach-Object { '{0} via {1}' -f $_.NextHop, $_.InterfaceAlias }
}
$dns = Invoke-Safely {
    (Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object { $_.ServerAddresses } |
        ForEach-Object { $_.ServerAddresses } | Select-Object -Unique) -join ' '
}

$bootTime = $null; $uptime = $null
if ($os -and $os.LastBootUpTime) {
    $bootTime = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
    $span = (Get-Date) - $os.LastBootUpTime
    $uptime = '{0}d {1}h {2}m' -f $span.Days, $span.Hours, $span.Minutes
}

$report = [ordered]@{
    'Report time (UTC)'  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    'Computer name'      = $env:COMPUTERNAME
    'Current user'       = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    'Operating system'   = $(if ($os) { $os.Caption })
    'OS version/build'   = $(if ($os) { '{0} (build {1})' -f $os.Version, $os.BuildNumber })
    'Architecture'       = $env:PROCESSOR_ARCHITECTURE
    'Manufacturer/model' = $(if ($cs) { '{0} {1}' -f $cs.Manufacturer, $cs.Model })
    'CPU model'          = $(if ($cpu) { $cpu.Name.Trim() })
    'Logical CPUs'       = $(if ($cs) { $cs.NumberOfLogicalProcessors })
    'Memory total (MB)'  = $memTotalMB
    'Memory used (MB)'   = $memUsedMB
    'Memory free (MB)'   = $memFreeMB
    'System drive'       = $systemDrive
    'IPv4 addresses'     = $ipv4
    'Default gateway'    = $gateway
    'DNS servers'        = $dns
    'Uptime'             = $uptime
    'Boot time'          = $bootTime
    'PowerShell'         = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
}

# Normalise every value to a display string.
foreach ($key in @($report.Keys)) { $report[$key] = Format-Value $report[$key] }

# ---------- rendering ----------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
                   ' System Information Report',
                   '==============================================')
        foreach ($key in $report.Keys) { $lines += ('{0,-20} : {1}' -f $key, $report[$key]) }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $output = ($report.GetEnumerator() |
            ForEach-Object { [pscustomobject]@{ Property = $_.Key; Value = $_.Value } } |
            ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]$report | ConvertTo-Json
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
        $file = Join-Path $OutputPath ('System-Info-{0}-{1}.{2}' -f $env:COMPUTERNAME, $stamp, $extension)
        $output | Out-File -LiteralPath $file -Encoding utf8
        Write-Information "Report saved to: $file" -InformationAction Continue
    }
    catch {
        Write-Error "Could not write report to '$OutputPath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}

exit 0
