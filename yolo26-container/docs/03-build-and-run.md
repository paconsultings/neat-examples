# 3. Build, deploy, and test

Complete the [development environment setup](01-development-environment.md)
before you use this guide.

Run the commands in the paired Neat SDK shell unless a step says to run them
on the DevKit.

## Development workflow

Use this sequence:

1. Select bundled mode.
2. Build and test one Python container.
3. Inspect its log and JSON report.
4. Build the C++ image.
5. Run the Python and C++ containers at the same time.
6. Verify the concurrent test and remove the containers.

## Check the environment

Go to the example directory:

```bash
cd /workspace/neat-examples/yolo26-container
```

Check the DevKit connection and local registry:

```bash
type dk
dk status
test -n "${SIMA_CONTAINER_REGISTRY}"
docker buildx version
```

All commands must succeed.

## Select bundled mode

Start with bundled images. They include the Neat user-space runtime from the
SDK sysroot:

```bash
export RUNTIME_MODE=bundled
```

Keep this value until the test is complete.

## Get the YOLO26 ModelPack

The first `run` action downloads the ModelPack automatically when it is not
present. The download requires a valid SiMa Developer Portal account.

Authenticate before the first run:

```bash
sima-cli login
```

To download the model before the test, run:

```bash
mkdir -p models
sima-cli download --dest models \
  https://docs.sima.ai/pkg_downloads/SDK2.1.3/models/modalix/yolo26-detection/yolo26m-det-int8-b1.tar.gz

test -f models/yolo26m-det-int8-b1.tar.gz
```

Do not commit the model archive.

## First test: run one Python container

Build and push the Python image:

```bash
./run-devkit.sh build python
```

Start the Python container, wait for it to finish, and show its output:

```bash
./run-devkit.sh run python
./run-devkit.sh wait python
./run-devkit.sh logs python
```

The `run` action starts the container in the background. The `wait` action
blocks until the application stops and fails if its exit code is not zero. The
`logs` action then shows the application result.

Inspect the JSON report:

```bash
python3 -m json.tool out/python-bundled.json
```

The script retains the stopped container. Remove it before the next test:

```bash
./run-devkit.sh cleanup python
```

## Next test: run two containers

The Python image is already in the local registry. Build and push the C++
image:

```bash
./run-devkit.sh build cpp
```

Start the Python and C++ containers:

```bash
./run-devkit.sh run both
```

Check their state:

```bash
./run-devkit.sh status both
```

Wait for both containers and verify that their execution times overlap:

```bash
./run-devkit.sh wait both
```

Show the application logs:

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

This result confirms that both applications ran at the same time. It does not
compare their performance.

Inspect both reports:

```bash
python3 -m json.tool out/python-bundled.json
python3 -m json.tool out/cpp-bundled.json
```

Remove both containers when the test is complete:

```bash
./run-devkit.sh cleanup both
```

Cleanup does not remove images, the ModelPack, or JSON reports.

## How the build works

The build uses Buildx with `--platform linux/arm64`. It pushes the images to
the local registry named by `SIMA_CONTAINER_REGISTRY`. The DevKit pulls the
images from that registry during deployment.

The C++ build cross-compiles `main.cpp` and checks that the executable is
ARM64. A bundled build copies the Neat runtime files and plug-ins from the SDK
sysroot and extracts `pyneat` from the wheel cached by the Neat installer. It
does not copy Neat from the DevKit.

Do not replace `--push` with `--load`. The `--load` option puts an image only
in the Docker engine on the development host.

To build both images in one command, run:

```bash
./run-devkit.sh build both
```

## Optional: test thin images

Thin images use the Neat installation on the DevKit. Select thin mode:

```bash
unset RUNTIME_MODE
```

Build and test them with the same `build`, `run`, `wait`, `logs`, and `cleanup`
commands. Thin mode uses different image, container, and report names.

## Change the test length

Each application processes 3,000 synthetic samples by default. Set `FRAMES`
when you start the containers to use a different value:

```bash
FRAMES=100 ./run-devkit.sh run python
FRAMES=5000 ./run-devkit.sh run both
```

You do not need to set `FRAMES` for `wait`, `status`, or `logs`.

## How `dk container` works

`dk container` commands run in the paired SDK shell, but they control Docker
on the DevKit.

If Docker is not installed on the DevKit, the first `dk container` command
installs and configures it. The DevKit must have Internet access during that
installation.

The example uses these operations:

| Command | Function on the DevKit |
| --- | --- |
| `dk container images` | Lists images |
| `dk container list` | Lists containers |
| `dk container deploy IMAGE ...` | Pulls an image and starts a container |
| `dk container logs NAME` | Shows a container log |
| `dk container remove NAME --force` | Removes a container |

For a local image name such as `neat-yolo26-python-bundled:poc`, `dk` adds the
configured registry address before the DevKit pulls it.

The deploy command accepts Docker options before `--`. It passes arguments
after `--` to the application. `run-devkit.sh` uses this boundary to pass the
model path, sample count, decode type, and report path.

## Equivalent manual Docker test

Use the helper script for normal tests. Use this procedure only to inspect the
Docker operation directly.

First, build the bundled Python image and show the registry address in the SDK
shell:

```bash
export RUNTIME_MODE=bundled
./run-devkit.sh build python
printf '%s\n' "${SIMA_CONTAINER_REGISTRY}"
```

Connect to the DevKit. Replace `DEVKIT_IP` and `REGISTRY` with values from your
environment:

```bash
ssh sima@DEVKIT_IP

export PROJECT_DIR=/workspace/neat-examples/yolo26-container
export REGISTRY=10.0.0.31:5050
export IMAGE="${REGISTRY}/neat-yolo26-python-bundled:poc"

mkdir -p "${PROJECT_DIR}/out"
docker pull "${IMAGE}"
```

Start the container:

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
  "${IMAGE}" \
  --model "${PROJECT_DIR}/models/yolo26m-det-int8-b1.tar.gz" \
  --frames 3000 \
  --decode-type yolo26-det \
  --output-json "${PROJECT_DIR}/out/python-bundled.json"
```

Wait for the application, inspect its log, and remove the container:

```bash
docker wait neat-yolo26-python-bundled
docker logs neat-yolo26-python-bundled
docker rm neat-yolo26-python-bundled
```

For C++, build `cpp` and use these values instead:

| Item | C++ value |
| --- | --- |
| Image | `neat-yolo26-cpp-bundled:poc` |
| Container | `neat-yolo26-cpp-bundled` |
| Report | `out/cpp-bundled.json` |

All other Docker options are the same.

## Configuration variables

| Variable | Default | Function |
| --- | --- | --- |
| `RUNTIME_MODE` | `host` | Selects thin or bundled images |
| `FRAMES` | `3000` | Sets the number of synthetic samples |
| `DEVKIT_PROJECT_DIR` | Script directory | Sets the shared project path |
| `MODEL_PATH` | `<project>/models/yolo26m-det-int8-b1.tar.gz` | Selects a ModelPack |
| `MODEL_URL` | Pinned Model Zoo URL | Selects a download URL |
| `PYTHON_IMAGE` | Mode-specific name | Overrides the Python image name |
| `CPP_IMAGE` | Mode-specific name | Overrides the C++ image name |
| `PYTHON_CONTAINER` | Mode-specific name | Overrides the Python container name |
| `CPP_CONTAINER` | Mode-specific name | Overrides the C++ container name |

## Troubleshooting

### `dk is unavailable`

Run the commands in the paired SDK shell. If SDK setup did not finish, run
these commands on the development host:

```bash
sima-cli neat install sdk@develop
sima-cli sdk neat
```

### `SIMA_CONTAINER_REGISTRY is unset`

Run `sima-cli neat install sdk@develop` again and enable the local registry.
Then, open a new SDK shell.

### The model download fails

Update sima-cli, sign in again, and repeat the `run` command:

```bash
sima-cli selfupdate --prod --branch develop
sima-cli login
```

### A container with the same name exists

Inspect and remove the retained container:

```bash
./run-devkit.sh logs both
./run-devkit.sh cleanup both
```

### The DevKit cannot pull a local image

Show the configured registry address:

```bash
printf '%s\n' "${SIMA_CONTAINER_REGISTRY}"
```

If the development host address changed, run the SDK installation again.

### A bundled build cannot find Neat

Install minimal Neat Core in the SDK shell:

```bash
sudo apt update
sima-cli neat install core@develop -t minimal
```

### MLA initialization reports a missing device

Connect to the DevKit and inspect the platform and devices:

```bash
ssh sima@DEVKIT_IP
cat /etc/os-release
ls -l /dev/dma_heap/linux,cma /dev/mla /dev/cvu
```

Use eLxr 3.0.0. Build ID B1859 is recommended.
