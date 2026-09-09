# Sources and evidence boundaries

Updated September 9, 2026. General references below come from September 8 research; the authenticated dataset selections and catalog description were rechecked September 9. This edit does not claim a new link check or a hardware test. Sources explain requirements and component behavior, not certification of this project.

## S1. Event

- [NDIA conference hackathon overview](https://www.ndiatechexpo.org/hackathon). September 8-10, 2026, Washington DC.
- [Maximus event overview](https://maximus.com/events/ndia). Venue and event context.
- [Washington DC judging criteria](https://ndia.hackathon-portal.maximus.com/event/ndia-global-defense-hackathon-main-event-washington-dc/judging-criteria). Authenticated source; private research notes are not reproduced here.
- [Washington DC schedule](https://ndia.hackathon-portal.maximus.com/event/ndia-global-defense-hackathon-main-event-washington-dc/schedule). Confirm current stage timing with organizers.
- [Selected challenge](https://ndia.hackathon-portal.maximus.com/event/ndia-global-defense-hackathon-main-event-washington-dc/use-cases/129). AME Survivable Post-Quantum Tactical Edge Communications. Requirements include two edges, NIST-standard PQ key establishment, two transport types, unchanged IP applications, continuity or rapid recovery, reduced topology exposure, operator status and rapid deployment with dependencies disclosed. Prepare the required live proof, architecture and connection-time, throughput and recovery evidence. No custom map or fresh ML-KEM exchange on every WAN switch is required.
- [Participant Terms & Agreement, v1.2](https://hackathon.ndia.org/api/events/3/legal-document/terms/?v=1.2). Sections 8-10 cover licensing, rights and data handling. Section 8 refers to GitLab and requires a licensing slide. Team CIS's judge repository remains [GitHub](https://github.com/DefaceRoot/tactical-quantum-edge); do not create a GitLab project. Clarify the wording with organizers without moving the repository. Licensing disclosure still needs owner approval. No new license for CISEN or third-party material is granted here.

## S2. Cursor-on-Target

- [MITRE, Cursor-on-Target Message Router User's Guide](https://www.mitre.org/sites/default/files/pdf/09_4937.pdf), Michael J. Kristan, Jeffrey T. Hamalainen, Douglas P. Robbins and Patrick J. Newell, November 2009. Section 2.1, pages 2-1 and 2-2, provides an example and required-field table. This is a router guide, not a replayable dataset. The example omits `how`, although Table 2-1 requires it; the original synthetic generator includes it.
- Direct PDF retrieval returned HTTP 403 during the earlier research. Text was inspected through [Jina Reader](https://r.jina.ai/https://www.mitre.org/sites/default/files/pdf/09_4937.pdf). Original figures and a downloaded XSD were not validated. Public-release marking retains MITRE copyright; it is not an open-source license.
- [Event dataset catalog](https://ndia.hackathon-portal.maximus.com/event/ndia-global-defense-hackathon-main-event-washington-dc/datasets). September 9 inspection confirmed MITRE Cursor on Target Standard and WILDTRACK selected. The MITRE entry describes a MARFORPAC XML/UDP feed, refers to a DSA and links only the guide. No feed endpoint, port, replay files or agreement has been supplied. Actual feed access is blocked; the operator separately approved synthetic CoT for the presentation.
- [TAK Product Center server repository](https://github.com/TAK-Product-Center/Server). Official source for software, license and compatibility information, not evidence about this deployment. The plan retains the existing TAK Server and WinTAK. WinTAK is reported running; live MITRE ingestion and recovery remain unverified.

The presentation now uses explicitly approved synthetic CoT, not MITRE/MARFORPAC data. Timestamp rebasing applies only to authorized recorded replay, never delayed live events. A track need not move to be current; a cached map icon does not establish fresh receipt.

The Windows-native CoT tool provides mTLS probe, replay, UDP relay and receive modes. Its [usage contract](demo.md#windows-cot-tool) is project integration work, not upstream certification. It uses raw XML TAK v0 and operator-supplied PFX files with password environment variables, without certificate-store installation. Client import uses Windows user-key handling, not an all-memory guarantee. The Windows mTLS probe succeeded without CoT. Separate synthetic-CoT receipts continued at about 1 Hz during the cable interruption, and the operator confirmed continuing WinTAK tracks. The demo window controls replay; its live WAN panel was skipped.

## S3. Post-quantum key establishment

- [NIST FIPS 203](https://csrc.nist.gov/pubs/fips/203/final). Standardizes ML-KEM-512, ML-KEM-768 and ML-KEM-1024. ML-KEM establishes shared secrets; it does not itself specify peer authentication or bulk encryption. The source page includes a November 2025 errata planning note.
- [NIST SP 800-227](https://csrc.nist.gov/pubs/sp/800/227/final). Recommendations for key-encapsulation mechanisms. The surrounding protocol, authentication and key lifecycle matter as well as the algorithm name.

The deployed CISEN algorithm and authenticated session/key-install state require actual non-secret evidence. A valid PQ-established session can remain protected across a transport change. A fresh authenticated PQ exchange is an optional stronger claim, not a mandatory condition for every recovery. Do not demand that a still-valid session stop merely because a new exchange is unavailable.

## S4. WireGuard

- [Protocol and cryptography](https://www.wireguard.com/protocol/). Conventional handshake and optional PSK mixing.
- [Known limitations](https://www.wireguard.com/known-limitations/). WireGuard is not post-quantum secure by default. The page describes an additional PQ handshake and PSK integration, roaming without another authentication round trip, and traffic-analysis limits.
- [Quick start](https://www.wireguard.com/quickstart/). NAT keepalive guidance. Keepalive does not establish PQ rekeying or application delivery.

An interface name, WireGuard or SSH handshake timestamp, packet entropy, encrypted capture or matching file hash does not prove ML-KEM. Wi-Fi and management SSH security are separate from CISEN protection. Never disclose keys or secret-bearing configuration as evidence.

## S5. Transport management

- [OpenWrt mwan3, iptables variant](https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3).
- [OpenWrt mwan3, nftables variant](https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3-nft).

These references distinguish load balancing from channel bonding and warn about version compatibility; they do not verify the deployed policy. The same Windows PC sends CoT and shares independent Wi-Fi through separate Ethernet adapters. ICS, the isolated backup WAN and direct-path blocks are configured. The source gateway's primary WAN default metric avoids colliding with the protected default. During the approved cable pull, the endpoint route selected the backup and the protected mission default remained installed; reconnection selected the primary. This is observed cable-pull behavior, not Internet-only outage detection or a precise recovery measurement.

## S6. Earlier video-distribution research

- [Rally Tactical Systems](https://rallytac.com/).
- [Rally Tactical public source and documentation](https://github.com/rallytac/pub).

These were references for an earlier video-server idea. They do not confirm the identity, version, license or capabilities of any deployed service. Do not infer RTSP, KLV or PQ protection from a product name. No new video-server integration is planned for the live CoT demo, and existing services remain unchanged.

## S7. WILDTRACK

- [EPFL WILDTRACK dataset](https://www.epfl.ch/labs/cvlab/data/data-wildtrack/). Primary dataset page. Annotated frames and camera videos are separate linked artifacts. Follow the source terms and event handling requirements; public download access does not grant unrestricted redistribution.
- The event catalog lists 62 GB. That listing does not establish the size or contents of the frames ZIP. Do not label the ZIP as 62 GB or claim it includes the separate camera videos without measuring and inspecting the specific artifact.

The team's [SMB file-transfer recording](../demo/SMB_Transfer_WAN_Failover.mp4) uses different equipment and a different path from the live demo. Loss, recovery, throughput and cryptographic measurements have not been independently verified or published here. The recording does not establish live CoT results.

## Claim discipline

Separate team reports, proposed configuration, public specifications and measured results. Keep historical research captures and verification artifacts unchanged and private; they are not new live-demo results. Publish no operational addresses, device hostnames, credentials or raw inventories.

The synthetic-CoT run supplied receiver observations and operator-confirmed WinTAK continuity through a primary-cable interruption. It did not establish zero loss, precise recovery time, capacity or deployed PQ key establishment. Loss percentages need matchable event IDs at both ends. Disclose existing CISEN and virtual IEG/TAK dependencies. Public sources do not verify the deployed implementation or certify its security.
