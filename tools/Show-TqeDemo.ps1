#Requires -Version 5.1
<#
.SYNOPSIS
One-window desktop panel that starts, stops, and shows the live CoT sender.

.DESCRIPTION
Runs on Windows PowerShell 5.1 with .NET Framework 4.8 in a single STA process.
The panel reads demo-config.json, compiles the sibling TqeCot.cs once on the
first start, and calls TqeDemo.Runner.Replay on a background runspace with a
shared cancellation token, so the window stays responsive. Stop cancels that
token and the runner closes its own socket and certificates.

Every number on screen comes from the JSONL run log written by the runner.
Completed writes are attempted writes minus writes whose delivery is unknown.
A completed write is a send attempt, not delivery. Confirm receipt in WinTAK.

The active WAN path panel is route evidence read from the gateway over a
restricted status login. It is not proof of encryption or post-quantum
protection. A failing or stale probe reads STATUS UNAVAILABLE; the panel never
keeps showing an old path.

Certificate passwords are typed into masked fields, held in process memory for
the run, and cleared when the window closes. Passwords never reach the command
line, a log, or disk. The panel does not display certificate subjects.

.PARAMETER ConfigPath
Path to demo-config.json. Defaults to the sibling of the tools folder.

.PARAMETER RenderPreview
Renders the real window to a PNG file and exits. No run, no CoT, no TLS.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\demo-config.json'),

    [ValidateNotNullOrEmpty()]
    [string]$RenderPreview
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- environment

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-Fatal([string]$message) {
    [Console]::Error.WriteLine('TQE panel: ' + $message)
    try {
        [Windows.Forms.MessageBox]::Show($message, 'TQE Live CoT Sender',
            [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    } catch { }
}

function Test-Environment {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
        $PSVersionTable.PSEdition -ne 'Desktop' -or
        $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -lt 1) {
        return 'Use Windows PowerShell 5.1 with .NET Framework 4.8, not PowerShell Core.'
    }
    if ($Host.Name -eq 'Windows PowerShell ISE Host') {
        return 'Run this panel from Start-TqeDemo.cmd, not PowerShell ISE.'
    }
    $release = [Microsoft.Win32.Registry]::GetValue(
        'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', 0)
    if ([int]$release -lt 528040) {
        return '.NET Framework 4.8 or later is required. This panel does not install it.'
    }
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
        return 'Start this panel with Start-TqeDemo.cmd, or run powershell.exe -STA -File Show-TqeDemo.ps1.'
    }
    return ''
}

$environmentProblem = Test-Environment
if ($environmentProblem) { Show-Fatal $environmentProblem; exit 1 }

# --------------------------------------------------------------- design tokens

$script:Palette = @{
    Chart      = [Drawing.Color]::FromArgb(0xED, 0xF0, 0xF4)
    Plate      = [Drawing.Color]::FromArgb(0xE2, 0xE7, 0xED)
    Rule       = [Drawing.Color]::FromArgb(0xC6, 0xCE, 0xD8)
    Ink        = [Drawing.Color]::FromArgb(0x10, 0x16, 0x1C)
    Graphite   = [Drawing.Color]::FromArgb(0x55, 0x60, 0x6B)
    Signal     = [Drawing.Color]::FromArgb(0x0B, 0x6F, 0xA4)
    SignalDeep = [Drawing.Color]::FromArgb(0x0A, 0x5E, 0x8A)
    Caution    = [Drawing.Color]::FromArgb(0x96, 0x43, 0x0A)
    Halt       = [Drawing.Color]::FromArgb(0x8A, 0x1C, 0x1C)
    Exercise   = [Drawing.Color]::FromArgb(0x5B, 0x2A, 0x86)
    Field      = [Drawing.Color]::FromArgb(0xFA, 0xFB, 0xFC)
}

$script:Brushes = @{}
foreach ($name in @($script:Palette.Keys)) {
    $script:Brushes[$name] = New-Object Drawing.SolidBrush($script:Palette[$name])
}
$script:Brushes['CautionWash'] = New-Object Drawing.SolidBrush(
    [Drawing.Color]::FromArgb(38, $script:Palette.Caution))

$script:FontStacks = @{
    Display = @('Bahnschrift SemiBold Condensed', 'Bahnschrift Condensed', 'Bahnschrift SemiBold',
                'Bahnschrift', 'Franklin Gothic Medium', 'Segoe UI Semibold', 'Segoe UI')
    Body    = @('Bahnschrift', 'Bahnschrift Light', 'Franklin Gothic Book', 'Segoe UI')
    Data    = @('Cascadia Mono', 'Consolas', 'Lucida Console', 'Courier New')
}

# role = stack, base point size, style
$script:FontRoles = @{
    Banner  = @('Display', 16.5, 'Regular')
    Title   = @('Display', 25.0, 'Regular')
    Meta    = @('Body',    13.5, 'Regular')
    Caption = @('Body',    10.5, 'Regular')
    Value   = @('Display', 19.0, 'Regular')
    Hero    = @('Display', 50.0, 'Regular')
    Count   = @('Display', 38.0, 'Regular')
    Address = @('Data',    24.0, 'Bold')
    Note    = @('Body',    11.0, 'Regular')
    Data    = @('Data',    12.5, 'Regular')
    Status  = @('Body',    12.5, 'Regular')
    Button  = @('Display', 15.0, 'Regular')
}

$script:FamilyCache = @{}
function Get-FontFamilyName([string]$stack) {
    if ($script:FamilyCache.ContainsKey($stack)) { return $script:FamilyCache[$stack] }
    $chosen = 'Segoe UI'
    foreach ($candidate in $script:FontStacks[$stack]) {
        $family = $null
        try { $family = New-Object Drawing.FontFamily($candidate) } catch { $family = $null }
        if ($null -ne $family) { $chosen = $candidate; $family.Dispose(); break }
    }
    $script:FamilyCache[$stack] = $chosen
    return $chosen
}

function New-FontSet([double]$scale) {
    $set = @{}
    foreach ($role in @($script:FontRoles.Keys)) {
        $definition = $script:FontRoles[$role]
        $size = [single]([Math]::Round([double]$definition[1] * $scale, 2))
        if ($size -lt 6) { $size = [single]6 }
        $style = [Drawing.FontStyle]$definition[2]
        $family = Get-FontFamilyName $definition[0]
        $font = $null
        try { $font = New-Object Drawing.Font($family, $size, $style) } catch { $font = $null }
        if ($null -eq $font) { $font = New-Object Drawing.Font('Segoe UI', $size) }
        $set[$role] = $font
    }
    return $set
}

# ------------------------------------------------------------------- app state

$script:App = @{
    ConfigPath = $ConfigPath
    Config     = @{}
    Problems   = New-Object Collections.ArrayList
    Redactions = New-Object Collections.ArrayList
    UI         = @{ Scale = 1.0; Fonts = $null; Typed = New-Object Collections.ArrayList
                    Form = $null; Root = $null; Timer = $null; HeroImage = $null; Hero = $null
                    Banner = $null; Source = $null; Link = $null; Age = $null
                    Unknown = $null; Dropped = $null; Started = $null; LogName = $null
                    Tracks = $null; StatusBox = $null; StartButton = $null; StopButton = $null
                    ClientBox = $null; TrustBox = $null; SameBox = $null }
    Log        = @{ Path = ''; Stream = $null; Decoder = $null; Pending = ''; Sync = $false; NextScan = [DateTime]::MinValue }
    View       = $null
    Run        = @{ State = 'idle'; LogPath = ''; Shell = $null; Runspace = $null; Handle = $null
                    Cancellation = $null; Options = $null; StartedUtc = $null; CloseWhenStopped = $false }
    Sender     = @{ Present = $false; Detail = ''; Checked = $false; NextCheck = [DateTime]::MinValue; Pids = '' }
    Status     = @{ Enabled = $false; Reason = ''; Process = $null; StartedAt = [DateTime]::MinValue
                    OutputTask = $null; ErrorTask = $null
                    NextProbe = [DateTime]::MinValue; ObservedAt = [DateTime]::MinValue
                    Active = ''; Name = ''; Interface = ''; SourceIp = ''; Gateway = ''
                    Protected = $null; Failure = ''; SshPath = '' }
    Message    = ''
}

function New-View {
    return @{
        Writes    = New-Object 'Collections.Generic.List[DateTime]'
        Faults    = New-Object 'Collections.Generic.List[DateTime]'
        Tracks    = New-Object Collections.ArrayList
        Attempted = 0L
        Unknown   = 0L
        Dropped   = 0L
        Connection = ''
        LastWrite = $null
        LastRecord = $null
        Started   = $null
        Lines     = 0L
        Unreadable = 0L
    }
}
$script:App.View = New-View

function Get-Prop($object, [string]$name) {
    if ($null -eq $object) { return $null }
    $property = $object.PSObject.Properties[$name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Add-Redaction([string]$from, [string]$to) {
    if ([string]::IsNullOrWhiteSpace($from) -or $from.Length -lt 4) { return }
    $null = $script:App.Redactions.Add(@{ From = $from; To = $to })
}

function Format-Safe([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return '' }
    $result = $text
    foreach ($secret in @($script:App.Run.Options)) {
        if ($null -ne $secret) {
            foreach ($password in @($secret.ClientPassword, $secret.TrustPassword)) {
                if (-not [string]::IsNullOrEmpty($password)) { $result = $result.Replace($password, '[password]') }
            }
        }
    }
    foreach ($pair in $script:App.Redactions) {
        $result = $result.Replace($pair.From, $pair.To)
    }
    $result = ($result -replace '\s+', ' ').Trim()
    if ($result.Length -gt 260) { $result = $result.Substring(0, 260) + [char]0x2026 }
    return $result
}

# ---------------------------------------------------------------- configuration

function Read-DemoConfig {
    $problems = $script:App.Problems
    $problems.Clear()
    $configured = @{
        ServerAddress = ''; ServerName = ''; Port = 8089; ClientPfxPath = ''; TrustPfxPath = ''
        InputFile = ''; LogDirectory = ''; DisplayName = 'TQE'; Synthetic = $false
        StatusHost = ''; StatusPort = 22; StatusUser = ''; StatusKeyPath = ''
        StatusKnownHostsPath = ''; StatusPrimaryName = '5G puck'; StatusBackupName = 'Phone hotspot'
    }
    $script:App.Config = $configured

    if (-not (Test-Path -LiteralPath $script:App.ConfigPath -PathType Leaf)) {
        $null = $problems.Add('No demo-config.json at ' + $script:App.ConfigPath +
            '. It needs ServerAddress, ServerName, Port, ClientPfxPath, TrustPfxPath, InputFile, LogDirectory, DisplayName and Synthetic.')
        return
    }
    $document = $null
    try {
        $document = (Get-Content -LiteralPath $script:App.ConfigPath -Raw -Encoding UTF8) | ConvertFrom-Json
    } catch {
        $null = $problems.Add('demo-config.json is not valid JSON: ' + $_.Exception.Message)
        return
    }

    foreach ($name in @('ServerAddress', 'ServerName', 'ClientPfxPath', 'TrustPfxPath', 'InputFile',
                        'LogDirectory', 'DisplayName', 'StatusHost', 'StatusUser', 'StatusKeyPath',
                        'StatusKnownHostsPath', 'StatusPrimaryName', 'StatusBackupName')) {
        $value = Get-Prop $document $name
        if ($null -ne $value) { $configured[$name] = ([string]$value).Trim() }
    }
    foreach ($name in @('Port', 'StatusPort')) {
        $value = Get-Prop $document $name
        if ($null -ne $value) {
            $number = 0
            if ([int]::TryParse(([string]$value), [ref]$number)) { $configured[$name] = $number }
            else { $null = $problems.Add($name + ' must be a whole number between 1 and 65535.') }
        }
    }
    $synthetic = Get-Prop $document 'Synthetic'
    if ($null -ne $synthetic) { $configured['Synthetic'] = [bool]$synthetic }
    if ([string]::IsNullOrWhiteSpace($configured['DisplayName'])) { $configured['DisplayName'] = 'TQE' }
    if ([string]::IsNullOrWhiteSpace($configured['StatusPrimaryName'])) { $configured['StatusPrimaryName'] = '5G puck' }
    if ([string]::IsNullOrWhiteSpace($configured['StatusBackupName'])) { $configured['StatusBackupName'] = 'Phone hotspot' }

    foreach ($name in @('ServerAddress', 'ServerName', 'ClientPfxPath', 'TrustPfxPath', 'InputFile', 'LogDirectory')) {
        if ([string]::IsNullOrWhiteSpace($configured[$name])) {
            $null = $problems.Add($name + ' is missing from demo-config.json.')
        }
    }
    if ($configured['Port'] -lt 1 -or $configured['Port'] -gt 65535) {
        $null = $problems.Add('Port must be between 1 and 65535.')
    }
    foreach ($name in @('ClientPfxPath', 'TrustPfxPath', 'InputFile')) {
        $path = $configured[$name]
        if ($path -and -not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $null = $problems.Add($name + ' points at a file that is not there: ' + (Split-Path -Leaf $path))
        }
    }
    $logDirectory = $configured['LogDirectory']
    if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
        try { $null = New-Item -ItemType Directory -Path $logDirectory -Force }
        catch { $null = $problems.Add('LogDirectory could not be created: ' + $_.Exception.Message) }
    }

    Add-Redaction $configured['ServerAddress'] 'the TAK server'
    Add-Redaction $configured['ServerName'] 'the TAK server name'
    Add-Redaction $configured['StatusHost'] 'the gateway'
    Add-Redaction $configured['StatusUser'] 'the status account'
    foreach ($name in @('ClientPfxPath', 'TrustPfxPath', 'InputFile', 'StatusKeyPath', 'StatusKnownHostsPath')) {
        $path = $configured[$name]
        if ($path) { Add-Redaction $path (Split-Path -Leaf $path) }
    }
}

function Initialize-StatusProbe {
    $configured = $script:App.Config
    $status = $script:App.Status
    $missing = @()
    foreach ($name in @('StatusHost', 'StatusUser', 'StatusKeyPath', 'StatusKnownHostsPath')) {
        if ([string]::IsNullOrWhiteSpace($configured[$name])) { $missing += $name }
    }
    if ($missing.Count -gt 0) {
        $status.Enabled = $false
        $status.Reason = 'Connection status is not configured. Add ' + ($missing -join ', ') + ' to demo-config.json.'
        return
    }
    foreach ($name in @('StatusKeyPath', 'StatusKnownHostsPath')) {
        if (-not (Test-Path -LiteralPath $configured[$name] -PathType Leaf)) {
            $status.Enabled = $false
            $status.Reason = $name + ' points at a file that is not there: ' + (Split-Path -Leaf $configured[$name])
            return
        }
    }
    $candidate = Join-Path $env:SystemRoot 'System32\OpenSSH\ssh.exe'
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $command = Get-Command 'ssh.exe' -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -eq $command) {
            $status.Enabled = $false
            $status.Reason = 'ssh.exe was not found, so the connection status cannot be read.'
            return
        }
        $candidate = $command.Source
    }
    $status.SshPath = $candidate
    $status.Enabled = $true
    $status.Reason = ''
}

# ------------------------------------------------------------------- log tail

function Close-LogTail {
    $log = $script:App.Log
    if ($null -ne $log.Stream) { try { $log.Stream.Dispose() } catch { } }
    $log.Stream = $null
    $log.Decoder = $null
    $log.Pending = ''
    $log.Path = ''
}

function Open-LogTail([string]$path) {
    Close-LogTail
    $log = $script:App.Log
    $stream = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
        ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $window = 262144L
    if ($stream.Length -gt $window) {
        $null = $stream.Seek(-$window, [IO.SeekOrigin]::End)
        $log.Sync = $true
    } else {
        $log.Sync = $false
    }
    $log.Stream = $stream
    $log.Decoder = [Text.Encoding]::UTF8.GetDecoder()
    $log.Pending = ''
    $log.Path = $path
    $script:App.View = New-View
    $created = $null
    try { $created = (Get-Item -LiteralPath $path).CreationTime } catch { $created = $null }
    $script:App.View.Started = $created
}

function Select-LatestLog {
    $directory = $script:App.Config['LogDirectory']
    if ([string]::IsNullOrWhiteSpace($directory) -or -not (Test-Path -LiteralPath $directory -PathType Container)) { return '' }
    $newest = Get-ChildItem -LiteralPath $directory -Filter 'send-*.jsonl' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -eq $newest) { return '' }
    return $newest.FullName
}

function Read-LogRecord([string]$line) {
    $view = $script:App.View
    $view.Lines++
    $record = $null
    try { $record = $line | ConvertFrom-Json } catch { $view.Unreadable++; return }
    $state = [string](Get-Prop $record 'state')
    if ([string]::IsNullOrEmpty($state)) { $view.Unreadable++; return }

    $stamp = [DateTime]::MinValue
    $utc = Get-Prop $record 'utc'
    $parsed = $false
    if ($null -ne $utc) {
        $parsed = [DateTime]::TryParse([string]$utc, [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind, [ref]$stamp)
    }
    if ($parsed) { $view.LastRecord = $stamp.ToUniversalTime() }

    foreach ($name in @('attempted', 'dropped', 'failedWritesDeliveryUnknown')) {
        $value = Get-Prop $record $name
        if ($null -eq $value) { continue }
        $number = 0L
        if (-not [long]::TryParse(([string]$value), [ref]$number)) { continue }
        if ($name -eq 'attempted') { $view.Attempted = $number }
        elseif ($name -eq 'dropped') { $view.Dropped = $number }
        else { $view.Unknown = $number }
    }
    $connection = Get-Prop $record 'connectionState'
    if ($null -ne $connection) { $view.Connection = [string]$connection }

    if ($state -eq 'write_completed_not_delivery') {
        if ($parsed) {
            $view.Writes.Add($view.LastRecord)
            $view.LastWrite = $view.LastRecord
        }
        $uid = [string](Get-Prop $record 'uid')
        if ($uid) {
            if ($uid.Length -gt 34) { $uid = $uid.Substring(0, 33) + [char]0x2026 }
            $clock = if ($parsed) { $view.LastRecord.ToString('HH:mm:ss') + 'Z' } else { '--:--:--' }
            $null = $view.Tracks.Add($clock + '  ' + $uid)
            while ($view.Tracks.Count -gt 4) { $view.Tracks.RemoveAt(0) }
        }
    } elseif ($state -eq 'write_failed_delivery_unknown' -or $state -eq 'disconnected_dropped') {
        if ($parsed) { $view.Faults.Add($view.LastRecord) }
    }
}

function Remove-Expired($series, [DateTime]$cutoff) {
    $drop = 0
    while ($drop -lt $series.Count -and $series[$drop] -lt $cutoff) { $drop++ }
    if ($drop -gt 0) { $series.RemoveRange(0, $drop) }
}

function Update-LogTail {
    $log = $script:App.Log
    if ($null -eq $log.Stream) { return }
    $stream = $log.Stream
    $length = 0L
    try { $length = $stream.Length } catch { Close-LogTail; return }
    if ($length -lt $stream.Position) { $path = $log.Path; Open-LogTail $path; return }

    $budget = 524288
    while ($stream.Position -lt $length -and $budget -gt 0) {
        $count = [int][Math]::Min([long]65536, $length - $stream.Position)
        if ($count -le 0) { break }
        $bytes = New-Object byte[] $count
        $read = $stream.Read($bytes, 0, $count)
        if ($read -le 0) { break }
        $budget -= $read
        $characters = New-Object char[] ($read + 1)
        $produced = $log.Decoder.GetChars($bytes, 0, $read, $characters, 0)
        if ($produced -gt 0) { $log.Pending += [string]::new($characters, 0, $produced) }
    }
    if ($log.Pending.Length -gt 1048576) { $log.Pending = ''; return }
    if ($log.Pending.IndexOf("`n") -lt 0) { return }

    $parts = $log.Pending -split "`n"
    $log.Pending = $parts[$parts.Length - 1]
    for ($index = 0; $index -lt $parts.Length - 1; $index++) {
        $line = $parts[$index].TrimEnd([char]13)
        if ($log.Sync) { $log.Sync = $false; continue }
        if ($line.Length -gt 0) { Read-LogRecord $line }
    }

    $cutoff = [DateTime]::UtcNow.AddSeconds(-60)
    Remove-Expired $script:App.View.Writes $cutoff
    Remove-Expired $script:App.View.Faults $cutoff
}

# --------------------------------------------------------- other sender guard

function Update-SenderGuard([bool]$force) {
    $sender = $script:App.Sender
    if (-not $force -and [DateTime]::UtcNow -lt $sender.NextCheck) { return }
    $sender.NextCheck = [DateTime]::UtcNow.AddSeconds(4)

    $candidates = @()
    try {
        $candidates = @(Get-Process -Name 'powershell', 'pwsh' -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -ne $PID } | Select-Object -ExpandProperty Id)
    } catch { $candidates = @() }
    $signature = ($candidates | Sort-Object) -join ','
    if (-not $force -and $signature -eq $sender.Pids) { return }
    $sender.Pids = $signature

    if ($candidates.Count -eq 0) {
        $sender.Present = $false; $sender.Detail = ''; $sender.Checked = $true
        return
    }
    $filter = ($candidates | ForEach-Object { 'ProcessId=' + $_ }) -join ' OR '
    $processes = $null
    try { $processes = @(Get-CimInstance -ClassName Win32_Process -Filter $filter -ErrorAction Stop) }
    catch {
        $sender.Checked = $false
        $sender.Detail = 'Could not check for other senders on this laptop.'
        return
    }
    $sender.Checked = $true
    $found = @()
    foreach ($process in $processes) {
        $commandLine = [string](Get-Prop $process 'CommandLine')
        if ([string]::IsNullOrEmpty($commandLine)) { continue }
        if ($commandLine -like '*Invoke-TqeCot*' -and $commandLine -like '*-Replay*') {
            $found += [string](Get-Prop $process 'ProcessId')
        }
    }
    if ($found.Count -gt 0) {
        $sender.Present = $true
        $sender.Detail = 'A sender is already streaming from this laptop (process ' + ($found -join ', ') + ').'
    } else {
        $sender.Present = $false
        $sender.Detail = ''
    }
}

# --------------------------------------------------------- WAN status probe

function Stop-StatusProbe {
    $status = $script:App.Status
    $status.OutputTask = $null
    $status.ErrorTask = $null
    if ($null -eq $status.Process) { return }
    try { if (-not $status.Process.HasExited) { $status.Process.Kill() } } catch { }
    try { $status.Process.Dispose() } catch { }
    $status.Process = $null
}

function Start-StatusProbe {
    $status = $script:App.Status
    $configured = $script:App.Config
    $arguments = New-Object Text.StringBuilder
    $null = $arguments.Append('-T -F NUL -i "').Append($configured['StatusKeyPath']).Append('"')
    $null = $arguments.Append(' -p ').Append($configured['StatusPort'])
    $null = $arguments.Append(' -oBatchMode=yes -oIdentitiesOnly=yes -oIdentityAgent=none')
    $null = $arguments.Append(' -oStrictHostKeyChecking=yes')
    $null = $arguments.Append(' -oUserKnownHostsFile="').Append($configured['StatusKnownHostsPath']).Append('"')
    $null = $arguments.Append(' -oConnectTimeout=2 ')
    $null = $arguments.Append($configured['StatusUser']).Append('@').Append($configured['StatusHost'])

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $status.SshPath
    $startInfo.Arguments = $arguments.ToString()
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        $null = $process.Start()
        $process.StandardInput.Close()
        $status.OutputTask = $process.StandardOutput.ReadToEndAsync()
        $status.ErrorTask = $process.StandardError.ReadToEndAsync()
    } catch {
        try { $process.Dispose() } catch { }
        $status.OutputTask = $null
        $status.ErrorTask = $null
        $status.Failure = Format-Safe ('Status login did not start: ' + $_.Exception.Message)
        $status.NextProbe = [DateTime]::UtcNow.AddSeconds(5)
        return
    }
    $status.Process = $process
    $status.StartedAt = [DateTime]::UtcNow
}

function Complete-StatusProbe {
    $status = $script:App.Status
    $process = $status.Process
    $exited = $false
    try { $exited = $process.HasExited } catch { $exited = $true }
    if (-not $exited) {
        if (([DateTime]::UtcNow - $status.StartedAt).TotalSeconds -lt 3) { return }
        Stop-StatusProbe
        $status.Failure = 'The status login did not answer within 3 seconds.'
        $status.NextProbe = [DateTime]::UtcNow.AddSeconds(2)
        return
    }
    $output = ''
    $errors = ''
    if ($null -ne $status.OutputTask) { try { $output = [string]$status.OutputTask.Result } catch { $output = '' } }
    if ($null -ne $status.ErrorTask) { try { $errors = [string]$status.ErrorTask.Result } catch { $errors = '' } }
    $code = 0
    try { $code = $process.ExitCode } catch { $code = -1 }
    try { $process.Dispose() } catch { }
    $status.Process = $null
    $status.OutputTask = $null
    $status.ErrorTask = $null
    $status.NextProbe = [DateTime]::UtcNow.AddSeconds(2)

    if ($code -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
        $detail = if ([string]::IsNullOrWhiteSpace($errors)) { 'exit code ' + $code } else { $errors }
        $status.Failure = Format-Safe ('Status login failed: ' + $detail)
        return
    }
    $record = $null
    try { $record = $output | ConvertFrom-Json } catch { $record = $null }
    if ($null -eq $record) {
        $status.Failure = 'The status login answered with something other than status JSON.'
        return
    }
    $active = [string](Get-Prop $record 'active')
    if ($active -ne 'primary' -and $active -ne 'backup') { $active = 'unknown' }
    $status.Active = $active
    $status.Name = switch ($active) {
        'primary' { $script:App.Config['StatusPrimaryName'] }
        'backup'  { $script:App.Config['StatusBackupName'] }
        default   { 'UNKNOWN PATH' }
    }
    $status.Interface = [string](Get-Prop $record 'interface')
    $status.SourceIp = [string](Get-Prop $record 'source_ip')
    $status.Gateway = [string](Get-Prop $record 'gateway')
    $protectedRoute = Get-Prop $record 'protected_route'
    $status.Protected = if ($null -eq $protectedRoute) { $null } else { [bool]$protectedRoute }
    $status.ObservedAt = [DateTime]::UtcNow
    $status.Failure = ''
}

function Update-StatusProbe {
    $status = $script:App.Status
    if (-not $status.Enabled) { return }
    if ($null -ne $status.Process) { Complete-StatusProbe; return }
    if ([DateTime]::UtcNow -ge $status.NextProbe) { Start-StatusProbe }
}

function Test-StatusFresh {
    $status = $script:App.Status
    if (-not $status.Enabled) { return $false }
    if ($status.ObservedAt -eq [DateTime]::MinValue) { return $false }
    return ([DateTime]::UtcNow - $status.ObservedAt).TotalSeconds -le 8
}

# ------------------------------------------------------------------- UI build

function Register-Typed($control, [string]$role) {
    $null = $script:App.UI.Typed.Add(@{ Control = $control; Role = $role })
    return $control
}

function New-Stack([int]$rows, [int]$columns) {
    $stack = New-Object Windows.Forms.TableLayoutPanel
    $stack.Dock = 'Fill'
    $stack.RowCount = $rows
    $stack.ColumnCount = $columns
    $stack.Margin = New-Object Windows.Forms.Padding(0)
    $stack.BackColor = [Drawing.Color]::Transparent
    return $stack
}

function New-Caption([string]$text) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $text
    $label.Dock = 'Fill'
    $label.AutoSize = $false
    $label.ForeColor = $script:Palette.Graphite
    $label.TextAlign = 'BottomLeft'
    $label.Margin = New-Object Windows.Forms.Padding(0)
    return (Register-Typed $label 'Caption')
}

function New-Value([string]$text) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $text
    $label.Dock = 'Fill'
    $label.AutoSize = $false
    $label.ForeColor = $script:Palette.Ink
    $label.TextAlign = 'TopLeft'
    $label.Margin = New-Object Windows.Forms.Padding(0)
    return (Register-Typed $label 'Value')
}

function New-Field([string]$caption, [string]$initial) {
    $stack = New-Stack 2 1
    $null = $stack.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 42)))
    $null = $stack.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 58)))
    $null = $stack.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    $captionLabel = New-Caption $caption
    $valueLabel = New-Value $initial
    $stack.Controls.Add($captionLabel, 0, 0)
    $stack.Controls.Add($valueLabel, 0, 1)
    return @{ Panel = $stack; Value = $valueLabel }
}

function Add-Hairline($panel) {
    $panel.Add_Paint({
        param($sender, $eventArgs)
        $eventArgs.Graphics.FillRectangle($script:Brushes.Rule, 0, 0, $sender.Width, 1)
    })
}

function Set-Text($control, [string]$value) {
    if ($control.Text -ne $value) { $control.Text = $value }
}

function Set-Foreground($control, $color) {
    if ($control.ForeColor -ne $color) { $control.ForeColor = $color }
}

function New-DemoButton([string]$text, [bool]$primary) {
    $button = New-Object Windows.Forms.Button
    $button.Text = $text
    $button.Dock = 'Fill'
    $button.FlatStyle = 'Flat'
    $button.Margin = New-Object Windows.Forms.Padding(0, 0, 12, 0)
    $button.UseVisualStyleBackColor = $false
    if ($primary) {
        $button.BackColor = $script:Palette.Signal
        $button.ForeColor = [Drawing.Color]::White
        $button.FlatAppearance.BorderColor = $script:Palette.SignalDeep
    } else {
        $button.BackColor = $script:Palette.Field
        $button.ForeColor = $script:Palette.Ink
        $button.FlatAppearance.BorderColor = $script:Palette.Graphite
    }
    $button.FlatAppearance.BorderSize = 2
    $button.Add_GotFocus({ param($sender, $eventArgs)
        $sender.FlatAppearance.BorderSize = 4
        $sender.FlatAppearance.BorderColor = $script:Palette.Ink })
    $button.Add_LostFocus({ param($sender, $eventArgs)
        $sender.FlatAppearance.BorderSize = 2
        $sender.FlatAppearance.BorderColor = if ($sender.BackColor -eq $script:Palette.Signal) { $script:Palette.SignalDeep } else { $script:Palette.Graphite } })
    return (Register-Typed $button 'Button')
}

function New-PasswordBox([string]$accessibleName) {
    $box = New-Object Windows.Forms.TextBox
    $box.UseSystemPasswordChar = $true
    $box.Dock = 'Fill'
    $box.BorderStyle = 'FixedSingle'
    $box.BackColor = $script:Palette.Field
    $box.ForeColor = $script:Palette.Ink
    $box.AccessibleName = $accessibleName
    $box.Margin = New-Object Windows.Forms.Padding(0, 2, 16, 6)
    return (Register-Typed $box 'Status')
}

function Build-Window {
    [Windows.Forms.Application]::EnableVisualStyles()
    [Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

    $ui = $script:App.UI
    $ui.Fonts = New-FontSet 1.0

    $form = New-Object Windows.Forms.Form
    $form.Text = 'TQE Live CoT Sender'
    $form.BackColor = $script:Palette.Chart
    $form.ForeColor = $script:Palette.Ink
    $form.ClientSize = New-Object Drawing.Size(1100, 650)
    $form.MinimumSize = New-Object Drawing.Size(920, 600)
    $form.StartPosition = 'CenterScreen'
    $form.Font = $ui.Fonts.Status
    $ui.Form = $form

    $root = New-Stack 7 1
    $null = $root.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    foreach ($height in @(40, 92, 0, 78, 118, 38, 96)) {
        $null = $root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $height)))
    }
    $root.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Percent
    $root.RowStyles[2].Height = 100
    $form.Controls.Add($root)
    $ui.Root = $root

    # exercise banner
    $banner = New-Object Windows.Forms.Label
    $banner.Dock = 'Fill'
    $banner.AutoSize = $false
    $banner.TextAlign = 'MiddleCenter'
    $banner.BackColor = $script:Palette.Exercise
    $banner.ForeColor = [Drawing.Color]::White
    $banner.Margin = New-Object Windows.Forms.Padding(0)
    $banner.Text = 'SYNTHETIC EXERCISE  -  fictional tracks for this rehearsal, not the MITRE feed'
    $null = Register-Typed $banner 'Banner'
    $root.Controls.Add($banner, 0, 0)
    $ui.Banner = $banner

    # header
    $header = New-Stack 2 2
    $header.Padding = New-Object Windows.Forms.Padding(28, 10, 28, 6)
    $null = $header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 58)))
    $null = $header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 42)))
    $null = $header.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 62)))
    $null = $header.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 38)))

    $title = New-Object Windows.Forms.Label
    $title.Text = 'TQE Live CoT Sender'
    $title.Dock = 'Fill'
    $title.AutoSize = $false
    $title.TextAlign = 'BottomLeft'
    $title.ForeColor = $script:Palette.Ink
    $title.Margin = New-Object Windows.Forms.Padding(0)
    $null = Register-Typed $title 'Title'
    $header.Controls.Add($title, 0, 0)

    $source = New-Object Windows.Forms.Label
    $source.Dock = 'Fill'
    $source.AutoSize = $false
    $source.TextAlign = 'TopLeft'
    $source.ForeColor = $script:Palette.Graphite
    $source.Margin = New-Object Windows.Forms.Padding(0)
    $source.Text = 'Starting up'
    $null = Register-Typed $source 'Meta'
    $header.Controls.Add($source, 0, 1)
    $ui.Source = $source

    $link = New-Object Windows.Forms.Label
    $link.Dock = 'Fill'
    $link.AutoSize = $false
    $link.TextAlign = 'BottomRight'
    $link.ForeColor = $script:Palette.Graphite
    $link.Margin = New-Object Windows.Forms.Padding(0)
    $link.Text = 'NO RUN LOG YET'
    $null = Register-Typed $link 'Value'
    $header.Controls.Add($link, 1, 0)
    $ui.Link = $link

    $age = New-Object Windows.Forms.Label
    $age.Dock = 'Fill'
    $age.AutoSize = $false
    $age.TextAlign = 'TopRight'
    $age.ForeColor = $script:Palette.Graphite
    $age.Margin = New-Object Windows.Forms.Padding(0)
    $age.Text = 'no writes yet'
    $null = Register-Typed $age 'Meta'
    $header.Controls.Add($age, 1, 1)
    $ui.Age = $age
    $root.Controls.Add($header, 0, 1)

    # hero plate
    $hero = New-Object Windows.Forms.PictureBox
    $hero.Dock = 'Fill'
    $hero.BackColor = $script:Palette.Plate
    $hero.Margin = New-Object Windows.Forms.Padding(28, 4, 28, 12)
    $hero.SizeMode = 'Normal'
    $hero.AccessibleName = 'Active WAN path and completed writes'
    $root.Controls.Add($hero, 0, 2)
    $ui.Hero = $hero

    # facts
    $facts = New-Stack 1 4
    $facts.Padding = New-Object Windows.Forms.Padding(28, 12, 28, 8)
    for ($column = 0; $column -lt 4; $column++) {
        $null = $facts.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 25)))
    }
    $null = $facts.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $unknownField = New-Field 'WRITE FAILURES, DELIVERY UNKNOWN' '0'
    $droppedField = New-Field 'DROPPED, NO LINK' '0'
    $startedField = New-Field 'RUN STARTED' '-'
    $logField = New-Field 'RUN LOG' '-'
    $facts.Controls.Add($unknownField.Panel, 0, 0)
    $facts.Controls.Add($droppedField.Panel, 1, 0)
    $facts.Controls.Add($startedField.Panel, 2, 0)
    $facts.Controls.Add($logField.Panel, 3, 0)
    Add-Hairline $facts
    $root.Controls.Add($facts, 0, 3)
    $ui.Unknown = $unknownField.Value
    $ui.Dropped = $droppedField.Value
    $ui.Started = $startedField.Value
    $ui.LogName = $logField.Value

    # tracks
    $tracks = New-Stack 2 1
    $tracks.Padding = New-Object Windows.Forms.Padding(28, 6, 28, 6)
    $null = $tracks.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    $null = $tracks.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 22)))
    $null = $tracks.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $tracks.Controls.Add((New-Caption 'LATEST TRACK IDS WRITTEN  -  TIME IS THE WRITE ATTEMPT, NOT ARRIVAL'), 0, 0)
    $trackList = New-Object Windows.Forms.Label
    $trackList.Dock = 'Fill'
    $trackList.AutoSize = $false
    $trackList.TextAlign = 'TopLeft'
    $trackList.ForeColor = $script:Palette.Ink
    $trackList.Margin = New-Object Windows.Forms.Padding(0)
    $trackList.Text = 'No writes yet.'
    $null = Register-Typed $trackList 'Data'
    $tracks.Controls.Add($trackList, 0, 1)
    $root.Controls.Add($tracks, 0, 4)
    $ui.Tracks = $trackList

    # status line
    $statusHost = New-Object Windows.Forms.Panel
    $statusHost.Dock = 'Fill'
    $statusHost.Padding = New-Object Windows.Forms.Padding(28, 4, 28, 8)
    $statusHost.Margin = New-Object Windows.Forms.Padding(0)
    $statusBox = New-Object Windows.Forms.TextBox
    $statusBox.Dock = 'Fill'
    $statusBox.ReadOnly = $true
    $statusBox.BorderStyle = 'None'
    $statusBox.BackColor = $script:Palette.Chart
    $statusBox.ForeColor = $script:Palette.Ink
    $statusBox.AccessibleName = 'Panel message'
    $statusBox.Text = 'Starting up.'
    $null = Register-Typed $statusBox 'Status'
    $statusHost.Controls.Add($statusBox)
    $root.Controls.Add($statusHost, 0, 5)
    $ui.StatusBox = $statusBox

    # controls
    $controls = New-Stack 2 4
    $controls.Padding = New-Object Windows.Forms.Padding(28, 12, 28, 14)
    $null = $controls.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 220)))
    $null = $controls.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 190)))
    $null = $controls.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 50)))
    $null = $controls.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 50)))
    $null = $controls.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 22)))
    $null = $controls.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))

    $startButton = New-DemoButton 'Start sending' $true
    $stopButton = New-DemoButton 'Stop sending' $false
    $stopButton.Enabled = $false
    $controls.Controls.Add($startButton, 0, 1)
    $controls.Controls.Add($stopButton, 1, 1)

    $controls.Controls.Add((New-Caption 'CLIENT PFX PASSWORD'), 2, 0)
    $clientBox = New-PasswordBox 'Client PFX password'
    $controls.Controls.Add($clientBox, 2, 1)

    $sameBox = New-Object Windows.Forms.CheckBox
    $sameBox.Text = 'Trust file uses the same password'
    $sameBox.Checked = $true
    $sameBox.Dock = 'Fill'
    $sameBox.ForeColor = $script:Palette.Graphite
    $sameBox.Margin = New-Object Windows.Forms.Padding(0)
    $null = Register-Typed $sameBox 'Caption'
    $controls.Controls.Add($sameBox, 3, 0)
    $trustBox = New-PasswordBox 'Trust PFX password'
    $trustBox.Enabled = $false
    $controls.Controls.Add($trustBox, 3, 1)
    $sameBox.Add_CheckedChanged({
        $script:App.UI.TrustBox.Enabled = -not $script:App.UI.SameBox.Checked
        if ($script:App.UI.SameBox.Checked) { $script:App.UI.TrustBox.Text = '' }
    })
    Add-Hairline $controls
    $root.Controls.Add($controls, 0, 6)

    $ui.StartButton = $startButton
    $ui.StopButton = $stopButton
    $ui.ClientBox = $clientBox
    $ui.TrustBox = $trustBox
    $ui.SameBox = $sameBox
    $form.AcceptButton = $startButton

    $startButton.Add_Click({ Start-Sending })
    $stopButton.Add_Click({ Stop-Sending $false })
    $form.Add_Resize({ Update-Scale })
    $form.Add_FormClosing({ param($sender, $eventArgs) Confirm-Closing $eventArgs })
    $form.Add_FormClosed({ Clear-Resources })

    Set-FontScale 1.0
    return $form
}

function Set-FontScale([double]$scale) {
    $ui = $script:App.UI
    $previous = $ui.Fonts
    $ui.Fonts = New-FontSet $scale
    foreach ($entry in $ui.Typed) {
        $entry.Control.Font = $ui.Fonts[$entry.Role]
    }
    if ($null -ne $ui.Form) { $ui.Form.Font = $ui.Fonts.Status }
    if ($null -ne $previous) {
        foreach ($role in @($previous.Keys)) { $previous[$role].Dispose() }
    }
}

function Update-Scale {
    $ui = $script:App.UI
    if ($null -eq $ui.Form) { return }
    $client = $ui.Form.ClientSize
    if ($client.Width -lt 200 -or $client.Height -lt 200) { return }
    $scale = [Math]::Min($client.Width / 1100.0, $client.Height / 650.0)
    if ($scale -lt 0.82) { $scale = 0.82 }
    if ($scale -gt 1.9) { $scale = 1.9 }
    if ([Math]::Abs($scale - $ui.Scale) -lt 0.03) { return }
    $ui.Scale = $scale
    Set-FontScale $scale
    $rows = @(40, 92, 0, 78, 118, 38, 96)
    for ($index = 0; $index -lt $rows.Length; $index++) {
        if ($index -eq 2) { continue }
        $height = [int][Math]::Round($rows[$index] * $scale)
        if ($index -eq 0 -and -not $script:App.Config['Synthetic']) { $height = 0 }
        $ui.Root.RowStyles[$index].Height = $height
    }
}

# ---------------------------------------------------------------- hero drawing

$script:HeroFormatRight = New-Object Drawing.StringFormat
$script:HeroFormatRight.Alignment = [Drawing.StringAlignment]::Far
$script:HeroFormatRight.FormatFlags = [Drawing.StringFormatFlags]::NoWrap

function Format-Age([double]$seconds) {
    if ($seconds -lt 10) { return ([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.0} s', $seconds)) }
    return ([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0} s', $seconds))
}

function Update-Hero {
    $ui = $script:App.UI
    $box = $ui.Hero
    $width = $box.ClientSize.Width
    $height = $box.ClientSize.Height
    if ($width -lt 200 -or $height -lt 120) { return }
    if ($null -eq $ui.HeroImage -or $ui.HeroImage.Width -ne $width -or $ui.HeroImage.Height -ne $height) {
        $box.Image = $null
        if ($null -ne $ui.HeroImage) { $ui.HeroImage.Dispose() }
        $ui.HeroImage = New-Object Drawing.Bitmap($width, $height)
        $box.Image = $ui.HeroImage
    }
    $fonts = $ui.Fonts
    $scale = $ui.Scale
    $pad = [int](26 * $scale)
    $graphics = [Drawing.Graphics]::FromImage($ui.HeroImage)
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $graphics.Clear($script:Palette.Plate)
        $graphics.FillRectangle($script:Brushes.Rule, 0, 0, $width, 1)

        $status = $script:App.Status
        $view = $script:App.View
        $completed = $view.Attempted - $view.Unknown
        if ($completed -lt 0) { $completed = 0 }
        $countText = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:N0}', $completed)
        $right = $width - $pad
        $noteLine = $graphics.MeasureString('Hg', $fonts.Note).Height
        $noteTop = $pad

        if (-not $status.Enabled) {
            $graphics.DrawString('TLS WRITES COMPLETED', $fonts.Caption, $script:Brushes.Graphite,
                [single]$pad, [single]$pad)
            $countTop = $pad + (18 * $scale)
            $graphics.DrawString($countText, $fonts.Hero, $script:Brushes.Ink, [single]$pad, [single]$countTop)
            $noteTop = $countTop + $graphics.MeasureString($countText, $fonts.Hero).Height - (10 * $scale)
            $graphics.DrawString('sent, not delivered  -  verify receipt in WinTAK', $fonts.Note,
                $script:Brushes.Graphite, [single]$pad, [single]$noteTop)
            $graphics.DrawString('WAN STATUS NOT SHOWN', $fonts.Caption, $script:Brushes.Graphite,
                [single]$right, [single]$pad, $script:HeroFormatRight)
            $graphics.DrawString('Watch the active path on the router.', $fonts.Note, $script:Brushes.Graphite,
                [single]$right, [single]($pad + 18 * $scale), $script:HeroFormatRight)
            $noteTop = $noteTop + $noteLine
        } else {
            $fresh = Test-StatusFresh
            $pathName = 'STATUS UNAVAILABLE'
            $pathBrush = $script:Brushes.Caution
            $addressText = ''
            $noteText = ''
            if ($fresh) {
                $pathName = $status.Name
                $pathBrush = if ($status.Active -eq 'primary') { $script:Brushes.Signal } else { $script:Brushes.Caution }
                $addressText = if ($status.SourceIp) { $status.SourceIp } else { 'no source address reported' }
                $parts = @()
                if ($status.Interface) { $parts += $status.Interface }
                if ($null -ne $status.Protected) {
                    $parts += $(if ($status.Protected) { 'protected route up' } else { 'protected route down' })
                }
                $parts += 'route evidence, not encryption proof'
                $noteText = $parts -join '  -  '
            } else {
                $noteText = if ($status.Failure) { $status.Failure } else { 'Waiting for the first status answer.' }
                if ($status.ObservedAt -ne [DateTime]::MinValue) {
                    $noteText = 'Last answer ' + (Format-Age ([DateTime]::UtcNow - $status.ObservedAt).TotalSeconds) + ' ago.  ' + $noteText
                }
            }

            $graphics.DrawString('ACTIVE WAN PATH', $fonts.Caption, $script:Brushes.Graphite, [single]$pad, [single]$pad)
            $nameTop = $pad + (18 * $scale)
            $graphics.DrawString($pathName, $fonts.Hero, $pathBrush, [single]$pad, [single]$nameTop)
            $addressTop = $nameTop + $graphics.MeasureString($pathName, $fonts.Hero).Height - (8 * $scale)
            if ($addressText) {
                $graphics.DrawString($addressText, $fonts.Address, $script:Brushes.Ink, [single]$pad, [single]$addressTop)
                $noteTop = $addressTop + $graphics.MeasureString($addressText, $fonts.Address).Height
            } else {
                $noteTop = $addressTop
            }
            if ($noteText) {
                $graphics.DrawString($noteText, $fonts.Note, $script:Brushes.Graphite, [single]$pad, [single]$noteTop)
            }
            $noteTop = $noteTop + $noteLine

            $graphics.DrawString('TLS WRITES COMPLETED', $fonts.Caption, $script:Brushes.Graphite,
                [single]$right, [single]$pad, $script:HeroFormatRight)
            $graphics.DrawString($countText, $fonts.Count, $script:Brushes.Ink,
                [single]$right, [single]($pad + 18 * $scale), $script:HeroFormatRight)
            $countHeight = $graphics.MeasureString($countText, $fonts.Count).Height
            $graphics.DrawString('sent, not delivered  -  verify receipt in WinTAK', $fonts.Note, $script:Brushes.Graphite,
                [single]$right, [single]($pad + 18 * $scale + $countHeight - 6 * $scale), $script:HeroFormatRight)
        }

        # cadence strip
        $stripHeight = [int](26 * $scale)
        $stripBottom = $height - $pad
        $stripTop = $stripBottom - $stripHeight
        $stripLeft = $pad
        $stripRight = $width - $pad
        $stripWidth = $stripRight - $stripLeft
        if ($stripWidth -gt 80 -and $stripTop -gt $noteTop) {
            $graphics.FillRectangle($script:Brushes.Rule, $stripLeft, $stripBottom, $stripWidth, 1)
            $now = [DateTime]::UtcNow
            $tick = [int][Math]::Max(2, [Math]::Round(2 * $scale))
            if ($null -ne $view.LastWrite) {
                $gap = ($now - $view.LastWrite).TotalSeconds
                if ($gap -gt 3 -and $gap -lt 60) {
                    $gapLeft = $stripLeft + $stripWidth * (1 - $gap / 60.0)
                    $graphics.FillRectangle($script:Brushes.CautionWash, [single]$gapLeft, [single]$stripTop,
                        [single]($stripRight - $gapLeft), [single]$stripHeight)
                }
            }
            foreach ($moment in $view.Writes) {
                $offset = ($now - $moment).TotalSeconds
                if ($offset -lt 0 -or $offset -gt 60) { continue }
                $x = $stripLeft + $stripWidth * (1 - $offset / 60.0)
                $graphics.FillRectangle($script:Brushes.Signal, [single]$x, [single]$stripTop, [single]$tick, [single]$stripHeight)
            }
            foreach ($moment in $view.Faults) {
                $offset = ($now - $moment).TotalSeconds
                if ($offset -lt 0 -or $offset -gt 60) { continue }
                $x = $stripLeft + $stripWidth * (1 - $offset / 60.0)
                $graphics.FillRectangle($script:Brushes.Halt, [single]$x, [single]($stripBottom - 6 * $scale), [single]$tick, [single](6 * $scale))
            }
            $graphics.DrawString('WRITE CADENCE, LAST 60 SECONDS', $fonts.Caption, $script:Brushes.Graphite,
                [single]$stripLeft, [single]($stripTop - 18 * $scale))
            $graphics.DrawString('now', $fonts.Caption, $script:Brushes.Graphite,
                [single]$stripRight, [single]($stripTop - 18 * $scale), $script:HeroFormatRight)
            if ($view.Writes.Count -eq 0) {
                $empty = if ($script:App.Run.State -eq 'running') { 'Waiting for the first write.' } else { 'No writes yet. Start sending to fill the tape.' }
                $graphics.DrawString($empty, $fonts.Note, $script:Brushes.Graphite,
                    [single]$stripLeft, [single]($stripTop + 4 * $scale))
            }
        }
    } finally {
        $graphics.Dispose()
    }
    $box.Invalidate()
}

# ------------------------------------------------------------------ run control

function Set-Message([string]$text) {
    $script:App.Message = $text
    Set-Text $script:App.UI.StatusBox $text
}

function Start-Sending {
    if ($script:App.Run.State -ne 'idle') { return }
    if ($script:App.Problems.Count -gt 0) {
        Set-Message ('Fix demo-config.json first: ' + $script:App.Problems[0])
        return
    }
    Update-SenderGuard $true
    if ($script:App.Sender.Present) {
        Set-Message ($script:App.Sender.Detail + ' This window stays read-only until that stream stops.')
        Update-Buttons
        return
    }
    $configured = $script:App.Config
    foreach ($name in @('ClientPfxPath', 'TrustPfxPath', 'InputFile')) {
        if (-not (Test-Path -LiteralPath $configured[$name] -PathType Leaf)) {
            Set-Message ($name + ' is not there any more: ' + (Split-Path -Leaf $configured[$name]))
            return
        }
    }
    $clientPassword = $script:App.UI.ClientBox.Text
    if ([string]::IsNullOrEmpty($clientPassword)) {
        Set-Message 'Enter the client PFX password, then start sending.'
        $script:App.UI.ClientBox.Focus() | Out-Null
        return
    }
    $trustPassword = if ($script:App.UI.SameBox.Checked) { $clientPassword } else { $script:App.UI.TrustBox.Text }
    if ([string]::IsNullOrEmpty($trustPassword)) {
        Set-Message 'Enter the trust PFX password, or tick the same-password box.'
        $script:App.UI.TrustBox.Focus() | Out-Null
        return
    }

    if (-not (Test-Path -LiteralPath $configured['LogDirectory'] -PathType Container)) {
        try { $null = New-Item -ItemType Directory -Path $configured['LogDirectory'] -Force }
        catch { Set-Message ('The log folder could not be created: ' + (Format-Safe $_.Exception.Message)); return }
    }
    $stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss')
    $logPath = Join-Path $configured['LogDirectory'] ('send-' + $stamp + '.jsonl')
    $suffix = 1
    while (Test-Path -LiteralPath $logPath) {
        $logPath = Join-Path $configured['LogDirectory'] ('send-' + $stamp + '-' + $suffix + '.jsonl')
        $suffix++
    }

    try {
        if (-not ('TqeDemo.Runner' -as [type])) {
            $source = Join-Path $PSScriptRoot 'TqeCot.cs'
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
                Set-Message 'TqeCot.cs is missing from the tools folder next to this panel.'
                return
            }
            Add-Type -Path $source -ReferencedAssemblies @(
                'System.dll', 'System.Core.dll', 'System.Xml.dll',
                'System.Xml.Linq.dll', 'System.Web.Extensions.dll')
        }
    } catch {
        Set-Message ('The sender could not be compiled: ' + (Format-Safe $_.Exception.GetBaseException().Message))
        return
    }

    $run = $script:App.Run
    try {
        $options = New-Object TqeDemo.ConnectionOptions
        $options.ServerAddress = $configured['ServerAddress']
        $options.ServerName = $configured['ServerName']
        $options.Port = $configured['Port']
        $options.ClientPfxPath = $configured['ClientPfxPath']
        $options.TrustPfxPath = $configured['TrustPfxPath']
        $options.DisplayName = $configured['DisplayName']
        $options.ClientPassword = $clientPassword
        $options.TrustPassword = $trustPassword
        $cancellation = New-Object Threading.CancellationTokenSource
        $options.CancellationToken = $cancellation.Token

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = [Threading.ApartmentState]::MTA
        $runspace.ThreadOptions = [Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $runspace.Open()
        $shell = [powershell]::Create()
        $shell.Runspace = $runspace
        $worker = @'
param($RunnerType, $Options, $InputFile, $LogPath)
$ErrorActionPreference = 'Stop'
$RunnerType::Replay($Options, $InputFile, $true, 1.0, $true, $LogPath)
'@
        $null = $shell.AddScript($worker).AddArgument(([TqeDemo.Runner])).AddArgument($options).
            AddArgument($configured['InputFile']).AddArgument($logPath)

        $run.Options = $options
        $run.Cancellation = $cancellation
        $run.Runspace = $runspace
        $run.Shell = $shell
        $run.LogPath = $logPath
        $run.StartedUtc = [DateTime]::UtcNow
        $run.CloseWhenStopped = $false
        $run.Handle = $shell.BeginInvoke()
        $run.State = 'running'
    } catch {
        Clear-Run
        Set-Message ('The sender did not start: ' + (Format-Safe $_.Exception.GetBaseException().Message))
        return
    }

    $script:App.UI.ClientBox.Enabled = $false
    $script:App.UI.TrustBox.Enabled = $false
    $script:App.UI.SameBox.Enabled = $false
    Close-LogTail
    $script:App.View = New-View
    $script:App.View.Started = [DateTime]::Now
    Set-Message 'Sending. Writes are attempts, not delivery: verify receipt in WinTAK.'
    Update-Buttons
}

function Stop-Sending([bool]$closing) {
    $run = $script:App.Run
    if ($run.State -ne 'running') { return }
    $run.State = 'stopping'
    $run.CloseWhenStopped = $run.CloseWhenStopped -or $closing
    try { $run.Cancellation.Cancel() } catch { }
    Set-Message 'Stopping the sender. Waiting for the connection to close.'
    Update-Buttons
}

function Clear-Run {
    $run = $script:App.Run
    if ($null -ne $run.Shell) { try { $run.Shell.Dispose() } catch { } }
    if ($null -ne $run.Runspace) { try { $run.Runspace.Close(); $run.Runspace.Dispose() } catch { } }
    if ($null -ne $run.Options) { $run.Options.ClientPassword = $null; $run.Options.TrustPassword = $null }
    if ($null -ne $run.Cancellation) { try { $run.Cancellation.Dispose() } catch { } }
    $run.Shell = $null
    $run.Runspace = $null
    $run.Handle = $null
    $run.Options = $null
    $run.Cancellation = $null
    $run.State = 'idle'
}

function Complete-Run {
    $run = $script:App.Run
    $completed = $script:App.View.Attempted - $script:App.View.Unknown
    if ($completed -lt 0) { $completed = 0 }
    $failure = ''
    try {
        $null = $run.Shell.EndInvoke($run.Handle)
        if ($run.Shell.Streams.Error.Count -gt 0) {
            $failure = [string]$run.Shell.Streams.Error[0].Exception.GetBaseException().Message
        }
    } catch {
        $failure = [string]$_.Exception.GetBaseException().Message
    }
    $wasStopping = $run.State -eq 'stopping'
    $closing = $run.CloseWhenStopped
    Clear-Run
    $script:App.UI.ClientBox.Enabled = $true
    $script:App.UI.SameBox.Enabled = $true
    $script:App.UI.TrustBox.Enabled = -not $script:App.UI.SameBox.Checked
    if ($failure) {
        Set-Message ('The sender stopped: ' + (Format-Safe $failure))
    } elseif ($wasStopping) {
        Set-Message ('Stopped. ' + $completed + ' writes completed this run.')
    } else {
        Set-Message ('The sender finished on its own. ' + $completed + ' writes completed this run.')
    }
    Update-Buttons
    if ($closing) { $script:App.UI.Form.Close() }
}

function Update-Buttons {
    $ui = $script:App.UI
    $run = $script:App.Run
    $blocked = $script:App.Sender.Present -or $script:App.Problems.Count -gt 0
    $ui.StartButton.Enabled = ($run.State -eq 'idle') -and -not $blocked
    $ui.StopButton.Enabled = ($run.State -eq 'running')
    $ui.StartButton.BackColor = if ($ui.StartButton.Enabled) { $script:Palette.Signal } else { $script:Palette.Rule }
    $ui.StartButton.ForeColor = if ($ui.StartButton.Enabled) { [Drawing.Color]::White } else { $script:Palette.Graphite }
}

function Confirm-Closing($eventArgs) {
    if ($script:App.Run.State -eq 'running') {
        $answer = [Windows.Forms.MessageBox]::Show(
            'This window is still sending. Stop sending and close?',
            'TQE Live CoT Sender', [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning)
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) { $eventArgs.Cancel = $true; return }
        $eventArgs.Cancel = $true
        Stop-Sending $true
        return
    }
    if ($script:App.Run.State -eq 'stopping') {
        $script:App.Run.CloseWhenStopped = $true
        $eventArgs.Cancel = $true
    }
}

function Clear-Resources {
    if ($null -ne $script:App.UI.Timer) { $script:App.UI.Timer.Stop(); $script:App.UI.Timer.Dispose() }
    Stop-StatusProbe
    Close-LogTail
    Clear-Run
    if ($null -ne $script:App.UI.ClientBox) { $script:App.UI.ClientBox.Text = '' }
    if ($null -ne $script:App.UI.TrustBox) { $script:App.UI.TrustBox.Text = '' }
    if ($null -ne $script:App.UI.HeroImage) { $script:App.UI.HeroImage.Dispose(); $script:App.UI.HeroImage = $null }
}

# --------------------------------------------------------------------- refresh

function Update-LogSelection {
    $log = $script:App.Log
    $run = $script:App.Run
    if ($run.State -eq 'running' -or $run.State -eq 'stopping') {
        if ($log.Path -ne $run.LogPath -and (Test-Path -LiteralPath $run.LogPath -PathType Leaf)) {
            Open-LogTail $run.LogPath
            $script:App.View.Started = $run.StartedUtc.ToLocalTime()
        }
        return
    }
    if ([DateTime]::UtcNow -lt $log.NextScan) { return }
    $log.NextScan = [DateTime]::UtcNow.AddSeconds(4)
    $latest = Select-LatestLog
    if ($latest -and $latest -ne $log.Path) { Open-LogTail $latest }
}

function Update-Panel {
    $ui = $script:App.UI
    $view = $script:App.View
    $run = $script:App.Run
    $now = [DateTime]::UtcNow

    if ($run.State -eq 'running' -or $run.State -eq 'stopping') {
        Set-Text $ui.Source 'Sending from this window'
    } elseif ($script:App.Sender.Present) {
        Set-Text $ui.Source 'Read-only view of the sender already running on this laptop'
    } elseif ($script:App.Log.Path) {
        Set-Text $ui.Source 'Read-only view of the most recent run log'
    } else {
        Set-Text $ui.Source 'Waiting to start'
    }

    $linkText = 'NO RUN LOG YET'
    $linkColor = $script:Palette.Graphite
    if ($view.Connection -eq 'authenticated') { $linkText = 'LINK AUTHENTICATED'; $linkColor = $script:Palette.SignalDeep }
    elseif ($view.Connection -eq 'disconnected') { $linkText = 'LINK DISCONNECTED'; $linkColor = $script:Palette.Halt }
    if ($null -ne $view.LastRecord -and ($now - $view.LastRecord).TotalSeconds -gt 10) {
        $linkText = 'RUN LOG STALE'
        $linkColor = $script:Palette.Caution
    }
    Set-Text $ui.Link $linkText
    Set-Foreground $ui.Link $linkColor

    if ($null -eq $view.LastWrite) {
        Set-Text $ui.Age 'no writes yet'
        Set-Foreground $ui.Age $script:Palette.Graphite
    } else {
        $gap = ($now - $view.LastWrite).TotalSeconds
        if ($gap -gt 3) {
            Set-Text $ui.Age ('no write for ' + (Format-Age $gap))
            Set-Foreground $ui.Age $script:Palette.Caution
        } else {
            Set-Text $ui.Age ('last write ' + (Format-Age $gap) + ' ago')
            Set-Foreground $ui.Age $script:Palette.Ink
        }
    }

    Set-Text $ui.Unknown ([string]$view.Unknown)
    Set-Foreground $ui.Unknown $(if ($view.Unknown -gt 0) { $script:Palette.Halt } else { $script:Palette.Ink })
    Set-Text $ui.Dropped ([string]$view.Dropped)
    Set-Foreground $ui.Dropped $(if ($view.Dropped -gt 0) { $script:Palette.Caution } else { $script:Palette.Ink })
    Set-Text $ui.Started $(if ($null -eq $view.Started) { '-' } else { $view.Started.ToString('HH:mm:ss') })
    Set-Text $ui.LogName $(if ($script:App.Log.Path) { Split-Path -Leaf $script:App.Log.Path } else { 'none' })

    if ($view.Tracks.Count -eq 0) {
        Set-Text $ui.Tracks 'No writes yet.'
    } else {
        Set-Text $ui.Tracks (($view.Tracks.ToArray()) -join "`r`n")
    }

    Update-Hero
}

function Update-Tick {
    try {
        Update-SenderGuard $false
        Update-StatusProbe
        Update-LogSelection
        Update-LogTail
        if ($script:App.Run.State -eq 'running' -or $script:App.Run.State -eq 'stopping') {
            if ($null -ne $script:App.Run.Handle -and $script:App.Run.Handle.IsCompleted) { Complete-Run }
        }
        Update-Buttons
        Update-Panel
    } catch {
        Set-Message ('Panel error: ' + (Format-Safe $_.Exception.GetBaseException().Message))
    }
}

# ------------------------------------------------------------------------ main

$form = $null
try {
    Read-DemoConfig
    Initialize-StatusProbe
    $form = Build-Window
    $script:App.UI.Banner.Visible = [bool]$script:App.Config['Synthetic']
    if (-not $script:App.Config['Synthetic']) { $script:App.UI.Root.RowStyles[0].Height = 0 }
} catch {
    Show-Fatal ('The panel could not start: ' + $_.Exception.GetBaseException().Message)
    exit 1
}

if ($script:App.Problems.Count -gt 0) {
    Set-Message ($script:App.Problems[0] + '  Fix demo-config.json and start this window again.')
} else {
    Update-SenderGuard $true
    if ($script:App.Sender.Present) {
        Set-Message ($script:App.Sender.Detail + ' This window stays read-only until that stream stops.')
    } elseif ($script:App.Sender.Detail) {
        Set-Message ($script:App.Sender.Detail + ' Enter the client PFX password, then start sending.')
    } else {
        Set-Message 'Ready. Enter the client PFX password, then start sending.'
    }
}
Update-Buttons

if ($RenderPreview) {
    $form.ShowInTaskbar = $false
    $form.Show()
    for ($pass = 0; $pass -lt 6; $pass++) {
        Update-Tick
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 120
    }
    $form.Refresh()
    [Windows.Forms.Application]::DoEvents()
    $size = $form.ClientSize
    $bitmap = New-Object Drawing.Bitmap($size.Width, $size.Height)
    try {
        $form.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0, 0, $size.Width, $size.Height)))
        $directory = Split-Path -Parent $RenderPreview
        if ($directory -and -not (Test-Path -LiteralPath $directory -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $directory -Force
        }
        $bitmap.Save($RenderPreview, [Drawing.Imaging.ImageFormat]::Png)
        Write-Output ('Rendered ' + $size.Width + 'x' + $size.Height + ' preview to ' + $RenderPreview)
    } finally {
        $bitmap.Dispose()
        $form.Close()
        $form.Dispose()
    }
    exit 0
}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({ Update-Tick })
$script:App.UI.Timer = $timer
$form.Add_Shown({ $script:App.UI.Timer.Start(); Update-Tick })
[Windows.Forms.Application]::Run($form)
$form.Dispose()
