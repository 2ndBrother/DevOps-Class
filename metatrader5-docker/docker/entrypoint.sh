#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

timestamp() {
  date --utc +'%Y-%m-%dT%H:%M:%SZ'
}

log() {
  printf '%s [entrypoint] %s\n' "$(timestamp)" "$*"
}

die() {
  log "ERROR: $*"
  exit 1
}

mkdir -p /tmp/mt5 "${XDG_CONFIG_HOME}" "${XDG_RUNTIME_DIR}" "${XDG_CACHE_HOME}"
chmod 0700 /tmp/mt5 "${XDG_CONFIG_HOME}" "${XDG_RUNTIME_DIR}" "${XDG_CACHE_HOME}"

if [[ ! -d "${WINEPREFIX}" ]]; then
  die "Wine prefix ${WINEPREFIX} is missing. Check the mt5-data volume mount."
fi

terminal_count="$(find "${WINEPREFIX}/drive_c/Program Files" \
  -type f -iname terminal64.exe -print 2>/dev/null | wc -l || true)"
if [[ "${terminal_count}" -eq 0 ]]; then
  die "terminal64.exe is missing from the persistent Wine prefix. Use a fresh volume or rebuild the image."
fi

vnc_password=""
if [[ -n "${VNC_PASSWORD_FILE:-}" && -r "${VNC_PASSWORD_FILE}" ]]; then
  vnc_password="$(tr -d '\r\n' < "${VNC_PASSWORD_FILE}")"
elif [[ -n "${VNC_PASSWORD:-}" ]]; then
  vnc_password="${VNC_PASSWORD}"
else
  die "Provide VNC_PASSWORD_FILE (recommended) or VNC_PASSWORD."
fi

if [[ "${#vnc_password}" -ne 8 ]]; then
  die "The VNC password must be exactly 8 ASCII characters (the RFB protocol ignores characters after the eighth)."
fi
if [[ ! "${vnc_password}" =~ ^[[:graph:]]{8}$ ]]; then
  die "The VNC password must contain exactly 8 printable ASCII characters."
fi

x11vnc -storepasswd "${vnc_password}" /tmp/mt5/vnc.pass >/dev/null
unset vnc_password VNC_PASSWORD

if [[ -f "${MT5_CONFIG_FILE:-/config/mt5.ini}" ]]; then
  config_mode="$(stat -c '%a' "${MT5_CONFIG_FILE:-/config/mt5.ini}" 2>/dev/null || true)"
  log "External MT5 configuration detected (mode ${config_mode:-unknown}); its contents will not be logged."
else
  log "No external mt5.ini found; MT5 will use the persistent profile and GUI settings."
fi

log "Starting MT5 desktop ${DISPLAY_WIDTH:-1600}x${DISPLAY_HEIGHT:-900}x${DISPLAY_DEPTH:-24}; noVNC listens inside the container on port 6080."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/mt5.conf
