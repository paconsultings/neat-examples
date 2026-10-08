#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-help}"
TARGET="${2:-both}"
RUNTIME_MODE="${RUNTIME_MODE:-host}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

case "${RUNTIME_MODE}" in
  host)
    PYTHON_IMAGE="${PYTHON_IMAGE:-neat-yolo26-python:poc}"
    CPP_IMAGE="${CPP_IMAGE:-neat-yolo26-cpp:poc}"
    PYTHON_CONTAINER="${PYTHON_CONTAINER:-neat-yolo26-python}"
    CPP_CONTAINER="${CPP_CONTAINER:-neat-yolo26-cpp}"
    REPORT_SUFFIX=""
    ;;
  bundled)
    PYTHON_IMAGE="${PYTHON_IMAGE:-neat-yolo26-python-bundled:poc}"
    CPP_IMAGE="${CPP_IMAGE:-neat-yolo26-cpp-bundled:poc}"
    PYTHON_CONTAINER="${PYTHON_CONTAINER:-neat-yolo26-python-bundled}"
    CPP_CONTAINER="${CPP_CONTAINER:-neat-yolo26-cpp-bundled}"
    REPORT_SUFFIX="-bundled"
    ;;
  *)
    echo "RUNTIME_MODE must be host or bundled." >&2
    exit 2
    ;;
esac
FRAMES="${FRAMES:-3000}"
DEVKIT_PROJECT_DIR="${DEVKIT_PROJECT_DIR:-${SCRIPT_DIR}}"
MODEL_PATH="${MODEL_PATH:-${DEVKIT_PROJECT_DIR}/models/yolo26m-det-int8-b1.tar.gz}"
MODEL_URL="${MODEL_URL:-https://docs.sima.ai/pkg_downloads/SDK2.1.3/models/modalix/yolo26-detection/yolo26m-det-int8-b1.tar.gz}"

usage() {
  cat <<'EOF'
Usage: ./run-devkit.sh ACTION [python|cpp|both]

Set RUNTIME_MODE=host (default) for thin images that use the DevKit's Neat
installation, or RUNTIME_MODE=bundled for images that carry Neat user space.

Actions:
  build    Build and push one image or both images (default: both)
  run      Start one container or both containers in the background
  status   Show the selected containers
  wait     Wait for completion; with both, verify execution overlap
  logs     Show logs from the selected containers
  cleanup  Remove the selected containers

Examples:
  ./run-devkit.sh build
  ./run-devkit.sh run python
  ./run-devkit.sh run cpp
  ./run-devkit.sh run both
  ./run-devkit.sh wait both
  RUNTIME_MODE=bundled ./run-devkit.sh build both
  RUNTIME_MODE=bundled ./run-devkit.sh run both
  RUNTIME_MODE=bundled ./run-devkit.sh wait both
EOF
}

case "${TARGET}" in
  python|cpp|both) ;;
  *)
    echo "Target must be python, cpp, or both." >&2
    usage >&2
    exit 2
    ;;
esac

if [[ "${ACTION}" == "help" || "${ACTION}" == "-h" || "${ACTION}" == "--help" ]]; then
  usage
  exit 0
fi

if ! declare -F dk >/dev/null 2>&1 && [[ -r "${HOME}/.devkit-sync.rc" ]]; then
  # `dk` is a shell function, so a child Bash process must load it explicitly.
  # shellcheck source=/dev/null
  source "${HOME}/.devkit-sync.rc"
fi
if ! declare -F dk >/dev/null 2>&1; then
  echo "dk is unavailable. Pair this SDK shell with a DevKit using sima-cli sdk setup." >&2
  exit 2
fi
if [[ -z "${SIMA_CONTAINER_REGISTRY:-}" ]]; then
  echo "SIMA_CONTAINER_REGISTRY is unset. Pair this SDK with a DevKit first." >&2
  exit 2
fi
if [[ ! "${FRAMES}" =~ ^[1-9][0-9]*$ ]]; then
  echo "FRAMES must be a positive integer." >&2
  exit 2
fi

devkit_ssh=(
  ssh
  -n
  -p "${DEVKIT_SYNC_DEVKIT_PORT:-22}"
  -o BatchMode=yes
  -o ConnectTimeout=8
  "${DEVKIT_SYNC_DEVKIT_USER:-sima}@${DEVKIT_SYNC_DEVKIT_IP}"
)

includes_target() {
  [[ "${TARGET}" == "$1" || "${TARGET}" == "both" ]]
}

container_exists() {
  "${devkit_ssh[@]}" docker container inspect "$1" >/dev/null 2>&1
}

ensure_model() {
  [[ -f "${MODEL_PATH}" ]] && return

  if ! command -v sima-cli >/dev/null 2>&1; then
    echo "YOLO26 model not found at ${MODEL_PATH}" >&2
    echo "sima-cli is unavailable; install it or set MODEL_PATH to an existing ModelPack." >&2
    exit 2
  fi

  local model_dir
  model_dir="$(dirname -- "${MODEL_PATH}")"
  mkdir -p "${model_dir}"
  echo "Downloading the YOLO26 ModelPack to ${model_dir}."
  sima-cli download --dest "${model_dir}" "${MODEL_URL}"

  if [[ ! -f "${MODEL_PATH}" ]]; then
    echo "Download completed but the expected model was not found at ${MODEL_PATH}." >&2
    echo "Set MODEL_PATH to the downloaded archive or use a MODEL_URL with the expected filename." >&2
    exit 2
  fi
}

build_cpp_binary() {
  "${SCRIPT_DIR}/prepare-build.sh" cpp
}

build_images() {
  if [[ "${RUNTIME_MODE}" == "bundled" ]]; then
    "${SCRIPT_DIR}/prepare-build.sh" --bundled "${TARGET}"
    local bundled_dockerfile="Dockerfile.bundled"
    local neat_runtime_version
    neat_runtime_version="$(cat build/bundled-runtime/.neat-version)"

    if includes_target python; then
      docker buildx build \
        --platform linux/arm64 \
        --file "${bundled_dockerfile}" \
        --target python \
        --build-arg "NEAT_RUNTIME_VERSION=${neat_runtime_version}" \
        --tag "${SIMA_CONTAINER_REGISTRY}/${PYTHON_IMAGE}" \
        --push \
        .
    fi
    if includes_target cpp; then
      docker buildx build \
        --platform linux/arm64 \
        --file "${bundled_dockerfile}" \
        --target cpp \
        --build-arg "NEAT_RUNTIME_VERSION=${neat_runtime_version}" \
        --tag "${SIMA_CONTAINER_REGISTRY}/${CPP_IMAGE}" \
        --push \
        .
    fi
    return
  fi

  if includes_target python; then
    docker buildx build \
      --platform linux/arm64 \
      --file Dockerfile.python \
      --tag "${SIMA_CONTAINER_REGISTRY}/${PYTHON_IMAGE}" \
      --push \
      .
  fi
  if includes_target cpp; then
    build_cpp_binary
    docker buildx build \
      --platform linux/arm64 \
      --file Dockerfile.cpp \
      --tag "${SIMA_CONTAINER_REGISTRY}/${CPP_IMAGE}" \
      --push \
      .
  fi
}

launch() {
  local image="$1"
  local name="$2"
  local report="$3"

  if container_exists "${name}"; then
    echo "Container ${name} already exists. Run '$0 cleanup ${TARGET}' first." >&2
    exit 2
  fi

  # The current runtime requires unmasked system paths and io_uring syscalls.
  # Expose only the accelerator devices used by this workload.
  dk container deploy "${image}" \
    --detach \
    --name "${name}" \
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
    -- \
    --model "${MODEL_PATH}" \
    --frames "${FRAMES}" \
    --decode-type yolo26-det \
    --output-json "${report}"
}

populate_selected_names() {
  names=()
  includes_target python && names+=("${PYTHON_CONTAINER}")
  includes_target cpp && names+=("${CPP_CONTAINER}")
  return 0
}

case "${ACTION}" in
  build)
    build_images
    ;;
  run)
    ensure_model
    mkdir -p "${DEVKIT_PROJECT_DIR}/out"
    includes_target python && launch "${PYTHON_IMAGE}" "${PYTHON_CONTAINER}" \
      "${DEVKIT_PROJECT_DIR}/out/python${REPORT_SUFFIX}.json"
    includes_target cpp && launch "${CPP_IMAGE}" "${CPP_CONTAINER}" \
      "${DEVKIT_PROJECT_DIR}/out/cpp${REPORT_SUFFIX}.json"
    RUNTIME_MODE="${RUNTIME_MODE}" "$0" status "${TARGET}"
    echo "Started ${TARGET} target(s) with ${FRAMES} samples. Containers are retained."
    echo "Use '$0 wait ${TARGET}' to wait for completion."
    ;;
  status)
    dk container list | awk \
      -v python_name="${PYTHON_CONTAINER}" \
      -v cpp_name="${CPP_CONTAINER}" \
      -v target="${TARGET}" \
      'NR == 1 || (target != "cpp" && $NF == python_name) || (target != "python" && $NF == cpp_name)'
    ;;
  wait)
    populate_selected_names
    for name in "${names[@]}"; do
      container_exists "${name}" || {
        echo "Container ${name} does not exist." >&2
        exit 2
      }
    done
    for name in "${names[@]}"; do
      "${devkit_ssh[@]}" docker wait "${name}"
    done
    if [[ "${TARGET}" == "both" ]]; then
      "${devkit_ssh[@]}" python3 "${DEVKIT_PROJECT_DIR}/verify-overlap.py" \
        "${PYTHON_CONTAINER}" "${CPP_CONTAINER}"
    else
      exit_code="$("${devkit_ssh[@]}" docker inspect --format '{{.State.ExitCode}}' "${names[0]}")"
      [[ "${exit_code}" == "0" ]] || {
        echo "Container ${names[0]} exited with ${exit_code}." >&2
        exit 3
      }
    fi
    ;;
  logs)
    populate_selected_names
    for name in "${names[@]}"; do
      echo "===== ${name} ====="
      dk container logs "${name}"
    done
    ;;
  cleanup)
    populate_selected_names
    for name in "${names[@]}"; do
      if container_exists "${name}"; then
        dk container remove "${name}" --force
      fi
    done
    ;;
  *)
    echo "Unknown action: ${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
