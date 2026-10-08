# 1. Set up the development environment

This guide prepares the development host, the Neat SDK shell, and one Modalix
DevKit.

## Requirements

| Component | Requirement |
| --- | --- |
| DevKit | Modalix with eLxr 3.0.0 |
| Recommended eLxr build | B1859 |
| sima-cli | 2.1.19 prerelease from the `develop` branch |
| Neat SDK | Build from the `develop` branch |
| Development host | Linux or macOS with Docker and Buildx |
| macOS container runtime | Current Colima release |

The development host and the DevKit must have network access to each other.
Record the DevKit IP address. The DevKit user must have password-free `sudo`
access.

If Docker is not installed on the DevKit, the DevKit must have Internet access.
The first `dk container` command installs Docker automatically.

## Update sima-cli

At the time of this document, sima-cli 2.1.19 is a prerelease. Install it from
the `develop` branch:

```bash
sima-cli selfupdate --prod --branch develop
sima-cli --version
```

The version must start with `2.1.19`.

## Install the Neat SDK

On the development host, run:

```bash
sima-cli neat install sdk@develop
```

Enter the DevKit IP address when the installer asks for it. Enable the local
container registry when the installer asks. The default registry port is
`5050`.

The installer checks Docker and Buildx on the development host. On macOS, it
also checks the Colima network configuration. Back up important Colima data
before you approve a request to recreate a Colima profile.

> [!CAUTION]
> The SDK shell can control the Docker engine on the development host. Use a
> trusted development host.

## Clone the examples

Use this directory layout:

```bash
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/paconsultings/neat-examples.git
```

If the repository is already present, update it:

```bash
cd ~/workspace/neat-examples
git pull --ff-only
```

Enter the SDK shell:

```bash
sima-cli sdk neat
```

The repository is now available at `/workspace/neat-examples`.

## Check the SDK shell

Run these commands in the SDK shell:

```bash
type dk
dk status

docker buildx version
docker buildx inspect --bootstrap

test -n "${SIMA_CONTAINER_REGISTRY}"
printf 'Registry: %s\n' "${SIMA_CONTAINER_REGISTRY}"

test -d /workspace/neat-examples/yolo26-container
```

All commands must succeed.

If `dk` or `SIMA_CONTAINER_REGISTRY` is not available, leave the SDK shell.
Run the SDK installation again. Then, open a new SDK shell.

## Install Neat in the SDK

The preview Neat SDK does not include the Neat Core libraries. Install the
minimal Neat Core package in the SDK shell:

```bash
sudo apt update
sima-cli neat install core@develop -t minimal
```

Run `sudo apt update` immediately before the Neat installation. The SDK
environment must have network access for this step.

## Check Docker on the DevKit

You do not need to install Docker on the DevKit manually. Run:

```bash
dk container images
dk container list
```

If Docker is not present, `dk container` installs and configures it. Keep the
DevKit connected to the Internet during this installation.

## Install Neat on the DevKit

Thin images use the Neat installation on the DevKit. Bundled images use the
Neat files that were installed in the SDK and added to the image.

If you plan to test thin images, install Neat Core from the `develop` branch:

```bash
dk shell
sudo apt update
sima-cli neat install core@develop -t minimal
exit
```

Run `sudo apt update` immediately before the Neat installation. The DevKit
must have network access for this step. You can skip this installation when
you test only bundled images.

## Check the DevKit

Open a DevKit shell and run:

```bash
dk shell
cat /etc/os-release
docker version
ls -l /dev/dma_heap/linux,cma /dev/mla /dev/cvu
exit
```

Confirm that the DevKit uses eLxr 3.0.0. Build ID B1859 is recommended. Confirm
that all three device files are present.

The launcher maps these device files into each container. The launcher does
not use `--privileged`.

## Registry security

The local registry uses HTTP without authentication. Use it only on a trusted
development network.

If the DevKit cannot pull an image, check the network path between these
systems:

1. the development host
2. the Docker or Colima virtual machine
3. the DevKit

If the host network address changed, run `sima-cli neat install sdk@develop`
again.

## Next step

Continue with [Understand the application design](02-application-design.md).
