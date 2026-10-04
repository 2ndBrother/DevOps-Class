#!/usr/bin/env bash
set -Eeuo pipefail

args=(--web /usr/share/novnc)

if [[ -n "${NOVNC_CERT_FILE:-}" || -n "${NOVNC_KEY_FILE:-}" ]]; then
  [[ -r "${NOVNC_CERT_FILE:-}" ]] || {
    echo "NOVNC_CERT_FILE is not readable" >&2
    exit 1
  }
  [[ -r "${NOVNC_KEY_FILE:-}" ]] || {
    echo "NOVNC_KEY_FILE is not readable" >&2
    exit 1
  }
  args+=(--cert "${NOVNC_CERT_FILE}" --key "${NOVNC_KEY_FILE}" --ssl-only)
fi

exec websockify "${args[@]}" 6080 127.0.0.1:5900

