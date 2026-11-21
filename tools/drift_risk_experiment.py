"""Evaluate a NumPy error-prediction model on reviewed, independent drives.

All features are available at the estimate timestamp. GPS position error is
used as the offline target only. The frozen test split is never opened here.
"""

import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np


CONTRACT = "driftlock-drift-risk-research-v1"
FEATURES = ("outage_s", "speed_mps", "absolute_yaw_rad", "motion_age_s")
TARGET = "horizontal_error_m"


def load_rows(path, expected_hash):
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
        raise ValueError(f"Hash mismatch: {path.name}")
    with path.open(newline="", encoding="utf-8") as source:
        reader = csv.DictReader(source)
        if reader.fieldnames != [*FEATURES, TARGET]:
            raise ValueError(f"Wrong feature layout in {path.name}")
        rows = np.array([[float(row[name]) for name in (*FEATURES, TARGET)] for row in reader])
    if rows.ndim != 2 or len(rows) < 10 or not np.isfinite(rows).all() or (rows < 0).any():
        raise ValueError(f"Unusable rows: {path.name}")
    return rows


def experiment(manifest_path):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest["contract"] != CONTRACT or manifest["review_status"] != "APPROVED_FOR_TRAINING":
        raise ValueError("A reviewed drift-risk manifest is required.")
    if not manifest.get("review_evidence"):
        raise ValueError("No source review evidence supplied.")
    splits = {"train": [], "validation": [], "calibration": [], "test": []}
    original_groups = set()
    digests = set()
    for drive in manifest["drives"]:
        group, digest = drive["original_group"], drive["sha256"]
        if not group or group in original_groups or digest in digests:
            raise ValueError("Original groups and byte hashes must be unique across all splits.")
        if not drive.get("causal_feature_evidence") or not drive.get("reference_evidence"):
            raise ValueError(f"Missing clock, feature-availability or reference review for {group}.")
        original_groups.add(group)
        digests.add(digest)
        splits[drive["split"]].append(drive)
    if not all(splits.values()):
        raise ValueError("Independent train, validation, calibration and reserved test groups are required.")
    rows = {
        key: np.concatenate([load_rows(manifest_path.parent / d["path"], d["sha256"]) for d in splits[key]])
        for key in ("train", "validation", "calibration")
    }
    train, validation, calibration = (rows[key] for key in ("train", "validation", "calibration"))
    mean = train[:, :-1].mean(axis=0)
    spread = train[:, :-1].std(axis=0)
    spread[spread == 0] = 1

    def design(data):
        return np.column_stack((np.ones(len(data)), (data[:, :-1] - mean) / spread))

    x = design(train)
    penalty = np.eye(x.shape[1])
    penalty[0, 0] = 0

    def fit(strength):
        return np.linalg.solve(x.T @ x + strength * penalty, x.T @ train[:, -1])

    validation_x = design(validation)
    baseline = float(np.mean(np.abs(validation[:, -1] - np.median(train[:, -1]))))
    errors = []
    for strength in (.1, 1., 10., 100.):
        beta = fit(strength)
        error = np.mean(np.abs(validation[:, -1] - np.maximum(0, validation_x @ beta)))
        errors.append((float(error), strength, beta))
    error, strength, beta = min(errors, key=lambda entry: (entry[0], entry[1]))
    residual = np.abs(calibration[:, -1] - np.maximum(0, design(calibration) @ beta))
    return {
        "contract": CONTRACT, "status": "validation_only",
        "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        "original_groups": {key: len(drives) for key, drives in splits.items()},
        "numpy_version": np.__version__,
        "features": list(FEATURES), "target": TARGET,
        "validation_mae_m": error, "baseline_validation_mae_m": baseline,
        "ridge_strength": strength,
        "calibration_residual_p95_m": float(np.quantile(residual, .95, method="higher")),
        "test_coverage": None, "radius_95_m": None,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.manifest:
        result = experiment(args.manifest)
    else:
        result = {
            "contract": CONTRACT, "status": "blocked",
            "benchmark_original_groups_reviewed": 1, "training_groups_approved": 0,
            "blocker": "The Austin benchmark windows share one drive. No independent, approved drift-risk feature groups are available.",
            "validation_mae_m": None, "test_coverage": None, "radius_95_m": None,
        }
    with args.output.open("x", encoding="utf-8") as target:
        json.dump(result, target, indent=2)
        target.write("\n")
    print(result["status"])


if __name__ == "__main__":
    main()
