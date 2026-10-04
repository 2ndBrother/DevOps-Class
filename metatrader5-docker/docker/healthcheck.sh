#!/usr/bin/env bash
set -Eeuo pipefail

curl --fail --silent --show-error --max-time 3 \
  http://127.0.0.1:6080/vnc.html >/dev/null

pgrep -f 'Xvfb .*:99' >/dev/null
pgrep -f 'x11vnc .*5900' >/dev/null
pgrep -f '[t]erminal64\.exe' >/dev/null

