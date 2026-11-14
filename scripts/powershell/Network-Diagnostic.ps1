<#
.SYNOPSIS
    Read-only, layered network diagnosis of one network adapter: link, addresses,
    counters, default route, gateway, DNS and an optional TCP port test.

.DESCRIPTION
    Runs the checks of a bottom-up troubleshooting method and reports one line per check
    with the status OK, WARN, FAIL or n/a:

      link-state, carrier   adapter status, admin status and media connection state
      mtu-mac, speed-duplex MTU, MAC address, link speed and duplex
      addresses             IPv4 / global IPv6 addresses (169.254.x.x alone = FAIL)
      counters              receive/send errors and discards against -MaxErrors
      default-route         IPv4 default route and the interface it uses
      gateway-neighbour     ARP state of the gateway (Windows only; n/a elsewhere)
      gateway-ping          two ICMP echo requests to the gateway
      dns-config, dns-lookup DNS servers of the adapter and an optional name lookup
      tcp-connect           optional TCP connection to -Target on -Port

    When at least one check FAILS the script exits with code 3, so it can be used by
    Task Scheduler, cron or a monitoring agent. The script only READS configuration and
    sends at most two pings, one DNS query and one TCP connection attempt; it never
    changes adapters, addresses, routes or firewall rules.

    Course : Linux & PowerShell Professional Mastery (Day 15)
    Target : Windows 11 with Windows PowerShell 5.1 or PowerShell 7.x
             (also runs in PowerShell 7 on Linux and macOS with fewer details)
    Needs  : No administrator rights. On Windows the NetAdapter, NetTCPIP and DnsClient
             modules are used (Get-NetAdapter, Get-NetAdapterStatistics, Get-NetIPAddress,
             Get-NetRoute, Get-NetNeighbor, Get-DnsClientServerAddress). Elsewhere, or when
             those cmdlets are missing, the .NET class
             System.Net.NetworkInformation.NetworkInterface is used and the neighbour (ARP)
             state is reported as n/a. Ping, DNS lookup and TCP test use .NET on every OS.

.PARAMETER InterfaceAlias
    Adapter to check (Windows: the InterfaceAlias / Name shown by Get-NetAdapter;
    Linux/macOS: the interface name). Default: the adapter of the IPv4 default route with
    the lowest metric; if there is none, the first adapter that is Up.

.PARAMETER Target
    Optional host name or IP address for a TCP connection test.

.PARAMETER Port
    TCP port for -Target (default 443).

.PARAMETER DnsName
    Optional name to resolve with the system resolver (hosts file + DNS).

.PARAMETER MaxErrors
    Maximum errors + discards before the counter check is flagged (default 0). Errors
    above the limit = FAIL; discards alone = WARN, because discards also count harmless
    drops (unknown protocols, filtered frames).

.PARAMETER Format
    Output format: Text (default), Csv or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    Network-Diagnostic-<COMPUTER>-<UTC timestamp>.<txt|csv|json>.

.EXAMPLE
    .\Network-Diagnostic.ps1

.EXAMPLE
    .\Network-Diagnostic.ps1 -InterfaceAlias 'Ethernet' -DnsName www.example.com -Target www.example.com -Port 443

.EXAMPLE
    .\Network-Diagnostic.ps1 -MaxErrors 100 -Format Json -OutputPath $HOME\lpm-lab\reports

.NOTES
    Exit codes: 0 OK (warnings allowed), 1 invalid arguments, 2 output file problem,
    3 at least one check FAILED.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$InterfaceAlias,

    [ValidatePattern('^[A-Za-z0-9._:-]{1,253}$')]
    [string]$Target,

    [ValidateRange(1, 65535)]
    [int]$Port = 443,

    [ValidatePattern('^[A-Za-z0-9._:-]{1,253}$')]
    [string]$DnsName,

    [ValidateRange(0, 2147483647)]
    [int]$MaxErrors = 0,

    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSBoundParameters.ContainsKey('Port') -and -not $PSBoundParameters.ContainsKey('Target')) {
    Write-Error '-Port needs -Target.' -ErrorAction Continue
    exit 1
}

# $IsWindows exists only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
$useCmdlets = $runningOnWindows -and ($null -ne (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue))

$checks = New-Object System.Collections.Generic.List[object]
function Add-Check {
    <# Appends one result row: Check, Status (OK/WARN/FAIL/n/a), Detail. #>
    param([string]$Check, [string]$Status, [string]$Detail)
    $checks.Add([pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail })
}

function Test-GatewayPing {
    <# Two ICMP echo requests with .NET Ping (same behaviour in 5.1 and 7, on every OS). #>
    param([string]$Address)
    $ping = New-Object System.Net.NetworkInformation.Ping
    $times = @()
    try {
        for ($i = 0; $i -lt 2; $i++) {
            $reply = $ping.Send($Address, 1000)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { $times += [double]$reply.RoundtripTime }
        }
    }
    catch {
        return [pscustomobject]@{ Status = 'n/a'; Detail = "ping not possible: $($_.Exception.GetBaseException().Message)" }
    }
    finally {
        $ping.Dispose()
    }
    if ($times.Count -gt 0) {
        $avg = ($times | Measure-Object -Average).Average
        return [pscustomobject]@{ Status = 'OK'; Detail = ('{0} of 2 replies, avg rtt {1:N0} ms' -f $times.Count, $avg) }
    }
    return [pscustomobject]@{ Status = 'FAIL'; Detail = "no reply from $Address" }
}

function Test-TcpPort {
    <# One TCP connection attempt with a 5-second timeout; distinguishes refused, timed out and unreachable. #>
    param([string]$HostName, [int]$TcpPort)
    $client = New-Object System.Net.Sockets.TcpClient
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $async = $client.BeginConnect($HostName, $TcpPort, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(5000)) {
            return [pscustomobject]@{ Status = 'FAIL'; Detail = "${HostName}:$TcpPort timed out after 5 s (filtered by a firewall, or no route)" }
        }
        $client.EndConnect($async)
        return [pscustomobject]@{ Status = 'OK'; Detail = ('{0}:{1} open ({2} ms)' -f $HostName, $TcpPort, $watch.ElapsedMilliseconds) }
    }
    catch {
        $base = $_.Exception.GetBaseException()
        $code = ''
        if ($base -is [System.Net.Sockets.SocketException]) { $code = $base.SocketErrorCode.ToString() }
        switch ($code) {
            'ConnectionRefused' { $text = 'connection refused (host reachable, nothing listening)' }
            'TimedOut' { $text = 'timed out (filtered by a firewall, or no route)' }
            'HostUnreachable' { $text = 'no route to host (host down or wrong address)' }
            'NetworkUnreachable' { $text = 'network unreachable (no route)' }
            'HostNotFound' { $text = 'could not be resolved' }
            default { $text = "failed: $($base.Message)" }
        }
        return [pscustomobject]@{ Status = 'FAIL'; Detail = "${HostName}:$TcpPort $text" }
    }
    finally {
        $client.Close()
    }
}

function Get-AddressCheck {
    <# Evaluates a list of IPv4 and global IPv6 address strings ("addr/prefix"). #>
    param([string[]]$IPv4, [string[]]$IPv6)
    $v4 = @($IPv4 | Where-Object { $_ })
    $v6 = @($IPv6 | Where-Object { $_ })
    if ($v4.Count -eq 0 -and $v6.Count -eq 0) {
        return [pscustomobject]@{ Status = 'FAIL'; Detail = 'no IPv4 and no global IPv6 address (DHCP failed or not configured)' }
    }
    $usable = @($v4 | Where-Object { $_ -notlike '169.254.*' })
    if ($v4.Count -gt 0 -and $usable.Count -eq 0) {
        return [pscustomobject]@{ Status = 'FAIL'; Detail = "only link-local $($v4 -join ' ') (169.254.x.x = APIPA, no DHCP answer)" }
    }
    $v4Text = $(if ($v4.Count -gt 0) { $v4 -join ' ' } else { 'none' })
    $v6Text = $(if ($v6.Count -gt 0) { $v6 -join ' ' } else { 'none' })
    return [pscustomobject]@{ Status = 'OK'; Detail = "IPv4 $v4Text; IPv6 global $v6Text" }
}

function Get-CounterCheck {
    <# Errors above the limit = FAIL; errors + discards above the limit = WARN. #>
    param([long]$RxErrors, [long]$TxErrors, [long]$RxDiscards, [long]$TxDiscards, [int]$Limit)
    $errors = $RxErrors + $TxErrors
    $detail = 'rx_errors {0}, tx_errors {1}, rx_discards {2}, tx_discards {3} (since the adapter started; limit {4})' -f $RxErrors, $TxErrors, $RxDiscards, $TxDiscards, $Limit
    if ($errors -gt $Limit) { return [pscustomobject]@{ Status = 'FAIL'; Detail = $detail } }
    if (($errors + $RxDiscards + $TxDiscards) -gt $Limit) { return [pscustomobject]@{ Status = 'WARN'; Detail = $detail } }
    return [pscustomobject]@{ Status = 'OK'; Detail = $detail }
}

$adapterName = 'n/a'
$adapterSource = '-InterfaceAlias'
$gateway = $null
$defaultAlias = $null

try {
    if ($useCmdlets) {
        # ---------------- Windows: NetAdapter / NetTCPIP / DnsClient cmdlets ----------------
        $route = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Sort-Object -Property RouteMetric | Select-Object -First 1)
        if ($route.Count -gt 0) {
            $gateway = [string]$route[0].NextHop
            $defaultAlias = [string]$route[0].InterfaceAlias
            if ($gateway -eq '0.0.0.0') { $gateway = $null }
        }

        $adapter = $null
        if ($PSBoundParameters.ContainsKey('InterfaceAlias')) {
            $adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue
            if ($null -eq $adapter) {
                Write-Error "Adapter '$InterfaceAlias' not found (see: Get-NetAdapter)." -ErrorAction Continue
                exit 1
            }
        }
        elseif ($route.Count -gt 0) {
            $adapter = Get-NetAdapter -InterfaceIndex $route[0].InterfaceIndex -ErrorAction SilentlyContinue
            $adapterSource = 'default route'
        }
        if ($null -eq $adapter) {
            $adapter = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Sort-Object -Property ifIndex) | Select-Object -First 1
            $adapterSource = 'first Up adapter (no default route)'
        }

        if ($null -eq $adapter) {
            Add-Check 'interface' 'FAIL' 'no default route and no adapter is Up (see: Get-NetAdapter)'
            $adapterSource = 'none found'
        }
        else {
            $adapterName = [string]$adapter.Name
            $ifIndex = [int]$adapter.ifIndex
            $status = [string]$adapter.Status
            $admin = [string]$adapter.AdminStatus
            switch ($status) {
                'Up' { Add-Check 'link-state' 'OK' "admin $admin, status Up" }
                'Disabled' { Add-Check 'link-state' 'FAIL' ("adapter disabled (fix, elevated: Enable-NetAdapter -Name '{0}')" -f $adapterName) }
                default { Add-Check 'link-state' 'FAIL' "admin $admin, status $status (no link: cable, switch port, Wi-Fi or driver)" }
            }
            $media = [string]$adapter.MediaConnectionState
            switch ($media) {
                'Connected' { Add-Check 'carrier' 'OK' 'media connected' }
                'Disconnected' { Add-Check 'carrier' 'FAIL' 'media disconnected (cable unplugged, switch port down, Wi-Fi not associated)' }
                default { Add-Check 'carrier' 'n/a' "media state $media" }
            }
            Add-Check 'mtu-mac' 'OK' ('MTU {0}, MAC {1}' -f $adapter.MtuSize, $adapter.MacAddress)
            if ($status -ne 'Up') {
                Add-Check 'speed-duplex' 'n/a' "not meaningful while the adapter is $status"
            }
            elseif ($adapter.FullDuplex -eq $false) {
                Add-Check 'speed-duplex' 'WARN' "$($adapter.LinkSpeed), half duplex (duplex mismatch? check the switch port)"
            }
            else {
                Add-Check 'speed-duplex' 'OK' "$($adapter.LinkSpeed), full duplex"
            }

            $v4 = @(Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength })
            $v6 = @(Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue |
                    Where-Object { $_.IPAddress -notlike 'fe80*' } | ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength })
            $a = Get-AddressCheck -IPv4 $v4 -IPv6 $v6
            Add-Check 'addresses' $a.Status $a.Detail

            try {
                $s = Get-NetAdapterStatistics -Name $adapterName -ErrorAction Stop
                $c = Get-CounterCheck -RxErrors $s.ReceivedPacketErrors -TxErrors $s.OutboundPacketErrors -RxDiscards $s.ReceivedDiscardedPackets -TxDiscards $s.OutboundDiscardedPackets -Limit $MaxErrors
                Add-Check 'counters' $c.Status $c.Detail
            }
            catch {
                Add-Check 'counters' 'n/a' "statistics not available for this adapter: $($_.Exception.Message)"
            }

            if ($null -eq $defaultAlias) {
                Add-Check 'default-route' 'FAIL' 'no IPv4 default route (only local subnets are reachable)'
            }
            elseif ($defaultAlias -ne $adapterName) {
                Add-Check 'default-route' 'WARN' "default route uses '$defaultAlias', not '$adapterName' (via $gateway)"
            }
            else {
                Add-Check 'default-route' 'OK' "via $gateway on '$defaultAlias'"
            }

            if ($null -ne $gateway) {
                $p = Test-GatewayPing -Address $gateway
                # Read the neighbour entry AFTER the ping, which refreshes it.
                $n = @(Get-NetNeighbor -IPAddress $gateway -ErrorAction SilentlyContinue | Select-Object -First 1)
                if ($n.Count -gt 0) {
                    $state = [string]$n[0].State
                    if ($state -in @('Reachable', 'Stale', 'Delay', 'Probe', 'Permanent')) {
                        Add-Check 'gateway-neighbour' 'OK' ('{0} is {1} (MAC {2})' -f $gateway, $state, $n[0].LinkLayerAddress)
                    }
                    else {
                        Add-Check 'gateway-neighbour' 'FAIL' "$gateway is ${state}: no ARP reply (wrong gateway, VLAN or link problem)"
                    }
                    # A gateway may drop ICMP on purpose: if ARP works, a failed ping is only a warning.
                    if ($p.Status -eq 'FAIL' -and $state -in @('Reachable', 'Stale', 'Delay', 'Probe', 'Permanent')) {
                        $p = [pscustomobject]@{ Status = 'WARN'; Detail = "$($p.Detail) (but ARP works: ICMP may be filtered)" }
                    }
                }
                else {
                    Add-Check 'gateway-neighbour' 'WARN' "no neighbour entry for $gateway"
                }
                Add-Check 'gateway-ping' $p.Status $p.Detail
            }

            $dns = @(Get-DnsClientServerAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.ServerAddresses })
            if ($dns.Count -gt 0) { Add-Check 'dns-config' 'OK' "DNS server(s) on '$adapterName': $($dns -join ' ')" }
            else { Add-Check 'dns-config' 'WARN' "no IPv4 DNS server configured on '$adapterName'" }
        }
    }
    else {
        # ---------------- PowerShell 7 on Linux/macOS (or no NetAdapter module): .NET ----------------
        $all = @([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
                Where-Object { $_.NetworkInterfaceType -ne [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback })
        $nic = $null
        if ($PSBoundParameters.ContainsKey('InterfaceAlias')) {
            $nic = $all | Where-Object { $_.Name -eq $InterfaceAlias } | Select-Object -First 1
            if ($null -eq $nic) {
                Write-Error "Interface '$InterfaceAlias' not found." -ErrorAction Continue
                exit 1
            }
        }
        foreach ($candidate in $all) {
            $gws = @($candidate.GetIPProperties().GatewayAddresses | Where-Object {
                    $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $_.Address.ToString() -ne '0.0.0.0' })
            if ($gws.Count -gt 0 -and $null -eq $defaultAlias) {
                $defaultAlias = $candidate.Name
                $gateway = $gws[0].Address.ToString()
                if ($null -eq $nic) { $nic = $candidate; $adapterSource = 'default route' }
            }
        }
        if ($null -eq $nic) {
            $nic = $all | Where-Object { $_.OperationalStatus -eq [System.Net.NetworkInformation.OperationalStatus]::Up } | Select-Object -First 1
            $adapterSource = 'first Up interface (no default route)'
        }

        if ($null -eq $nic) {
            Add-Check 'interface' 'FAIL' 'no default route and no non-loopback interface is Up'
            $adapterSource = 'none found'
        }
        else {
            $adapterName = $nic.Name
            $oper = $nic.OperationalStatus.ToString()
            if ($oper -eq 'Up') { Add-Check 'link-state' 'OK' 'operational status Up' }
            else { Add-Check 'link-state' 'FAIL' "operational status $oper (no link, or interface down)" }
            Add-Check 'carrier' 'n/a' 'not exposed by .NET (included in the operational status)'

            $props = $nic.GetIPProperties()
            $mtu = 'n/a'
            try { $mtu = [string]$props.GetIPv4Properties().Mtu } catch { Write-Verbose "MTU unavailable: $($_.Exception.Message)" }
            $macBytes = $nic.GetPhysicalAddress().GetAddressBytes()
            $mac = ($macBytes | ForEach-Object { $_.ToString('x2') }) -join ':'
            if (-not $mac) { $mac = 'n/a' }
            Add-Check 'mtu-mac' 'OK' "MTU $mtu, MAC $mac"
            $speed = [long]-1
            try { $speed = [long]$nic.Speed } catch { Write-Verbose "Speed unavailable: $($_.Exception.Message)" }
            if ($oper -ne 'Up') { Add-Check 'speed-duplex' 'n/a' "not meaningful while the interface is $oper" }
            elseif ($speed -gt 0) { Add-Check 'speed-duplex' 'OK' ('{0} Mb/s, duplex n/a' -f [math]::Round($speed / 1000000)) }
            else { Add-Check 'speed-duplex' 'n/a' 'not reported by the driver' }

            $v4 = @()
            $v6 = @()
            foreach ($u in $props.UnicastAddresses) {
                $ip = $u.Address
                if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { $v4 += ('{0}/{1}' -f $ip, $u.PrefixLength) }
                elseif (-not $ip.IsIPv6LinkLocal) { $v6 += ('{0}/{1}' -f $ip, $u.PrefixLength) }
            }
            $a = Get-AddressCheck -IPv4 $v4 -IPv6 $v6
            Add-Check 'addresses' $a.Status $a.Detail

            try {
                $st = $nic.GetIPStatistics()
                $values = @{}
                foreach ($name in 'IncomingPacketsWithErrors', 'OutgoingPacketsWithErrors', 'IncomingPacketsDiscarded', 'OutgoingPacketsDiscarded') {
                    try { $values[$name] = [long]$st.$name } catch { $values[$name] = [long]0 }
                }
                $c = Get-CounterCheck -RxErrors $values['IncomingPacketsWithErrors'] -TxErrors $values['OutgoingPacketsWithErrors'] -RxDiscards $values['IncomingPacketsDiscarded'] -TxDiscards $values['OutgoingPacketsDiscarded'] -Limit $MaxErrors
                Add-Check 'counters' $c.Status $c.Detail
            }
            catch {
                Add-Check 'counters' 'n/a' "statistics not available: $($_.Exception.Message)"
            }

            if ($null -eq $defaultAlias) { Add-Check 'default-route' 'FAIL' 'no IPv4 default gateway (only local subnets are reachable)' }
            elseif ($defaultAlias -ne $adapterName) { Add-Check 'default-route' 'WARN' "default gateway is on '$defaultAlias', not '$adapterName' (via $gateway)" }
            else { Add-Check 'default-route' 'OK' "via $gateway on '$defaultAlias'" }

            if ($null -ne $gateway) {
                Add-Check 'gateway-neighbour' 'n/a' 'ARP state not available in .NET (Linux: ip neigh show)'
                $p = Test-GatewayPing -Address $gateway
                Add-Check 'gateway-ping' $p.Status $p.Detail
            }

            $dns = @($props.DnsAddresses | ForEach-Object { $_.ToString() })
            if ($dns.Count -gt 0) { Add-Check 'dns-config' 'OK' "DNS server(s): $($dns -join ' ')" }
            else { Add-Check 'dns-config' 'WARN' 'no DNS server reported for this interface' }
        }
    }
}
catch {
    Write-Error "Could not read the network configuration: $($_.Exception.Message)" -ErrorAction Continue
    Add-Check 'interface' 'FAIL' "configuration not readable: $($_.Exception.Message)"
}

if ($PSBoundParameters.ContainsKey('DnsName')) {
    try {
        $addresses = @([System.Net.Dns]::GetHostAddresses($DnsName) | ForEach-Object { $_.ToString() } | Sort-Object -Unique | Select-Object -First 4)
        if ($addresses.Count -gt 0) { Add-Check 'dns-lookup' 'OK' "$DnsName -> $($addresses -join ' ')" }
        else { Add-Check 'dns-lookup' 'FAIL' "$DnsName returned no addresses" }
    }
    catch {
        Add-Check 'dns-lookup' 'FAIL' "$DnsName did not resolve: $($_.Exception.GetBaseException().Message) (try: Resolve-DnsName $DnsName)"
    }
}

if ($PSBoundParameters.ContainsKey('Target')) {
    $t = Test-TcpPort -HostName $Target -TcpPort $Port
    Add-Check 'tcp-connect' $t.Status $t.Detail
}

$failCount = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count
$warnCount = @($checks | Where-Object { $_.Status -eq 'WARN' }).Count
$overall = 'OK'
if ($warnCount -gt 0) { $overall = 'WARN' }
if ($failCount -gt 0) { $overall = 'FAIL' }
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$computerName = $(if ($runningOnWindows) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() })
$source = $(if ($useCmdlets) { 'NetAdapter / NetTCPIP / DnsClient cmdlets' } else { '.NET NetworkInformation (no ARP state)' })

$summary = [ordered]@{
    'Report time (UTC)' = $timestamp
    'Computer name'     = $computerName
    'Interface'         = "$adapterName ($adapterSource)"
    'Data source'       = $source
    'Error limit'       = $MaxErrors
    'Status'            = '{0} ({1} failed, {2} warnings)' -f $overall, $failCount, $warnCount
    'PowerShell'        = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition
}

# ---------- rendering ----------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
                   ' Network Diagnostic Report',
                   '==============================================')
        foreach ($key in $summary.Keys) { $lines += ('{0,-20} : {1}' -f $key, $summary[$key]) }
        $lines += '', '--- Checks (bottom-up: link -> IP -> gateway -> DNS -> port) ---'
        $lines += '{0,-18} {1,-5} {2}' -f 'CHECK', 'STATUS', 'DETAIL'
        foreach ($c in $checks) { $lines += ('{0,-18} {1,-5} {2}' -f $c.Check, $c.Status, $c.Detail) }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $output = ($checks | Select-Object @{ n = 'TimestampUtc'; e = { $timestamp } }, @{ n = 'Computer'; e = { $computerName } },
                @{ n = 'Interface'; e = { $adapterName } }, Check, Status, Detail | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]@{
            Summary = [pscustomobject]$summary
            Checks  = $checks.ToArray()
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
        $file = Join-Path $OutputPath ('Network-Diagnostic-{0}-{1}.{2}' -f $safeName, $stamp, $extension)
        $output | Out-File -LiteralPath $file -Encoding utf8
        Write-Information "Report saved to: $file" -InformationAction Continue
    }
    catch {
        Write-Error "Could not write report to '$OutputPath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}

if ($failCount -gt 0) { exit 3 }
exit 0
