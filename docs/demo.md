# Demonstration procedure

Updated September 9, 2026. The WILDTRACK SMB transfer recording is complete according to the team. It used a different setup and is separate from the live procedure below. No live failover, delivery or PQ measurements are claimed yet.

## Before the live run

1. Obtain organizer instructions for the selected MITRE CoT dataset. The catalog describes a MARFORPAC XML/UDP stream to an external IPv4 address, but supplies no feed endpoint, port, approved replay files or Data Sharing Agreement. The linked MITRE PDF is a router guide. Do not replace the required dataset with generated events without renewed explicit approval.
2. Confirm delivery, authorization and handling terms. Establish whether the input is live or an approved recording, how it reaches the Linux source laptop, and which CoT fields identify individual events. Do not assume the feed contains moving tracks. A live feed's delayed events must retain their real timestamps. Rebase timestamps only for an authorized recorded replay and label that transformation.
3. Preserve the existing TAK Server VM, virtual IEG and CISEN path. WinTAK is reported running; use its existing map. Confirm authorized ingress and client compatibility without changing production services. No replay sender or additional receiver-status code has been built yet.
4. Inspect the Windows sharing PC's adapters and A's port membership read-only. Obtain approval for exact sharing and secondary-WAN changes, their impact and rollback. The sharing connection must not join an existing production LAN. PC sharing and dual WAN are not configured or tested.
5. Keep the Linux source on A's LAN. A's primary WAN uses puck A; its isolated secondary WAN uses Ethernet from the separate PC sharing phone or public Wi-Fi. B stays on puck B with WinTAK on its LAN. Verify the secondary upstream is independent of A's primary, and check captive portals, NAT, UDP restrictions and MTU. Two different uplinks on separate IEGs alone are not failover.
6. Confirm non-secret evidence for the actual PQ algorithm, authenticated peer and installed session. Plan to show either continuity of a valid PQ-established session or a fresh authenticated exchange. A fresh exchange on every switch is not required. Check that mission traffic has no unprotected bypass; preserve existing security rules.
7. Establish independent sender and receiver observations with a shared run ID. Use monotonic clocks for local intervals. For cross-host delay or event age, establish clock synchronization and report uncertainty. A sender log proves attempted transmission, not receipt.
8. Confirm that interrupting A's primary WAN cannot affect other users. Obtain exact change approval before the run. Do not reset or reboot equipment, change VM power or vSwitches, disable firewalls or install unapproved drivers.

## Visible run

| Stage | Operator action | Judge-visible evidence |
|---|---|---|
| Baseline | Deliver the authorized MITRE input through A, CISEN, the existing TAK service and B to WinTAK | Actual received updates, event age/expiry, WinTAK tracks and selected transport |
| Break | Disconnect only A's approved primary uplink, retaining LAN and power | Primary path down and interruption timestamp |
| Recover | Let the approved transport policy use A's secondary WAN | Alternate egress, valid protected session evidence and newly received application data |
| Verify | Reconcile observations from both ends | Recovery interval, delivery counts where matchable, freshness and any observed loss |
| Restore | Reconnect the primary and observe existing policy | Stable operation without manual application-address changes; record whether failback occurs |

Use WinTAK's existing map rather than build a custom map. Keep an independent receiver record visible if possible. An optional laptop-only status display would need real receiver observations, not sender counters or simulated success. Do not add a new server UI for the demo.

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

Show the completed WILDTRACK recording separately, then explain the planned live path and its dependencies. If authorized MITRE access is available, show real traffic, interrupt the approved uplink and present the recovery timeline. If access is still missing, state that blocker; do not quietly substitute synthetic input.

Finish with only measured results, unchanged application destinations and remaining limits. Distinguish pre-existing CISEN capabilities from hackathon integration work. Prepare a short version, but confirm the stage time with organizers rather than treat a rehearsal length as an event rule.
