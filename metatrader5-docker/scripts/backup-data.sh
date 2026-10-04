#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

read_dotenv_value() {
  local key="$1"
  [[ -f .env ]] || return 0
  awk -v key="${key}" '
    index($0, key "=") == 1 { value = substr($0, length(key) + 2) }
    END { sub(/\r$/, "", value); print value }
  ' .env
}

image="$(docker compose config --images | sed -n '1p')"
[[ -n "${image}" ]] || image="local/metatrader5-wine:latest"
volume="${MT5_DATA_VOLUME:-$(read_dotenv_value MT5_DATA_VOLUME)}"
volume="${volume:-mt5-data}"
stamp="$(date --utc +'%Y%m%dT%H%M%SZ')"
mkdir -p backups
output="mt5-data-${stamp}.tar.gz"

was_running="$(docker compose ps --status running -q mt5)"
if [[ -n "${was_running}" ]]; then
  docker compose stop mt5
  trap 'docker compose start mt5 >/dev/null' EXIT
fi

docker run --rm \
  --entrypoint /bin/bash \
  --user 0:0 \
  --read-only \
  --mount "type=volume,src=${volume},dst=/data,readonly" \
  --mount "type=bind,src=${project_dir}/backups,dst=/backup" \
  "${image}" \
  -c "tar -C /data -czf /backup/${output} ."

if [[ -n "${was_running}" ]]; then
  docker compose start mt5 >/dev/null
  trap - EXIT
fi

sha256sum "backups/${output}" > "backups/${output}.sha256"
printf 'Created backups/%s\n' "${output}"
printf 'This archive contains account state and must be encrypted and access-controlled.\n'
