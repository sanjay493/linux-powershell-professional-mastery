<#
.SYNOPSIS
    Read-only report of listening TCP/UDP ports and their owning processes, with an
    exposure check and a baseline comparison.

.DESCRIPTION
    Lists every listening TCP socket and every UDP endpoint with its local address, port,
    owning process ID and name and (on Windows) the services hosted in that process.
    Optionally flags listeners bound to ALL addresses (0.0.0.0 or ::) whose port is not
    in an allowed list, summarises TCP connections by state, saves the current listeners
    as a baseline file and compares them with a baseline saved earlier (NEW / GONE).
    When a NEW listener or an exposed port is found the script exits with code 3, so it
    can be used by Task Scheduler, cron or a monitoring agent. The script only READS
    socket tables; it never closes connections, stops processes or changes the firewall.

    Course : Linux & PowerShell Professional Mastery (Day 14)
    Target : Windows 11 with Windows PowerShell 5.1 or PowerShell 7.x
             (also runs in PowerShell 7 on Linux and macOS, without process information)
    Needs  : No administrator rights. On Windows the NetTCPIP cmdlets Get-NetTCPConnection
             and Get-NetUDPEndpoint are used; service names come from Win32_Service (CIM).
             Elsewhere, or when those cmdlets are missing, the .NET class
             System.Net.NetworkInformation.IPGlobalProperties is used and process
             information is reported as n/a.

    The baseline file format (one "proto address port" line per listener, # comments)
    is the same as the one written by port-monitor.sh -s, so baselines can be compared
    with either script.

.PARAMETER Protocol
    Protocols to report: Tcp, Udp or both (default both).

.PARAMETER CheckExposure
    Flag listeners bound to all addresses (0.0.0.0, ::) whose port is not in -AllowedPort.

.PARAMETER AllowedPort
    Ports that may listen on all addresses when -CheckExposure is used (default 22).

.PARAMETER ConnectionSummary
    Also count TCP connections by state (Established, TimeWait, CloseWait ...).

.PARAMETER BaselinePath
    Baseline file saved earlier with -SaveBaselinePath (or port-monitor.sh -s).
    NEW and GONE listeners are reported; a NEW listener sets exit code 3.

.PARAMETER SaveBaselinePath
    File to save the current listeners to, for later comparisons.

.PARAMETER Format
    Output format: Text (default), Csv or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    Port-Monitor-<COMPUTER>-<UTC timestamp>.<txt|csv|json>.

.EXAMPLE
    .\Port-Monitor.ps1

.EXAMPLE
    .\Port-Monitor.ps1 -Protocol Tcp -CheckExposure -AllowedPort 135, 445, 3389

.EXAMPLE
    .\Port-Monitor.ps1 -SaveBaselinePath $HOME\lpm-lab\ports-baseline.txt
    .\Port-Monitor.ps1 -BaselinePath $HOME\lpm-lab\ports-baseline.txt -ConnectionSummary

.EXAMPLE
    .\Port-Monitor.ps1 -Format Json -OutputPath $HOME\lpm-lab\reports

.NOTES
    Exit codes: 0 OK, 1 invalid arguments, 2 output or baseline file problem,
    3 a NEW listener (compared with -BaselinePath) or an exposed port (-CheckExposure).
#>
[CmdletBinding()]
param(
    [ValidateSet('Tcp', 'Udp')]
    [string[]]$Protocol = @('Tcp', 'Udp'),

    [switch]$CheckExposure,

    [ValidateRange(1, 65535)]
    [int[]]$AllowedPort = @(22),

    [switch]$ConnectionSummary,

    [ValidateNotNullOrEmpty()]
    [string]$BaselinePath,

    [ValidateNotNullOrEmpty()]
    [string]$SaveBaselinePath,

    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSBoundParameters.ContainsKey('BaselinePath') -and -not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) {
    Write-Error "-BaselinePath '$BaselinePath' is not an existing file." -ErrorAction Continue
    exit 1
}

# $IsWindows exists only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
$wantTcp = $Protocol -contains 'Tcp'
$wantUdp = $Protocol -contains 'Udp'

function Get-BindScope {
    <# Returns ALL for wildcard addresses, LOOPBACK for 127.x / ::1, otherwise SPECIFIC. #>
    param([string]$Address)
    if ($Address -eq '0.0.0.0' -or $Address -eq '::') { return 'ALL' }
    if ($Address -like '127.*' -or $Address -eq '::1') { return 'LOOPBACK' }
    return 'SPECIFIC'
}

function Get-PortListener {
    <#
        Returns one object per listening TCP socket / UDP endpoint:
        Protocol, Address, Port, ProcessId (or $null when unknown).
    #>
    param([bool]$IncludeTcp, [bool]$IncludeUdp, [bool]$UseNetTcpIp)
    $found = New-Object System.Collections.Generic.List[object]
    if ($UseNetTcpIp) {
        if ($IncludeTcp) {
            foreach ($c in @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)) {
                $found.Add([pscustomobject]@{ Protocol = 'tcp'; Address = [string]$c.LocalAddress; Port = [int]$c.LocalPort; ProcessId = [int]$c.OwningProcess })
            }
        }
        if ($IncludeUdp) {
            foreach ($u in @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue)) {
                $found.Add([pscustomobject]@{ Protocol = 'udp'; Address = [string]$u.LocalAddress; Port = [int]$u.LocalPort; ProcessId = [int]$u.OwningProcess })
            }
        }
    }
    else {
        $ipProps = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        if ($IncludeTcp) {
            foreach ($ep in @($ipProps.GetActiveTcpListeners())) {
                $found.Add([pscustomobject]@{ Protocol = 'tcp'; Address = $ep.Address.ToString(); Port = [int]$ep.Port; ProcessId = $null })
            }
        }
        if ($IncludeUdp) {
            foreach ($ep in @($ipProps.GetActiveUdpListeners())) {
                $found.Add([pscustomobject]@{ Protocol = 'udp'; Address = $ep.Address.ToString(); Port = [int]$ep.Port; ProcessId = $null })
            }
        }
    }
    return $found
}

# ---------- collect ----------
$useNetTcpIp = $runningOnWindows -and ($null -ne (Get-Command -Name Get-NetTCPConnection -ErrorAction SilentlyContinue))
$source = $(if ($useNetTcpIp) { 'Get-NetTCPConnection / Get-NetUDPEndpoint' } else { '.NET IPGlobalProperties (no process information)' })

try {
    $raw = @(Get-PortListener -IncludeTcp $wantTcp -IncludeUdp $wantUdp -UseNetTcpIp $useNetTcpIp)
}
catch {
    Write-Error "Could not read the socket tables: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}

# Process names (one Get-Process call) and, on Windows, the services hosted by each PID.
$processNames = @{}
foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) { $processNames[[int]$p.Id] = $p.ProcessName }
$serviceNames = @{}
if ($useNetTcpIp) {
    try {
        foreach ($svc in @(Get-CimInstance -ClassName Win32_Service -Filter "State = 'Running'" -ErrorAction Stop)) {
            $svcPid = [int]$svc.ProcessId
            if ($serviceNames.ContainsKey($svcPid)) { $serviceNames[$svcPid] = $serviceNames[$svcPid] + ',' + $svc.Name }
            else { $serviceNames[$svcPid] = [string]$svc.Name }
        }
    }
    catch {
        Write-Verbose "Service names unavailable: $($_.Exception.Message)"
    }
}

$listeners = foreach ($item in $raw) {
    $procName = 'n/a'
    $procId = 'n/a'
    $services = 'n/a'
    if ($null -ne $item.ProcessId) {
        $procId = [string]$item.ProcessId
        if ($processNames.ContainsKey([int]$item.ProcessId)) { $procName = $processNames[[int]$item.ProcessId] }
        if ($serviceNames.ContainsKey([int]$item.ProcessId)) { $services = $serviceNames[[int]$item.ProcessId] }
    }
    $scope = Get-BindScope -Address $item.Address
    $flag = '-'
    if ($CheckExposure -and $scope -eq 'ALL' -and ($AllowedPort -notcontains $item.Port)) { $flag = 'EXPOSED' }
    [pscustomobject]@{
        Protocol  = $item.Protocol
        Address   = $item.Address
        Port      = $item.Port
        ProcessId = $procId
        Process   = $procName
        Services  = $services
        BoundTo   = $scope
        Flag      = $flag
    }
}
# Several sockets can share one address and port (for example SO_REUSEPORT); report each once.
$listeners = @($listeners | Where-Object { $null -ne $_ } | Sort-Object -Property Protocol, Port, Address, ProcessId -Unique)
$exposed = @($listeners | Where-Object { $_.Flag -eq 'EXPOSED' })

# ---------- baseline comparison ----------
$currentKeys = @($listeners | ForEach-Object { '{0} {1} {2}' -f $_.Protocol, $_.Address, $_.Port } | Sort-Object -Unique)
$newKeys = @()
$goneKeys = @()
if ($PSBoundParameters.ContainsKey('BaselinePath')) {
    try {
        $baseKeys = @(Get-Content -LiteralPath $BaselinePath -ErrorAction Stop |
                Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' } |
                ForEach-Object {
                    $tokens = @($_.Trim() -split '\s+')
                    if ($tokens.Count -ge 3) { '{0} {1} {2}' -f $tokens[0], $tokens[1], $tokens[2] }
                } |
                Sort-Object -Unique)
    }
    catch {
        Write-Error "Could not read baseline '$BaselinePath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
    $newKeys = @($currentKeys | Where-Object { $baseKeys -notcontains $_ })
    $goneKeys = @($baseKeys | Where-Object { $currentKeys -notcontains $_ })
}

# ---------- optional: TCP connections by state ----------
$stateCounts = @()
if ($ConnectionSummary) {
    try {
        if ($useNetTcpIp) {
            $states = @(Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.State.ToString() -ne 'Listen' } |
                    ForEach-Object { $_.State.ToString() })
        }
        else {
            $states = @([System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpConnections() |
                    ForEach-Object { $_.State.ToString() })
        }
        $stateCounts = @($states | Group-Object | Sort-Object -Property Count -Descending |
                Select-Object @{ n = 'State'; e = { $_.Name } }, Count)
    }
    catch {
        Write-Verbose "Connection summary unavailable: $($_.Exception.Message)"
    }
}

$status = 'OK'
if ($newKeys.Count -gt 0 -or $exposed.Count -gt 0) { $status = 'ALERT' }
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$computerName = $(if ($runningOnWindows) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() })

$summary = [ordered]@{
    'Report time (UTC)' = $timestamp
    'Computer name'     = $computerName
    'Protocols'         = ($Protocol -join ', ')
    'Data source'       = $source
    'Listeners'         = $listeners.Count
    'Status'            = $status
    'PowerShell'        = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
}
if ($CheckExposure) { $summary['Exposed listeners'] = '{0} (allowed on all addresses: {1})' -f $exposed.Count, ($AllowedPort -join ',') }
if ($PSBoundParameters.ContainsKey('BaselinePath')) { $summary['Baseline'] = '{0} (NEW {1}, GONE {2})' -f $BaselinePath, $newKeys.Count, $goneKeys.Count }

# ---------- rendering ----------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
                   ' Port Monitor Report',
                   '==============================================')
        foreach ($key in $summary.Keys) { $lines += ('{0,-20} : {1}' -f $key, $summary[$key]) }
        $lines += '', '--- Listening sockets ---'
        $lines += '{0,-5} {1,-28} {2,-6} {3,-8} {4,-20} {5,-9} {6,-8} {7}' -f 'PROTO', 'ADDRESS', 'PORT', 'PID', 'PROCESS', 'BOUND_TO', 'FLAG', 'SERVICES'
        if ($listeners.Count -eq 0) { $lines += '(none found)' }
        foreach ($l in $listeners) {
            $lines += '{0,-5} {1,-28} {2,-6} {3,-8} {4,-20} {5,-9} {6,-8} {7}' -f $l.Protocol, $l.Address, $l.Port, $l.ProcessId,
                $l.Process, $l.BoundTo, $l.Flag, $l.Services
        }
        if ($PSBoundParameters.ContainsKey('BaselinePath')) {
            $lines += '', '--- Compared with baseline ---'
            if ($newKeys.Count -eq 0 -and $goneKeys.Count -eq 0) { $lines += 'No changes.' }
            foreach ($k in $newKeys) { $lines += "NEW   $k" }
            foreach ($k in $goneKeys) { $lines += "GONE  $k" }
        }
        if ($ConnectionSummary) {
            $lines += '', '--- TCP connections by state (listeners excluded) ---'
            if ($stateCounts.Count -eq 0) { $lines += '(none)' }
            foreach ($s in $stateCounts) { $lines += ('{0,7}  {1}' -f $s.Count, $s.State) }
        }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $csvRows = @($listeners | Select-Object @{ n = 'TimestampUtc'; e = { $timestamp } }, @{ n = 'Computer'; e = { $computerName } },
                Protocol, Address, Port, ProcessId, Process, Services, BoundTo, Flag)
        foreach ($k in @($newKeys) + @($goneKeys)) {
            $parts = $k -split ' '
            $csvRows += [pscustomobject]@{
                TimestampUtc = $timestamp; Computer = $computerName; Protocol = $parts[0]; Address = $parts[1]; Port = $parts[2]
                ProcessId = 'n/a'; Process = 'n/a'; Services = 'n/a'; BoundTo = 'n/a'
                Flag = $(if ($newKeys -contains $k) { 'NEW' } else { 'GONE' })
            }
        }
        $output = ($csvRows | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]@{
            Summary          = [pscustomobject]$summary
            Listeners        = $listeners
            New              = $newKeys
            Gone             = $goneKeys
            ConnectionStates = $stateCounts
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
        $file = Join-Path $OutputPath ('Port-Monitor-{0}-{1}.{2}' -f $safeName, $stamp, $extension)
        $output | Out-File -LiteralPath $file -Encoding utf8
        Write-Information "Report saved to: $file" -InformationAction Continue
    }
    catch {
        Write-Error "Could not write report to '$OutputPath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}

if ($PSBoundParameters.ContainsKey('SaveBaselinePath')) {
    try {
        $header = '# port-monitor baseline: proto address port   (computer {0}, {1}, source {2})' -f $computerName, $timestamp, $source
        @($header) + $currentKeys | Out-File -LiteralPath $SaveBaselinePath -Encoding ascii
        Write-Information "Baseline saved to: $SaveBaselinePath ($($listeners.Count) listeners)" -InformationAction Continue
    }
    catch {
        Write-Error "Could not write baseline '$SaveBaselinePath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}

if ($status -eq 'OK') { exit 0 }
exit 3
