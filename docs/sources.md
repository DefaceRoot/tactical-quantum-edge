# Sources and evidence boundaries

Retrieved September 8, 2026. Links identify the source of a claim, not certification of this project.

## S1. Event

- [NDIA conference hackathon overview](https://www.ndiatechexpo.org/hackathon). September 8-10, 2026, Washington DC.
- [Maximus event overview](https://maximus.com/events/ndia). Venue and event context.
- [Washington DC judging criteria](https://ndia.hackathon-portal.maximus.com/event/ndia-global-defense-hackathon-main-event-washington-dc/judging-criteria). Authenticated portal source. Research notes are local, not reproduced here.
- [Washington DC schedule](https://ndia.hackathon-portal.maximus.com/event/ndia-global-defense-hackathon-main-event-washington-dc/schedule). Authenticated portal source; check for updates.
- [Selected challenge](https://ndia.hackathon-portal.maximus.com/event/ndia-global-defense-hackathon-main-event-washington-dc/use-cases/129). AME Survivable Post-Quantum Tactical Edge Communications.
- [Participant Terms & Agreement, v1.2](https://hackathon.ndia.org/api/events/3/legal-document/terms/?v=1.2). Sections 8-10 cover licensing, rights and data handling. Section 8 refers to a GitLab project and requires a licensing slide. Confirm GitHub acceptance with organizers. Publicly accessible source links do not override event data restrictions.

## S2. Cursor-on-Target

- [MITRE, Cursor-on-Target Message Router User's Guide](https://www.mitre.org/sites/default/files/pdf/09_4937.pdf), Michael J. Kristan, Jeffrey T. Hamalainen, Douglas P. Robbins and Patrick J. Newell, November 2009. Section 2.1, pages 2-1 and 2-2, provides a message example and required field table. It is a user guide, not a replayable dataset. The example omits `how`, even though Table 2-1 lists it as required; generated events include it.
- Direct PDF retrieval returned HTTP 403 during research. The text was inspected through [Jina Reader](https://r.jina.ai/https://www.mitre.org/sites/default/files/pdf/09_4937.pdf). No original figures or downloaded XSD were validated. The guide is marked public release with MITRE copyright retained; do not infer an open-source license.
- [Event dataset catalog](https://ndia.hackathon-portal.maximus.com/event/ndia-global-defense-hackathon-main-event-washington-dc/datasets). The selected MITRE entry describes an XML/UDP stream but exposes only the PDF source link and refers to a Data Sharing Agreement. No usable stream endpoint or traffic file was supplied by that record when inspected.
- [TAK Product Center server repository](https://github.com/TAK-Product-Center/Server). Official server source reference. Pin the deployed version and review its license and client compatibility before use. No TAK ingestion test has been performed during repository setup.

## S3. Post-quantum key establishment

- [NIST FIPS 203](https://csrc.nist.gov/pubs/fips/203/final). Standardizes ML-KEM-512, ML-KEM-768 and ML-KEM-1024. ML-KEM establishes shared secrets; it does not itself specify peer authentication or bulk traffic encryption. The page includes a November 2025 errata planning note.
- [NIST SP 800-227](https://csrc.nist.gov/pubs/sp/800/227/final). Recommendations for key-encapsulation mechanisms and their use. An implementation needs the surrounding protocol, key lifecycle and authentication reviewed as well as the algorithm name.

## S4. WireGuard

- [Protocol and cryptography](https://www.wireguard.com/protocol/). Conventional WireGuard handshake and optional PSK mixing.
- [Known limitations](https://www.wireguard.com/known-limitations/). Explicitly says WireGuard is not post-quantum secure by default; describes an additional PQ handshake and PSK integration. Also documents roaming without an additional authentication round trip and traffic-analysis limitations.
- [Quick start](https://www.wireguard.com/quickstart/). NAT keepalive guidance. Keepalive is not a PQ rekey trigger and does not prove live application delivery.

## S5. Transport management

- [OpenWrt mwan3, iptables variant](https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3).
- [OpenWrt mwan3, nftables variant](https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3-nft).

The iptables documentation warns about current-version compatibility and distinguishes per-connection load balancing from channel bonding. These references do not establish which transport manager the IEGs use.

## S6. Video distribution

- [Rally Tactical Systems](https://rallytac.com/). Its Rallypoint component creates application-specific multicast overlays and routes traffic between Engage nodes, other Rallypoints and third-party traffic.
- [Rally Tactical public source and documentation](https://github.com/rallytac/pub).

This is a plausible identity for the team's Rally Point server, not a confirmed match. Confirm the exact product, version, license and video protocol with its operator. Do not infer RTSP ingest, KLV metadata support or PQ security from the product name. A video server's own encryption does not establish CISEN's security properties.

## Claim discipline

Team-provided design inputs include two IEGs, one cellular puck, CISEN with ML-KEM-1024, private overlay addressing and randomized relay paths. Public sources support the component concepts; they do not verify that the deployed CISEN build implements them correctly. Hardware measurements and software inspection are still required.
