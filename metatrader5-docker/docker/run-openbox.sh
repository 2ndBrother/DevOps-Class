#!/usr/bin/env bash
set -Eeuo pipefail

for _ in {1..60}; do
  if xdpyinfo -display "${DISPLAY:-:99}" >/dev/null 2>&1; then
    exec openbox --sm-disable
  fi
  sleep 1
done

echo "X display ${DISPLAY:-:99} did not become ready" >&2
exit 1

