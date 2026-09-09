# Tactical Quantum Edge (TQE)

Team CIS's project for the 2026 NDIA Global Defense Hackathon. Alex is team lead. This GitHub repository is the judge submission repository.

Keep unchanged mission applications usable when a transport fails, without weakening the protected connection.

## The demonstration

The team completed its WILDTRACK SMB file-transfer video recording using a different setup from the planned live demo. Throughput, loss, recovery and post-quantum security measurements have not been independently verified or published here.

The live demo will use the actual NDIA-selected MITRE Cursor-on-Target data through the existing TAK Server and WinTAK. The planned application path is:

```text
Linux source -> IEG A -> CISEN -> existing virtual IEG / TAK Server
TAK Server -> CISEN -> IEG B -> WinTAK
```

IEG A will use its cellular puck as the primary WAN. A separate Windows PC will share phone or public Wi-Fi over Ethernet to an isolated secondary WAN port on A. The source laptop stays on A's LAN, not on the sharing PC. IEG B stays on its own cellular puck. Two different uplinks on two different IEGs alone do not demonstrate failover; A needs both uplinks available at once.

This is a proposed configuration. PC sharing and dual-WAN failover are not configured or tested. Preserve the existing ESXi, TAK, IEG and CISEN configuration. Any operational change requires prior approval with its exact impact and rollback.

## Current status

Updated September 9, 2026.

Both MITRE Cursor on Target Standard and WILDTRACK are selected in the authenticated event catalog. The MITRE entry describes a MARFORPAC XML/UDP feed to an external IPv4 address, refers to a Data Sharing Agreement and links only a router user guide. No feed endpoint, port, approved replay files or agreement has been supplied. Organizer delivery and handling instructions are the live-demo blocker.

WinTAK is reported running. Use its existing map; no new server UI is planned. Live delivery, receiver freshness, failover and the deployed post-quantum key establishment still need evidence. No new replay or receiver code has been built. A valid PQ-established session may remain protected across a WAN switch; a fresh authenticated PQ exchange is an optional stronger demonstration, not a requirement on every switch.

This repository contains the project docs and an original synthetic dataset generator. The generator is a separate fixture, not the selected MITRE dataset or an approved substitute. It does not send traffic, replay CoT, establish a VPN or implement failover. This repository does not contain CISEN's proprietary implementation or deployment credentials.

## Start here

- [Architecture and security evidence](docs/architecture.md)
- [Live demonstration and measurements](docs/demo.md)
- [Selected datasets and synthetic generator](docs/datasets.md)
- [Primary sources and evidence boundaries](docs/sources.md)

## Public boundary

Only reviewed project-core files are tracked. Research notes, account details, source downloads, generated datasets, run logs, captures and operational configuration stay out of Git. Do not force-add them.

GitHub remains the submission location; do not create a GitLab project. The participant terms' GitLab wording remains an organizer clarification, not permission to move the project. The project contribution license and required licensing disclosure need owner approval before final submission. No new license is granted here for CISEN or third-party material. Public access to a repository or dataset link does not grant redistribution rights.
