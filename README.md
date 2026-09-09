# Tactical Quantum Edge (TQE)

Team CIS's project for the 2026 NDIA Global Defense Hackathon.

Keep unchanged mission applications usable when a transport fails, without weakening the protected connection.

## The demonstration

The team completed its [WILDTRACK SMB file-transfer recording](demo/SMB_Transfer_WAN_Failover.mp4) using a different setup from the live demo. Throughput, loss, recovery and post-quantum security measurements have not been independently verified or published here.

The presentation now uses explicitly approved synthetic CoT through the existing TAK Server and WinTAK. These are fictional events, not the MITRE/MARFORPAC feed. The application path is:

```text
Windows sender -> source IEG -> CISEN -> existing virtual IEG / TAK Server
TAK Server -> existing protected receiver connection -> WinTAK
```

The compact kit uses one Windows PC as both the CoT sender and a Wi-Fi-to-Ethernet sharing host. One Ethernet adapter connects to the source IEG's LAN. A second adapter supplies an isolated backup WAN from independent phone Wi-Fi. Windows routing and firewall rules block direct mission-subnet access over Wi-Fi or the sharing adapter. The Linux laptop is for management only. The receiver keeps its original connection.

Windows sharing and the isolated backup WAN are configured. During an approved primary-cable interruption, the source IEG selected the backup while retaining the protected mission route. CoT receipts continued at about one update per second, and the operator confirmed WinTAK tracks continued. Reconnecting the cable returned selection to the primary. No zero-loss or precise recovery-time claim is made. This is cable-pull behavior, not Internet-outage detection.

## Current status

Updated September 9, 2026.

Both MITRE Cursor on Target Standard and WILDTRACK are selected in the event catalog. The MITRE entry describes a MARFORPAC XML/UDP feed, refers to a Data Sharing Agreement and links only a router guide. No feed endpoint, port, approved replay files or agreement has been supplied. That blocks use of the actual MITRE data, not the newly approved synthetic presentation.

The Windows-native [CoT tool and demo controls](docs/demo.md#windows-cot-tool) provide mTLS probing, recorded replay, UDP relay and independent receiver logs. A Windows mTLS probe succeeded with an authorized client and supplied CA. Synthetic CoT receipts and operator-confirmed WinTAK continuity were observed during the cable-pull run. Precise recovery, loss and deployed post-quantum key-establishment evidence remain pending. A valid PQ-established session may remain protected across a WAN switch; a fresh authenticated PQ exchange is optional stronger evidence.

The Windows tools use PowerShell 5.1 and .NET Framework 4.8, with no Python or external dependencies. The original synthetic generator still requires Python. Its fictional output is approved for this presentation but is not the selected MITRE dataset. The tools do not implement CISEN cryptography or gateway failover. This repository contains no CISEN proprietary implementation or deployment credentials.

## Start here

- [Architecture and security evidence](docs/architecture.md)
- [Live demonstration and measurements](docs/demo.md)
- [Selected datasets and synthetic generator](docs/datasets.md)
- [Primary sources and evidence boundaries](docs/sources.md)

## Public boundary

Only reviewed project-core files and the team's approved recording are public. Research notes, account details, source downloads, generated datasets, run logs, captures and operational configuration stay out of Git. Do not force-add them.

The project stays on GitHub; do not create a GitLab project. The participant terms' GitLab wording remains an organizer clarification, not permission to move the project. Contribution licensing and the required licensing disclosure need owner approval. No new license is granted here for CISEN or third-party material. Public access to a repository or dataset link does not grant redistribution rights.
