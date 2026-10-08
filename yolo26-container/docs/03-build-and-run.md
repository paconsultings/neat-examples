# 3. Build and run the containers

Complete the [development environment setup](01-development-environment.md)
before you use this guide.

Run all commands in the paired Neat SDK shell unless a step identifies a
different system.

## Check the environment

Go to the example directory:

```bash
cd /workspace/neat-examples/yolo26-container
```

Check the DevKit connection and the registry:

```bash
type dk
dk status
test -n "${SIMA_CONTAINER_REGISTRY}"
```

The launcher gets the DevKit project path from its location. For the standard
workspace layout, do not set `DEVKIT_PROJECT_DIR`.

## Get the YOLO26 ModelPack

The first `run` action downloads this file if it is not present:

```text
models/yolo26m-det-int8-b1.tar.gz
```

The download uses sima-cli and the pinned Model Zoo 2.1.3 URL. Authenticate
before the first run:

```bash
sima-cli login
```

You can also download the model before you run the application:

```bash
mkdir -p models
sima-cli download \
  --dest models \
  https://docs.sima.ai/pkg_downloads/SDK2.1.3/models/modalix/yolo26-detection/yolo26m-det-int8-b1.tar.gz
```

sima-cli resumes an incomplete download when possible. Do not commit the model
archive.

## Select an image type

The default setting builds a thin image. This image uses Neat from the DevKit:

```bash
unset RUNTIME_MODE
```

To include the Neat user-space runtime in the image, select bundled mode:

```bash
export RUNTIME_MODE=bundled
```

Do not change `RUNTIME_MODE` until you finish the test. Thin mode and bundled
mode use different image, container, and report names.

## Build and push the images

Build the Python and C++ images:

```bash
./run-devkit.sh build both
```

To build only one image, run one of these commands:

```bash
./run-devkit.sh build python
./run-devkit.sh build cpp
```

The Python build adds `main.py` to the image. The C++ build does these
operations:

1. Copies the public Neat development files from the DevKit.
2. Cross-compiles `main.cpp`.
3. Checks that the executable is ARM64.

Bundled mode also copies Neat runtime files and plug-ins from the DevKit.

Buildx uses `--platform linux/arm64` and `--push`. It pushes the images to
`SIMA_CONTAINER_REGISTRY`. The DevKit then pulls the images from this
registry.

Do not replace `--push` with `--load`. The `--load` option puts the image
only in the Docker engine on the development host.

## Run one application

Start the Python container:

```bash
./run-devkit.sh run python
```

Wait for it to stop. Then, show its log:

```bash
./run-devkit.sh wait python
./run-devkit.sh logs python
```

To test C++, run:

```bash
./run-devkit.sh run cpp
./run-devkit.sh wait cpp
./run-devkit.sh logs cpp
```

The `wait` action returns a failure if the container exit code is not zero.
The script keeps the container after it stops.

## Run both applications

Start both containers:

```bash
./run-devkit.sh run both
```

Check their state:

```bash
./run-devkit.sh status both
```

Wait for both containers and check their execution times:

```bash
./run-devkit.sh wait both
```

Show both logs:

```bash
./run-devkit.sh logs both
```

A successful overlap check has output similar to this:

```text
<python-container>: status=exited exit=0 started=... finished=...
<cpp-container>: status=exited exit=0 started=... finished=...
overlap_seconds=13.088961
concurrency_validation=passed
```

This result shows that the applications ran at the same time. It does not
compare application performance.

## Set the test length

Each application processes 3,000 synthetic samples by default. Set `FRAMES`
on the `run` command to use a different value:

```bash
FRAMES=100 ./run-devkit.sh run python
FRAMES=5000 ./run-devkit.sh run both
```

The script stores the value when it starts the containers. You do not need to
set `FRAMES` for `wait`, `status`, or `logs`.

## Inspect and remove containers

Inspect the retained containers:

```bash
./run-devkit.sh status both
./run-devkit.sh logs both
```

Remove the containers before you start another test with the same names:

```bash
./run-devkit.sh cleanup both
```

You can replace `both` with `python` or `cpp`. The `cleanup` action does
not remove images, the ModelPack, or JSON reports.

## Configuration variables

| Variable | Default | Function |
| --- | --- | --- |
| `RUNTIME_MODE` | `host` | Selects a thin or bundled image |
| `FRAMES` | `3000` | Sets the number of synthetic samples |
| `DEVKIT_PROJECT_DIR` | Script directory | Sets a different shared project path |
| `MODEL_PATH` | `<project>/models/yolo26m-det-int8-b1.tar.gz` | Selects a different local ModelPack |
| `MODEL_URL` | Pinned Model Zoo 2.1.3 URL | Selects a different download URL |
| `PYTHON_IMAGE` | Mode-specific name | Sets the Python image name |
| `CPP_IMAGE` | Mode-specific name | Sets the C++ image name |
| `PYTHON_CONTAINER` | Mode-specific name | Sets the Python container name |
| `CPP_CONTAINER` | Mode-specific name | Sets the C++ container name |

## Troubleshooting

### `dk is unavailable`

The command is not running in the paired SDK shell, or the SDK setup did not
finish.

On the development host, run:

```bash
sima-cli neat install sdk@develop
sima-cli sdk neat
```

Enter the DevKit IP address when the installer asks for it.

### `SIMA_CONTAINER_REGISTRY is unset`

Run `sima-cli neat install sdk@develop` again. Enable the local registry.
Then, open a new SDK shell.

### The repository is not in `/workspace`

On the development host, clone the repository under `~/workspace`:

```bash
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/paconsultings/neat-examples.git
sima-cli sdk neat
```

### The model download fails

Update sima-cli and authenticate again:

```bash
sima-cli selfupdate --prod --branch develop
sima-cli --version
sima-cli login
```

Then, repeat the `run` command.

You can also download the archive on an authenticated host. Put it in the
`models/` directory in the shared workspace.

### A container with the same name exists

Inspect and remove the old container:

```bash
./run-devkit.sh logs both
./run-devkit.sh cleanup both
```

### Docker is not available on the DevKit

From the SDK shell, run:

```bash
dk container list
```

If Docker is not present, this command installs and configures it. The DevKit
must have Internet access.

### The DevKit cannot pull an image

Check the network path between the development host, the Docker or Colima
virtual machine, and the DevKit.

Show the registry address:

```bash
printf '%s\n' "${SIMA_CONTAINER_REGISTRY}"
```

If the host address changed, run the SDK installation again.

### An image has the wrong architecture

Build the image with `run-devkit.sh`. The launcher selects `linux/arm64` and
checks the C++ executable.

### MLA initialization reports a missing device

Check the eLxr version and the device files:

```bash
dk shell
cat /etc/os-release
ls -l /dev/dma_heap/linux,cma /dev/mla /dev/cvu
exit
```

Use eLxr 3.0.0. Build ID B1859 is recommended.

### A bundled build cannot copy Neat

The paired DevKit must contain compatible installations of these packages:

- `sima-neat`
- `sima-neat-dev`
- `neat-runtime`
- `neat-gst-plugins`
- `sima-lmm-core`
- `pyneat`

Use a DevKit that has the Neat version that you want to package.
