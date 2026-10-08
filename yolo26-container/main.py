#!/usr/bin/env python3
"""Run a YOLO26 package through pyneat's synthetic model benchmark."""

from __future__ import annotations

import argparse
import glob
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


DECODE_TYPES = {"yolo26-det": "YoloV26", "yolo26-seg": "YoloV26Seg"}
BOXDECODE_TOP_K = 100


def add_target_python_paths() -> None:
    """Expose target-owned Debian modules when running in the thin container."""
    for path in glob.glob("/usr/lib/python3*/dist-packages"):
        if path not in sys.path:
            sys.path.insert(0, path)


def spec_strings(model: object, method_name: str) -> list[str]:
    try:
        return [str(spec) for spec in getattr(model, method_name)()]
    except Exception as exc:  # Keep a successful benchmark useful if introspection fails.
        return [f"unavailable: {exc}"]


def route_fields(model: object) -> dict:
    try:
        info = model.info()
    except Exception as exc:
        return {"resolved_postprocess": f"unavailable: {exc}", "output_topology": None}
    return {
        "resolved_postprocess": info.selection.selected_post_kind,
        "output_topology": {
            "physical": info.output_topology.physical_outputs,
            "logical": info.output_topology.logical_outputs,
            "packed": info.output_topology.packed_outputs,
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True, help="compiled YOLO26 .tar.gz package")
    parser.add_argument("--frames", type=int, default=100, help="measured synthetic frames")
    parser.add_argument(
        "--decode-type",
        choices=sorted(DECODE_TYPES),
        default="yolo26-det",
        help="BoxDecode route to exercise",
    )
    parser.add_argument(
        "--output-json",
        type=Path,
        default=Path("/workspace/yolo26-container/out/report.json"),
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="validate the mounted target runtime and model without running inference",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.frames <= 0:
        print("--frames must be greater than zero", file=sys.stderr)
        return 2
    if not args.model.is_file():
        print(f"model file does not exist: {args.model}", file=sys.stderr)
        return 2

    add_target_python_paths()
    try:
        import pyneat
    except ImportError as exc:
        print(f"pyneat is not importable from the mounted DevKit runtime: {exc}", file=sys.stderr)
        return 3

    print(f"python={sys.executable}")
    print(f"pyneat={Path(pyneat.__file__).resolve()}")
    print(f"model={args.model}")
    if args.validate_only:
        print("runtime_validation=ok")
        return 0

    try:
        options = pyneat.ModelOptions()
        options.decode_type = getattr(pyneat.BoxDecodeType, DECODE_TYPES[args.decode_type])
        options.top_k = BOXDECODE_TOP_K
        model = pyneat.Model(str(args.model), options)
        report = model.benchmark(args.frames)
    except Exception as exc:
        print(f"benchmark failed: {exc}", file=sys.stderr)
        return 4

    result = {
        "implementation": "python",
        "benchmark": {
            "type": "model.synthetic",
            "frames": args.frames,
            "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        },
        "model": {
            "path": str(args.model),
            "file": args.model.name,
            "requested_decode_type": args.decode_type,
            "boxdecode_top_k": BOXDECODE_TOP_K,
            **route_fields(model),
            "input_specs": spec_strings(model, "input_specs"),
            "output_specs": spec_strings(model, "output_specs"),
        },
        "metrics": {
            "latency_ms": report.latency_ms,
            "fps": report.fps,
            "avg_power_watts": report.avg_power_watts,
            "energy_joules": report.energy_joules,
        },
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    print(f"latency_ms={report.latency_ms}")
    print(f"fps={report.fps}")
    print(f"avg_power_watts={report.avg_power_watts}")
    print(f"energy_joules={report.energy_joules}")
    print(f"report_json={args.output_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
