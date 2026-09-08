# Tactical Quantum Edge (TQE)

Team CIS's project for the 2026 NDIA Global Defense Hackathon.

Keep mission applications connected across changing transports. After an interruption, re-establish post-quantum-protected connectivity before releasing mission traffic.

## The demonstration

Two Iron Edge Gateways connect separate edge networks through the team's CISEN software-defined network. A 5G/4G puck supplies an alternate transport. The demonstration will move sequenced mission messages, TAK/Cursor-on-Target tracks, shared files and video, interrupt the primary path, then measure protected recovery on the alternate path.

Existing applications keep their private overlay destinations. Cellular, Wi-Fi and Ethernet are candidate underlays. Satellite is an architectural extension, not a demonstrated capability with the current equipment.

## Start here

- [Architecture and security evidence](docs/architecture.md)
- [Live demonstration and measurement procedure](docs/demo.md)
- [Multimodal dataset and generation instructions](docs/datasets.md)
- [Primary sources and evidence boundaries](docs/sources.md)

## Current status

This repository contains the project definition, demo procedure, source references and an original synthetic dataset generator. It does not contain CISEN's proprietary implementation or deployment credentials. The generator creates data locally; it does not establish a VPN, stream traffic, replay CoT, or implement failover.

Hardware failover, TAK ingestion, video-server integration and CISEN post-quantum rekeying have not been verified by this repository setup. No measured recovery times, throughput figures or cryptographic certification are claimed.

The cryptographic acceptance condition is a fresh authenticated PQ key-establishment event bound to the recovered connection, followed by protected application delivery. A new route, a WireGuard handshake timestamp, or a green connectivity indicator alone does not establish that condition.

## Public boundary

Only reviewed project-core files are tracked. Research notes, portal account information, source downloads, generated datasets, run logs, packet captures and operational configuration are excluded from Git. Do not force-add these materials. A public repository is not a license to redistribute CISEN, third-party software, or event data.

The project contribution license and the event's required licensing disclosure need owner approval before final submission. No license for pre-existing CISEN technology is granted here. GitHub is the project's public home; organizer acceptance of this submission location must be confirmed because the participant agreement refers to GitLab.
