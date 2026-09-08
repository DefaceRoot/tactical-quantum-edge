# Multi-Modal Tactical Edge Mission Dataset

An original synthetic traffic workload for static and mobile edge demonstrations. It is not an AI training dataset, a CISEN configuration bundle, a recording of real operations, or measured project results.

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
| Shared folder | Exercise brief, original schematic and 16 MiB deterministic transfer file | File sharing, throughput and transfer recovery |
| Recorded video | 10-second H.264 synthetic test pattern, 640x360, 15 fps, no audio | Repeatable video delivery independent of a live camera |
| Manifest | Relative path, byte size and SHA-256 for every other file | Received-file integrity against the original package |

The test pattern is deliberately not realistic surveillance footage. It proves that a video payload can be carried and decoded, not sensor authenticity or KLV interoperability. Keep it available even if the live demonstration uses a camera through the team's Rally Point server.

Coordinates are arithmetic inventions near zero latitude/longitude. They are not observed positions or representations of people, customer sites or operational locations. They must not be used for navigation. The binary is a deterministic public test payload, never key material.

## Replay and measurement

The package uses a fixed fictional epoch, January 1, 2026. Before a live CoT replay, shift `time`, `start` and `stale` together to the run epoch. Preserve the event spacing and 60-second validity window. Recompute payload byte counts and hashes for any derived replay copy. Keep the original ZIP unchanged and identify the replay transformation in the run record.

The XML files contain one standalone event per line, not one XML root wrapping the stream. Each JSONL/CSV record carries its corresponding XML event. `payload_bytes` means UTF-8 bytes of that XML payload, excluding the record wrapper and transport overhead. Sequence numbers belong to each source; message IDs are unique across both sources.

The generator does not send packets, ingest TAK data, mount a shared folder, stream video, or measure recovery. Use actual configured applications over the authorized CISEN connection. Do not report dataset generation as proof of interoperability or PQC.

Keep `results/<run-id>/` separate from the input package. Record send/receive times, unique IDs, transport transitions, non-secret key-establishment evidence and final hashes. A hash manifest detects corruption only when the reference manifest is trusted; it does not authenticate the sender. FFmpeg versions may produce different MP4 bytes, so each generated package carries its own hashes.

## MITRE and event data

Team CIS selected the portal's MITRE Cursor on Target Standard entry. The linked [MITRE PDF](https://www.mitre.org/sites/default/files/pdf/09_4937.pdf) is the November 2009 Cursor-on-Target Message Router User's Guide. Its example and required-field table are format references, not a ready-to-replay dataset. The generated events are original and include `how`, which the guide's required-field table lists but its old example omits.

The portal entry also describes a MARFORPAC XML/UDP stream. Its inspected record supplies neither a stream endpoint nor a sample traffic download, and says to refer to the Data Sharing Agreement. Obtain authorized access and terms before using it. Do not treat selection in the portal as proof the feed works or permission to copy event data onto personal equipment.

The original synthetic package can be proposed as an additional dataset. Portal submission, approval, licensing/data-rights assertion and selection are separate from generation. None is implied by having a local ZIP. Do not upload sponsor data, CISEN configs, private keys, real coordinates or project results as part of this package.

See [sources](sources.md) and the [demo procedure](demo.md).
