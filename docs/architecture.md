# Architecture

Updated September 9, 2026. The live wiring below is proposed, not a completed failover test.

## Live path

```text
Linux source on A's LAN
  -> physical IEG A
       primary WAN: cellular puck A
       secondary WAN: isolated Ethernet from Windows Wi-Fi-sharing PC
  -> existing CISEN network
  -> existing virtual IEG -> existing TAK Server VM on ESXi
  -> existing CISEN network
  -> physical IEG B -> Windows receiver running WinTAK
       WAN: separate cellular puck B
```

The sharing PC supplies only A's secondary uplink. It is not the mission source. Keeping the source behind A prevents its traffic from bypassing the gateway under test. A needs two simultaneous uplinks; putting a different uplink on B does not provide failover for A. The secondary Wi-Fi upstream must be independent of puck A. Ethernet and Wi-Fi from the same puck share its failure domain.

The RB5009 has no integrated Wi-Fi. A PC sharing phone or public Wi-Fi avoids installing a radio or driver on the IEG. PC sharing and A's secondary WAN are not configured or tested. Inspect PC adapters and gateway port membership first. Never connect a sharing interface to an existing production LAN: its DHCP and address changes could disrupt other users. Repurposing a LAN port as WAN requires explicit approval.

Keep B and the existing TAK service reachable while interrupting only A's primary uplink. Preserve ESXi, TAK, all IEG configuration and the existing CISEN network. Start read-only, confirm the interruption will not affect other users, and obtain approval for each exact operational change with its impact and rollback. No resets, reboots, VM power changes, vSwitch changes, firewall disabling or unapproved drivers.

## Responsibilities

| Layer | Responsibility | Evidence needed |
|---|---|---|
| Underlay | Detect failure and select an independent working uplink | Link state, selected egress and failure/switch timestamps |
| CISEN security | Authenticate peers and protect traffic using NIST-standard PQ key establishment | Actual algorithm, authenticated peer and correlated non-secret session/key-install evidence |
| Overlay routing | Keep authorized mission destinations reachable through CISEN | Authorized path and stable application destinations before and after the switch |
| Mission application | Continue or recover without endpoint reconfiguration | Independently received CoT updates and real WinTAK behavior |

Inspect the existing transport policy before choosing any changes. Do not assume an installed or missing package proves how a custom IEG handles failover. Reuse compatible existing mechanisms rather than install a competing manager. OpenWrt's mwan3 documentation distinguishes version-specific implementations and warns about compatibility. Multi-WAN failover is not channel bonding. [S5](sources.md#s5-transport-management)

## Protection during recovery

The goal is protected application continuity or rapid recovery. A valid session established with PQ key material may remain protected when its outer transport changes. A fresh ML-KEM exchange on every WAN switch is not required. If a fresh authenticated exchange is demonstrated, report it separately as stronger evidence.

Never release mission traffic over an unprotected fallback. Keep LAN mission traffic on the existing protected connection and preserve its security policy. Failure of a new exchange does not by itself require stopping an already-valid protected session. Do not rewrite CISEN cryptography or restart its services to manufacture a rekey demonstration.

ML-KEM establishes shared secrets; it does not by itself authenticate peers or encrypt bulk traffic. Evidence must identify the actual NIST-standard algorithm and how the deployed implementation binds its session and installed key material to an authenticated peer. Record whether authentication is classical, hybrid or post-quantum. No cryptographic certification is claimed. [S3](sources.md#s3-post-quantum-key-establishment)

Stock WireGuard is not post-quantum secure by default. Its optional PSK integration can be part of a larger PQ protocol, and roaming can change outer endpoints without a new authentication round trip. Inspect CISEN's actual integration rather than infer it from WireGuard. [S4](sources.md#s4-wireguard)

Use a run ID and pseudonymous peer/session identifiers to correlate non-secret algorithm, authentication and key-install evidence with received application data. Never display keys, PSKs, shared secrets or secret-bearing configuration. An interface name, recent WireGuard or SSH handshake, packet entropy, encrypted capture or matching file hash does not prove ML-KEM. Wi-Fi WPA2/WPA3 and management SSH are separate from CISEN's security claim.

## Mission data and visibility

The live input must be the selected MITRE CoT feed or an organizer-approved recording of that dataset. Access and handling instructions are still missing. The guide PDF is not traffic, and the repository's synthetic generator is not a substitute. Real feed tracks may be stationary; motion is not an acceptance condition.

WinTAK's existing map is the application view. A cached icon does not prove new delivery. Correlate receiver arrival time, source event time and expiry with the map. A small laptop-only receiver-status display may help if needed, but none has been built. Do not add a new ESXi or server UI.

The completed WILDTRACK recording is separate from this live topology. It does not establish live CoT interoperability or this path's recovery and security properties.

## Challenge coverage and limits

The selected challenge calls for two edges, NIST-standard PQ key establishment, two transport types, unchanged IP mission applications, continuity or rapid recovery, reduced topology exposure, operator status and rapid deployment with dependencies disclosed. The evidence package must cover the live proof, architecture, connection time, delivered throughput and recovery measurements. These remain planned evidence, not measured results. [S1](sources.md#s1-event)

Report session continuity separately from automatic application recovery. Neither a restored route nor attempted sends prove delivery. Goodput measures received application data under the stated workload; it is not a link-capacity benchmark. Loss needs matchable event identifiers at sender and receiver.

CISEN and the existing virtual IEG/TAK service remain dependencies. The demo tests one transport interruption, not server failover, RF jamming, satellite service, disconnected delivery or production scale. Satellite is an architectural option, not demonstrated equipment. Private addressing and randomized relay paths do not prove anonymity or hide all timing, volume and topology information. Keep operational details private and show judges only reviewed, redacted status.
