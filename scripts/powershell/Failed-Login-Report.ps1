<#
.SYNOPSIS
    Read-only authentication report for the last N hours: failed logons by source address,
    account, failure reason and logon type, account lockouts, successful logons, and
    "success after failure".

.DESCRIPTION
    On Windows the script reads the Security log with Get-WinEvent -FilterHashtable for
    event IDs 4625 (an account failed to log on), 4624 (an account was successfully logged
    on) and 4740 (a user account was locked out) since -Hours ago, reads each event's
    EventData by name (ToXml()), and reports:

      - failed logons grouped by source address (IpAddress), target account
        (TargetUserName), failure reason (SubStatus, or Status when SubStatus is 0x0, with
        its meaning) and logon type,
      - account lockouts (4740) and successful logons by logon type,
      - source addresses with -Threshold or more failures,
      - "success after failure": a network (type 3) or Remote Desktop (type 10) logon from
        an address that failed earlier in the window. It may be a user who mistyped a
        password, or a guessed password: always investigate.

    With -LogFile (any OS), or in PowerShell 7 on Linux, a Linux auth-log-format text file
    (plain or .gz; default /var/log/auth.log, else /var/log/secure) is parsed instead: sshd
    "Failed ... for", "Invalid user", "Accepted ... for", sudo "incorrect password attempts"
    and "NOT in sudoers", and su "FAILED SU" lines.

    The script only READS logs. It never blocks addresses, unlocks or changes accounts, or
    clears logs.

    Course : Linux & PowerShell Professional Mastery (Day 17)
    Target : Windows 11 / Windows Server with Windows PowerShell 5.1 or PowerShell 7.x
             (also runs in PowerShell 7 on Linux with a readable auth log)
    Needs  : The Security log can be read only from an elevated (Administrator) session;
             otherwise it is reported as n/a. On Linux, /var/log/auth.log is readable by root
             and the 'adm' group.

.PARAMETER Hours
    Time window in hours (default 24, 0-8760). 0 = the whole log or file.

.PARAMETER Threshold
    Failed logons from one source address that count as an attack (default 10).

.PARAMETER Top
    Number of entries in the "top" lists (default 10, 1-100).

.PARAMETER Format
    Output format: Text (default), Csv or Json.

.PARAMETER OutputPath
    Optional folder. When given, the report is also saved as
    Failed-Login-Report-<COMPUTER>-<UTC timestamp>.<txt|csv|json>.

.PARAMETER LogFile
    Analyse a Linux auth-log-format text file (plain or .gz) instead of the Security log.

.EXAMPLE
    .\Failed-Login-Report.ps1

.EXAMPLE
    .\Failed-Login-Report.ps1 -Hours 2 -Threshold 5 -Top 5

.EXAMPLE
    .\Failed-Login-Report.ps1 -LogFile $HOME\lab17\logs\auth.log -Hours 0 -Format Csv -OutputPath $HOME\lab17\reports

.NOTES
    Exit codes: 0 OK (also when no log could be read: reported as n/a), 1 invalid arguments,
    2 output file problem, 3 alert: an address reached -Threshold failures, or a success
    after failure was found.
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 8760)]
    [int]$Hours = 24,

    [ValidateRange(1, 100000)]
    [int]$Threshold = 10,

    [ValidateRange(1, 100)]
    [int]$Top = 10,

    [ValidateSet('Text', 'Csv', 'Json')]
    [string]$Format = 'Text',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSBoundParameters.ContainsKey('LogFile') -and -not (Test-Path -LiteralPath $LogFile -PathType Leaf)) {
    Write-Error "-LogFile '$LogFile' is not an existing file." -ErrorAction Continue
    exit 1
}

# $IsWindows exists only in PowerShell 6+; Windows PowerShell 5.1 always runs on Windows.
$runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
$startTime = $null
if ($Hours -gt 0) { $startTime = (Get-Date).AddHours(-$Hours) }
$maxEvents = 50000
$computerName = [Environment]::MachineName
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

# Status / SubStatus codes of event 4625 (NTSTATUS values; lower-case keys).
$reasonText = @{
    '0xc000006d' = 'bad user name or password (generic)'
    '0xc000006a' = 'wrong password'
    '0xc0000064' = 'user name does not exist'
    '0xc0000234' = 'account locked out'
    '0xc0000072' = 'account disabled'
    '0xc000006f' = 'outside allowed logon hours'
    '0xc0000070' = 'workstation not allowed'
    '0xc0000071' = 'password expired'
    '0xc0000193' = 'account expired'
    '0xc0000224' = 'password must be changed'
    '0xc000015b' = 'logon type not granted'
    '0xc0000133' = 'clock skew between client and DC'
    '0xc0000413' = 'authentication firewall (not allowed to authenticate)'
}
$logonTypeText = @{
    '2' = 'Interactive'; '3' = 'Network'; '4' = 'Batch'; '5' = 'Service'; '7' = 'Unlock'
    '8' = 'NetworkCleartext'; '9' = 'NewCredentials'; '10' = 'RemoteInteractive (RDP)'
    '11' = 'CachedInteractive'
}

# Every source becomes records: Time (DateTime), Kind (Fail|Success|Lockout|SudoFail|
# SudoNotInSudoers|SuFail), Account, Address, Reason, LogonType.
$records = New-Object System.Collections.Generic.List[object]
$sourceText = 'n/a'
$sourceStatus = 'not read'
$truncated = $false

function ConvertTo-AuthRecord {
    param([datetime]$Time, [string]$Kind, [string]$Account, [string]$Address, [string]$Reason, [string]$LogonType)
    [pscustomobject]@{
        Time = $Time; Kind = $Kind; Account = $Account; Address = $Address
        Reason = $Reason; LogonType = $LogonType
    }
}

function Get-EventDataTable {
    <# Returns EventData as a hashtable Name -> value (works in 5.1 and 7, StrictMode-safe). #>
    param($LogEvent)
    $table = @{}
    try {
        $xml = [xml]$LogEvent.ToXml()
        foreach ($node in $xml.GetElementsByTagName('Data')) {
            $name = $node.GetAttribute('Name')
            if ($name) { $table[$name] = $node.InnerText }
        }
    }
    catch { Write-Verbose "Could not read EventData of record $($LogEvent.RecordId): $($_.Exception.Message)" }
    return $table
}

function Get-Value {
    param([hashtable]$Table, [string]$Name)
    if ($Table.ContainsKey($Name) -and $Table[$Name]) { return [string]$Table[$Name] }
    return '-'
}

function Read-WindowsSecurityLog {
    $filter = @{ LogName = 'Security'; Id = 4625, 4624, 4740 }
    if ($startTime) { $filter['StartTime'] = $startTime }
    $events = @()
    try {
        $events = @(Get-WinEvent -FilterHashtable $filter -MaxEvents $maxEvents -ErrorAction Stop)
        $script:sourceStatus = 'read'
    }
    catch {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
            $script:sourceStatus = 'read (no matching events)'
        }
        elseif ($_.Exception -is [System.UnauthorizedAccessException] -or $_.Exception.Message -match 'unauthori[sz]ed|access is denied') {
            $script:sourceStatus = 'n/a (access denied: run from an elevated session)'
            return
        }
        else {
            $script:sourceStatus = "n/a ($($_.Exception.Message))"
            return
        }
    }
    $script:sourceText = 'Windows Security log (4625, 4624, 4740)'
    if ($events.Count -ge $maxEvents) { $script:truncated = $true }
    foreach ($e in $events) {
        $d = Get-EventDataTable -LogEvent $e
        switch ($e.Id) {
            4625 {
                $code = (Get-Value $d 'SubStatus').ToLowerInvariant()
                if ($code -eq '0x0' -or $code -eq '-') { $code = (Get-Value $d 'Status').ToLowerInvariant() }
                $reason = $code
                if ($reasonText.ContainsKey($code)) { $reason = '{0} {1}' -f $code, $reasonText[$code] }
                $account = Get-Value $d 'TargetUserName'
                $domain = Get-Value $d 'TargetDomainName'
                if ($domain -ne '-' -and $account -ne '-') { $account = '{0}\{1}' -f $domain, $account }
                $records.Add((ConvertTo-AuthRecord -Time $e.TimeCreated -Kind 'Fail' -Account $account `
                            -Address (Get-Value $d 'IpAddress') -Reason $reason -LogonType (Get-Value $d 'LogonType')))
            }
            4624 {
                $account = Get-Value $d 'TargetUserName'
                # Skip computer accounts (NAME$) and built-in service logons: they are noise here.
                if ($account -like '*$' -or $account -in @('SYSTEM', 'LOCAL SERVICE', 'NETWORK SERVICE', 'ANONYMOUS LOGON')) { continue }
                $records.Add((ConvertTo-AuthRecord -Time $e.TimeCreated -Kind 'Success' -Account $account `
                            -Address (Get-Value $d 'IpAddress') -Reason (Get-Value $d 'AuthenticationPackageName') -LogonType (Get-Value $d 'LogonType')))
            }
            4740 {
                $records.Add((ConvertTo-AuthRecord -Time $e.TimeCreated -Kind 'Lockout' -Account (Get-Value $d 'TargetUserName') `
                            -Address (Get-Value $d 'TargetDomainName') -Reason 'locked out' -LogonType '-'))
            }
        }
    }
}

function Read-AuthLogText {
    param([string]$File)
    $lines = @()
    try {
        if ($File -like '*.gz') {
            $stream = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $File).ProviderPath)
            try {
                $gzip = New-Object System.IO.Compression.GZipStream($stream, [System.IO.Compression.CompressionMode]::Decompress)
                $reader = New-Object System.IO.StreamReader($gzip)
                $lines = $reader.ReadToEnd() -split "`r?`n"
                $reader.Dispose()
            }
            finally { $stream.Dispose() }
        }
        else {
            $lines = @(Get-Content -LiteralPath $File)
        }
        $script:sourceStatus = 'read'
    }
    catch {
        $script:sourceStatus = "n/a ($($_.Exception.Message))"
        return
    }
    $script:sourceText = $File
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $now = Get-Date
    $rxIso = '^(?<ts>\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:?\d\d)?)\s+\S+\s+(?<prog>[^\s\[:]+)(?:\[\d+\])?:\s+(?<msg>.*)$'
    $rxClassic = '^(?<ts>[A-Z][a-z]{2}\s+\d{1,2}\s+\d\d:\d\d:\d\d)\s+\S+\s+(?<prog>[^\s\[:]+)(?:\[\d+\])?:\s+(?<msg>.*)$'
    $invalidPending = @{}
    foreach ($line in $lines) {
        $time = $null
        if ($line -match $rxIso) {
            $ts = $Matches['ts'] -replace '([+-]\d\d)(\d\d)$', '$1:$2'
            try { $time = ([datetimeoffset]::Parse($ts, $culture)).LocalDateTime } catch { continue }
        }
        elseif ($line -match $rxClassic) {
            $ts = ($Matches['ts'] -replace '\s+', ' ')
            try { $time = [datetime]::ParseExact(('{0} {1}' -f $now.Year, $ts), 'yyyy MMM d HH:mm:ss', $culture) } catch { continue }
            if ($time -gt $now.AddDays(1)) { $time = $time.AddYears(-1) }
        }
        else { continue }
        if ($startTime -and $time -lt $startTime) { continue }
        $prog = $Matches['prog']; $msg = $Matches['msg']
        if ($prog -like 'sshd*') {
            if ($msg -match '^Failed (?<m>\S+) for (?<inv>invalid user )?(?<u>.*?) from (?<ip>\S+) port (?<port>\d+)') {
                $user = $Matches['u']; if ($Matches['inv']) { $user = "$user (invalid)" }
                $key = '{0}:{1}' -f $Matches['ip'], $Matches['port']
                if ($invalidPending.ContainsKey($key)) { $invalidPending.Remove($key) }
                $records.Add((ConvertTo-AuthRecord -Time $time -Kind 'Fail' -Account $user -Address $Matches['ip'] -Reason "ssh $($Matches['m'])" -LogonType 'ssh'))
            }
            elseif ($msg -match '^Invalid user (?<u>.*?) ?from (?<ip>\S+) port (?<port>\d+)') {
                $user = $Matches['u']; if (-not $user) { $user = '(empty)' }
                $key = '{0}:{1}' -f $Matches['ip'], $Matches['port']
                $invalidPending[$key] = ConvertTo-AuthRecord -Time $time -Kind 'Fail' -Account "$user (invalid)" -Address $Matches['ip'] -Reason 'ssh invalid user' -LogonType 'ssh'
            }
            elseif ($msg -match '^Accepted (?<m>\S+) for (?<u>.*?) from (?<ip>\S+) port') {
                $records.Add((ConvertTo-AuthRecord -Time $time -Kind 'Success' -Account $Matches['u'] -Address $Matches['ip'] -Reason $Matches['m'] -LogonType 'ssh'))
            }
        }
        elseif ($prog -eq 'sudo') {
            $who = ($msg -split ' : ')[0].Trim()
            if ($msg -match 'incorrect password attempt') {
                $records.Add((ConvertTo-AuthRecord -Time $time -Kind 'SudoFail' -Account $who -Address '-' -Reason 'sudo incorrect password' -LogonType 'sudo'))
            }
            elseif ($msg -match 'NOT in sudoers') {
                $records.Add((ConvertTo-AuthRecord -Time $time -Kind 'SudoNotInSudoers' -Account $who -Address '-' -Reason 'sudo user NOT in sudoers' -LogonType 'sudo'))
            }
        }
        elseif ($prog -eq 'su' -and $msg -match '^FAILED SU') {
            $records.Add((ConvertTo-AuthRecord -Time $time -Kind 'SuFail' -Account '-' -Address '-' -Reason $msg -LogonType 'su'))
        }
    }
    # "Invalid user" lines with no "Failed" line for the same address and port (key-only servers).
    foreach ($r in $invalidPending.Values) { $records.Add($r) }
}

# ---------------- collect ----------------
if ($PSBoundParameters.ContainsKey('LogFile')) {
    Read-AuthLogText -File $LogFile
}
elseif ($runningOnWindows) {
    Read-WindowsSecurityLog
}
else {
    $candidate = @('/var/log/auth.log', '/var/log/secure') | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ($candidate) { Read-AuthLogText -File $candidate }
    else { $sourceStatus = 'n/a (no /var/log/auth.log or /var/log/secure)' }
}

# ---------------- analyse ----------------
$sorted = @($records | Sort-Object Time)
$fails = @($sorted | Where-Object { $_.Kind -eq 'Fail' })
$successes = @($sorted | Where-Object { $_.Kind -eq 'Success' })
$lockouts = @($sorted | Where-Object { $_.Kind -eq 'Lockout' })
$sudoFails = @($sorted | Where-Object { $_.Kind -eq 'SudoFail' })
$sudoNotInSudoers = @($sorted | Where-Object { $_.Kind -eq 'SudoNotInSudoers' })
$suFails = @($sorted | Where-Object { $_.Kind -eq 'SuFail' })

$byAddress = @($fails | Group-Object Address | ForEach-Object {
        [pscustomobject]@{
            Address  = $_.Name
            Failures = $_.Count
            Accounts = @($_.Group | Select-Object -ExpandProperty Account -Unique).Count
            First    = ($_.Group | Select-Object -First 1).Time.ToString('yyyy-MM-dd HH:mm:ss')
            Last     = ($_.Group | Select-Object -Last 1).Time.ToString('yyyy-MM-dd HH:mm:ss')
        }
    } | Sort-Object @{ Expression = 'Failures'; Descending = $true }, Address)
$byAccount = @($fails | Group-Object Account | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        Select-Object -First $Top @{ n = 'Account'; e = { $_.Name } }, Count)
$byReason = @($fails | Group-Object Reason | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        Select-Object @{ n = 'Reason'; e = { $_.Name } }, Count)
$byFailType = @($fails | Group-Object LogonType | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        Select-Object @{ n = 'LogonType'; e = { if ($logonTypeText.ContainsKey($_.Name)) { '{0} {1}' -f $_.Name, $logonTypeText[$_.Name] } else { $_.Name } } }, Count)
$bySuccessType = @($successes | Group-Object LogonType | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        Select-Object @{ n = 'LogonType'; e = { if ($logonTypeText.ContainsKey($_.Name)) { '{0} {1}' -f $_.Name, $logonTypeText[$_.Name] } else { $_.Name } } }, Count)
$overThreshold = @($byAddress | Where-Object { $_.Failures -ge $Threshold -and $_.Address -ne '-' })

# Success after failure: a remote success from an address that failed earlier in the window.
$firstFail = @{}
foreach ($f in $fails) { if ($f.Address -ne '-' -and -not $firstFail.ContainsKey($f.Address)) { $firstFail[$f.Address] = $f.Time } }
$failCount = @{}
foreach ($a in $byAddress) { $failCount[$a.Address] = $a.Failures }
$successAfterFailure = @($successes | Where-Object {
        $_.Address -ne '-' -and $firstFail.ContainsKey($_.Address) -and $_.Time -ge $firstFail[$_.Address] -and
        ($_.LogonType -in @('3', '10', 'ssh'))
    } | ForEach-Object {
        [pscustomobject]@{
            Time              = $_.Time.ToString('yyyy-MM-dd HH:mm:ss')
            Address           = $_.Address
            Account           = $_.Account
            LogonType         = $_.LogonType
            Method            = $_.Reason
            FailuresByAddress = $failCount[$_.Address]
        }
    })

$status = 'OK'
if ($sourceText -eq 'n/a') { $status = "n/a (no readable authentication log)" }
elseif ($overThreshold.Count -gt 0 -or $successAfterFailure.Count -gt 0) { $status = 'ALERT' }

$summary = [ordered]@{
    'Report time (UTC)'         = $timestamp
    'Computer'                  = $computerName
    'PowerShell'                = ('{0} {1}' -f $PSVersionTable.PSEdition, $PSVersionTable.PSVersion)
    'Source'                    = $sourceText
    'Source status'             = $sourceStatus
    'Window'                    = $(if ($startTime) { 'last {0} h (since {1:yyyy-MM-dd HH:mm:ss} local time)' -f $Hours, $startTime } else { 'all entries' })
    'Failed logons'             = $fails.Count
    'Successful logons'         = $successes.Count
    'Account lockouts (4740)'   = $lockouts.Count
    'sudo incorrect password'   = $sudoFails.Count
    'sudo NOT in sudoers'       = $sudoNotInSudoers.Count
    'su failures'               = $suFails.Count
    'Distinct failing addresses' = $byAddress.Count
    'Addresses over threshold'  = ('{0} (threshold {1})' -f $overThreshold.Count, $Threshold)
    'Success after failure'     = $successAfterFailure.Count
    'Truncated'                 = $(if ($truncated) { "yes (first $maxEvents events only)" } else { 'no' })
    'Status'                    = $status
}
if ($sourceText -eq 'n/a') {
    foreach ($k in @('Failed logons', 'Successful logons', 'Account lockouts (4740)', 'sudo incorrect password', 'sudo NOT in sudoers', 'su failures', 'Distinct failing addresses', 'Success after failure')) { $summary[$k] = 'n/a' }
}

# ---------------- rendering ----------------
switch ($Format) {
    'Text' {
        $lines = @('==============================================',
            ' Failed Login Report',
            '==============================================')
        foreach ($key in $summary.Keys) { $lines += ('{0,-27} : {1}' -f $key, $summary[$key]) }
        $lines += '', "--- Top $Top source addresses of failed logons ---"
        if ($byAddress.Count -eq 0) { $lines += '(none)' }
        else {
            $lines += ('{0,7}  {1,8}  {2,-39}  {3,-19}  {4}' -f 'fails', 'accounts', 'address', 'first', 'last')
            foreach ($a in ($byAddress | Select-Object -First $Top)) { $lines += ('{0,7}  {1,8}  {2,-39}  {3,-19}  {4}' -f $a.Failures, $a.Accounts, $a.Address, $a.First, $a.Last) }
        }
        $lines += '', "--- Top $Top targeted accounts ---"
        if ($byAccount.Count -eq 0) { $lines += '(none)' }
        foreach ($u in $byAccount) { $lines += ('{0,7}  {1}' -f $u.Count, $u.Account) }
        $lines += '', '--- Failure reasons ---'
        if ($byReason.Count -eq 0) { $lines += '(none)' }
        foreach ($r in $byReason) { $lines += ('{0,7}  {1}' -f $r.Count, $r.Reason) }
        $lines += '', '--- Failed logons by logon type ---'
        if ($byFailType.Count -eq 0) { $lines += '(none)' }
        foreach ($t in $byFailType) { $lines += ('{0,7}  {1}' -f $t.Count, $t.LogonType) }
        $lines += '', '--- Successful logons by logon type ---'
        if ($bySuccessType.Count -eq 0) { $lines += '(none)' }
        foreach ($t in $bySuccessType) { $lines += ('{0,7}  {1}' -f $t.Count, $t.LogonType) }
        $lines += '', '--- Account lockouts ---'
        if ($lockouts.Count -eq 0) { $lines += '(none)' }
        foreach ($l in $lockouts) { $lines += ('{0:yyyy-MM-dd HH:mm:ss}  {1}  (caller: {2})' -f $l.Time, $l.Account, $l.Address) }
        $lines += '', "--- Addresses with $Threshold or more failed logons ---"
        if ($overThreshold.Count -eq 0) { $lines += '(none)' }
        foreach ($o in $overThreshold) { $lines += ('{0,7}  {1}  ({2} accounts)' -f $o.Failures, $o.Address, $o.Accounts) }
        $lines += '', '--- Success after failure (investigate!) ---'
        if ($successAfterFailure.Count -eq 0) { $lines += '(none)' }
        foreach ($s in $successAfterFailure) {
            $lines += ('{0}  {1}  user={2}  type={3}  method={4}  failures_from_address={5}' -f $s.Time, $s.Address, $s.Account, $s.LogonType, $s.Method, $s.FailuresByAddress)
        }
        $output = $lines -join [Environment]::NewLine
        $extension = 'txt'
    }
    'Csv' {
        $rows = New-Object System.Collections.Generic.List[object]
        foreach ($key in @('Failed logons', 'Successful logons', 'Account lockouts (4740)', 'sudo incorrect password', 'sudo NOT in sudoers', 'su failures', 'Distinct failing addresses', 'Success after failure')) {
            $rows.Add([pscustomobject]@{ Section = 'summary'; Item = $key; Count = $summary[$key] })
        }
        $rows.Add([pscustomobject]@{ Section = 'summary'; Item = 'threshold'; Count = $Threshold })
        $rows.Add([pscustomobject]@{ Section = 'summary'; Item = "source: $sourceText"; Count = $sourceStatus })
        foreach ($a in ($byAddress | Select-Object -First $Top)) { $rows.Add([pscustomobject]@{ Section = 'source_address'; Item = ('{0} ({1} accounts)' -f $a.Address, $a.Accounts); Count = $a.Failures }) }
        foreach ($u in $byAccount) { $rows.Add([pscustomobject]@{ Section = 'account'; Item = $u.Account; Count = $u.Count }) }
        foreach ($r in $byReason) { $rows.Add([pscustomobject]@{ Section = 'reason'; Item = $r.Reason; Count = $r.Count }) }
        foreach ($t in $byFailType) { $rows.Add([pscustomobject]@{ Section = 'failed_logon_type'; Item = $t.LogonType; Count = $t.Count }) }
        foreach ($t in $bySuccessType) { $rows.Add([pscustomobject]@{ Section = 'success_logon_type'; Item = $t.LogonType; Count = $t.Count }) }
        foreach ($s in $successAfterFailure) { $rows.Add([pscustomobject]@{ Section = 'success_after_failure'; Item = ('{0} {1} user={2}' -f $s.Time, $s.Address, $s.Account); Count = $s.FailuresByAddress }) }
        $output = ($rows | Select-Object @{ n = 'TimestampUtc'; e = { $timestamp } }, @{ n = 'Computer'; e = { $computerName } }, Section, Item, Count |
                ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        $extension = 'csv'
    }
    'Json' {
        $output = [pscustomobject]@{
            Summary             = [pscustomobject]$summary
            TopAddresses        = @($byAddress | Select-Object -First $Top)
            TopAccounts         = $byAccount
            Reasons             = $byReason
            FailedByLogonType   = $byFailType
            SuccessByLogonType  = $bySuccessType
            Lockouts            = @($lockouts | Select-Object @{ n = 'Time'; e = { $_.Time.ToString('yyyy-MM-dd HH:mm:ss') } }, Account, @{ n = 'Caller'; e = { $_.Address } })
            OverThreshold       = $overThreshold
            SuccessAfterFailure = $successAfterFailure
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
        $file = Join-Path $OutputPath ('Failed-Login-Report-{0}-{1}.{2}' -f $safeName, $stamp, $extension)
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
