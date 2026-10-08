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

## Use the prebuilt bundled images

GitHub Actions builds the bundled images on an ARM64 runner. Each successful
build publishes these moving tags:

```text
ghcr.io/paconsultings/neat-yolo26-python-bundled:develop
ghcr.io/paconsultings/neat-yolo26-cpp-bundled:develop
```

It also publishes an immutable `sha-<commit>` tag for each image. Use an
immutable tag when you need to repeat a test with the same image.

To pull the images directly on the DevKit, run:

```bash
dk shell
docker pull ghcr.io/paconsultings/neat-yolo26-python-bundled:develop
docker pull ghcr.io/paconsultings/neat-yolo26-cpp-bundled:develop
exit
```

To use the prebuilt images, run these commands in the SDK shell:

```bash
export RUNTIME_MODE=bundled
export PYTHON_IMAGE=ghcr.io/paconsultings/neat-yolo26-python-bundled:develop
export CPP_IMAGE=ghcr.io/paconsultings/neat-yolo26-cpp-bundled:develop

./run-devkit.sh run both
./run-devkit.sh wait both
./run-devkit.sh logs both
```

The DevKit pulls the images directly from GitHub Container Registry. Public
packages do not require a registry login. If GitHub reports `denied`, ask the
repository owner to confirm that both packages are public.

> [!IMPORTANT]
> SiMa software distribution terms apply to the Neat files in these images.
> A repository owner must confirm redistribution permission before making the
> packages public.

The publishing workflow runs after relevant application or container files
change on `main`. A repository maintainer can also start it with
`workflow_dispatch`. The workflow does these operations:

1. Uses the `ubuntu-24.04-arm` GitHub-hosted runner.
2. Installs or verifies Docker on the runner.
3. Installs sima-cli from the `develop` branch.
4. Installs the `develop` SDK without a DevKit connection.
5. Installs minimal Neat Core in the SDK.
6. Stages Neat from the SDK sysroot.
7. Builds and publishes both images to GitHub Container Registry.

The workflow does not use a DevKit or copy files over SSH.

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

1. Reads the public Neat development files from the SDK sysroot.
2. Cross-compiles `main.cpp`.
3. Checks that the executable is ARM64.

Bundled mode copies Neat runtime files and plug-ins from the SDK sysroot. It
extracts `pyneat` from the wheel cached by the SDK installation. It does not
copy Neat from the DevKit.

Buildx uses `--platform linux/arm64` and `--push`. It pushes the images to
`SIMA_CONTAINER_REGISTRY`. The DevKit then pulls the images from this
registry.

Do not replace `--push` with `--load`. The `--load` option puts the image
only in the Docker engine on the development host.

## Understand `dk container`

Run `dk container` commands in the paired SDK shell. The commands control
Docker on the DevKit. They do not control Docker in the SDK container.

On the first `dk container` command, `dk` does these operations when
necessary:

1. Installs Docker on the DevKit.
2. Moves Docker data storage to `/data`.
3. Configures the DevKit to use the local development registry.

The DevKit must have Internet access if Docker is not installed.

The commands used by this example have these functions:

| Command | Function on the DevKit |
| --- | --- |
| `dk container images` | Lists container images |
| `dk container list` | Lists containers |
| `dk container deploy IMAGE ...` | Pulls an image and starts a container |
| `dk container logs NAME` | Shows the container log |
| `dk container remove NAME --force` | Removes a container |

For an image name such as `neat-yolo26-python-bundled:poc`, `dk` adds the
configured registry address. It then makes the DevKit pull the complete image
name. For example:

```text
10.0.0.31:5050/neat-yolo26-python-bundled:poc
```

The registry address is different for each development environment. Show the
correct value in the SDK shell:

```bash
printf '%s\n' "${SIMA_CONTAINER_REGISTRY}"
```

The `deploy` command accepts Docker run options before `--`. It passes all
arguments after `--` to the image entry point. The launcher uses this
separation to pass the model, sample count, decode type, and report path to the
application.

The SDK and the DevKit share `/workspace`. The image does not contain the
ModelPack. The container reads the model from the shared project directory and
writes its report to the same directory.

## Run both images manually on the DevKit

The normal test uses `run-devkit.sh`. Use the commands in this section only
when you must examine the equivalent Docker operations.

First, complete these actions in the SDK shell:

1. Download the ModelPack as described above.
2. Build and push both bundled images.
3. Show and record `SIMA_CONTAINER_REGISTRY`.
4. Run `dk container list` at least once.

Then, open a DevKit shell:

```bash
dk shell
```

Set the project path and registry address on the DevKit. Replace the example
registry address with the value from your SDK shell:

```bash
export PROJECT_DIR=/workspace/neat-examples/yolo26-container
export REGISTRY=10.0.0.31:5050

mkdir -p "${PROJECT_DIR}/out"
```

Pull both bundled images:

```bash
docker pull "${REGISTRY}/neat-yolo26-python-bundled:poc"
docker pull "${REGISTRY}/neat-yolo26-cpp-bundled:poc"
```

Start the Python container:

```bash
docker run --detach \
  --name neat-yolo26-python-bundled \
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
  "${REGISTRY}/neat-yolo26-python-bundled:poc" \
  --model "${PROJECT_DIR}/models/yolo26m-det-int8-b1.tar.gz" \
  --frames 3000 \
  --decode-type yolo26-det \
  --output-json "${PROJECT_DIR}/out/python-bundled.json"
```

Start the C++ container:

```bash
docker run --detach \
  --name neat-yolo26-cpp-bundled \
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
  "${REGISTRY}/neat-yolo26-cpp-bundled:poc" \
  --model "${PROJECT_DIR}/models/yolo26m-det-int8-b1.tar.gz" \
  --frames 3000 \
  --decode-type yolo26-det \
  --output-json "${PROJECT_DIR}/out/cpp-bundled.json"
```

Both `docker run` commands return immediately because they use `--detach`.
The containers then run at the same time.

Check the containers:

```bash
docker ps --all \
  --filter name=neat-yolo26-python-bundled \
  --filter name=neat-yolo26-cpp-bundled
```

Wait for both containers. Each command prints the container exit code:

```bash
docker wait neat-yolo26-python-bundled
docker wait neat-yolo26-cpp-bundled
```

Show the logs and verify that the execution times overlap:

```bash
docker logs neat-yolo26-python-bundled
docker logs neat-yolo26-cpp-bundled

python3 "${PROJECT_DIR}/verify-overlap.py" \
  neat-yolo26-python-bundled \
  neat-yolo26-cpp-bundled
```

Remove the containers when the test is complete:

```bash
docker rm --force \
  neat-yolo26-python-bundled \
  neat-yolo26-cpp-bundled
exit
```

To test thin images, use these image and container names instead:

| Application | Image | Container | Report |
| --- | --- | --- | --- |
| Python | `neat-yolo26-python:poc` | `neat-yolo26-python` | `out/python.json` |
| C++ | `neat-yolo26-cpp:poc` | `neat-yolo26-cpp` | `out/cpp.json` |

All other Docker options remain the same.

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

### A bundled build cannot find Neat

Install the minimal Neat package in the SDK:

```bash
sudo apt update
sima-cli neat install core@develop -t minimal
```

The installer puts the libraries and headers in the SDK sysroot. It also
caches the Debian packages and the `pyneat` wheel under
`${SYSROOT}/neat-install-packages`. The bundled build uses these files.
