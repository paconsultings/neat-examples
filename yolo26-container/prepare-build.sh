#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUNDLED=0

if [[ "${1:-}" == "--bundled" ]]; then
  BUNDLED=1
  shift
fi

TARGET="${1:-both}"
case "${TARGET}" in
  python|cpp|both) ;;
  *)
    echo "Usage: ./prepare-build.sh [--bundled] [python|cpp|both]" >&2
    exit 2
    ;;
esac

if [[ -z "${SYSROOT:-}" ]]; then
  # shellcheck source=/dev/null
  source /opt/bin/simaai-init-build-env modalix >/dev/null
fi

if [[ ! -d "${SYSROOT}" ]]; then
  echo "SDK sysroot not found: ${SYSROOT}" >&2
  exit 2
fi

CACHE_DIR="${SYSROOT}/neat-install-packages"

find_package_deb() {
  local package="$1"
  local deb
  local found=""

  shopt -s nullglob
  for deb in "${CACHE_DIR}"/*.deb; do
    if [[ "$(dpkg-deb -f "${deb}" Package 2>/dev/null || true)" == "${package}" ]]; then
      if [[ -n "${found}" ]]; then
        echo "More than one ${package} package is present in ${CACHE_DIR}." >&2
        exit 2
      fi
      found="${deb}"
    fi
  done
  shopt -u nullglob

  if [[ -z "${found}" ]]; then
    echo "Package ${package} is not present in ${CACHE_DIR}." >&2
    echo "Run: sudo apt update && sima-cli neat install core@develop -t minimal" >&2
    exit 2
  fi

  printf '%s\n' "${found}"
}

stage_bundled_runtime() {
  local bundle_root="${SCRIPT_DIR}/build/bundled-runtime"
  local path_list
  local package
  local deb
  local package_version
  local sima_neat_version=""
  local wheel
  local -a wheels=()
  local -a packages=(sima-neat neat-runtime neat-gst-plugins sima-lmm-core)

  if [[ ! -d "${CACHE_DIR}" ]]; then
    echo "Neat package cache not found: ${CACHE_DIR}" >&2
    echo "Run: sudo apt update && sima-cli neat install core@develop -t minimal" >&2
    exit 2
  fi

  mkdir -p "${bundle_root}"
  path_list="${bundle_root}/.runtime-paths"

  : > "${path_list}"
  {
    printf 'bundle-schema=3\n'
    for package in "${packages[@]}"; do
      deb="$(find_package_deb "${package}")"
      package_version="$(dpkg-deb -f "${deb}" Version)"
      printf '%s=%s\n' "${package}" "${package_version}"
      if [[ "${package}" == "sima-neat" ]]; then
        sima_neat_version="${package_version}"
      fi

      if [[ "${package}" == "sima-lmm-core" ]]; then
        dpkg-deb --fsys-tarfile "${deb}" |
          tar -tf - |
          sed 's#^[.]/##' |
          grep -E '^usr/lib/(.*/)?libsima_lmm_runtime[.]so([.]|$)' >> "${path_list}"
      else
        dpkg-deb --fsys-tarfile "${deb}" |
          tar -tf - |
          sed 's#^[.]/##' |
          grep -E '^usr/lib/|^usr/libexec/sima-neat(/|$)|^usr/share/sima-neat(/|$)' >> "${path_list}"
      fi
    done
  } > "${bundle_root}/.version"

  sort -u -o "${path_list}" "${path_list}"
  while IFS= read -r path; do
    path="${path%/}"
    if [[ -n "${path}" && ( -f "${SYSROOT}/${path}" || -L "${SYSROOT}/${path}" ) ]]; then
      printf '%s\n' "${path}"
    fi
  done < "${path_list}" > "${path_list}.installed"
  mv "${path_list}.installed" "${path_list}"

  if [[ ! -s "${path_list}" ]]; then
    echo "No Neat runtime files were found in the SDK sysroot." >&2
    exit 2
  fi

  rm -rf "${bundle_root}/rootfs" "${bundle_root}/python"
  mkdir -p "${bundle_root}/rootfs" "${bundle_root}/python"
  tar -C "${SYSROOT}" -cf - -T "${path_list}" |
    tar -C "${bundle_root}/rootfs" -xf -
  rm -f "${path_list}"

  shopt -s nullglob
  wheels=("${CACHE_DIR}"/pyneat-*.whl)
  shopt -u nullglob
  if [[ "${#wheels[@]}" -ne 1 ]]; then
    echo "Expected one pyneat wheel in ${CACHE_DIR}; found ${#wheels[@]}." >&2
    exit 2
  fi
  wheel="${wheels[0]}"
  python3 -m zipfile -e "${wheel}" "${bundle_root}/python"

  if [[ ! -f "${bundle_root}/python/pyneat/__init__.py" ]]; then
    echo "The pyneat wheel did not contain pyneat/__init__.py." >&2
    exit 2
  fi

  printf 'pyneat=%s\n' "$(basename "${wheel}")" >> "${bundle_root}/.version"
  printf '%s\n' "${sima_neat_version}" > "${bundle_root}/.neat-version"
}

build_cpp_binary() {
  local neat_dir="${SYSROOT}/usr/lib/cmake/SimaNeat"
  local nlohmann_dir="${SYSROOT}/usr/share/cmake/nlohmann_json"

  if [[ ! -d "${neat_dir}" ]]; then
    echo "SimaNeat CMake files are not installed in the SDK sysroot." >&2
    echo "Run: sudo apt update && sima-cli neat install core@develop -t minimal" >&2
    exit 2
  fi

  cmake +    -S "${SCRIPT_DIR}" +    -B "${SCRIPT_DIR}/build/cmake" +    -DCMAKE_BUILD_TYPE=Release +    -DCMAKE_TOOLCHAIN_FILE="${SCRIPT_DIR}/cmake/modalix-arm64.cmake" +    -DSimaNeat_DIR="${neat_dir}" +    -Dnlohmann_json_DIR="${nlohmann_dir}"
  cmake --build "${SCRIPT_DIR}/build/cmake" --parallel
  file "${SCRIPT_DIR}/build/cmake/yolo26-benchmark" |
    grep -Eq 'aarch64|ARM aarch64|ARM64'
}

if [[ "${BUNDLED}" -eq 1 ]]; then
  stage_bundled_runtime
fi

if [[ "${TARGET}" == "cpp" || "${TARGET}" == "both" ]]; then
  build_cpp_binary
fi
