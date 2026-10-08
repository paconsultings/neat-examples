# Run Python and C++ Neat applications in containers

This example shows how to build and run a Neat application as an ARM64
container on a Modalix DevKit. It provides the same YOLO26 model benchmark in
two languages:

| Application | Thin image | Bundled-Neat image |
| --- | --- | --- |
| Python | `neat-yolo26-python:poc` | `neat-yolo26-python-bundled:poc` |
| C++ | `neat-yolo26-cpp:poc` | `neat-yolo26-cpp-bundled:poc` |

You can run either application by itself or run both containers concurrently.
The concurrent mode demonstrates that two independent containerized Neat
applications can execute on the same DevKit. It is a functional smoke test,
not a performance comparison, because both applications share the MLA device.

## How the example works

The development flow is:

1. Build one or both `linux/arm64` images in the Neat SDK.
2. Push the images to the local registry configured by SDK setup.
3. Ask the DevKit to download and start the selected image or images.
4. Run a synthetic YOLO26 benchmark using the mounted model package.
5. Write a JSON report to the shared workspace.

The example supports two runtime packaging modes. The default thin images
contain only the application and use the Neat installation on the DevKit. The
optional bundled images also carry the matching Neat library, Neat runtime and
GStreamer plugins, and `pyneat` package.

Both modes continue to use the DevKit's base operating-system libraries, MLA
platform runtime, kernel drivers, device nodes, model storage, and workspace.

## Prerequisites and development environment

Before using this example, follow the prerequisites and environment setup in
[SDK issue #236: Build and run a container application with the Neat SDK](https://github.com/sima-neat/sdk/issues/236).
In particular, complete the steps that:

- install and verify Docker and Buildx on the development host;
- pair the SDK with your DevKit using `sima-cli sdk setup`;
- enter the Neat SDK shell;
- verify that `SIMA_CONTAINER_REGISTRY` is configured; and
- prepare Docker on the DevKit with `dk container setup`.

The host and DevKit must be able to reach each other over the network. Run the
model download, image build, and DevKit commands inside the paired Neat SDK
shell.

This example additionally requires the YOLO26 ModelPack. When
`run-devkit.sh run` cannot find it, the script uses `sima-cli` to download the
Model Zoo `2.1.3` artifact automatically. To download it ahead of time, run:

```bash
cd path/to/yolo26-container
mkdir -p models
sima-cli download \
  --dest models \
  https://docs.sima.ai/pkg_downloads/SDK2.1.3/models/modalix/yolo26-detection/yolo26m-det-int8-b1.tar.gz
```

The command authenticates through `sima-cli`, downloads the archive if it is
missing, and safely skips it when the complete file is already present. The
result must be:

```text
<example-directory>/models/yolo26m-det-int8-b1.tar.gz
```

The `models` directory is shared with the SDK and DevKit through `/workspace`,
so no additional copy step is required. Do not commit the model package to
source control.

## Project contents

The important files are:

| File | Purpose |
| --- | --- |
| `main.py` | Python implementation using `pyneat.Model.benchmark()` |
| `main.cpp` | C++ implementation using `simaai::neat::Model::benchmark()` |
| `Dockerfile.python` | Builds the Python application image |
| `Dockerfile.cpp` | Builds the C++ application image |
| `Dockerfile.bundled` | Builds either application with Neat user space included |
| `run-bundled-app.sh` | Verifies that the bundled Neat runtime is selected |
| `run-devkit.sh` | Builds, deploys, inspects, and removes the containers |
| `verify-overlap.py` | Confirms that two completed containers ran concurrently |

## Choose the runtime packaging mode

### Thin images: use Neat from the deployment target

This is the default mode. The images are very small, but the deployment DevKit
must already have a compatible Neat installation, including `pyneat` for the
Python application:

```bash
./run-devkit.sh build both
./run-devkit.sh run both
```

### Bundled images: include Neat in the images

Set `RUNTIME_MODE=bundled` to use the multi-stage `Dockerfile.bundled`:

```bash
export RUNTIME_MODE=bundled

./run-devkit.sh build both
./run-devkit.sh run both
./run-devkit.sh wait both
./run-devkit.sh logs both
```

The build exports the matching Neat user-space files from the paired source
DevKit and packages them under `/app/runtime`. The resulting deployment target
does not need these packages installed:

- `sima-neat`;
- `neat-runtime`;
- `neat-gst-plugins`; or
- the `/media/nvme/pyneat` environment.

The bundled images are not a complete DevKit root filesystem. The deployment
target must still run a compatible SiMa platform release and provide Python
3.13 for the Python image, the normal OS/GStreamer/OpenCV libraries, MLA-RT,
kernel drivers, and SiMa device nodes. Building also requires one paired source
DevKit with the desired Neat version so the script can stage the runtime.

At startup, the bundled Python image verifies that `pyneat` resolves under
`/app/runtime/python`. The bundled C++ image verifies that `libsima_neat.so.6`
resolves under `/app/runtime/rootfs`. A mismatch fails immediately instead of
silently using Neat from the host.

The bundled files may be subject to SiMa software distribution terms. Confirm
that you are authorized to redistribute them before publishing an image beyond
your approved registry or development environment.

Keep `RUNTIME_MODE=bundled` set for `status`, `wait`, `logs`, and `cleanup`,
because bundled mode uses distinct image and container names. Return to the
default thin-image mode with:

```bash
unset RUNTIME_MODE
```

## Build the images

Change to the example directory in the SDK workspace:

```bash
cd /workspace/yolo26-container
```

Build and publish both images for the selected runtime mode:

```bash
./run-devkit.sh build
```

`both` is the default target for `build`. You can instead build only one image:

```bash
./run-devkit.sh build python
./run-devkit.sh build cpp
```

Without `RUNTIME_MODE`, these commands build the thin images. The Python build
packages `main.py`. The C++ build first cross-compiles
`main.cpp` for ARM64 and then packages the resulting executable. To compile
against the same Neat version that is installed on the target, the script
stages the DevKit's public Neat development files under the ignored
`build/devkit-neat-root` directory. These development files are not copied
into the image.

Buildx pushes each completed image to `SIMA_CONTAINER_REGISTRY`. The DevKit can
then download it through `dk container deploy`.

## Run one application

Start the Python container in the background:

```bash
./run-devkit.sh run python
```

Wait for the benchmark to finish and then view its output:

```bash
./run-devkit.sh wait python
./run-devkit.sh logs python
```

Use the same workflow for C++:

```bash
./run-devkit.sh run cpp
./run-devkit.sh wait cpp
./run-devkit.sh logs cpp
```

Thin-image reports are written to `out/python.json` and `out/cpp.json`.
Bundled-image reports are written to `out/python-bundled.json` and
`out/cpp-bundled.json`.

## Run both applications concurrently

Start one Python container and one C++ container:

```bash
./run-devkit.sh run both
```

The command returns after both containers have started. Check their current
state with:

```bash
./run-devkit.sh status both
```

Wait for both benchmarks to finish:

```bash
./run-devkit.sh wait both
```

`wait both` does not start another test. It waits for the two containers that
were started by `run both`. After both stop, it checks their exit codes and
compares their Docker start and finish timestamps. A successful result ends
with output similar to:

```text
<python-container>: status=exited exit=0 started=... finished=...
<cpp-container>: status=exited exit=0 started=... finished=...
overlap_seconds=39.277773
concurrency_validation=passed
```

`concurrency_validation=passed` means both applications exited successfully
and their execution intervals overlapped.

View both logs with:

```bash
./run-devkit.sh logs both
```

## Change the test duration

Each application processes 3,000 synthetic samples by default. This keeps the
containers active long enough to observe concurrent execution. Set `FRAMES`
when starting the containers to change the sample count:

```bash
FRAMES=100 ./run-devkit.sh run python
FRAMES=5000 ./run-devkit.sh run both
```

The value is captured when the container starts; it does not need to be passed
again to `wait`, `status`, or `logs`.

## Inspect and remove containers

Completed containers are retained so you can inspect their state and logs:

```bash
./run-devkit.sh status both
./run-devkit.sh logs both
```

You must remove retained containers before starting another run with the same
names:

```bash
./run-devkit.sh cleanup python
./run-devkit.sh cleanup cpp
```

Remove both with one command:

```bash
./run-devkit.sh cleanup both
```

Removing a container does not remove its image, model, or JSON report.

## Current DevKit runtime workarounds

This YOLO26 application uses the MLA accelerator. The launcher currently adds
the following options for the DevKit runtime limitations tracked by
`SWMLA-10052`:

- `--security-opt systempaths=unconfined` allows MLA-RT to resolve the reserved
  memory device-tree path.
- `--security-opt seccomp=unconfined` allows MLA-RT to use the required
  `io_uring` system calls.
- `--privileged` exposes the SiMa device nodes to the container.

The launcher also mounts `/bin`, `/sbin`, `/usr`, `/etc`, `/opt`, `/lib`,
`/media/nvme`, and `/workspace` from the DevKit. A writable executable `/tmp`
is provided separately. Bundled Neat files live under `/app/runtime`, so these
platform mounts do not hide them.

These settings intentionally favor functional validation. They provide broad
access to the DevKit and are not a production container-security boundary.

## Troubleshooting

### `dk is unavailable`

Run the example inside the paired SDK shell. If necessary, repeat the SDK setup
procedure from issue #236 and open a new SDK shell.

### `SIMA_CONTAINER_REGISTRY is unset`

Repeat `sima-cli sdk setup --devkit <devkit-ip>` and then enter a new SDK shell.

### The model cannot be opened

Confirm that this file exists and is a valid ModelPack archive:

```text
/workspace/yolo26-container/models/yolo26m-det-int8-b1.tar.gz
```

If it is missing or incomplete, run `run-devkit.sh run` again or repeat the
`sima-cli download` command. The CLI resumes a partial download when possible.

### A container with the same name already exists

Inspect its logs if needed, then remove it before starting the next run:

```bash
./run-devkit.sh logs both
./run-devkit.sh cleanup both
```

### An image has the wrong architecture

Build it through `run-devkit.sh`. The launcher uses Buildx with
`--platform linux/arm64` and verifies that the C++ executable is ARM64.
