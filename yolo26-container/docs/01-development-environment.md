# 1. Set up the development environment

This guide prepares a development host, a Neat SDK shell, and one Modalix
DevKit for the YOLO26 container example.

## Required versions

| Component | Requirement |
| --- | --- |
| DevKit platform | eLxr 3.0.0 on Modalix |
| sima-cli | 2.1.19 prerelease from the `develop` branch |
| Neat SDK | Image built from the `develop` branch |
| Development host | Linux or macOS with Docker and Buildx |
| macOS container runtime | Current Colima release |

The host and DevKit must be able to reach each other. Record the DevKit IP
address before setup. The DevKit user must have password-free `sudo` access.
If Docker is not already installed on the DevKit, the DevKit also needs
Internet access while `dk container setup` installs it.

## Install host prerequisites

Install Docker on the development host. On macOS, install a current Colima
release as the Docker runtime.

At the time this guide was created, sima-cli 2.1.19 was a prerelease rather
than the default production release. Install or update to it from the
production artifact service's `develop` branch, then confirm the version:

```bash
sima-cli selfupdate --prod --branch develop
sima-cli --version
```

The reported version must begin with `2.1.19`. This prerelease CLI is part of
the preview workflow; return to the normal production channel when you no
longer need the preview features.

Docker socket access gives the SDK shell control of the host Docker engine.
Use this workflow only on a trusted development host.

## Clone the examples into the SDK workspace

The following layout makes the repository available as
`/workspace/neat-examples` inside the SDK and on the paired DevKit:

```bash
mkdir -p ~/sima-neat
cd ~/sima-neat
git clone https://github.com/paconsultings/neat-examples.git
```

If the repository already exists, update it instead:

```bash
cd ~/sima-neat/neat-examples
git pull --ff-only
```

## Pair the SDK with the DevKit

Run setup on the development host, replacing `<devkit-ip>` with the DevKit IP:

```bash
sima-cli sdk setup \
  --devkit <devkit-ip> \
  --workspace ~/sima-neat
```

When setup asks you to choose an SDK image, select a build produced from the
Neat SDK `develop` branch. Do not use a stable SDK image for this preview.

Setup checks Docker and Buildx on the host, configures SDK-to-DevKit access,
and offers to start a local container registry. The default registry port is
`5050`; setup chooses another available port when necessary. Do not pass
`--no-container-registry`, because the DevKit must pull the images built by
this example.

On macOS, setup also checks Colima networking. A Colima profile created without
the required shared or bridged network configuration may need to be recreated.
Back up important Colima data before approving any profile recreation prompt.

Enter the SDK shell:

```bash
sima-cli sdk neat
```

## Verify the SDK shell

Run these checks inside the SDK shell:

```bash
type dk
dk status

docker buildx version
docker buildx inspect --bootstrap

test -n "${SIMA_CONTAINER_REGISTRY}"
printf 'Registry: %s\n' "${SIMA_CONTAINER_REGISTRY}"

test -d /workspace/neat-examples/yolo26-container
```

The final command confirms that the repository is inside the shared workspace.
The C++ build produced later must be ARM64, even when the development host is
AMD64.

If `dk` or `SIMA_CONTAINER_REGISTRY` is missing, leave the SDK shell, repeat
`sima-cli sdk setup`, and open a new SDK shell.

## Prepare Docker on the DevKit

Setup configures the SDK side, but it does not silently install Docker on the
DevKit. From the SDK shell, run:

```bash
dk container setup
```

If Docker is missing, `dk` explains the changes and asks for approval. Docker
data is placed under `/data`, and the DevKit is configured to reach the local
registry. For an approved noninteractive installation, use:

```bash
dk container setup --yes
```

Confirm that the container interface responds:

```bash
dk container images
dk container list
```

## Verify the DevKit platform and devices

Open a DevKit shell:

```bash
dk shell
```

On the DevKit, confirm eLxr 3.0.0, Docker, and the accelerator devices:

```bash
cat /etc/os-release
docker version
ls -l /dev/dma_heap/linux,cma /dev/mla /dev/cvu
exit
```

All three devices must exist for this YOLO26 workload. The launcher maps only
these devices into the application containers; it does not use
`--privileged`.

## Registry and network behavior

The local development registry uses HTTP without authentication. SDK setup
limits it to local and DevKit-facing network paths, but it is still intended
only for a trusted development network.

If the DevKit cannot pull an image, verify that the host, the Docker or Colima
VM, and the DevKit have a reachable network path. Re-running SDK setup repairs
the stored registry address when the host network changes.

## Next step

Continue with [Understand the application and container design](02-application-design.md).
