#!/usr/bin/env bash
set -Eeuo pipefail

: "${MT5_INSTALLER_URL:?MT5_INSTALLER_URL is required}"
: "${WEBVIEW2_INSTALLER_URL:?WEBVIEW2_INSTALLER_URL is required}"
: "${WINEPREFIX:?WINEPREFIX is required}"

build_dir="$(mktemp -d)"
install_log="${build_dir}/mt5-install.log"
xvfb_pid=""
installer_pid=""

log() {
  printf '[image-build] %s\n' "$*"
}

cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  wineserver -k >/dev/null 2>&1 || true
  if [[ -n "${installer_pid}" ]]; then
    kill "${installer_pid}" >/dev/null 2>&1 || true
    wait "${installer_pid}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${xvfb_pid}" ]]; then
    kill "${xvfb_pid}" >/dev/null 2>&1 || true
    wait "${xvfb_pid}" >/dev/null 2>&1 || true
  fi
  rm -rf "${build_dir}"
  exit "${rc}"
}
trap cleanup EXIT INT TERM

mkdir -p "${WINEPREFIX}" "${HOME}/.cache" /opt/mt5-meta

log "Starting temporary X display"
Xvfb "${DISPLAY}" -screen 0 1280x800x24 -nolisten tcp -noreset >"${build_dir}/xvfb.log" 2>&1 &
xvfb_pid=$!

for _ in {1..60}; do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1 || {
  cat "${build_dir}/xvfb.log" >&2
  exit 1
}

log "Downloading the official MT5 and WebView2 installers"
curl --fail --location --show-error --silent --retry 5 --retry-all-errors \
  "${MT5_INSTALLER_URL}" -o "${build_dir}/mt5setup.exe"
curl --fail --location --show-error --silent --retry 5 --retry-all-errors \
  "${WEBVIEW2_INSTALLER_URL}" -o "${build_dir}/webview2.exe"

mt5_sha256="$(sha256sum "${build_dir}/mt5setup.exe" | awk '{print $1}')"
webview_sha256="$(sha256sum "${build_dir}/webview2.exe" | awk '{print $1}')"

if [[ -n "${MT5_INSTALLER_SHA256:-}" && "${mt5_sha256}" != "${MT5_INSTALLER_SHA256,,}" ]]; then
  echo "MT5 installer SHA-256 mismatch" >&2
  exit 1
fi
if [[ -n "${WEBVIEW2_INSTALLER_SHA256:-}" && "${webview_sha256}" != "${WEBVIEW2_INSTALLER_SHA256,,}" ]]; then
  echo "WebView2 installer SHA-256 mismatch" >&2
  exit 1
fi

log "Initializing the Wine prefix"
wineboot --init >"${build_dir}/wineboot.log" 2>&1
winecfg -v=win11 >"${build_dir}/winecfg.log" 2>&1

log "Installing Microsoft WebView2"
webview_rc=0
timeout 600s wine "${build_dir}/webview2.exe" /silent /install \
  >"${build_dir}/webview2-install.log" 2>&1 || webview_rc=$?
# Windows installers commonly use 3010 (194 after POSIX truncation) for
# "success, restart required". A container restart is not needed at build time.
if [[ "${webview_rc}" -ne 0 && "${webview_rc}" -ne 194 ]]; then
  cat "${build_dir}/webview2-install.log" >&2
  exit 1
fi

webview_binary=""
for _ in {1..120}; do
  webview_binary="$(find "${WINEPREFIX}/drive_c/Program Files" \
    "${WINEPREFIX}/drive_c/Program Files (x86)" \
    -type f -iname msedgewebview2.exe -print -quit 2>/dev/null || true)"
  [[ -n "${webview_binary}" ]] && break
  sleep 1
done
if [[ -z "${webview_binary}" ]]; then
  cat "${build_dir}/webview2-install.log" >&2
  echo "WebView2 installation did not produce msedgewebview2.exe" >&2
  exit 1
fi

log "Installing MetaTrader 5 in unattended mode"
wine "${build_dir}/mt5setup.exe" /auto >"${install_log}" 2>&1 &
installer_pid=$!

terminal_path=""
installer_exited_at=""
deadline=$((SECONDS + 900))
while (( SECONDS < deadline )); do
  terminal_path="$(find "${WINEPREFIX}/drive_c/Program Files" \
    -type f -iname terminal64.exe -print -quit 2>/dev/null || true)"

  if [[ -n "${terminal_path}" ]]; then
    # Give the installer time to finish copying support files. It may then
    # launch the terminal and remain alive, so the Wine server is stopped below.
    sleep 20
    break
  fi

  if ! kill -0 "${installer_pid}" >/dev/null 2>&1; then
    if [[ -z "${installer_exited_at}" ]]; then
      installer_exited_at="${SECONDS}"
    elif (( SECONDS - installer_exited_at > 120 )); then
      break
    fi
  fi
  sleep 2
done

terminal_path="$(find "${WINEPREFIX}/drive_c/Program Files" \
  -type f -iname terminal64.exe -print -quit 2>/dev/null || true)"

if [[ -z "${terminal_path}" ]]; then
  cat "${install_log}" >&2
  echo "MetaTrader 5 installation did not produce terminal64.exe" >&2
  exit 1
fi

wineserver -k >/dev/null 2>&1 || true
wait "${installer_pid}" >/dev/null 2>&1 || true
installer_pid=""

cat > /opt/mt5-meta/build-info.txt <<EOF
base_image=ubuntu:24.04
architecture=amd64
wine_version=$(wine --version)
mt5_installer_url=${MT5_INSTALLER_URL}
mt5_installer_sha256=${mt5_sha256}
webview2_installer_url=${WEBVIEW2_INSTALLER_URL}
webview2_installer_sha256=${webview_sha256}
terminal_path=${terminal_path}
EOF

log "MT5 installed at ${terminal_path}"
