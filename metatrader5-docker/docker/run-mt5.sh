#!/usr/bin/env bash
set -Eeuo pipefail

timestamp() {
  date --utc +'%Y-%m-%dT%H:%M:%SZ'
}

log() {
  printf '%s [mt5] %s\n' "$(timestamp)" "$*"
}

is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

for _ in {1..60}; do
  if xdpyinfo -display "${DISPLAY:-:99}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
xdpyinfo -display "${DISPLAY:-:99}" >/dev/null 2>&1 || {
  log "ERROR: X display ${DISPLAY:-:99} did not become ready"
  exit 1
}

terminal_path="${MT5_TERMINAL_PATH:-}"
if [[ -n "${terminal_path}" ]]; then
  [[ -f "${terminal_path}" ]] || {
    log "ERROR: MT5_TERMINAL_PATH does not exist: ${terminal_path}"
    exit 1
  }
else
  mapfile -d '' terminal_candidates < <(
    find "${WINEPREFIX}/drive_c/Program Files" \
      -type f -iname terminal64.exe -print0 2>/dev/null
  )
  if [[ "${#terminal_candidates[@]}" -eq 0 ]]; then
    log "ERROR: terminal64.exe was not found"
    exit 1
  fi
  if [[ "${#terminal_candidates[@]}" -gt 1 ]]; then
    log "ERROR: multiple MT5 terminals were found; set MT5_TERMINAL_PATH explicitly"
    printf '  %s\n' "${terminal_candidates[@]}" >&2
    exit 1
  fi
  terminal_path="${terminal_candidates[0]}"
fi

args=()
if is_true "${MT5_PORTABLE:-true}"; then
  args+=(/portable)
fi

config_source="${MT5_CONFIG_FILE:-/config/mt5.ini}"
if [[ -f "${config_source}" ]]; then
  runtime_config=/tmp/mt5/mt5-runtime.ini
  magic="$(od -An -tx1 -N3 "${config_source}" | tr -d ' \n')"
  case "${magic}" in
    fffe*)
      cp "${config_source}" "${runtime_config}"
      ;;
    feff*)
      printf '\xff\xfe' > "${runtime_config}"
      tail -c +3 "${config_source}" | iconv -f UTF-16BE -t UTF-16LE >> "${runtime_config}"
      ;;
    efbbbf)
      printf '\xff\xfe' > "${runtime_config}"
      tail -c +4 "${config_source}" | iconv -f UTF-8 -t UTF-16LE >> "${runtime_config}"
      ;;
    *)
      printf '\xff\xfe' > "${runtime_config}"
      iconv -f UTF-8 -t UTF-16LE "${config_source}" >> "${runtime_config}"
      ;;
  esac
  chmod 0600 "${runtime_config}"
  windows_config="$(winepath -w "${runtime_config}")"
  args+=("/config:${windows_config}")
  log "Using the externally mounted startup configuration"
fi

if [[ -n "${MT5_PROFILE:-}" ]]; then
  args+=("/profile:${MT5_PROFILE}")
fi

log "Launching ${terminal_path}"
exec wine "${terminal_path}" "${args[@]}"

