# Validation status

Validated on 2026-10-07 using a paired Neat SDK and Modalix DevKit.

## Build validation

- Python syntax compilation passed for `main.py` and `verify-overlap.py`.
- Shell syntax validation passed for `run-devkit.sh`.
- C++20 cross-compilation passed with the SDK ARM64 compiler; the binary is an
  AArch64 ELF dynamically linked against `libsima_neat.so.6`.
- Buildx built and pushed both `linux/arm64` scratch images independently.
- DevKit image disk usage was 22 kB for `neat-yolo26-python:poc` and 111 kB
  for `neat-yolo26-cpp:poc`.
- The SDK 2.1.3 Model Zoo archive
  `models/yolo26m-det-int8-b1.tar.gz` has SHA-256
  `0d0e455a6d6656b66a465f2d6c61e128500809138bbec0237404f89dcd091097`.

## Concurrent DevKit validation

Both independent images were launched with the SWMLA-10052 security options,
completed 3,000 synthetic samples, and exited with status 0:

| Implementation | Latency | Throughput | Average power | Energy |
| --- | ---: | ---: | ---: | ---: |
| Python | 6.753842542666658 ms | 243.73930989244877 inf/s | 14.590134297520661 W | 179.59369220437733 J |
| C++ | 7.8469414426666715 ms | 267.39450643191816 inf/s | 14.339204545454546 W | 160.89222048516987 J |

Execution timing from Docker inspection:

- Python: `2026-10-08T00:01:27.454338Z` to
  `2026-10-08T00:02:10.804660Z`.
- C++: `2026-10-08T00:01:31.526887Z` to
  `2026-10-08T00:02:17.225048Z`.
- Verified overlap: 39.277773 seconds.

Reports are in `out/python.json` and `out/cpp.json`. The measurements are
concurrency smoke observations, not performance-comparison claims, because
both processes share one MLA device.

## Thin-image runtime note

ModelPack opens the archive listing through `/bin/sh`. The scratch containers
therefore require the DevKit's `/bin` and `/sbin` mounts in addition to the
runtime library mounts and writable executable `/tmp`. Both split-image runs
confirm that the consolidated launcher supplies these dependencies correctly.

## Bundled-Neat image validation

The optional `Dockerfile.bundled` targets were built from the matching runtime
staged from the paired DevKit:

- `neat-yolo26-python-bundled:poc`: 260 MB DevKit disk usage.
- `neat-yolo26-cpp-bundled:poc`: 260 MB DevKit disk usage.

Runtime checks confirmed that the applications selected the image-owned files:

- `pyneat` loaded from `/app/runtime/python/pyneat/__init__.py`.
- `libsima_neat.so.6` loaded from
  `/app/runtime/rootfs/usr/lib/libsima_neat.so.6`.
- GStreamer `neatprocessmla` loaded from
  `/app/runtime/rootfs/usr/lib/aarch64-linux-gnu/neat/gst-plugins/libgstneatprocessmla.so`.

Both bundled images then completed 3,000 synthetic samples with exit code 0:

| Implementation | Latency | Throughput | Average power | Energy |
| --- | ---: | ---: | ---: | ---: |
| Python | 6.899779667333336 ms | 190.0879655206825 inf/s | 14.48649193548387 W | 228.64552148348892 J |
| C++ | 6.9796696893333454 ms | 194.17707309136989 inf/s | 14.639802631578947 W | 226.19640691832566 J |

Their execution intervals overlapped for 44.644167 seconds. Reports are in
`out/python-bundled.json` and `out/cpp-bundled.json`. As with the thin-image
run, these are shared-device smoke observations rather than comparative
performance results.

This validation proves that Neat user space came from the images. It does not
remove the requirement for the deployment target's compatible OS libraries,
MLA platform runtime, kernel drivers, and device nodes.
