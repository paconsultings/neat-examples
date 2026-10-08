#!/usr/bin/env python3
"""Verify that two Docker containers executed during an overlapping interval."""

from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone


def timestamp(value: str) -> datetime:
    if not value or value.startswith("0001-"):
        return datetime.now(timezone.utc)
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} CONTAINER_A CONTAINER_B", file=sys.stderr)
        return 2

    payload = subprocess.run(
        ["docker", "inspect", *sys.argv[1:]],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    containers = json.loads(payload.stdout)
    intervals: list[tuple[datetime, datetime]] = []
    failed = False

    for container in containers:
        name = container["Name"].lstrip("/")
        state = container["State"]
        start = timestamp(state["StartedAt"])
        finish = timestamp(state["FinishedAt"])
        intervals.append((start, finish))
        exit_code = state["ExitCode"]
        failed = failed or state["Running"] or exit_code != 0
        print(
            f"{name}: status={state['Status']} exit={exit_code} "
            f"started={start.isoformat()} finished={finish.isoformat()}"
        )

    overlap_start = max(interval[0] for interval in intervals)
    overlap_finish = min(interval[1] for interval in intervals)
    overlap_seconds = (overlap_finish - overlap_start).total_seconds()
    print(f"overlap_seconds={max(overlap_seconds, 0.0):.6f}")

    if failed:
        print("At least one container is still running or failed.", file=sys.stderr)
        return 3
    if overlap_seconds <= 0:
        print("The container execution intervals did not overlap.", file=sys.stderr)
        return 4
    print("concurrency_validation=passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
