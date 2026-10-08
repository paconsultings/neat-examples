# 2. Understand the application and container design

This example exercises the same compiled YOLO26 ModelPack through public Neat
APIs in Python and C++. It deliberately keeps the applications small so the
container, cross-build, runtime, and concurrency behavior remain visible.

## End-to-end flow

1. `run-devkit.sh build` creates one or both `linux/arm64` images.
2. Buildx pushes the images to `SIMA_CONTAINER_REGISTRY`.
3. `run-devkit.sh run` asks the DevKit to pull and start the selected images.
4. Each application benchmarks synthetic input through the YOLO26 model.
5. Each application writes a JSON report into the shared `out/` directory.
6. `run-devkit.sh wait both` checks both exit codes and proves their execution
   intervals overlapped.

The overlap check is a functional concurrency test. It is not a performance
comparison because both processes share one MLA device.

## Python application

`main.py` imports public `pyneat`, configures `ModelOptions` for YOLO26 object
detection, loads the ModelPack, and calls `Model.benchmark()`. It records:

- the selected Python and `pyneat` paths;
- the model and decode configuration;
- logical and physical output information when available; and
- latency, throughput, power, and energy fields returned by Neat.

The thin Python image contains only `main.py` and starts it with the DevKit's
`/media/nvme/pyneat` Python environment. The bundled Python image includes the
matching `pyneat` package under `/app/runtime/python` and verifies that this
copy is selected before the application starts.

## C++ application

`main.cpp` uses C++20 and the public `<neat.h>` API. It applies the same YOLO26
decode configuration, calls `simaai::neat::Model::benchmark()`, and writes a
JSON report with the same primary metrics as the Python implementation.

The build uses `find_package(SimaNeat REQUIRED)` and links
`SimaNeat::sima_neat`. `run-devkit.sh` stages the matching public development
files from the paired DevKit, cross-compiles with the SDK ARM64 toolchain, and
checks that the result is an AArch64 executable before building the image.

## Thin and bundled images

| Property | Thin image | Bundled-Neat image |
| --- | --- | --- |
| Application code | Included | Included |
| Neat shared libraries and plugins | Supplied by target | Included under `/app/runtime` |
| `pyneat` for Python | Supplied by target | Included under `/app/runtime/python` |
| Platform OS and GStreamer libraries | Supplied by target | Supplied by target |
| MLA-RT, kernel drivers, and devices | Supplied by target | Supplied by target |
| Typical use | Small image on a prepared DevKit | Portable Neat user space on a compatible platform |

The bundled image is not a complete DevKit root filesystem. It still requires
eLxr 3.0.0 on Modalix, Python 3.13 for the Python target, compatible platform
libraries, MLA-RT, kernel drivers, and SiMa device nodes. Build ID B1859 is the
recommended eLxr 3.0.0 build for this preview.

Building a bundled image requires a paired source DevKit containing the Neat
version to package. The script copies the relevant user-space files into the
ignored `build/bundled-runtime/` directory and then into the image. At startup:

- Python must load `pyneat` from `/app/runtime/python`.
- C++ must load `libsima_neat.so.6` from `/app/runtime/rootfs`.

The startup wrapper fails if either application silently resolves Neat from
the target instead.

Bundled SiMa files remain subject to SiMa software distribution terms. Confirm
that you are authorized to redistribute them before publishing an image beyond
the approved development registry.

## DevKit runtime contract

The launcher does not use Docker privileged mode. It maps the three devices
required by this workload:

```text
/dev/dma_heap/linux,cma
/dev/mla
/dev/cvu
```

The current eLxr/MLA runtime limitations tracked by SWMLA-10052 also require:

```text
--security-opt systempaths=unconfined
--security-opt seccomp=unconfined
```

The launcher mounts `/bin`, `/sbin`, `/usr`, `/etc`, `/opt`, `/lib`,
`/media/nvme`, and `/workspace` from the DevKit. A writable, executable `/tmp`
is provided separately. The system mounts supply platform libraries and tools;
bundled Neat files remain under `/app/runtime` so the mounts do not hide them.

This remains a broad development-time runtime contract. The explicit device
list is narrower than `--privileged`, but the system mounts and unconfined
security options are not a production isolation boundary.

## Model and reports

Both applications use:

```text
models/yolo26m-det-int8-b1.tar.gz
```

When the archive is missing, `run-devkit.sh run` uses `sima-cli` to retrieve it
from the SiMa Developer Portal. The user must have a valid Developer Portal
account with access to the model and an authenticated `sima-cli` session. Run
`sima-cli login` before starting the example if authentication has not already
been configured.

The downloaded model is ignored by Git. With the default thin mode, reports
are written to `out/python.json` and `out/cpp.json`. Bundled mode uses
`out/python-bundled.json` and `out/cpp-bundled.json`.

Models, reports, staged runtime files, cross-build output, and container layers
must not be committed to this repository.

## Next step

Continue with [Build and run the containers](03-build-and-run.md).
