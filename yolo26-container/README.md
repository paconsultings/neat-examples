# Run YOLO26 Neat applications in containers

![Status: Preview](https://img.shields.io/badge/status-preview-orange)
![eLxr: 3.0.0](https://img.shields.io/badge/eLxr-3.0.0-blue)
![Recommended build: B1859](https://img.shields.io/badge/recommended_build-B1859-blueviolet)
![sima-cli: 2.1.19](https://img.shields.io/badge/sima--cli-2.1.19-blue)
![Neat SDK: develop](https://img.shields.io/badge/Neat_SDK-develop-blue)
[![Bundled images](https://github.com/paconsultings/neat-examples/actions/workflows/yolo26-bundled-images.yml/badge.svg)](https://github.com/paconsultings/neat-examples/actions/workflows/yolo26-bundled-images.yml)

> [!IMPORTANT]
> This example is a preview. The prebuilt image requires eLxr 3.0.0 and
> sima-cli 2.1.19. Building an image also requires a Neat SDK build from the
> `develop` branch. The recommended eLxr build ID is B1859.

This example runs the same YOLO26 benchmark in two ARM64 containers on a
Modalix DevKit:

- a Python application that uses the public `pyneat` API
- a C++20 application that uses the public Neat C++ API

## Quick start with a prebuilt container image

This sample project uses a CI/CD workflow to build the bundled ARM64 container
images automatically. The workflow runs on an ARM64 GitHub-hosted runner and
publishes the images to GitHub Container Registry (GHCR). The `develop` tag
points to the latest successful build from the `main` branch.

This quick start uses the prebuilt Python image. You do not have to build the
application, install the Neat SDK, or install Neat Core before you run it.

The DevKit must have Docker and sima-cli 2.1.19. You do not need to clone this
repository for the prebuilt-image test. The commands create a working directory
under `/workspace` on the DevKit.

From the development host, connect directly to the DevKit. Replace
`DEVKIT_IP` with the DevKit IP address:

```bash
ssh sima@DEVKIT_IP
```

### Download the model

Run these commands on the DevKit. You must have a valid SiMa Developer Portal
account to download the model.

```bash
sima-cli --version

export PROJECT_DIR=/workspace/neat-examples/yolo26-container
mkdir -p "${PROJECT_DIR}"
cd "${PROJECT_DIR}"
mkdir -p models out

sima-cli download --dest models \
  https://docs.sima.ai/pkg_downloads/SDK2.1.3/models/modalix/yolo26-detection/yolo26m-det-int8-b1.tar.gz

test -f models/yolo26m-det-int8-b1.tar.gz
```

### Pull and run the prebuilt Python image

The image is public. Pull and run it without GHCR authentication:

```bash
export PROJECT_DIR=/workspace/neat-examples/yolo26-container
export IMAGE=ghcr.io/paconsultings/neat-yolo26-python-bundled:develop

docker pull "${IMAGE}"

docker run --name neat-yolo26-python-bundled \
  --network host \
  --ipc host \
  --device /dev/dma_heap/linux,cma:/dev/dma_heap/linux,cma \
  --device /dev/mla:/dev/mla \
  --device /dev/cvu:/dev/cvu \
  --security-opt systempaths=unconfined \
  --security-opt seccomp=unconfined \
  --volume /bin:/bin:ro \
  --volume /sbin:/sbin:ro \
  --volume /usr:/usr:ro \
  --volume /etc:/etc:ro \
  --volume /opt:/opt:ro \
  --volume /lib:/lib:ro \
  --volume /media/nvme:/media/nvme \
  --volume /workspace:/workspace \
  --tmpfs /tmp:rw,exec,nosuid,size=512m,mode=1777 \
  --env HOME=/tmp \
  --env XDG_CACHE_HOME=/tmp/.cache \
  "${IMAGE}" \
  --model "${PROJECT_DIR}/models/yolo26m-det-int8-b1.tar.gz" \
  --frames 3000 \
  --decode-type yolo26-det \
  --output-json "${PROJECT_DIR}/out/python-bundled.json"
```

The container remains on the DevKit after it stops. Remove it before you run
the same command again:

```bash
docker rm neat-yolo26-python-bundled
```

## Build your own container images

After the prebuilt image runs successfully, set up the development environment
and build the images. Read these guides in order:

1. [Set up the development environment](docs/01-development-environment.md)
2. [Understand the application design](docs/02-application-design.md)
3. [Build and run the containers](docs/03-build-and-run.md)

### Build and run with the example script

The example script builds the images and pushes them to the local registry
configured by the SDK. It can then download a missing model, deploy one or
both images, and retain the containers for inspection. Run it from the SDK
shell:

```bash
cd /workspace/neat-examples/yolo26-container

export RUNTIME_MODE=bundled

./run-devkit.sh build both
./run-devkit.sh run both
./run-devkit.sh wait both
./run-devkit.sh logs both
```

The script supplies the default image names. Set `PYTHON_IMAGE` or `CPP_IMAGE`
only when you want to use different names.

If the YOLO26 ModelPack is not present, the `run` action downloads it with
`sima-cli`.

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
| `prepare-build.sh` | Stages Neat from the SDK and builds the C++ application |
| `run-bundled-app.sh` | Checks the bundled Neat runtime at startup |
| `run-devkit.sh` | Builds, deploys, checks, and removes containers |
| `verify-overlap.py` | Checks that two containers ran at the same time |
| `docs/` | Contains setup, design, and test instructions |

## Published images

GitHub Actions builds both bundled images on an ARM64 GitHub-hosted runner. It
publishes a moving `develop` tag and an immutable `sha-<commit>` tag:

- `ghcr.io/paconsultings/neat-yolo26-python-bundled:develop`
- `ghcr.io/paconsultings/neat-yolo26-cpp-bundled:develop`

The workflow installs Neat in the SDK. It does not copy Neat files from a
DevKit.

## Security scope

This example is for development tests. It is not a production security
configuration or a performance test.

The launcher does not use `--privileged`. It maps only the required
accelerator devices. It also uses temporary runtime security options and
mounts system directories from the DevKit. Read the
[runtime contract](docs/02-application-design.md#devkit-runtime-contract)
before you change the launcher.
