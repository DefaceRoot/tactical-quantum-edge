#!/usr/bin/env python3
"""Generate an offline, original synthetic multi-modal mission dataset."""

import argparse
import csv
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile


DATASET_NAME = "Multi-Modal Tactical Edge Mission Dataset"
VERSION = "1.0.0"
START = datetime(2026, 1, 1, tzinfo=timezone.utc)
SAMPLES = 120
STALE_SECONDS = 60
TRACK_UIDS = ("STATIC-ALPHA", "MOBILE-BRAVO")
BINARY_BYTES = 16 * 1024 * 1024
CHUNK_BYTES = 1024 * 1024
BINARY_SEED = b"TQE synthetic transfer payload v1\0"
COT_GUIDE = "https://www.mitre.org/sites/default/files/pdf/09_4937.pdf"
FIELDS = (
    "id", "sequence", "time", "source", "destination", "type", "priority",
    "fictional_latitude", "fictional_longitude", "payload", "payload_bytes",
)


README = f"""# {DATASET_NAME}

Version {VERSION}. All assets are original synthetic exercise material.
There is no classified, proprietary, or customer data. No real people, observed
locations, operational observations, or captured network traffic are included.
Coordinates are invented numbers near latitude and longitude zero. They are not
observations or a claim about any real location. Do not use them for navigation.

## Contents

- `video/synthetic-test-pattern.mp4` is a prerecorded FFmpeg `testsrc2` pattern.
  It is synthetic, not live ISR or real footage. It has no audio. It uses H.264,
  yuv420p, 640 by 360 pixels, 15 frames per second, and a 10-second duration.
- `cot/static.xml` and `cot/mobile.xml` each contain 120 standalone CoT event
  elements, one per line. These are event streams, not single-root XML documents.
- `mission/events.jsonl` and `mission/events.csv` contain the same 240 records,
  ordered by timestamp and then static/mobile source. Each source has sequences
  1 through 120. The `payload` is exactly its corresponding CoT XML event without
  a newline. `payload_bytes` counts UTF-8 bytes of that payload only. It excludes
  CSV quoting, JSON escaping, record delimiters, headers, and transport overhead.
- `shared/exercise-brief.txt` describes the fictional exercise.
- `shared/synthetic-schematic.svg` is an original schematic, not a map.
- `shared/synthetic-transfer-16mib.bin` is a 16 MiB deterministic, nonzero,
  noncryptographic transfer payload. Each 1 MiB chunk is SHAKE-256 of the public
  seed plus its zero-based index as four big-endian bytes. The seed and algorithm
  are recorded in the manifest. Do not use this file as a key or random secret.
- `manifest.json` records generation parameters, provenance, byte sizes, and
  SHA-256 digests for every other file. It excludes itself and the sibling ZIP.
  It contains no benchmark or security results.

## Timing and replay

The fictional exercise starts at `2026-01-01T00:00:00Z`. Each source emits at 1 Hz
for a 120-second window, with samples at offsets 0 through 119 seconds. CoT
`time` and `start` equal the sample time. `stale` is 60 seconds later. The static
UID is `STATIC-ALPHA`; the mobile UID is `MOBILE-BRAVO`. Both use CoT version 2.0,
`type="a-f-G"`, and `how="m-g"`. Priority is a synthetic mission-record label, not
a CoT priority extension. `SIM-COLLECTOR` is a fictional destination identifier,
not a hostname or endpoint. Point coordinates and uncertainties are synthetic.

Before replay, rebase every CoT `time`, `start`, and `stale` by the same offset
from the fixed exercise epoch to your chosen replay epoch. Preserve the offsets
between events and the 60-second stale interval. Otherwise TAK sees expired data.
If you also replay mission records, shift their `time` and embedded CoT payload
timestamps consistently, then recompute `payload_bytes` and regenerate integrity
metadata for the modified copy. This generator does not replay or transmit data.
The 10-second video is a separate transfer asset, not a synchronized 120-second
sensor recording.

## Limitations and source

CoT interoperability with TAK has not yet been tested. XML syntax alone does not
establish TAK compatibility. This dataset supplies no actual post-quantum
cryptography, deployment, tunnel, encryption, or security guarantee. It provides
no evidence of throughput, latency, resilience, or cryptographic performance.

CoT format reference: MITRE, *Cursor on Target* guide,
{COT_GUIDE}
The guide is cited as a reference. No examples or other material were copied
from it. The generator does not fetch the guide or any other external content.

## Packaging

The sibling ZIP contains this entire directory under its directory name, using
relative paths only. Extract it to an empty directory. Compare extracted files
with the byte counts and SHA-256 digests in `manifest.json`. File hashes are
integrity checks, not authentication. FFmpeg versions can produce different MP4
bytes, so hashes describe this generated copy rather than a universal build.
"""

BRIEF = """SYNTHETIC EXERCISE ONLY

Exercise: Multi-Modal Tactical Edge Mission Dataset
Epoch: 2026-01-01T00:00:00Z
Window: 120 seconds, one event per source per second

STATIC-ALPHA stays at the invented coordinate 0.001000, 0.001000.
MOBILE-BRAVO starts at 0.002000, 0.002000. Each second adds 0.000010
latitude and 0.000015 longitude. These are fabricated arithmetic positions.
Both sources address the fictional SIM-COLLECTOR identifier.

Use the CoT streams and matching mission records as repeatable input payloads.
Use the test-pattern video, this brief, the schematic, and the 16 MiB binary as
shared-file transfer inputs. No service, real mission, person, endpoint, map,
customer, or observed location is represented. Transfer and replay tooling must
be supplied separately. Rebase CoT timestamps before any TAK replay.

This package contains no measured results and provides no encryption or PQC.
"""

SCHEMATIC = """<svg xmlns="http://www.w3.org/2000/svg" width="900" height="360" viewBox="0 0 900 360" role="img" aria-labelledby="title description">
  <title id="title">Synthetic exercise schematic, not a map</title>
  <desc id="description">Fictional static and mobile sources point to a fictional collector. No geography or actual deployment is shown.</desc>
  <rect width="900" height="360" fill="#101827"/>
  <g fill="#ffffff" font-family="sans-serif" text-anchor="middle">
    <text x="450" y="40" font-size="24">SYNTHETIC EXERCISE ONLY - NOT A MAP</text>
    <text x="450" y="325" font-size="17">Fictional identifiers. No actual network or encryption shown.</text>
  </g>
  <g fill="#21354a" stroke="#a8d8ff" stroke-width="2">
    <rect x="50" y="85" width="260" height="70" rx="8"/>
    <rect x="50" y="205" width="260" height="70" rx="8"/>
    <rect x="580" y="145" width="270" height="70" rx="8"/>
  </g>
  <g fill="none" stroke="#a8d8ff" stroke-width="3">
    <path d="M310 120 L450 120 L450 180 L565 180 M310 240 L450 240 L450 180"/>
    <path d="M550 170 L565 180 L550 190"/>
  </g>
  <g fill="#ffffff" font-family="sans-serif" font-size="20" text-anchor="middle">
    <text x="180" y="127">STATIC-ALPHA</text>
    <text x="180" y="247">MOBILE-BRAVO</text>
    <text x="715" y="187">SIM-COLLECTOR</text>
  </g>
</svg>
"""


def timestamp(value):
    return value.isoformat(timespec="seconds").replace("+00:00", "Z")


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def event_record(uid, offset):
    sequence = offset + 1
    sample_time = START + timedelta(seconds=offset)
    if uid == "STATIC-ALPHA":
        latitude, longitude = 0.001, 0.001
    else:
        latitude = 0.002 + offset * 0.000010
        longitude = 0.002 + offset * 0.000015
    latitude = round(latitude, 6)
    longitude = round(longitude, 6)
    event = ET.Element("event", {
        "version": "2.0", "uid": uid, "type": "a-f-G", "how": "m-g",
        "time": timestamp(sample_time), "start": timestamp(sample_time),
        "stale": timestamp(sample_time + timedelta(seconds=STALE_SECONDS)),
    })
    ET.SubElement(event, "point", {
        "lat": f"{latitude:.6f}", "lon": f"{longitude:.6f}",
        "hae": "0.0", "ce": "9999999.0", "le": "9999999.0",
    })
    detail = ET.SubElement(event, "detail")
    ET.SubElement(detail, "remarks").text = (
        f"SYNTHETIC EXERCISE ONLY; sequence={sequence}; invented position; not observed"
    )
    payload = ET.tostring(event, encoding="unicode")
    return {
        "id": f"{uid}-{sequence:06d}", "sequence": sequence,
        "time": timestamp(sample_time), "source": uid,
        "destination": "SIM-COLLECTOR", "type": "a-f-G", "priority": "routine",
        "fictional_latitude": latitude, "fictional_longitude": longitude,
        "payload": payload, "payload_bytes": len(payload.encode("utf-8")),
    }


def write_events(output):
    with (
        (output / "cot/static.xml").open("w", encoding="utf-8", newline="\n") as static,
        (output / "cot/mobile.xml").open("w", encoding="utf-8", newline="\n") as mobile,
        (output / "mission/events.jsonl").open("w", encoding="utf-8", newline="\n") as jsonl,
        (output / "mission/events.csv").open("w", encoding="utf-8", newline="") as csvfile,
    ):
        writer = csv.DictWriter(csvfile, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        for offset in range(SAMPLES):
            for uid, stream in zip(TRACK_UIDS, (static, mobile)):
                record = event_record(uid, offset)
                stream.write(record["payload"] + "\n")
                jsonl.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
                writer.writerow(record)


def write_binary(path):
    with path.open("wb") as handle:
        for index in range(BINARY_BYTES // CHUNK_BYTES):
            chunk = hashlib.shake_256(BINARY_SEED + index.to_bytes(4, "big")).digest(CHUNK_BYTES)
            handle.write(chunk)


def encode_video(path, ffmpeg):
    subprocess.run([
        ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-n",
        "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=15:duration=10",
        "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", "15", "-t", "10",
        "-movflags", "+faststart", "-metadata", "title=SYNTHETIC TEST PATTERN - NOT LIVE ISR",
        "-metadata", "comment=Original generated testsrc2 pattern; no real footage or audio",
        str(path),
    ], check=True)


def file_entry(path, output):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK_BYTES), b""):
            digest.update(chunk)
    return {
        "path": path.relative_to(output).as_posix(),
        "bytes": path.stat().st_size, "sha256": digest.hexdigest(),
    }


def write_manifest(output):
    files = sorted(path for path in output.rglob("*") if path.is_file())
    write_json(output / "manifest.json", {
        "name": DATASET_NAME,
        "version": VERSION,
        "generator": "tools/generate_dataset.py",
        "parameters": {
            "start_timestamp": timestamp(START), "duration_seconds": SAMPLES,
            "sample_interval_seconds": 1, "samples_per_track": SAMPLES,
            "sequence_start": 1, "track_uids": list(TRACK_UIDS),
            "cot_version": "2.0", "cot_type": "a-f-G", "cot_how": "m-g",
            "stale_offset_seconds": STALE_SECONDS,
            "point_hae": 0.0, "point_ce": 9999999.0, "point_le": 9999999.0,
            "fictional_coordinates": {
                "STATIC-ALPHA": {"latitude": 0.001, "longitude": 0.001},
                "MOBILE-BRAVO": {
                    "start_latitude": 0.002, "start_longitude": 0.002,
                    "latitude_increment_per_second": 0.000010,
                    "longitude_increment_per_second": 0.000015,
                },
            },
            "mission_destination": "SIM-COLLECTOR", "mission_priority": "routine",
            "payload_bytes_definition": "UTF-8 bytes of the XML payload only; no record delimiters or transport overhead",
            "video": {
                "source": "testsrc2", "duration_seconds": 10, "width": 640,
                "height": 360, "frames_per_second": 15, "encoder": "libx264",
                "codec": "H.264", "pixel_format": "yuv420p", "audio": False,
                "marking": "Synthetic test pattern identified by filename, metadata, and README; no drawtext dependency",
            },
            "binary": {
                "bytes": BINARY_BYTES, "chunk_bytes": CHUNK_BYTES,
                "seed_hex": BINARY_SEED.hex(),
                "algorithm": "Concatenate SHAKE-256(seed || zero-based chunk index as uint32 big-endian), each digest chunk_bytes long",
                "purpose": "Deterministic noncryptographic transfer payload; not key material",
            },
        },
        "provenance": {
            "synthetic": True,
            "declaration": "Original synthetic assets only. No classified, proprietary, customer, real-person, observed-location, or operational data. No external downloads or captured traffic.",
            "cot_reference": COT_GUIDE,
            "reference_use": "Format reference only; no copied examples",
            "cot_interoperability": "Not yet tested with TAK",
            "pqc": "Not provided; no encryption or security claims",
        },
        "manifest_scope": "Every other file in the dataset directory; manifest.json and sibling ZIP excluded",
        "files": [file_entry(path, output) for path in files],
    })


def generate(output, ffmpeg):
    output = output.absolute()
    if output.name in ("", ".", "..") or "\\" in output.name or ":" in output.name:
        raise OSError("Output directory name must be a safe relative ZIP folder name")
    archive = output.with_name(output.name + ".zip")
    for path in (output, archive):
        if path.exists() or path.is_symlink():
            raise FileExistsError(f"Refusing to overwrite existing path: {path}")
    output.mkdir(parents=True, exist_ok=False)
    archive_created = False
    try:
        for name in ("video", "cot", "mission", "shared"):
            (output / name).mkdir()
        (output / "README.md").write_text(README, encoding="utf-8")
        (output / "shared/exercise-brief.txt").write_text(BRIEF, encoding="utf-8")
        (output / "shared/synthetic-schematic.svg").write_text(SCHEMATIC, encoding="utf-8")
        write_events(output)
        write_binary(output / "shared/synthetic-transfer-16mib.bin")
        encode_video(output / "video/synthetic-test-pattern.mp4", ffmpeg)
        write_manifest(output)
        with archive.open("xb") as handle:
            archive_created = True
            with zipfile.ZipFile(handle, "w", compression=zipfile.ZIP_STORED) as package:
                for path in sorted(output.rglob("*")):
                    if path.is_file():
                        package.write(path, (Path(output.name) / path.relative_to(output)).as_posix())
    except BaseException:
        if archive_created:
            archive.unlink(missing_ok=True)
        shutil.rmtree(output)
        raise
    return output, archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path, default=Path("data/multi-modal-tactical-edge-mission"),
        help="New dataset directory; neither it nor its sibling .zip may exist",
    )
    parser.add_argument(
        "--ffmpeg", default="ffmpeg",
        help="FFmpeg executable or wrapper path with lavfi testsrc2 and libx264 support",
    )
    args = parser.parse_args()
    try:
        output, archive = generate(args.output, args.ffmpeg)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Dataset generation failed: {error}", file=sys.stderr)
        return 1
    print(f"Dataset: {output}")
    print(f"Package: {archive}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
