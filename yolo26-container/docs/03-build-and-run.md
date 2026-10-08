# 3. Build and run the containers

Complete the [development environment setup](01-development-environment.md)
before running these commands. Unless a step says otherwise, run everything
from the paired Neat SDK shell.

## Enter the example directory

```bash
cd /workspace/neat-examples/yolo26-container
```

The launcher derives the DevKit project path from its own location. You do not
need to set `DEVKIT_PROJECT_DIR` for the standard workspace layout.

Verify the connection and registry:

```bash
type dk
dk status
test -n "${SIMA_CONTAINER_REGISTRY}"
```

## Obtain the YOLO26 ModelPack

The first `run` action downloads the pinned Model Zoo 2.1.3 artifact when this
file is missing:

```text
models/yolo26m-det-int8-b1.tar.gz
```

The download uses sima-cli 2.1.19 from the SDK shell. Authenticate first if
needed:

```bash
sima-cli login
```

To download the model before building or running, use:

```bash
mkdir -p models
sima-cli download \
  --dest models \
  https://docs.sima.ai/pkg_downloads/SDK2.1.3/models/modalix/yolo26-detection/yolo26m-det-int8-b1.tar.gz
```

The CLI resumes a partial download when possible. Do not commit the archive.

## Choose a packaging mode

The default is a thin image that uses Neat installed on the deployment target:

```bash
unset RUNTIME_MODE
```

To include matching Neat user space in the image:

```bash
export RUNTIME_MODE=bundled
```

Keep `RUNTIME_MODE` unchanged for `build`, `run`, `status`, `wait`, `logs`, and
`cleanup`. The two modes use different image, container, and report names.

## Build and publish images

Build both Python and C++ images:

```bash
./run-devkit.sh build both
```

Or build only one implementation:

```bash
./run-devkit.sh build python
./run-devkit.sh build cpp
```

The Python build packages `main.py`. The C++ build stages matching public Neat
development files from the DevKit, cross-compiles `main.cpp`, and verifies the
ARM64 executable. Bundled mode additionally stages Neat runtime files and
plugins from the paired DevKit.

Buildx uses `--platform linux/arm64` and `--push`. The images go directly to
`SIMA_CONTAINER_REGISTRY`, where the DevKit can download them. Do not replace
`--push` with `--load`; `--load` puts the image only in the host Docker engine.

## Run one application

Start Python in the background:

```bash
./run-devkit.sh run python
```

Wait for completion and inspect its output:

```bash
./run-devkit.sh wait python
./run-devkit.sh logs python
```

Run C++ the same way:

```bash
./run-devkit.sh run cpp
./run-devkit.sh wait cpp
./run-devkit.sh logs cpp
```

`wait` exits unsuccessfully when the selected container has a nonzero exit
code. Containers remain available for inspection after completion.

## Run Python and C++ concurrently

Start both containers:

```bash
./run-devkit.sh run both
```

Inspect their current state, wait for completion, and show their logs:

```bash
./run-devkit.sh status both
./run-devkit.sh wait both
./run-devkit.sh logs both
```

`wait both` checks both exit codes and compares the Docker start and finish
timestamps. Success ends with output similar to:

```text
<python-container>: status=exited exit=0 started=... finished=...
<cpp-container>: status=exited exit=0 started=... finished=...
overlap_seconds=13.088961
concurrency_validation=passed
```

This proves that the two applications ran at the same time. It does not compare
their performance because they share the MLA device.

## Change the test duration

Each application processes 3,000 synthetic samples by default. Set `FRAMES`
only on the `run` command to change the sample count:

```bash
FRAMES=100 ./run-devkit.sh run python
FRAMES=5000 ./run-devkit.sh run both
```

The value is captured when the containers start. It is not needed for later
`wait`, `status`, or `logs` commands.

## Inspect and clean up

List the selected containers and view their logs:

```bash
./run-devkit.sh status both
./run-devkit.sh logs both
```

Remove retained containers before starting another run with the same names:

```bash
./run-devkit.sh cleanup both
```

You can also clean up only `python` or `cpp`. Cleanup removes containers but
does not remove images, the ModelPack, or JSON reports.

## Launcher configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `RUNTIME_MODE` | `host` | Select `host` for thin images or `bundled` |
| `FRAMES` | `3000` | Number of synthetic samples processed by each app |
| `DEVKIT_PROJECT_DIR` | Script directory | Override the shared project path |
| `MODEL_PATH` | `<project>/models/yolo26m-det-int8-b1.tar.gz` | Use an existing ModelPack at another path |
| `MODEL_URL` | Pinned Model Zoo 2.1.3 URL | Override the automatic download source |
| `PYTHON_IMAGE` | Mode-specific name | Override the Python image name |
| `CPP_IMAGE` | Mode-specific name | Override the C++ image name |
| `PYTHON_CONTAINER` | Mode-specific name | Override the Python container name |
| `CPP_CONTAINER` | Mode-specific name | Override the C++ container name |

## Troubleshooting

### `dk is unavailable`

The command is running outside the paired SDK shell, or SDK setup did not
finish. On the host, reinstall and set up the develop SDK, enter the DevKit IP
when prompted, and open the SDK shell:

```bash
sima-cli neat install sdk@develop
sima-cli sdk neat
```

### `SIMA_CONTAINER_REGISTRY is unset`

Run `sima-cli neat install sdk@develop` again, enable the local registry during
setup, enter the DevKit IP when prompted, and then open a new SDK shell.

### The repository is not under `/workspace`

Clone or move the repository under the default host workspace, then re-enter
the SDK shell:

```bash
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/paconsultings/neat-examples.git
sima-cli sdk neat
```

### The model download fails or redirects repeatedly

Install the required sima-cli prerelease from the `develop` branch, confirm the
version, and authenticate again:

```bash
sima-cli selfupdate --prod --branch develop
sima-cli --version
sima-cli login
```

Then repeat `./run-devkit.sh run ...`. You may also download the archive on an
authenticated host and place it in `models/` inside the shared workspace.

### A container with the same name already exists

Inspect it if needed, then remove it before the next run:

```bash
./run-devkit.sh logs both
./run-devkit.sh cleanup both
```

### Docker is unavailable on the DevKit

Run:

```bash
dk container setup
```

Approve the installation, or use `--yes` only when the noninteractive changes
are already approved.

### The DevKit cannot download an image

Check connectivity among the host, Docker or Colima VM, and DevKit. Repeat SDK
setup if the host address changed. Confirm the registry value inside the SDK:

```bash
printf '%s\n' "${SIMA_CONTAINER_REGISTRY}"
```

### An image has the wrong architecture

Build it through `run-devkit.sh`. The launcher selects `linux/arm64` and checks
that the C++ executable is ARM64.

### MLA initialization reports a missing device

Confirm eLxr 3.0.0 and the required DevKit devices. Build ID B1859 is
recommended:

```bash
dk shell
ls -l /dev/dma_heap/linux,cma /dev/mla /dev/cvu
exit
```

The launcher maps these devices explicitly and does not require
`--privileged`.

### A bundled build cannot stage Neat

The paired source DevKit must contain compatible `sima-neat`, `sima-neat-dev`,
`neat-runtime`, `neat-gst-plugins`, `sima-lmm-core`, and `pyneat` installations.
Use a DevKit that matches the runtime version you intend to package.
