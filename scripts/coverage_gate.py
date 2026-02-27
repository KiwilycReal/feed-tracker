#!/usr/bin/env python3
"""Coverage gate for SwiftPM JSON coverage output."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass


@dataclass
class CoverageResult:
    global_percent: float
    core_percent: float
    core_covered: int
    core_total: int


def resolve_coverage_path(explicit_path: str | None) -> str:
    if explicit_path:
        return explicit_path

    completed = subprocess.run(
        ["swift", "test", "--show-codecov-path"],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def load_coverage(path: str) -> CoverageResult:
    if not os.path.exists(path):
        raise FileNotFoundError(f"Coverage file does not exist: {path}")

    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    data = payload.get("data") or []
    if not data:
        raise ValueError("Coverage payload has no 'data' entries")

    report = data[0]
    global_percent = float(report["totals"]["lines"]["percent"])

    core_covered = 0
    core_total = 0
    for file_entry in report.get("files", []):
        filename = file_entry.get("filename", "")
        if "/Sources/FeedTrackerCore/" not in filename:
            continue

        lines = file_entry.get("summary", {}).get("lines", {})
        core_covered += int(lines.get("covered", 0))
        core_total += int(lines.get("count", 0))

    if core_total == 0:
        raise ValueError("Core module coverage could not be computed (0 executable lines)")

    core_percent = (core_covered / core_total) * 100
    return CoverageResult(
        global_percent=global_percent,
        core_percent=core_percent,
        core_covered=core_covered,
        core_total=core_total,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Swift coverage thresholds")
    parser.add_argument("--path", help="Coverage JSON path from swift test --show-codecov-path")
    parser.add_argument("--global-threshold", type=float, default=70.0)
    parser.add_argument("--core-threshold", type=float, default=80.0)
    args = parser.parse_args()

    try:
        path = resolve_coverage_path(args.path)
        result = load_coverage(path)
    except Exception as exc:  # noqa: BLE001
        print(f"::error::{exc}")
        return 1

    print(f"Coverage file: {path}")
    print(f"Global line coverage: {result.global_percent:.2f}%")
    print(
        "Core module coverage: "
        f"{result.core_percent:.2f}% ({result.core_covered}/{result.core_total} lines)"
    )

    failed = False
    if result.global_percent < args.global_threshold:
        print(
            "::error::Global coverage below threshold: "
            f"{result.global_percent:.2f}% < {args.global_threshold:.2f}%"
        )
        failed = True

    if result.core_percent < args.core_threshold:
        print(
            "::error::Core coverage below threshold: "
            f"{result.core_percent:.2f}% < {args.core_threshold:.2f}%"
        )
        failed = True

    if failed:
        return 1

    print("Coverage gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
