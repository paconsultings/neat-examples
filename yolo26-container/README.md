# Run YOLO26 Neat applications in containers

![Status: Preview](https://img.shields.io/badge/status-preview-orange)
![eLxr: 3.0.0](https://img.shields.io/badge/eLxr-3.0.0-blue)
![Recommended build: B1859](https://img.shields.io/badge/recommended_build-B1859-blueviolet)
![sima-cli: 2.1.19](https://img.shields.io/badge/sima--cli-2.1.19-blue)
![Neat SDK: develop](https://img.shields.io/badge/Neat_SDK-develop-blue)

> [!IMPORTANT]
> This example is a preview. Use eLxr 3.0.0, sima-cli 2.1.19, and a Neat SDK
> build from the `develop` branch. The recommended eLxr build ID is B1859.

This example runs the same YOLO26 benchmark in two ARM64 containers on a
Modalix DevKit:

- a Python application that uses the public `pyneat` API
- a C++20 application that uses the public Neat C++ API

You can run one application or both applications. You can also select a thin
image or a bundled image.

## Read the guides

For the first test, read these guides in order:

1. [Set up the development environment](docs/01-development-environment.md)
2. [Understand the application design](docs/02-application-design.md)
3. [Build and run the containers](docs/03-build-and-run.md)

## Quick start

Complete the setup guide first. Then, run these commands in the Neat SDK shell:

```bash
cd /workspace/neat-examples/yolo26-container

export RUNTIME_MODE=bundled

./run-devkit.sh build both
./run-devkit.sh run both
./run-devkit.sh wait both
./run-devkit.sh logs both
```

If the YOLO26 ModelPack is not present, the `run` action downloads it with
sima-cli. You must have access to the model in the SiMa Developer Portal.

The script keeps completed containers. Remove them when the test is complete:

```bash
./run-devkit.sh cleanup both
```

## Select an image type

| Application | Thin image | Bundled image |
| --- | --- | --- |
| Python | `neat-yolo26-python:poc` | `neat-yolo26-python-bundled:poc` |
| C++ | `neat-yolo26-cpp:poc` | `neat-yolo26-cpp-bundled:poc` |

A thin image uses the Neat installation on the DevKit. A bundled image includes
the Neat user-space runtime. Both image types use platform libraries, drivers,
and device nodes from the DevKit.

## Project files

| Path | Purpose |
| --- | --- |
| `main.py` | Runs the Python benchmark |
| `main.cpp` | Runs the C++ benchmark |
| `CMakeLists.txt` | Builds the C++20 application |
| `cmake/modalix-arm64.cmake` | Selects the ARM64 cross-toolchain |
| `Dockerfile.python` | Builds the thin Python image |
| `Dockerfile.cpp` | Builds the thin C++ image |
| `Dockerfile.bundled` | Builds a bundled Python or C++ image |
| `run-bundled-app.sh` | Checks the bundled Neat runtime at startup |
| `run-devkit.sh` | Builds, deploys, checks, and removes containers |
| `verify-overlap.py` | Checks that two containers ran at the same time |
| `docs/` | Contains setup, design, and test instructions |

## Security scope

This example is for development tests. It is not a production security
configuration or a performance test.

The launcher does not use `--privileged`. It maps only the required
accelerator devices. It also uses temporary SWMLA-10052 security options and
mounts system directories from the DevKit. Read the
[runtime contract](docs/02-application-design.md#devkit-runtime-contract)
before you change the launcher.
