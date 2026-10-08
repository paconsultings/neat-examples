# 2. Understand the application design

This example runs the same YOLO26 ModelPack with the public Neat APIs for
Python and C++. The applications are small so that you can examine the build
and container behavior.

## Test sequence

The test has these steps:

1. `run-devkit.sh build` builds one or two `linux/arm64` images.
2. Docker Buildx pushes the images to `SIMA_CONTAINER_REGISTRY`.
3. `run-devkit.sh run` makes the DevKit pull and start the images.
4. Each application runs the YOLO26 benchmark with synthetic input.
5. Each application writes a JSON report to the shared `out/` directory.
6. `run-devkit.sh wait both` checks the exit codes and execution times.

The last step checks that both containers ran at the same time. It does not
compare performance. Both applications use the same MLA device.

## Python application

`main.py` uses the public `pyneat` API. It does these operations:

1. Sets the YOLO26 object-detection options.
2. Loads the ModelPack.
3. Calls `Model.benchmark()`.
4. Writes the benchmark data to a JSON report.

The report includes the Python and `pyneat` paths, model configuration, output
information, latency, throughput, power, and energy.

The thin image starts the application with the DevKit Python environment at
`/media/nvme/pyneat`. The bundled image uses the `pyneat` package in
`/app/runtime/python`.

## C++ application

`main.cpp` uses C++20 and the public `<neat.h>` API. It uses the same model
configuration as the Python application. It calls
`simaai::neat::Model::benchmark()` and writes the results to JSON.

CMake finds `SimaNeat` and links `SimaNeat::sima_neat`. The launcher copies
the public development files from the DevKit. It then cross-compiles the
application with the SDK ARM64 toolchain. The build stops if the executable is
not AArch64.

## Image types

| Item | Thin image | Bundled image |
| --- | --- | --- |
| Application | Included | Included |
| Neat libraries and plug-ins | From the DevKit | In `/app/runtime` |
| Python `pyneat` package | From the DevKit | In `/app/runtime/python` |
| eLxr and GStreamer libraries | From the DevKit | From the DevKit |
| MLA runtime, drivers, and devices | From the DevKit | From the DevKit |
| Use | Small image for a prepared DevKit | Image with Neat user space |

A bundled image is not a complete DevKit file system. It still requires these
items on the DevKit:

- eLxr 3.0.0 on Modalix
- compatible platform libraries
- MLA runtime
- kernel drivers and SiMa device nodes
- Python 3.13 for the Python application

Build ID B1859 is recommended for this preview.

To build a bundled image, pair the SDK with a DevKit that has the required Neat
version. The launcher copies the Neat files to
`build/bundled-runtime/`. Git ignores this directory.

At startup, the wrapper checks the source of the Neat files:

- Python must load `pyneat` from `/app/runtime/python`.
- C++ must load `libsima_neat.so.6` from `/app/runtime/rootfs`.

The container stops if it loads these files from the DevKit installation.

> [!IMPORTANT]
> SiMa software distribution terms apply to the files in a bundled image.
> Before you publish an image, confirm that you can redistribute these files.

## DevKit runtime contract

The launcher maps these device files:

```text
/dev/dma_heap/linux,cma
/dev/mla
/dev/cvu
```

The launcher does not use `--privileged`.

The current eLxr and MLA runtime require these temporary options:

```text
--security-opt systempaths=unconfined
--security-opt seccomp=unconfined
```

The launcher mounts these DevKit directories:

```text
/bin
/sbin
/usr
/etc
/opt
/lib
/media/nvme
/workspace
```

It also provides a writable and executable `/tmp`. The mounts supply platform
libraries and tools. They do not hide the bundled Neat files in
`/app/runtime`.

This configuration is for development tests. The explicit device list is more
limited than `--privileged`. However, the system mounts and unconfined
security options do not provide a production isolation boundary.

## Model and reports

Both applications use this ModelPack:

```text
models/yolo26m-det-int8-b1.tar.gz
```

If this file is not present, `run-devkit.sh run` downloads it from the SiMa
Developer Portal. You need:

- a valid Developer Portal account
- access to the model
- an authenticated sima-cli session

If necessary, run:

```bash
sima-cli login
```

Git ignores the downloaded model. The default thin mode writes
`out/python.json` and `out/cpp.json`. Bundled mode writes
`out/python-bundled.json` and `out/cpp-bundled.json`.

Do not commit models, reports, runtime files, build output, or container layers.

## Next step

Continue with [Build and run the containers](03-build-and-run.md).
