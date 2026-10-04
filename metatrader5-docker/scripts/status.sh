#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

docker compose ps
echo
docker compose exec -T mt5 \
  supervisorctl -c /etc/supervisor/conf.d/mt5.conf status
