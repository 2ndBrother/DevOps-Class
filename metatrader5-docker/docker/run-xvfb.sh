#!/usr/bin/env bash
set -Eeuo pipefail

width="${DISPLAY_WIDTH:-1600}"
height="${DISPLAY_HEIGHT:-900}"
depth="${DISPLAY_DEPTH:-24}"

for value in "${width}" "${height}" "${depth}"; do
  [[ "${value}" =~ ^[0-9]+$ ]] || {
    echo "Invalid display dimension/depth: ${value}" >&2
    exit 1
  }
done

exec Xvfb "${DISPLAY:-:99}" \
  -screen 0 "${width}x${height}x${depth}" \
  -nolisten tcp \
  -noreset \
  +extension RANDR

