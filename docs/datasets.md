# Datasets

Updated September 9, 2026. Team CIS has selected both MITRE Cursor on Target Standard and WILDTRACK in the event catalog. Selected data, the repository's synthetic fixture and measured results are separate materials.

## Required live input: MITRE CoT

The live demo must use the actual NDIA-selected MITRE dataset through the existing TAK Server and WinTAK. The authenticated catalog describes a MARFORPAC XML/UDP stream to an external IPv4 address, says to refer to a Data Sharing Agreement and links only the [MITRE router guide](https://www.mitre.org/sites/default/files/pdf/09_4937.pdf). It provides no feed endpoint, port, approved replay files or agreement. Organizer delivery and handling instructions are still required.

The PDF explains the CoT format; it is not a traffic corpus. Dataset selection does not establish working access or permission to copy data to personal equipment. Obtain the handling terms before receiving, storing, replaying or publishing event data.

A live feed may contain stationary tracks. Preserve its source times and expiry, even when delivery is delayed. Only an authorized recorded replay may rebase `time`, `start` and `stale` together, preserving track identities and event spacing. Label the replay and its transformation; do not present it as a live observation.

## Completed recording: WILDTRACK

The team completed its WILDTRACK SMB file-transfer video recording using different equipment and a different path from the proposed live CoT demonstration. Loss, recovery, throughput and PQ security measurements have not been independently verified or published here. No recording URL is supplied here.

The catalog's 62 GB listing is not a measurement of the EPFL ZIP. The [EPFL WILDTRACK page](https://www.epfl.ch/labs/cvlab/data/data-wildtrack/) links the annotated frames archive and camera videos separately. Do not assume that the ZIP is 62 GB or contains those videos.

For any future authorized transfer-integrity check, preserve the original archive byte-for-byte and compare its SHA-256 at both ends. Extraction is separate from transfer verification. Keep source downloads, recordings and results out of Git, and follow the source and event's usage terms.

## Original synthetic fixture

The Multi-Modal Tactical Edge Mission Dataset is an original synthetic workload, not the selected MITRE dataset. It is not the primary live input and cannot substitute for the required data without renewed explicit approval. It is not an AI training dataset, a CISEN configuration bundle, a recording of real operations or measured project results.

## Generate locally

Requirements: Python 3.9 or newer and FFmpeg with `lavfi`, `testsrc2` and the `libx264` encoder. Generation is offline and reads no sponsor data.

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

For a separately authorized synthetic replay, the package's fixed fictional epoch is January 1, 2026. Shift `time`, `start` and `stale` together to the run epoch. Preserve event spacing and the 60-second validity window. Recompute byte counts and hashes for a derived replay copy, keep the original ZIP unchanged and identify the transformation. These fixture instructions do not authorize replacing MITRE input or changing delayed live-feed timestamps.

The XML files contain one standalone event per line, not one XML root wrapping the stream. Each JSONL/CSV record carries its corresponding XML event. `payload_bytes` means UTF-8 bytes of that XML payload, excluding the record wrapper and transport overhead. Sequence numbers belong to each source; message IDs are unique across both sources.

The generator does not send packets, ingest TAK data, mount a shared folder, stream video, or measure recovery. Use actual configured applications over the authorized CISEN connection. Do not report dataset generation as proof of interoperability or PQC.

Keep `results/<run-id>/` separate from inputs. Independently record receiver arrivals, source times and expiry. A cached map icon does not prove fresh delivery. Loss requires matchable event IDs at both ends; a track UID alone may cover many updates. Without reliable matching, report arrivals and gaps rather than a loss percentage. Goodput is received application data per stated interval, not link capacity.

A trusted hash manifest can detect file corruption; it does not authenticate the sender or prove PQ key establishment. FFmpeg versions may produce different MP4 bytes, so each generated package carries its own hashes.

## Source and licensing boundaries

The MITRE guide's old example omits `how`, although its required-field table includes it. The original generator includes that field. This format choice does not give the generated events MITRE dataset provenance.

The synthetic package may be proposed as an additional dataset. Generation does not imply portal submission, approval, licensing rights or selection. No new license is granted by these instructions. Do not upload sponsor data, CISEN configuration, keys, real operational coordinates or project results as part of the fixture.

See [sources](sources.md) and the [demo procedure](demo.md).
