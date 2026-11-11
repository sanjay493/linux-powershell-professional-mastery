<#
.SYNOPSIS
    Read-only volume usage report with warning and critical thresholds.

.DESCRIPTION
    Lists every ready volume of the selected drive types (local fixed disks by default)
    with size, used and free space and percentage used, flags volumes at or above the
    warning or critical threshold, and optionally lists the largest folders directly under
    a path. When any volume is at or above a threshold the script exits with code 3, so it
    can be used by Task Scheduler, cron or a monitoring agent. The script only READS; it
    never deletes, moves or changes files.

    Course : Linux & PowerShell Professional Mastery (Day 09)
    Target : Windows 11 with Windows PowerShell 5.1 or PowerShell 7.x
             (also runs in PowerShell 7 on Linux, where each mount point is a "drive")
    Needs  : No administrator rights. Volume information comes from .NET
             System.IO.DriveInfo, which works in 5.1 and 7 on every OS. Folders you
             cannot read are skipped and counted.

.PARAMETER WarningPercent
    Warning threshold in percent used (1-100). Default 80.

.PARAMETER CriticalPercent
    Critical threshold in percent used (1-100). Must be >= WarningPercent. Default 90.

.PARAMETER DriveType
    Drive types to include: Fixed (default), Removable, Network, Ram, CDRom, Unknown.
    On Linux, tmpfs mounts are reported as Ram and most pseudo filesystems as Unknown.

.PARAMETER DriveName
    Optional drive names to report, for example 'C', 'R:\' or '/srv/lab09' (wildcards such as
    'D*' are allowed). Matched against System.IO.DriveInfo.Name without the trailing separator;
    a single letter means that drive letter. Default: every drive of the selected types.

.PARAMETER FolderPath
    Optional folder. When given, the largest sub-folders directly under it are listed
    (recursive size, reparse points such as junctions and symbolic links are not followed).

.PARAMETER Top
    Number of folders to list with -FolderPath (1-50). Default 10.

.PARAMETER Format
    Output format: Text (default), Csv or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    Disk-Monitor-<COMPUTER>-<UTC timestamp>.<txt|csv|json>.

.EXAMPLE
    .\Disk-Monitor.ps1

.EXAMPLE
    .\Disk-Monitor.ps1 -WarningPercent 70 -CriticalPercent 85 -FolderPath $env:USERPROFILE -Top 5

.EXAMPLE
    .\Disk-Monitor.ps1 -Format Csv -OutputPath $HOME\lpm-lab\reports

.NOTES
    Exit codes: 0 OK, 1 invalid arguments, 2 output folder problem,
    3 at least one volume is at or above a threshold.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 100)]
    [int]$WarningPercent = 80,

    [ValidateRange(1, 100)]
    [int]$CriticalPercent = 90,

    [ValidateSet('Fixed', 'Removable', 'Network', 'Ram', 'CDRom', 'Unknown')]
    [string[]]$DriveType = @('Fixed'),

    [ValidateNotNullOrEmpty()]
    [string[]]$DriveName,

    [ValidateNotNullOrEmpty()]
    [string]$FolderPath,

    [ValidateRange(1, 50)]
    [int]$Top = 10,

    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($CriticalPercent -lt $WarningPercent) {
    Write-Error "-CriticalPercent ($CriticalPercent) must be greater than or equal to -WarningPercent ($WarningPercent)." -ErrorAction Continue
    exit 1
}
if ($PSBoundParameters.ContainsKey('FolderPath') -and -not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
    Write-Error "-FolderPath '$FolderPath' is not an existing folder." -ErrorAction Continue
    exit 1
}

# $IsWindows exists only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)

function Format-Size {
    <# Converts a byte count to a short human-readable string (KB, MB, GB, TB; base 1024). #>
    param($Bytes)
    if ($null -eq $Bytes) { return 'n/a' }
    $value = [double]$Bytes
    $units = 'B', 'KB', 'MB', 'GB', 'TB', 'PB'
    $i = 0
    while ($value -ge 1024 -and $i -lt ($units.Count - 1)) { $value = $value / 1024; $i++ }
    if ($i -eq 0) { return ('{0} B' -f [long]$value) }
    return ('{0:N1} {1}' -f $value, $units[$i])
}

function Get-FolderSize {
    <#
        Returns total bytes, file count and the number of unreadable folders under Path.
        Uses an explicit stack instead of recursion and never follows reparse points
        (junctions, symbolic links), so it cannot loop and behaves the same in 5.1 and 7.
    #>
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [long]0
    $files = [long]0
    $denied = 0
    $stack = New-Object System.Collections.Stack
    $stack.Push((New-Object System.IO.DirectoryInfo -ArgumentList $Path))
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        try {
            foreach ($entry in $dir.GetFileSystemInfos()) {
                if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                if ($entry -is [System.IO.DirectoryInfo]) { $stack.Push($entry) }
                else { $bytes += $entry.Length; $files++ }
            }
        }
        catch { $denied++ }
    }
    [pscustomobject]@{ Bytes = $bytes; Files = $files; Unreadable = $denied }
}

# ---------- volumes ----------
try {
    $allDrives = @([System.IO.DriveInfo]::GetDrives())
}
catch {
    Write-Error "Could not enumerate drives: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}

$volumes = foreach ($drive in $allDrives) {
    if ($DriveType -notcontains $drive.DriveType.ToString()) { continue }
    if ($PSBoundParameters.ContainsKey('DriveName')) {
        # Compare without trailing separators; a bare letter such as 'R' means 'R:'.
        $have = $drive.Name.TrimEnd('\', '/')
        $nameMatches = @($DriveName | Where-Object {
                $want = $_.TrimEnd('\', '/')
                if ($want -match '^[A-Za-z]$') { $want += ':' }
                $have -like $want
            })
        if ($nameMatches.Count -eq 0) { continue }
    }
    try {
        if (-not $drive.IsReady) { Write-Verbose "Skipping $($drive.Name): not ready"; continue }
        $size = [double]$drive.TotalSize
        $freeTotal = [double]$drive.TotalFreeSpace
        $available = [double]$drive.AvailableFreeSpace
        $fsFormat = $drive.DriveFormat
    }
    catch {
        Write-Verbose "Skipping $($drive.Name): $($_.Exception.Message)"
        continue
    }
    if ($size -le 0) { continue }
    $label = $null
    try { $label = $drive.VolumeLabel } catch { $label = $null }

    # Same formula as Linux df: used / (used + available), so blocks reserved for root
    # on ext4 count as unavailable. On NTFS TotalFreeSpace normally equals AvailableFreeSpace.
    $used = $size - $freeTotal
    $usedPercent = 0
    if (($used + $available) -gt 0) { $usedPercent = [math]::Round(($used / ($used + $available)) * 100, 1) }

    $level = 'OK'
    if ($usedPercent -ge $CriticalPercent) { $level = 'CRITICAL' }
    elseif ($usedPercent -ge $WarningPercent) { $level = 'WARNING' }

    [pscustomobject]@{
        Name        = $drive.Name
        Label       = $(if ([string]::IsNullOrWhiteSpace($label) -or $label -eq $drive.Name) { 'n/a' } else { $label })
        DriveType   = $drive.DriveType.ToString()
        FileSystem  = $(if ([string]::IsNullOrWhiteSpace($fsFormat)) { 'n/a' } else { $fsFormat })
        SizeGB      = [math]::Round($size / 1GB, 2)
        UsedGB      = [math]::Round($used / 1GB, 2)
        FreeGB      = [math]::Round($available / 1GB, 2)
        UsedPercent = $usedPercent
        Level       = $level
    }
}
$volumes = @($volumes | Sort-Object -Property Name)
$breaches = @($volumes | Where-Object { $_.Level -ne 'OK' })

$status = 'OK'
if (@($breaches | Where-Object { $_.Level -eq 'CRITICAL' }).Count -gt 0) { $status = 'CRITICAL' }
elseif ($breaches.Count -gt 0) { $status = 'WARNING' }

# ---------- optional: largest folders ----------
$folders = @()
$unreadableTotal = 0
if ($PSBoundParameters.ContainsKey('FolderPath')) {
    $resolved = (Resolve-Path -LiteralPath $FolderPath).ProviderPath
    try {
        $children = @((New-Object System.IO.DirectoryInfo -ArgumentList $resolved).GetDirectories() |
                Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0 })
    }
    catch {
        Write-Error "Cannot list '$resolved': $($_.Exception.Message)" -ErrorAction Continue
        exit 1
    }
    $folders = foreach ($child in $children) {
        $result = Get-FolderSize -Path $child.FullName
        $unreadableTotal += $result.Unreadable
        [pscustomobject]@{
            Folder     = $child.FullName
            SizeBytes  = $result.Bytes
            Size       = Format-Size $result.Bytes
            Files      = $result.Files
            Unreadable = $result.Unreadable
        }
    }
    $folders = @($folders | Sort-Object -Property SizeBytes -Descending | Select-Object -First $Top)
}

$summary = [ordered]@{
    'Report time (UTC)' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    'Computer name'     = $(if ($runningOnWindows) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() })
    'Volumes'           = $volumes.Count
    'Drive types'       = ($DriveType -join ', ')
    'Thresholds'        = 'WARNING >= {0}%, CRITICAL >= {1}% used' -f $WarningPercent, $CriticalPercent
    'Status'            = $status
    'PowerShell'        = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
}

# ---------- rendering ----------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
                   ' Disk Monitor Report',
                   '==============================================')
        foreach ($key in $summary.Keys) { $lines += ('{0,-20} : {1}' -f $key, $summary[$key]) }
        $lines += '', '--- Volumes ---'
        $lines += '{0,-22} {1,-8} {2,-9} {3,10} {4,10} {5,10} {6,6} {7,-9} {8}' -f 'Name', 'FS', 'Type', 'Size(GB)', 'Used(GB)', 'Free(GB)', 'Use%', 'Level', 'Label'
        foreach ($v in $volumes) {
            $name = $v.Name
            if ($name.Length -gt 22) { $name = $name.Substring(0, 22) }
            $lines += '{0,-22} {1,-8} {2,-9} {3,10} {4,10} {5,10} {6,6} {7,-9} {8}' -f $name, $v.FileSystem, $v.DriveType,
                $v.SizeGB, $v.UsedGB, $v.FreeGB, $v.UsedPercent, $v.Level, $v.Label
        }
        $lines += '', '--- Threshold breaches ---'
        if ($breaches.Count -eq 0) { $lines += 'none' }
        foreach ($b in $breaches) {
            $lines += '{0,-9} {1} used {2}% ({3} GB free of {4} GB)' -f $b.Level, $b.Name, $b.UsedPercent, $b.FreeGB, $b.SizeGB
        }
        if ($PSBoundParameters.ContainsKey('FolderPath')) {
            $lines += '', "--- Largest folders under $resolved ---"
            if ($folders.Count -eq 0) { $lines += 'n/a (no sub-folders)' }
            foreach ($f in $folders) { $lines += '{0,12}  {1,9} files  {2}' -f $f.Size, $f.Files, $f.Folder }
            $lines += "Unreadable folders skipped: $unreadableTotal"
        }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $csvRows = @($volumes | Select-Object @{ n = 'Record'; e = { 'volume' } }, Name, Label, DriveType, FileSystem,
                SizeGB, UsedGB, FreeGB, UsedPercent, Level, @{ n = 'Files'; e = { $null } })
        $csvRows += @($folders | Select-Object @{ n = 'Record'; e = { 'folder' } }, @{ n = 'Name'; e = { $_.Folder } },
                @{ n = 'Label'; e = { $null } }, @{ n = 'DriveType'; e = { $null } }, @{ n = 'FileSystem'; e = { $null } },
                @{ n = 'SizeGB'; e = { [math]::Round($_.SizeBytes / 1GB, 3) } }, @{ n = 'UsedGB'; e = { $null } },
                @{ n = 'FreeGB'; e = { $null } }, @{ n = 'UsedPercent'; e = { $null } }, @{ n = 'Level'; e = { $null } }, Files)
        $output = ($csvRows | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]@{
            Summary  = [pscustomobject]$summary
            Volumes  = $volumes
            Breaches = $breaches
            Folders  = $folders
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
        $file = Join-Path $OutputPath ('Disk-Monitor-{0}-{1}.{2}' -f $safeName, $stamp, $extension)
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
