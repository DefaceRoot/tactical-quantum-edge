# Architecture

Updated September 9, 2026. The approved synthetic-CoT run exercised primary-cable failover. The backup was selected, CoT receipts continued at about 1 Hz, and the operator confirmed continuing WinTAK tracks. Precise recovery and loss are not established.

## Live path

```text
Windows PC, source Ethernet adapter -> source IEG LAN
  -> source IEG
       primary WAN: cellular puck
       backup WAN: isolated Ethernet from the same PC's sharing adapter
                   <- Windows ICS <- independent phone Wi-Fi
  -> existing CISEN network
  -> existing virtual IEG -> existing TAK Server VM on ESXi
  -> existing protected receiver connection -> WinTAK

Linux laptop: management only
```

The Windows PC has two Ethernet adapters with separate roles. Its source adapter reaches the mission subnet through the IEG LAN. Its sharing adapter supplies only the isolated backup WAN. Windows routing and firewall rules block direct mission-subnet traffic over Wi-Fi and the sharing adapter; forced direct TCP probes timed out while the normal gateway path reached the TAK port. That establishes the checked network prerequisite, not TLS authentication or CoT delivery.

The RB5009 has no integrated Wi-Fi. Windows Internet Connection Sharing supplies the backup without a new IEG radio or driver. Sharing is enabled and the isolated WAN has a DHCP lease. The Wi-Fi upstream must remain independent of the primary puck. Two connectors on the same puck do not provide independent backhauls.

The receiver remains on its original connection; no receiving-network move is claimed. The original virtual-IEG WAN is restored. Preserve TAK, ESXi and the other physical IEG. Only explicitly approved source-gateway changes and interruptions are in scope.

## Responsibilities

| Layer | Responsibility | Evidence needed |
|---|---|---|
| Underlay | Detect failure and select an independent working uplink | Link state, selected egress and failure/switch timestamps |
| CISEN security | Authenticate peers and protect traffic using NIST-standard PQ key establishment | Actual algorithm, authenticated peer and correlated non-secret session/key-install evidence |
| Overlay routing | Keep authorized mission destinations reachable through CISEN | Authorized path and stable application destinations before and after the switch |
| Mission application | Continue or recover without endpoint reconfiguration | Independently received CoT updates and real WinTAK behavior |

The source gateway uses primary and backup host routes to the existing CISEN endpoint, with metrics 10 and 20. The primary WAN default metric is 10 to avoid a collision with the protected tunnel default. During the approved cable interruption, the endpoint route selected the backup and the protected mission default remained installed. Reconnecting the cable selected the primary again. Keys and firewall policy were preserved. This tests cable-pull behavior, not Internet-only outage detection while Ethernet stays up. No new failover package or route-reset script is needed. Multi-WAN failover is not channel bonding. [S5](sources.md#s5-transport-management)

## Protection during recovery

The goal is protected application continuity or rapid recovery. A valid session established with PQ key material may remain protected when its outer transport changes. A fresh ML-KEM exchange on every WAN switch is not required. If a fresh authenticated exchange is demonstrated, report it separately as stronger evidence.

Never release mission traffic over an unprotected fallback. Keep LAN mission traffic on the existing protected connection and preserve its security policy. Failure of a new exchange does not by itself require stopping an already-valid protected session. Do not rewrite CISEN cryptography or restart its services to manufacture a rekey demonstration.

ML-KEM establishes shared secrets; it does not by itself authenticate peers or encrypt bulk traffic. Evidence must identify the actual NIST-standard algorithm and how the deployed implementation binds its session and installed key material to an authenticated peer. Record whether authentication is classical, hybrid or post-quantum. No cryptographic certification is claimed. [S3](sources.md#s3-post-quantum-key-establishment)

Stock WireGuard is not post-quantum secure by default. Its optional PSK integration can be part of a larger PQ protocol, and roaming can change outer endpoints without a new authentication round trip. Inspect CISEN's actual integration rather than infer it from WireGuard. [S4](sources.md#s4-wireguard)

Use a run ID and pseudonymous peer/session identifiers to correlate non-secret algorithm, authentication and key-install evidence with received application data. Never display keys, PSKs, shared secrets or secret-bearing configuration. An interface name, recent WireGuard or SSH handshake, packet entropy, encrypted capture or matching file hash does not prove ML-KEM. Wi-Fi WPA2/WPA3 and management SSH are separate from CISEN's security claim.

## Mission data and visibility

The operator explicitly approved synthetic CoT for the presentation. Label it fictional, not MITRE/MARFORPAC traffic. Actual MITRE access and handling instructions are still missing; its PDF is a reference guide, not a feed. Preserve live timestamps if authorized real input later becomes available.

WinTAK's existing map is the application view. The Windows-native CoT tool supplies console and JSONL receiver observations, not a map or health/PQC badge. Correlate arrivals, source times and expiry with WinTAK; a cached icon does not prove delivery. The tool uses raw XML TAK v0 over mTLS with operator-supplied client and trust PFX files. It does not install certificates in the OS certificate stores. Client-key import uses Windows user-key handling without requesting persistent storage; this is not an all-memory guarantee. A Windows mTLS probe succeeded without CoT payloads. Application receipt and CISEN PQ evidence remain separate checks. See the [tool procedure](demo.md#windows-cot-tool).

The deployed Windows demo window has Start and Stop controls for its replay sender. WinTAK remains the map. The live WAN panel was omitted at the operator's request after a Windows SSH-client problem; do not imply the window shows current gateway routing or PQ status. Read-only route inspection is separate.

The completed WILDTRACK recording is separate from this live topology. It does not establish live CoT interoperability or this path's recovery and security properties.

## Challenge coverage and limits

The selected challenge calls for two edges, NIST-standard PQ key establishment, two transport types, unchanged IP mission applications, continuity or rapid recovery, reduced topology exposure, operator status and rapid deployment with dependencies disclosed. Synthetic-CoT cable-pull observations cover part of that evidence. Precise connection time, throughput, recovery, loss and deployed PQ evidence are not established. [S1](sources.md#s1-event)

Report session continuity separately from automatic application recovery. Neither a restored route nor attempted sends prove delivery. Goodput measures received application data under the stated workload; it is not a link-capacity benchmark. Loss needs matchable event identifiers at sender and receiver.

CISEN and the existing virtual IEG/TAK service remain dependencies. The demo tests one transport interruption, not server failover, RF jamming, satellite service, disconnected delivery or production scale. Satellite is an architectural option, not demonstrated equipment. Private addressing and randomized relay paths do not prove anonymity or hide all timing, volume and topology information. Keep operational details private and show judges only reviewed, redacted status.
