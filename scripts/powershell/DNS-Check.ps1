<#
.SYNOPSIS
    Read-only forward and reverse DNS lookups across several resolvers.

.DESCRIPTION
    Looks up each name for each record type against every selected resolver, reports the
    status (OK, NODATA, NXDOMAIN, SERVFAIL, REFUSED, TIMEOUT...), the TTL, the query time and
    the answers, flags resolvers that return different answers and, with -Reverse, checks
    that every address found has a PTR record that resolves back to the same address
    (forward-confirmed reverse DNS). When anything fails or disagrees the script exits
    with code 3, so it can be used by Task Scheduler, cron or a monitoring agent.
    The script only sends DNS queries; it never changes DNS settings or clears caches.

    Course : Linux & PowerShell Professional Mastery (Day 13)
    Target : Windows 11 with Windows PowerShell 5.1 or PowerShell 7.x
             (also runs in PowerShell 7 on Linux/macOS with reduced features)
    Needs  : No administrator rights. On Windows the DnsClient module (Resolve-DnsName,
             Get-DnsClientServerAddress) is used. On Linux/macOS only the system resolver
             is available through .NET System.Net.Dns (A, AAAA and PTR); lookups against a
             specific server are reported as n/a there.

.PARAMETER Name
    Names to look up. Default: example.com on every resolver, plus this computer's own
    name on the system resolver only.

.PARAMETER Server
    Resolvers to ask: IPv4/IPv6 addresses, or 'System' for the operating system resolver
    (DNS client cache and hosts file included). Default on Windows: System plus every DNS
    server configured on the network adapters (Get-DnsClientServerAddress). Default on
    Linux/macOS: System.

.PARAMETER Type
    Record types: A, AAAA, CNAME, MX, NS, TXT, SOA, SRV, PTR. Default A and AAAA.
    The system resolver on Linux/macOS answers only A and AAAA (n/a for other types).

.PARAMETER Reverse
    Also look up the PTR record of every address found and check that the PTR name
    resolves back to the same address.

.PARAMETER NoQuickTimeout
    Windows only. By default Resolve-DnsName is called with -QuickTimeout so that an
    unreachable server fails fast; use this switch to wait for the normal timeouts.

.PARAMETER TimeoutSeconds
    Timeout for each system-resolver lookup on Linux/macOS (1-30). Default 5.

.PARAMETER Format
    Output format: Text (default), Csv or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    DNS-Check-<COMPUTER>-<UTC timestamp>.<txt|csv|json>.

.EXAMPLE
    .\DNS-Check.ps1

.EXAMPLE
    .\DNS-Check.ps1 -Name www.corp.example, intranet.corp.example -Server System, 192.168.13.53 -Reverse

.EXAMPLE
    .\DNS-Check.ps1 -Name corp.example -Type MX, TXT, NS -Format Csv -OutputPath $HOME\lpm-lab\reports

.NOTES
    Exit codes: 0 OK, 1 invalid arguments, 2 output folder problem,
    3 at least one lookup failed, resolvers disagree, or (with -Reverse) a PTR is missing
    or does not match.
    Resolve-DnsName has no CAA record type, so CAA is not offered; use nslookup -type=CAA
    or dig for CAA records.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[A-Za-z0-9_]([A-Za-z0-9_-]{0,62})(\.[A-Za-z0-9_]([A-Za-z0-9_-]{0,62}))*\.?$')]
    [string[]]$Name,

    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            $parsed = $null
            if ($_ -eq 'System' -or [System.Net.IPAddress]::TryParse($_, [ref]$parsed)) { $true }
            else { throw "'$_' is not an IP address or 'System'." }
        })]
    [string[]]$Server,

    [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'NS', 'TXT', 'SOA', 'SRV', 'PTR')]
    [string[]]$Type = @('A', 'AAAA'),

    [switch]$Reverse,

    [switch]$NoQuickTimeout,

    [ValidateRange(1, 30)]
    [int]$TimeoutSeconds = 5,

    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $IsWindows exists only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
$haveResolveDnsName = $runningOnWindows -and ($null -ne (Get-Command -Name Resolve-DnsName -ErrorAction SilentlyContinue))
$failureStatus = @('NXDOMAIN', 'SERVFAIL', 'REFUSED', 'TIMEOUT', 'FORMERR', 'NOTIMP', 'ERROR')

function Get-PropertyValue {
    <# Returns a property value or $null, without failing under Set-StrictMode. #>
    param($InputObject, [string]$PropertyName)
    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function ConvertTo-DnsStatus {
    <# Maps a Resolve-DnsName / .NET error to a short DNS status word. #>
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    $code = $null
    $exception = $ErrorRecord.Exception
    if ($exception -is [System.ComponentModel.Win32Exception]) { $code = $exception.NativeErrorCode }
    $id = [string]$ErrorRecord.FullyQualifiedErrorId
    if ($code -eq 9003 -or $id -like 'DNS_ERROR_RCODE_NAME_ERROR*') { return 'NXDOMAIN' }
    if ($code -eq 9501 -or $id -like 'DNS_INFO_NO_RECORDS*') { return 'NODATA' }
    if ($code -eq 9002 -or $id -like 'DNS_ERROR_RCODE_SERVER_FAILURE*') { return 'SERVFAIL' }
    if ($code -eq 9005 -or $id -like 'DNS_ERROR_RCODE_REFUSED*') { return 'REFUSED' }
    if ($code -eq 9001 -or $id -like 'DNS_ERROR_RCODE_FORMAT_FAILURE*') { return 'FORMERR' }
    if ($code -eq 9004 -or $id -like 'DNS_ERROR_RCODE_NOT_IMPLEMENTED*') { return 'NOTIMP' }
    if ($code -eq 1460 -or $id -like 'ERROR_TIMEOUT*' -or $exception.Message -match 'timeout|timed out') { return 'TIMEOUT' }
    return 'ERROR'
}

function Format-DnsRecord {
    <# Converts one Resolve-DnsName answer record to the text a dig user would expect. #>
    param($Record, [string]$RecordType)
    switch ($RecordType) {
        'A' { return [string](Get-PropertyValue $Record 'IPAddress') }
        'AAAA' { return [string](Get-PropertyValue $Record 'IPAddress') }
        'CNAME' { return ('{0}.' -f (Get-PropertyValue $Record 'NameHost')) }
        'NS' { return ('{0}.' -f (Get-PropertyValue $Record 'NameHost')) }
        'PTR' { return ('{0}.' -f (Get-PropertyValue $Record 'NameHost')) }
        'MX' { return ('{0} {1}.' -f (Get-PropertyValue $Record 'Preference'), (Get-PropertyValue $Record 'NameExchange')) }
        'TXT' { return ('"{0}"' -f ((@(Get-PropertyValue $Record 'Strings')) -join '')) }
        'SRV' {
            return ('{0} {1} {2} {3}.' -f (Get-PropertyValue $Record 'Priority'), (Get-PropertyValue $Record 'Weight'),
                (Get-PropertyValue $Record 'Port'), (Get-PropertyValue $Record 'NameTarget'))
        }
        'SOA' {
            return ('{0}. {1}. {2}' -f (Get-PropertyValue $Record 'PrimaryServer'), (Get-PropertyValue $Record 'NameAdministrator'),
                (Get-PropertyValue $Record 'SerialNumber'))
        }
    }
    return [string]$Record
}

function Invoke-WindowsLookup {
    <# One lookup with Resolve-DnsName (Windows only). $DnsServer 'System' = normal OS resolution. #>
    param([string]$DnsServer, [string]$LookupName, [string]$RecordType)
    $arguments = @{ Name = $LookupName; Type = $RecordType; ErrorAction = 'Stop' }
    if (-not $NoQuickTimeout) { $arguments['QuickTimeout'] = $true }
    if ($DnsServer -ne 'System') {
        $arguments['Server'] = $DnsServer
        $arguments['DnsOnly'] = $true
        $arguments['NoHostsFile'] = $true
    }
    $result = [ordered]@{ Status = 'OK'; TTL = 'n/a'; Ms = 'n/a'; Answers = @() }
    $records = @()
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $records = @(Resolve-DnsName @arguments)
    }
    catch {
        $result.Status = ConvertTo-DnsStatus -ErrorRecord $_
    }
    $timer.Stop()
    $result.Ms = [int]$timer.ElapsedMilliseconds
    if ($result.Status -ne 'OK') { return [pscustomobject]$result }
    # Keep only answer-section records of the requested type (Resolve-DnsName also returns
    # the CNAME chain and, for empty answers, the SOA from the authority section).
    $answers = @($records | Where-Object {
            ([string](Get-PropertyValue $_ 'Section') -eq 'Answer') -and ([string](Get-PropertyValue $_ 'Type') -eq $RecordType)
        })
    if ($answers.Count -eq 0) {
        $result.Status = 'NODATA'
        return [pscustomobject]$result
    }
    $result.Answers = @($answers | ForEach-Object { Format-DnsRecord -Record $_ -RecordType $RecordType } | Sort-Object -Unique)
    $ttls = @($answers | ForEach-Object { Get-PropertyValue $_ 'TTL' } | Where-Object { $null -ne $_ } | Sort-Object)
    if ($ttls.Count -gt 0) { $result.TTL = [string]$ttls[0] }
    return [pscustomobject]$result
}

function Invoke-DotNetLookup {
    <# System-resolver lookup through System.Net.Dns (works in 5.1 and 7 on every OS). #>
    param([string]$LookupName, [string]$RecordType)
    $result = [ordered]@{ Status = 'OK'; TTL = 'n/a'; Ms = 'n/a'; Answers = @() }
    if ($RecordType -notin @('A', 'AAAA', 'PTR')) {
        $result.Status = 'n/a'
        return [pscustomobject]$result
    }
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        if ($RecordType -eq 'PTR') {
            $task = [System.Net.Dns]::GetHostEntryAsync([System.Net.IPAddress]::Parse($LookupName))
        }
        else {
            $task = [System.Net.Dns]::GetHostAddressesAsync($LookupName)
        }
        if (-not $task.Wait($TimeoutSeconds * 1000)) {
            $result.Status = 'TIMEOUT'
        }
        elseif ($RecordType -eq 'PTR') {
            $result.Answers = @('{0}.' -f $task.Result.HostName)
        }
        else {
            $family = [System.Net.Sockets.AddressFamily]::InterNetwork
            if ($RecordType -eq 'AAAA') { $family = [System.Net.Sockets.AddressFamily]::InterNetworkV6 }
            $result.Answers = @($task.Result | Where-Object { $_.AddressFamily -eq $family } |
                    ForEach-Object { $_.IPAddressToString } | Sort-Object -Unique)
            if ($result.Answers.Count -eq 0) { $result.Status = 'NOTFOUND' }
        }
    }
    catch {
        $result.Status = 'NOTFOUND'
        $inner = $_.Exception.GetBaseException()
        if ($inner -is [System.Net.Sockets.SocketException] -and
            $inner.SocketErrorCode -eq [System.Net.Sockets.SocketError]::TryAgain) {
            $result.Status = 'SERVFAIL'
        }
    }
    $timer.Stop()
    $result.Ms = [int]$timer.ElapsedMilliseconds
    return [pscustomobject]$result
}

function Invoke-Lookup {
    param([string]$DnsServer, [string]$LookupName, [string]$RecordType)
    if ($haveResolveDnsName) {
        return Invoke-WindowsLookup -DnsServer $DnsServer -LookupName $LookupName -RecordType $RecordType
    }
    if ($DnsServer -eq 'System') {
        return Invoke-DotNetLookup -LookupName $LookupName -RecordType $RecordType
    }
    # No per-server DNS client in .NET: report the lookup as not available.
    return [pscustomobject]@{ Status = 'n/a'; TTL = 'n/a'; Ms = 'n/a'; Answers = @() }
}

# ---------- resolvers and names ----------
if (-not $PSBoundParameters.ContainsKey('Server')) {
    $Server = @('System')
    if ($haveResolveDnsName -and (Get-Command -Name Get-DnsClientServerAddress -ErrorAction SilentlyContinue)) {
        try {
            # fec0:0:0:ffff::1-3 are the built-in "unconfigured" IPv6 defaults, not real servers.
            $configured = @(Get-DnsClientServerAddress -ErrorAction Stop |
                    ForEach-Object { $_.ServerAddresses } |
                    Where-Object { $_ -and $_ -notlike 'fec0:0:0:ffff::*' } | Select-Object -Unique)
            $Server += $configured
        }
        catch {
            Write-Verbose "Get-DnsClientServerAddress failed: $($_.Exception.Message)"
        }
    }
}
$Server = @($Server | Select-Object -Unique)

$computerName = $(if ($runningOnWindows) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() })
$checks = @()
if ($PSBoundParameters.ContainsKey('Name')) {
    if (@($Name).Count -gt 50) {
        Write-Error 'At most 50 names can be checked in one run.' -ErrorAction Continue
        exit 1
    }
    foreach ($n in $Name) { $checks += [pscustomobject]@{ Name = $n.TrimEnd('.'); Scope = 'All' } }
}
else {
    $checks += [pscustomobject]@{ Name = 'example.com'; Scope = 'All' }
    if ($computerName) { $checks += [pscustomobject]@{ Name = $computerName; Scope = 'System' } }
}

# ---------- lookups ----------
$results = @()
$consistency = @()
$problems = @()

foreach ($check in $checks) {
    $systemTried = $false
    $systemFound = $false
    foreach ($recordType in $Type) {
        $signatures = [ordered]@{}
        foreach ($dnsServer in $Server) {
            if ($check.Scope -eq 'System' -and $dnsServer -ne 'System') { continue }
            $r = Invoke-Lookup -DnsServer $dnsServer -LookupName $check.Name -RecordType $recordType
            $answerText = $(if (@($r.Answers).Count -gt 0) { @($r.Answers) -join ' ' } else { '-' })
            $results += [pscustomobject]@{
                Name    = $check.Name
                Type    = $recordType
                Server  = $dnsServer
                Status  = $r.Status
                TTL     = $r.TTL
                Ms      = $r.Ms
                Answers = $answerText
            }
            if ($failureStatus -contains $r.Status) {
                $problems += ('LOOKUP    {0} {1} via {2}: {3}' -f $check.Name, $recordType, $dnsServer, $r.Status)
            }
            if ($dnsServer -eq 'System' -and $r.Status -ne 'n/a') {
                $systemTried = $true
                if ($r.Status -eq 'OK') { $systemFound = $true }
            }
            # Compare answers; failed lookups are already problems. The system resolver takes
            # part only for A records (it may omit AAAA on IPv4-only computers).
            if (($failureStatus -notcontains $r.Status) -and ($r.Status -notin @('n/a', 'NOTFOUND')) -and
                ($dnsServer -ne 'System' -or $recordType -eq 'A')) {
                $signatures[$dnsServer] = $answerText
            }
        }
        if ($signatures.Count -gt 1) {
            $distinct = @($signatures.Values | Sort-Object -Unique)
            if ($distinct.Count -gt 1) {
                $detail = (@($signatures.Keys | ForEach-Object { '{0}={1}' -f $_, $signatures[$_] })) -join '; '
                $consistency += [pscustomobject]@{ Name = $check.Name; Type = $recordType; Result = 'DIFFER'; Detail = $detail }
                $problems += ('DIFFER    {0} {1}: resolvers return different answers ({2})' -f $check.Name, $recordType, $detail)
            }
            else {
                $consistency += [pscustomobject]@{
                    Name = $check.Name; Type = $recordType; Result = 'SAME'; Detail = ('{0} resolvers agree' -f $signatures.Count)
                }
            }
        }
    }
    if ($systemTried -and -not $systemFound) {
        $problems += ('LOOKUP    {0}: the system resolver found no address' -f $check.Name)
    }
}

# ---------- reverse checks ----------
$reverseRows = @()
if ($Reverse) {
    $reverseServer = 'System'
    if ($haveResolveDnsName) {
        $firstDns = @($Server | Where-Object { $_ -ne 'System' } | Select-Object -First 1)
        if ($firstDns.Count -gt 0) { $reverseServer = $firstDns[0] }
    }
    $addresses = @($results | Where-Object { $_.Type -in @('A', 'AAAA') -and $_.Answers -ne '-' } |
            ForEach-Object { $_.Answers -split ' ' } | Select-Object -Unique)
    foreach ($address in $addresses) {
        $ptr = Invoke-Lookup -DnsServer $reverseServer -LookupName $address -RecordType 'PTR'
        $ptrName = '-'
        $confirmed = 'n/a'
        if ($ptr.Status -eq 'OK' -and @($ptr.Answers).Count -gt 0) {
            $ptrName = @($ptr.Answers)[0]
            $forwardType = $(if ($address -like '*:*') { 'AAAA' } else { 'A' })
            $forward = Invoke-Lookup -DnsServer $reverseServer -LookupName $ptrName.TrimEnd('.') -RecordType $forwardType
            $confirmed = $(if (@($forward.Answers) -contains $address) { 'yes' } else { 'NO' })
            if ($confirmed -eq 'NO') { $problems += ('PTR       {0} -> {1} does not resolve back to {0}' -f $address, $ptrName) }
        }
        elseif ($ptr.Status -ne 'n/a') {
            $problems += ('PTR       {0} has no PTR record ({1} via {2})' -f $address, $ptr.Status, $reverseServer)
        }
        $reverseRows += [pscustomobject]@{
            Address = $address; Ptr = $ptrName; Status = $ptr.Status; Confirmed = $confirmed; Via = $reverseServer
        }
    }
}

$status = $(if ($problems.Count -eq 0) { 'OK' } else { 'PROBLEMS FOUND' })
$lookupMethod = $(if ($haveResolveDnsName) { 'Resolve-DnsName (DnsClient module)' } else { 'System.Net.Dns (system resolver only)' })
$summary = [ordered]@{
    'Report time (UTC)' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    'Computer name'     = $computerName
    'Lookup method'     = $lookupMethod
    'Resolvers'         = ($Server -join ' ')
    'Record types'      = ($Type -join ' ')
    'Reverse check'     = $(if ($Reverse) { 'yes' } else { 'no' })
    'Status'            = $status
    'PowerShell'        = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
}

# ---------- rendering ----------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
            ' DNS Check Report',
            '==============================================')
        foreach ($key in $summary.Keys) { $lines += ('{0,-20} : {1}' -f $key, $summary[$key]) }
        $lines += '', '--- Lookups ---'
        $lines += '{0,-28} {1,-5} {2,-16} {3,-10} {4,6} {5,6}  {6}' -f 'NAME', 'TYPE', 'SERVER', 'STATUS', 'TTL', 'MS', 'ANSWERS'
        foreach ($row in $results) {
            $lines += '{0,-28} {1,-5} {2,-16} {3,-10} {4,6} {5,6}  {6}' -f $row.Name, $row.Type, $row.Server, $row.Status,
            $row.TTL, $row.Ms, $row.Answers
        }
        if ($consistency.Count -gt 0) {
            $lines += '', '--- Resolver consistency ---'
            foreach ($c in $consistency) { $lines += '{0,-7} {1,-28} {2,-5} {3}' -f $c.Result, $c.Name, $c.Type, $c.Detail }
        }
        if ($Reverse) {
            $lines += '', '--- Reverse (PTR) check ---'
            $lines += '{0,-40} {1,-34} {2,-10} {3,-9} {4}' -f 'ADDRESS', 'PTR', 'STATUS', 'CONFIRMED', 'VIA'
            if ($reverseRows.Count -eq 0) { $lines += 'No addresses were found to check.' }
            foreach ($p in $reverseRows) {
                $lines += '{0,-40} {1,-34} {2,-10} {3,-9} {4}' -f $p.Address, $p.Ptr, $p.Status, $p.Confirmed, $p.Via
            }
        }
        $lines += '', '--- Problems ---'
        if ($problems.Count -eq 0) { $lines += 'None.' } else { $lines += $problems }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $csvRows = @($results | Select-Object @{ n = 'Section'; e = { 'lookup' } }, Name, Type, Server, Status, TTL, Ms, Answers)
        $csvRows += @($consistency | Select-Object @{ n = 'Section'; e = { 'consistency' } }, Name, Type,
            @{ n = 'Server'; e = { $null } }, @{ n = 'Status'; e = { $_.Result } }, @{ n = 'TTL'; e = { $null } },
            @{ n = 'Ms'; e = { $null } }, @{ n = 'Answers'; e = { $_.Detail } })
        $csvRows += @($reverseRows | Select-Object @{ n = 'Section'; e = { 'reverse' } }, @{ n = 'Name'; e = { $_.Address } },
            @{ n = 'Type'; e = { 'PTR' } }, @{ n = 'Server'; e = { $_.Via } }, Status, @{ n = 'TTL'; e = { $null } },
            @{ n = 'Ms'; e = { $null } }, @{ n = 'Answers'; e = { '{0} confirmed={1}' -f $_.Ptr, $_.Confirmed } })
        $output = ($csvRows | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]@{
            Summary     = [pscustomobject]$summary
            Lookups     = $results
            Consistency = $consistency
            Reverse     = $reverseRows
            Problems    = $problems
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
        $file = Join-Path $OutputPath ('DNS-Check-{0}-{1}.{2}' -f $safeName, $stamp, $extension)
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
