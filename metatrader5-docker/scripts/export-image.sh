#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

image="$(docker compose config --images | sed -n '1p')"
[[ -n "${image}" ]] || image="local/metatrader5-wine:latest"
mkdir -p backups
safe_name="$(printf '%s' "${image}" | tr '/:' '__')"
output="backups/${safe_name}.tar.gz"

docker image inspect "${image}" >/dev/null
docker save "${image}" | gzip -1 > "${output}"
sha256sum "${output}" > "${output}.sha256"

printf 'Exported image to %s\n' "${output}"
printf 'The image does not contain runtime login data; back up the volume separately.\n'
