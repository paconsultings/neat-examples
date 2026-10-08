#!/bin/sh
set -eu

mode="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "${mode}" in
  python)
    python=/usr/bin/python3.13
    pyneat_path="$(${python} -c 'import pyneat; print(pyneat.__file__)')"
    case "${pyneat_path}" in
      /app/runtime/python/*) ;;
      *)
        echo "Bundled pyneat was not selected: ${pyneat_path}" >&2
        exit 5
        ;;
    esac
    echo "bundled_pyneat=${pyneat_path}"
    exec "${python}" /app/main.py "$@"
    ;;
  cpp)
    neat_library="$(ldd /app/yolo26-benchmark | awk '/libsima_neat[.]so[.]6/{print $3; exit}')"
    case "${neat_library}" in
      /app/runtime/rootfs/*) ;;
      *)
        echo "Bundled libsima_neat was not selected: ${neat_library:-not found}" >&2
        exit 5
        ;;
    esac
    echo "bundled_libsima_neat=${neat_library}"
    exec /app/yolo26-benchmark "$@"
    ;;
  *)
    echo "Internal error: expected python or cpp bundled-image mode." >&2
    exit 2
    ;;
esac
