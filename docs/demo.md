# Demonstration procedure

This procedure targets two IEGs and one cellular puck. It has not yet been exercised on hardware. Run the actual mission applications; do not replace them with a dashboard that only simulates success.

## Before the run

1. Connect separate client networks behind IEG A and IEG B. Establish two usable transport paths for A and a working path for B. Record actual media and upstream dependencies.
2. Confirm the service VM, TAK client/server, shared-folder application and chosen video product are available. Record versions. Identify the exact Rally Point product, codecs and ingest/playback protocol; do not assume RTSP or KLV support from its name.
3. Verify peer identity, CISEN algorithm and security-policy configuration using authorized operator access. Confirm fresh PQ rekeying is coupled to interruption recovery and traffic release.
4. Verify both underlays independently reach the overlay service. Check captive portals, UDP restrictions, carrier-grade NAT, MTU, DNS and IPv6. A working venue Wi-Fi connection is not proof that its upstream is independent of venue Ethernet.
5. Generate the [synthetic dataset](datasets.md). Keep input hashes fixed. Rebase CoT timestamps at replay time; do not change the archived input package.
6. Establish sender/receiver logging with a shared run ID. Use a single monotonic clock for local duration measurements. For one-way delay across hosts, synchronize clocks and report the measured clock error. Preserve sender and receiver evidence separately.
7. Check app traffic cannot leave unprotected through either WAN, including IPv6 and DNS paths. Test this only on the team's equipment and authorized network.

## The visible run

| Stage | Operator action | Judge-visible evidence |
|---|---|---|
| Baseline | Send numbered messages in both directions, publish static/mobile CoT, play video, start a file transfer | Increasing received sequences, current tracks, decoded moving frames and file progress |
| Break | Physically remove A's primary uplink; retain power and LAN | Named primary path down and interruption timestamp |
| Recover | Allow existing transport policy and CISEN recovery to run | Alternate transport selected, fresh authenticated PQ epoch confirmed, protected payload delivery resumes |
| Verify | Complete the file and reconcile message logs | Correct SHA-256, unique delivery/loss counts, track age and video interruption duration |
| Restore | Reconnect the primary path and observe the configured policy | Stable fallback or deliberate failback; no oscillation or manual app-address changes |

Use a source frame counter or timestamp for live video. A local prerecorded loop can hide an upstream freeze unless the receiver also shows stream freshness. A video playing from local cache does not count as recovered network delivery.

Keep bulk transfer pressure below the point where it starves the track stream. Measure the actual puck capacity first. Rate-limiting a transfer for repeatability is acceptable if disclosed. Do not promise zero packet loss or a recovery threshold before measuring it.

## Measurements

Save raw observations under `results/<run-id>/`, separate from `data/`. Keep real addresses, captures and raw key-establishment logs private. Publish only a reviewed summary after measurement.

| Metric | Definition |
|---|---|
| Initial protected connection time | Initiation to confirmed secure readiness |
| Loss detection time | Link interruption to declared path failure |
| Underlay switch time | Declared failure to usable alternate egress |
| PQ establishment time | Start to authenticated completion of the new exchange |
| Protected recovery time | Link interruption to first successfully received mission payload under the confirmed new epoch |
| Unique delivery | Unique received message IDs divided by all attempted message IDs |
| Loss, duplicates, reordering | Reconcile IDs at both ends; report receive cutoff and late arrivals separately |
| Goodput | Unique application payload bytes received divided by the stated measurement interval |
| Track freshness | Receiver time minus source event time, with clock uncertainty |
| Video freeze | Last decoded pre-break frame to first fresh post-break frame |
| File integrity | Received file size and SHA-256 equal the trusted input manifest |
| Operator effort | Actions and elapsed setup/recovery time; distinguish automatic from manual recovery |

Report baseline, outage and recovered intervals separately. Include failed trials. After rehearsals, report median and worst observed recovery across at least five repeat runs if time permits. Five is a proposed rehearsal count, not statistical qualification.

## Negative and boundary checks

- Disable the alternate path as well. Show honest disconnected status; do not label it continuous connectivity.
- In an isolated authorized run, prevent the new PQ exchange. The system must not release mission payload over an unprotected or classical-only fallback.
- Restore the primary path repeatedly. Check hysteresis and policy stability.
- Deliver delayed CoT events. Verify expired observations are not presented as current tracks.
- Inspect egress during transition. An absence of readable plaintext in a capture alone is not proof of the negotiated algorithm.

## Pitch plan

Prepare a three-minute version and a longer operator walkthrough. Three minutes is a rehearsal choice; confirm the Washington DC stage limit with organizers.

1. Explain the operator problem in one sentence. "The team must keep its mission applications usable when an available transport disappears, without silently weakening connection security."
2. Show traffic before explaining cryptography. Pull the primary link while the judges watch.
3. Show the recovered transport, confirmed new PQ epoch and received application data on the same timeline.
4. Finish with measured recovery, intact files, unchanged application destinations, limitations and the next pilot test.

Distinguish pre-existing CISEN capabilities from work completed during the hackathon. Do not claim the PQ protocol itself is a new invention. The project contribution is the tactical integration and measured recovery evidence.
