# Run Python and C++ Neat applications in containers

![Status: Preview](https://img.shields.io/badge/status-preview-orange)
![eLxr: 3.0.0](https://img.shields.io/badge/eLxr-3.0.0-blue)
![sima-cli: 2.1.19](https://img.shields.io/badge/sima--cli-2.1.19-blue)
![Neat SDK: develop](https://img.shields.io/badge/Neat_SDK-develop-blue)

> [!IMPORTANT]
> This is a preview workflow. It requires eLxr 3.0.0, sima-cli 2.1.19, and a
> Neat SDK image built from the `develop` branch.

At the time this guide was created, sima-cli 2.1.19 was a prerelease. Install
or update to the required build from the `develop` branch with:

```bash
sima-cli selfupdate --prod --branch develop
```

This example builds and runs the same YOLO26 Neat benchmark as two independent
ARM64 containers on a Modalix DevKit:

- a Python application using the public `pyneat` API; and
- a C++20 application cross-compiled with the Neat SDK.

You can run either implementation alone or run both concurrently. The example
also compares thin images, which use Neat installed on the target, with bundled
images, which carry the matching Neat user-space runtime.

## Documentation

Follow the guides in order on your first run:

1. [Set up the development environment](docs/01-development-environment.md)
2. [Understand the application and container design](docs/02-application-design.md)
3. [Build and run the containers](docs/03-build-and-run.md)

The guides are self-contained; you do not need a separate SDK issue or
technical note to complete the example.

## Quick start

After completing the development-environment guide, enter the paired SDK shell
and run:

```bash
cd /workspace/neat-examples/yolo26-container

export RUNTIME_MODE=bundled

./run-devkit.sh build both
./run-devkit.sh run both
./run-devkit.sh wait both
./run-devkit.sh logs both
```

The `run` action downloads the pinned YOLO26 ModelPack with `sima-cli` when it
is not already present. Containers are retained after they finish. Remove them
when you are done:

```bash
./run-devkit.sh cleanup both
```

## Image variants

| Application | Thin image | Bundled-Neat image |
| --- | --- | --- |
| Python | `neat-yolo26-python:poc` | `neat-yolo26-python-bundled:poc` |
| C++ | `neat-yolo26-cpp:poc` | `neat-yolo26-cpp-bundled:poc` |

Thin images are smaller but require compatible Neat packages on the deployment
target. Bundled images include Neat user space, but still require the target's
eLxr libraries, MLA platform runtime, kernel drivers, and device nodes.

## Project contents

| Path | Purpose |
| --- | --- |
| `main.py` | Python implementation using `pyneat.Model.benchmark()` |
| `main.cpp` | C++ implementation using `simaai::neat::Model::benchmark()` |
| `CMakeLists.txt` | Builds the C++20 application against public Neat APIs |
| `cmake/modalix-arm64.cmake` | Selects the SDK ARM64 cross-toolchain |
| `Dockerfile.python` | Builds the thin Python image |
| `Dockerfile.cpp` | Builds the thin C++ image |
| `Dockerfile.bundled` | Builds either application with Neat user space included |
| `run-bundled-app.sh` | Verifies that bundled Neat files are selected at startup |
| `run-devkit.sh` | Downloads, builds, deploys, inspects, and removes containers |
| `verify-overlap.py` | Confirms that two completed containers ran concurrently |
| `docs/` | Guided setup, design, and operation documentation |

## Preview and security scope

This is a functional development workflow, not a production container-security
profile or a performance comparison. The launcher uses explicit accelerator
devices instead of `--privileged`, but it still applies temporary SWMLA-10052
security workarounds and mounts several DevKit system directories. Review the
[runtime design](docs/02-application-design.md#devkit-runtime-contract) before
adapting it for production.
