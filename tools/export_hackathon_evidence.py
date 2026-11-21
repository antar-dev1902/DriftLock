"""Reproduce both Flutter assets and public Serverpod summaries from the Swift engine."""

import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from validate_contract import validate

APP = ROOT / "hackbriven/driftlock/driftlock_flutter/assets"
SERVER = ROOT / "hackbriven/driftlock/driftlock_server/web/evidence"
DRIVE = ROOT / "ios/App/Resources/AustinReplay.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("exporter", type=Path, help="Built driftlock-export-playback executable")
    args = parser.parse_args()
    exporter = args.exporter.resolve()
    playback, benchmark = (
        subprocess.check_output([exporter, "--hackathon-" + mode, DRIVE])
        for mode in ("playback", "benchmark")
    )
    previous = json.loads((APP / "austin_playback.json").read_bytes())
    current = json.loads(playback)
    for old, new in zip(previous["windows"], current["windows"], strict=True):
        if any(old[key] != new[key] for key in old):
            raise ValueError(f"Playback changed for existing window {old['id']}")
    groups = json.loads(benchmark)["groups"]
    for group in groups:
        validate(group["summary"])
    for target, data in (("austin_replay_v2.json", playback), ("austin_benchmark.json", benchmark)):
        (APP / target).write_bytes(data)
    for group in groups:
        summary = group["summary"]
        (SERVER / f"austin-{summary['outage_seconds']}s.json").write_text(
            json.dumps(summary, indent=2) + "\n", encoding="utf-8"
        )
    print(f"Verified {len(current['windows'])} replay windows and {len(groups)} shared benchmark records")


if __name__ == "__main__":
    main()
