# Demonstration procedure

Updated September 9, 2026. The presentation uses explicitly approved synthetic CoT, not MITRE/MARFORPAC data. An approved primary-cable interruption selected the backup while the protected mission route remained installed. CoT receipts continued at about 1 Hz, and the operator confirmed continuing WinTAK tracks. Reconnection selected the primary again. No zero-loss, precise recovery-time or PQ certification claim is made. The [WILDTRACK SMB recording](../demo/SMB_Transfer_WAN_Failover.mp4) is a separate setup.

## Before the live run

1. Use the explicitly approved synthetic presentation input and label it fictional. The actual MITRE feed remains unavailable: its catalog supplies a router guide, no endpoint, port, replay corpus or DSA. This prevents use of that feed, not the synthetic presentation.
2. Keep input mode and event identity clear. For an authorized recording, refresh `time`, `start` and `stale` together and preserve UIDs. Never rewrite delayed live observations to look fresh.
3. Preserve the existing TAK Server VM, virtual IEG and CISEN path. Windows mTLS and synthetic CoT receipt have been exercised, and the operator confirmed WinTAK updates through the interruption. The receiver keeps its original connection.
4. Use the compact kit's Windows PC for both sending and Wi-Fi sharing. One Ethernet adapter connects to the source IEG LAN; the second feeds its isolated backup WAN. ICS is enabled, and that WAN has a DHCP lease. The Linux laptop is management-only. Keep the sharing adapter off production LANs.
5. Preserve the Windows mission-subnet route through the source IEG and direct-path firewall blocks on Wi-Fi and the sharing adapter. Forced direct TCP probes timed out; the normal gateway path reached the TAK port. Confirm independent upstream connectivity before a run. These checks do not prove application delivery or PQ protection.
6. Preserve the tested endpoint-route policy and primary WAN default metric. The cable-pull run selected the backup without losing the protected mission default; reconnection selected the primary. Internet-only outage detection is not claimed.
7. Obtain non-secret evidence of the deployed PQ algorithm, authenticated peer and installed session. An existing valid PQ-established session may continue across a switch; a fresh exchange on every switch is not required.
8. Establish independent sender and receiver observations with a shared run ID. Use monotonic clocks for local intervals. Establish synchronization and uncertainty for cross-host event age. A sender log proves attempted transmission, not receipt.
9. Obtain separate approval before interrupting the primary WAN and confirm that other users are unaffected. Do not reset or reboot equipment, change VM power or vSwitches, disable firewalls or install unapproved drivers.

## Windows CoT tool

Run `tools/Invoke-TqeCot.ps1` beside `tools/TqeCot.cs` on Windows PowerShell 5.1 with .NET Framework 4.8. No Python or external dependencies are needed. The separate synthetic generator still requires Python.

For the deployed presentation, open `Start-TqeDemo.cmd` to launch `Show-TqeDemo.ps1`. Start runs the configured synthetic replay; Stop cancels that window's sender. Start/Stop cancellation was exercised, and the operator is testing Start in the deployed window. The previous background sender was stopped at the operator's request. Use one sender to avoid duplicate tracks.

The window is a replay control, not WinTAK's map. Its live WAN panel was skipped at the operator's request after a Windows SSH-client problem. Do not add status fields to the private configuration or imply the window displays live gateway/PQ state. Read-only gateway CLI inspection remains separate.

Choose exactly one mode, `-Probe`, `-Replay`, `-Relay` or `-Receive`. All require `-ServerAddress`, `-ServerName`, `-ClientPfx` and `-TrustPfx`. The address is the approved connection destination; the name must match the server certificate. `-Port` defaults to `8089`, and the local `-DisplayName` defaults to `Hackathon`. That label does not rewrite dataset UIDs or callsigns.

Supply PFX passwords privately through `TQE_CLIENT_PFX_PASSWORD` and `TQE_TRUST_PFX_PASSWORD` in the process environment, never as command-line arguments, committed values or transcript output. The tool does not install certificates in Windows certificate stores. Client import uses `UserKeySet` without `PersistKeySet` for SChannel compatibility; trust import is ephemeral. Do not claim that all private-key handling stays in memory. Use an authorized non-admin client identity.

After privately setting those environment variables, fill these variables with operator-approved values:

```powershell
$connection = @{
    ServerAddress = $ApprovedServerAddress
    ServerName = $CertificateServerName
    ClientPfx = $ClientPfxPath
    TrustPfx = $TrustPfxPath
}
.\tools\Invoke-TqeCot.ps1 -Probe @connection
```

`-Probe` checks mTLS without sending CoT. A Windows probe to the existing TAK service succeeded with the authorized client and supplied CA. Separate synthetic replay and receive observations exercised application delivery; a TLS handshake alone would not prove it. Neither result establishes CISEN's PQ algorithm.

For an authorized recording:

```powershell
.\tools\Invoke-TqeCot.ps1 -Replay @connection `
    -InputFile $ApprovedRecording -RefreshReplayTimes -Speed 1 `
    -LogPath $NewSenderLog
```

Replay accepts event fragments or one XML wrapper containing direct `event` children. Events need ordered timestamps for pacing. `-RefreshReplayTimes` optionally shifts `time`, `start` and `stale` together while preserving UIDs. `-Speed` controls pacing; `-Loop` repeats the recording. Do not use replay to relabel delayed live observations as current.

For an authorized live UDP feed:

```powershell
.\tools\Invoke-TqeCot.ps1 -Relay @connection `
    -BindAddress $ApprovedLocalBindAddress -UdpPort $ApprovedUdpPort `
    -LogPath $NewSenderLog
```

`-UdpPort` is required. `-BindAddress` defaults to `127.0.0.1`; an external feed needs an explicitly approved local bind address and delivery path. Relay preserves live timestamps. Both send modes forward raw XML TAK v0 over mTLS. XML is limited to 64 KiB and depth 64, with DTDs prohibited.

Run an independent receiver on the receiver host:

```powershell
.\tools\Invoke-TqeCot.ps1 -Receive @connection `
    -Uids $DatasetUids -LogPath $NewReceiverLog
```

`-Uids` is optional; filter to the presentation's synthetic tracks, or actual MITRE tracks if authorized access is later supplied. Each long mode requires `-LogPath` and creates a new file rather than overwriting one. Keep JSONL logs private. Console and log records are observations, not a map, health badge or proof of PQ protection. Keep WinTAK visible separately.

## Visible run

| Stage | Operator action | Judge-visible evidence |
|---|---|---|
| Baseline | Deliver the approved, clearly labeled synthetic input through the source IEG, CISEN and existing TAK service | Independent received updates, event time/expiry and WinTAK tracks |
| Break | Disconnect only the source IEG's separately approved primary uplink, retaining LAN and power | Primary path down and interruption timestamp |
| Recover | Observe whether the configured host-route policy selects the backup WAN | Alternate egress, valid protected session evidence and newly received application data |
| Verify | Reconcile observations from both ends | Recovery interval, delivery counts where matchable, freshness and any observed loss |
| Restore | Reconnect the primary and observe existing policy | Stable operation without manual application-address changes; record whether failback occurs |

Use WinTAK's existing map and keep the independent receiver console visible. Receiver records must show actual receipt, not sender counters or simulated success. Do not add a new server UI.

A stationary track can be current. A moving or persistent icon can be cached. Show the last receiver arrival, original event time and `stale` expiry so judges can distinguish them. Never make delayed live events look fresh by rewriting their timestamps.

Present the WILDTRACK recording as the team's completed recorded transfer demo. Do not imply that it tests this live wiring or proves zero loss, measured recovery, throughput or PQ protection. A matching file hash, if actually measured at both ends, proves file integrity against that reference, not the transport's cryptographic algorithm.

## Measurements

Keep raw observations under `results/<run-id>/`, separate from dataset inputs and outside Git. Keep real addresses, operational captures and raw security logs private. Publish only a reviewed summary of measurements actually taken.

| Metric | Definition |
|---|---|
| Initial protected connection time | Initiation to confirmed protected readiness; a pre-existing session has no new setup measurement unless setup is actually observed |
| Failure detection time | Primary interruption to declared path failure |
| Underlay switch time | Declared failure to usable secondary egress |
| Application recovery time | Interruption to first new mission payload received through the confirmed protected path |
| Session outcome | State whether the existing session continued, a connection recovered automatically, or an operator restarted it |
| PQ exchange time, if observed | Exchange start to authenticated completion and confirmed key installation |
| Unique delivery and loss | Match eligible sent events to received events by stable event identifiers, using a stated receive cutoff and reporting late arrivals |
| Duplicates and reordering | Compare matchable event identities and ordering at both ends |
| Goodput | Unique application payload bytes received divided by the stated interval |
| Track freshness | Receiver time minus original event time, with clock uncertainty and expiry status |
| Operator effort | Setup and recovery actions, elapsed time and required infrastructure |

A CoT track UID identifies a track, not necessarily each update. Establish an event-level matching method from the authorized data before calculating loss. Sender counts alone are insufficient. If no reliable event matching is available, report observed arrivals and gaps, not an end-to-end loss percentage. Count receiver-side application bytes without duplicates where possible and disclose the counting method.

Report baseline, outage and recovered intervals separately. CoT delivery rate and goodput describe the offered workload, not the capacity of the uplink or CISEN. Record dependencies and failed trials. If multiple rehearsals are approved, report the number of runs and observed range rather than promise a threshold before measurement.

## Boundary checks

Perform disruptive checks only in an isolated, explicitly approved setup.

- If both uplinks are unavailable, show disconnected status rather than continuous connectivity.
- Check that recovery never sends mission data through an unprotected fallback. Do not invalidate a working protected session merely to force a new exchange.
- Observe primary restoration for unstable switching. Report actual policy behavior.
- Check how expired or delayed CoT appears at the receiver. A retained icon must not be described as a fresh update.
- Correlate transport, security state and receiver delivery. An encrypted-looking packet capture alone does not establish the algorithm.

## Presentation

Show the WILDTRACK recording separately, then demonstrate the approved synthetic replay and explain its path and dependencies. Label every synthetic track as fictional in the presentation. Explain that the actual MITRE/MARFORPAC feed and its DSA remain unavailable; do not claim these generated events came from it.

Finish with only measured results, unchanged application destinations and remaining limits. Distinguish pre-existing CISEN capabilities from hackathon integration work. Prepare a short version, but confirm the stage time with organizers rather than treat a rehearsal length as an event rule.
