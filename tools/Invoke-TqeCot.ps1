#Requires -Version 5.1
<#
.SYNOPSIS
Connects real CoT input and an independent receiver to an existing TAK TLS server.

.DESCRIPTION
Runs on Windows PowerShell 5.1 with .NET Framework 4.8. Compiles the sibling
TqeCot.cs in memory once per PowerShell process. No Python, module installation,
certificate-store import, or execution-policy changes are required.

Use the actual authorized MITRE dataset or live feed for the primary demo.
This tool does not download data or generate substitute tracks. Replay accepts
UTF-8 XML event fragments or one XML root with direct CoT event children. Events
are limited to 64 KiB and XML nesting to 64 levels. DTDs and external entities
are prohibited. Replay validates the whole file before transmission and requires
nondecreasing event times. The TLS receiver expects XML CoT, not TAK Protocol
protobuf messages.

Replay preserves UID, callsign, and payload fields. Only -RefreshReplayTimes
changes time, start, and stale, using one common offset per replay loop. Speed
changes pacing only, not timestamp intervals. Live UDP relay forwards valid XML
bytes without changing payload timestamps or identities. Supply one complete
CoT event per UDP datagram. UDP has no delivery guarantee. Reconnection does not
create an unbounded retry queue; events can be dropped during an outage.
Replay waits each source-time interval after the previous write, so transport
stalls extend the run rather than trigger a catch-up burst.

ServerAddress selects the network destination. ServerName must match the TLS
server certificate. TLS 1.2 or later and hostname checking are required. The
client PFX authenticates this connection; the trust PFX supplies the only trusted
CA anchors. Certificates are not installed in the Windows certificate store.
Windows may use a temporary user key container for the client private key.
Trust certificates use ephemeral import. Passwords come only from the named
process environment variables. Set these privately before invoking the script.
Do not put passwords in command lines, scripts, shell history, or logs. Keep
certificates, datasets, and operational logs outside the public repository.
Environment variables and in-memory passwords are not a secret vault.
Certificate revocation is not checked.

Long-running modes require a new JSONL log path. Existing logs are not silently
overwritten. Logs contain metadata rather than full raw payloads. UID metadata
can still be sensitive. The parent directory must already exist.

Sender attempts do not prove delivery. Use Receive separately to record received
UIDs and arrival times, and use WinTAK for the map and interoperability evidence.
CLI counters and TLS connectivity do not prove post-quantum protection or zero
loss. DisplayName labels console/log output only; it does not rename tracks or
the certificate identity. Press Ctrl+C in a PowerShell console to stop a long
mode. Do not run this script in PowerShell ISE.

.PARAMETER Probe
Performs a TLS connection and client authentication without sending CoT events.

.PARAMETER Replay
Replays a real local XML CoT file using source-event timing.

.PARAMETER Relay
Relays an authorized live UDP XML CoT feed to the TLS connection.

.PARAMETER Receive
Receives XML CoT and records independent receipt metadata without printing positions.

.PARAMETER ServerAddress
Required network destination, as an IP address or DNS name.

.PARAMETER ServerName
Required TLS hostname from the server certificate. Hostname checking is mandatory.

.PARAMETER Port
TAK TLS port. Defaults to 8089.

.PARAMETER ClientPfx
Path to the private client PKCS#12 file containing its certificate and private key.

.PARAMETER TrustPfx
Path to the PKCS#12 file containing the trusted CA certificates.

.PARAMETER ClientPasswordEnvironmentVariable
Process environment variable containing the client PFX password.
Defaults to TQE_CLIENT_PFX_PASSWORD. This parameter is a variable name, not a password.

.PARAMETER TrustPasswordEnvironmentVariable
Process environment variable containing the trust PFX password.
Defaults to TQE_TRUST_PFX_PASSWORD. This parameter is a variable name, not a password.

.PARAMETER DisplayName
Console/log client label. Defaults to Hackathon. Does not alter input or certificates.

.PARAMETER InputFile
Required real CoT XML file for Replay. No built-in dataset is supplied.

.PARAMETER RefreshReplayTimes
Explicitly rebases replay time, start, and stale by a common offset. Live relay
never rebases timestamps. Without this switch, old replay events may be stale.

.PARAMETER Speed
Positive finite replay pacing multiplier. Defaults to 1 for source timing.

.PARAMETER Loop
Repeats the replay file until Ctrl+C. No track identities are generated.

.PARAMETER BindAddress
Local UDP bind address for Relay. Defaults to 127.0.0.1. Bind a LAN address only
when intentionally accepting an authorized feed. No firewall rules are changed.

.PARAMETER UdpPort
Required UDP listening port for Relay, between 1 and 65535.

.PARAMETER Uids
Optional exact UID filter for Receive. Omit to log all received events. Use the
MITRE input UIDs to avoid recording unrelated production tracks.

.PARAMETER LogPath
Required new JSONL file path for Replay, Relay, and Receive. Not accepted by Probe.

.EXAMPLE
.\tools\Invoke-TqeCot.ps1 -Probe -ServerAddress tak.example.test `
    -ServerName tak.example.test -ClientPfx C:\TqePrivate\client.p12 `
    -TrustPfx C:\TqePrivate\trust.p12

After privately setting both password environment variables, checks TLS only.
The example hostname is reserved and must be replaced with the authorized server.

.EXAMPLE
.\tools\Invoke-TqeCot.ps1 -Replay -ServerAddress tak.example.test `
    -ServerName tak.example.test -ClientPfx C:\TqePrivate\client.p12 `
    -TrustPfx C:\TqePrivate\trust.p12 -InputFile C:\TqePrivate\mitre-input.xml `
    -RefreshReplayTimes -Speed 1 -LogPath C:\TqePrivate\replay-run-01.jsonl

Replays an operator-supplied MITRE file with refreshed timestamps. File names are
examples, not included data. Use a new log name for each run.

.EXAMPLE
.\tools\Invoke-TqeCot.ps1 -Relay -ServerAddress tak.example.test `
    -ServerName tak.example.test -ClientPfx C:\TqePrivate\client.p12 `
    -TrustPfx C:\TqePrivate\trust.p12 -UdpPort 17012 `
    -LogPath C:\TqePrivate\relay-run-01.jsonl

Accepts a real local feed on loopback only and leaves its timestamps unchanged.

.EXAMPLE
.\tools\Invoke-TqeCot.ps1 -Receive -ServerAddress tak.example.test `
    -ServerName tak.example.test -ClientPfx C:\TqePrivate\client.p12 `
    -TrustPfx C:\TqePrivate\trust.p12 -LogPath C:\TqePrivate\receive-run-01.jsonl

Records independent receipt metadata. Add -Uids with the actual input UID values
to restrict logging. Use WinTAK separately for the map.
#>
[CmdletBinding(DefaultParameterSetName = 'Probe')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Probe')]
    [switch]$Probe,

    [Parameter(Mandatory = $true, ParameterSetName = 'Replay')]
    [switch]$Replay,

    [Parameter(Mandatory = $true, ParameterSetName = 'Relay')]
    [switch]$Relay,

    [Parameter(Mandatory = $true, ParameterSetName = 'Receive')]
    [switch]$Receive,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerAddress,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,

    [ValidateRange(1, 65535)]
    [int]$Port = 8089,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientPfx,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TrustPfx,

    [ValidateNotNullOrEmpty()]
    [string]$ClientPasswordEnvironmentVariable = 'TQE_CLIENT_PFX_PASSWORD',

    [ValidateNotNullOrEmpty()]
    [string]$TrustPasswordEnvironmentVariable = 'TQE_TRUST_PFX_PASSWORD',

    [ValidateNotNullOrEmpty()]
    [string]$DisplayName = 'Hackathon',

    [Parameter(Mandatory = $true, ParameterSetName = 'Replay')]
    [ValidateNotNullOrEmpty()]
    [string]$InputFile,

    [Parameter(ParameterSetName = 'Replay')]
    [switch]$RefreshReplayTimes,

    [Parameter(ParameterSetName = 'Replay')]
    [ValidateScript({ $_ -gt 0 -and -not [double]::IsNaN($_) -and -not [double]::IsInfinity($_) })]
    [double]$Speed = 1,

    [Parameter(ParameterSetName = 'Replay')]
    [switch]$Loop,

    [Parameter(ParameterSetName = 'Relay')]
    [ValidateNotNullOrEmpty()]
    [string]$BindAddress = '127.0.0.1',

    [Parameter(Mandatory = $true, ParameterSetName = 'Relay')]
    [ValidateRange(1, 65535)]
    [int]$UdpPort,

    [Parameter(ParameterSetName = 'Receive')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Uids,

    [Parameter(Mandatory = $true, ParameterSetName = 'Replay')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Relay')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Receive')]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$clientPassword = $null
$trustPassword = $null
$options = $null
$exitCode = 1

function Resolve-FileSystemPath([string]$Path) {
    $provider = $null
    $drive = $null
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $Path, [ref]$provider, [ref]$drive)
    if ($provider.Name -ne 'FileSystem') {
        throw 'Certificate, input, and log paths must use the FileSystem provider.'
    }
    return $resolved
}

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
        $PSVersionTable.PSEdition -ne 'Desktop' -or
        $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -lt 1) {
        throw 'Use Windows PowerShell 5.1 with .NET Framework 4.8, not PowerShell Core.'
    }
    if ($Host.Name -eq 'Windows PowerShell ISE Host') {
        throw 'Run this script in a Windows PowerShell console, not PowerShell ISE.'
    }
    $frameworkRelease = [Microsoft.Win32.Registry]::GetValue(
        'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full',
        'Release', 0)
    if ([int]$frameworkRelease -lt 528040) {
        throw '.NET Framework 4.8 or later is required. This script does not install it.'
    }
    if (-not $PSBoundParameters[$PSCmdlet.ParameterSetName]) {
        throw 'Select one enabled mode switch: -Probe, -Replay, -Relay, or -Receive.'
    }

    $clientPassword = [Environment]::GetEnvironmentVariable(
        $ClientPasswordEnvironmentVariable, [EnvironmentVariableTarget]::Process)
    $trustPassword = [Environment]::GetEnvironmentVariable(
        $TrustPasswordEnvironmentVariable, [EnvironmentVariableTarget]::Process)
    if ($null -eq $clientPassword) {
        throw 'The client PFX password environment variable is not set in this process.'
    }
    if ($null -eq $trustPassword) {
        throw 'The trust PFX password environment variable is not set in this process.'
    }

    if (-not ('TqeDemo.Runner' -as [type])) {
        $sourcePath = Join-Path $PSScriptRoot 'TqeCot.cs'
        Add-Type -Path $sourcePath -ReferencedAssemblies @(
            'System.dll', 'System.Core.dll', 'System.Xml.dll',
            'System.Xml.Linq.dll', 'System.Web.Extensions.dll')
    }

    $options = New-Object TqeDemo.ConnectionOptions
    $options.ServerAddress = $ServerAddress
    $options.ServerName = $ServerName
    $options.Port = $Port
    $options.ClientPfxPath = Resolve-FileSystemPath $ClientPfx
    $options.TrustPfxPath = Resolve-FileSystemPath $TrustPfx
    $options.ClientPassword = $clientPassword
    $options.TrustPassword = $trustPassword
    $options.DisplayName = $DisplayName

    if ($PSCmdlet.ParameterSetName -ne 'Probe') {
        $LogPath = Resolve-FileSystemPath $LogPath
    }
    switch ($PSCmdlet.ParameterSetName) {
        'Probe' { $exitCode = [TqeDemo.Runner]::Probe($options) }
        'Replay' {
            $InputFile = Resolve-FileSystemPath $InputFile
            $exitCode = [TqeDemo.Runner]::Replay(
                $options, $InputFile, [bool]$RefreshReplayTimes, $Speed, [bool]$Loop, $LogPath)
        }
        'Relay' { $exitCode = [TqeDemo.Runner]::Relay($options, $BindAddress, $UdpPort, $LogPath) }
        'Receive' { $exitCode = [TqeDemo.Runner]::Receive($options, $Uids, $LogPath) }
    }
}
catch {
    $message = $_.Exception.GetBaseException().Message
    foreach ($secret in @($clientPassword, $trustPassword)) {
        if (-not [string]::IsNullOrEmpty($secret)) {
            $message = $message.Replace($secret, '[redacted]')
        }
    }
    [Console]::Error.WriteLine('TQE CoT: ' + $message)
    $exitCode = 1
}
finally {
    if ($null -ne $options) {
        $options.ClientPassword = $null
        $options.TrustPassword = $null
    }
    $clientPassword = $null
    $trustPassword = $null
}
exit $exitCode
