# Datasets

Updated September 9, 2026. Team CIS selected MITRE Cursor on Target Standard and WILDTRACK in the catalog. The operator has now explicitly approved synthetic CoT for the presentation. It is fictional data, not the selected MITRE/MARFORPAC feed.

## MITRE CoT access remains unavailable

The authenticated catalog describes a MARFORPAC XML/UDP stream, refers to a Data Sharing Agreement and links only the [MITRE router guide](https://www.mitre.org/sites/default/files/pdf/09_4937.pdf). No feed endpoint, port, approved replay files or agreement has been supplied. Organizer instructions are required before using that feed. This does not block the newly approved synthetic presentation.

The PDF explains the CoT format; it is not a traffic corpus. Dataset selection does not establish working access or permission to copy data to personal equipment. Obtain the handling terms before receiving, storing, replaying or publishing event data.

A live feed may contain stationary tracks. Preserve its source times and expiry, even when delivery is delayed. Only an authorized recorded replay may rebase `time`, `start` and `stale` together, preserving track identities and event spacing. Label the replay and its transformation; do not present it as a live observation.

The Windows-native [CoT tool](demo.md#windows-cot-tool) accepts an authorized XML recording with `-Replay` or forwards an authorized UDP feed with `-Relay`. Replay supports paced event fragments or one wrapper with direct `event` children; `-RefreshReplayTimes` is explicit and preserves UIDs. Relay never refreshes live timestamps. The `Hackathon` display label does not replace dataset callsigns or identities. `-Receive` records independent arrivals and can filter dataset UIDs. These modes do not supply the missing MITRE feed or grant handling permission.

## Completed recording: WILDTRACK

The team's [WILDTRACK SMB file-transfer recording](../demo/SMB_Transfer_WAN_Failover.mp4) uses different equipment and a different path from the live CoT demonstration. Loss, recovery, throughput and PQ security measurements have not been independently verified or published here.

The catalog's 62 GB listing is not a measurement of the EPFL ZIP. The [EPFL WILDTRACK page](https://www.epfl.ch/labs/cvlab/data/data-wildtrack/) links the annotated frames archive and camera videos separately. Do not assume that the ZIP is 62 GB or contains those videos.

For any future authorized transfer-integrity check, preserve the original archive byte-for-byte and compare its SHA-256 at both ends. Extraction is separate from transfer verification. The reviewed team recording is public; source downloads, unreviewed recordings and raw results stay out of Git. Follow the source and event's usage terms.

## Original synthetic fixture

The Multi-Modal Tactical Edge Mission Dataset is an original synthetic workload approved by the operator for this presentation. It is not the selected MITRE dataset, an AI training dataset, a CISEN configuration bundle, a recording of real operations or measured project results. This presentation approval does not imply organizer dataset acceptance or new redistribution rights.

## Generate locally

The synthetic generator requires Python 3.9 or newer and FFmpeg with `lavfi`, `testsrc2` and the `libx264` encoder. Generation is offline and reads no sponsor data. These requirements do not apply to the Windows CoT tool, which uses PowerShell 5.1 and .NET Framework 4.8 without Python.

```sh
python3 tools/generate_dataset.py --output data/multi-modal-tactical-edge-mission
```

If FFmpeg is not on PATH, pass `--ffmpeg /path/to/ffmpeg`. An executable wrapper is also supported. The command refuses to overwrite an existing output directory or ZIP. Use a different output name for a new generation.

Outputs:

```text
data/
  multi-modal-tactical-edge-mission/
    README.md
    manifest.json
    cot/static.xml
    cot/mobile.xml
    mission/events.jsonl
    mission/events.csv
    shared/exercise-brief.txt
    shared/synthetic-schematic.svg
    shared/synthetic-transfer-16mib.bin
    video/synthetic-test-pattern.mp4
  multi-modal-tactical-edge-mission.zip
```

The ZIP contains the dataset directory, its short README and integrity manifest. Generated payloads and archives stay out of Git; the reviewed generator is the project core. This keeps the public repository small and reproducible without redistributing restricted material.

## What the package contains

| Component | Content | Evaluation purpose |
|---|---|---|
| Mission records | 240 sequenced JSONL/CSV records, 120 per fictional source | Unique delivery, loss, delay and recovery |
| CoT streams | One static and one mobile fictional track, 1 Hz, 120 samples each | Recognizable situational-awareness data with stable track UIDs |
| Shared folder | Exercise brief, original schematic and 16 MiB deterministic transfer file | File sharing, received goodput and transfer recovery |
| Recorded video | 10-second H.264 synthetic test pattern, 640x360, 15 fps, no audio | Repeatable video delivery independent of a live camera |
| Manifest | Relative path, byte size and SHA-256 for every other file | Received-file integrity against the original package |

The test pattern is deliberately not realistic surveillance footage. It supplies repeatable video input; generation alone proves no network delivery, sensor authenticity or KLV interoperability. Live video-server integration is not part of the current CoT demo plan.

Coordinates are arithmetic inventions near zero latitude/longitude. They are not observed positions or representations of people, customer sites or operational locations. They must not be used for navigation. The binary is a deterministic public test payload, never key material.

## Replay and measurement

For the approved synthetic replay, the package's fixed fictional epoch is January 1, 2026. Shift `time`, `start` and `stale` together to the run epoch. Preserve event spacing and the 60-second validity window. Recompute byte counts and hashes for a derived replay copy, keep the original ZIP unchanged and identify the transformation. This never authorizes changing delayed live-feed timestamps or claiming MITRE provenance.

The XML files contain one standalone event per line, not one XML root wrapping the stream. Each JSONL/CSV record carries its corresponding XML event. `payload_bytes` means UTF-8 bytes of that XML payload, excluding the record wrapper and transport overhead. Sequence numbers belong to each source; message IDs are unique across both sources.

The generator does not send packets, ingest TAK data, mount a shared folder, stream video, or measure recovery. Use actual configured applications over the authorized CISEN connection. Do not report dataset generation as proof of interoperability or PQC.

Keep `results/<run-id>/` separate from inputs. Independently record receiver arrivals, source times and expiry. A cached map icon does not prove fresh delivery. Loss requires matchable event IDs at both ends; a track UID alone may cover many updates. Without reliable matching, report arrivals and gaps rather than a loss percentage. Goodput is received application data per stated interval, not link capacity.

A trusted hash manifest can detect file corruption; it does not authenticate the sender or prove PQ key establishment. FFmpeg versions may produce different MP4 bytes, so each generated package carries its own hashes.

## Source and licensing boundaries

The MITRE guide's old example omits `how`, although its required-field table includes it. The original generator includes that field. This format choice does not give the generated events MITRE dataset provenance.

The synthetic package may be proposed as an additional dataset. Generation does not imply portal submission, approval, licensing rights or selection. No new license is granted by these instructions. Do not upload sponsor data, CISEN configuration, keys, real operational coordinates or project results as part of the fixture.

See [sources](sources.md) and the [demo procedure](demo.md).
