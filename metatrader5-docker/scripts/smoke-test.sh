#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

container_id="$(docker compose ps -q mt5)"
if [[ -z "${container_id}" ]]; then
  echo "MT5 container is not running. Start it with: docker compose up -d" >&2
  exit 1
fi

deadline=$((SECONDS + 300))
health=""
while (( SECONDS < deadline )); do
  health="$(docker inspect --format \
    '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
    "${container_id}")"
  case "${health}" in
    healthy)
      break
      ;;
    unhealthy|exited|dead)
      docker compose logs --tail=200 mt5 >&2
      echo "MT5 smoke test failed with state: ${health}" >&2
      exit 1
      ;;
  esac
  sleep 5
done

if [[ "${health}" != "healthy" ]]; then
  docker compose logs --tail=200 mt5 >&2
  echo "MT5 did not become healthy within 300 seconds (last state: ${health})." >&2
  exit 1
fi

docker compose exec -T mt5 \
  supervisorctl -c /etc/supervisor/conf.d/mt5.conf status
endpoint="$(docker compose port mt5 6080)"
published_port="${endpoint##*:}"
curl --fail --silent --show-error --max-time 5 \
  "http://127.0.0.1:${published_port}/vnc.html" >/dev/null

printf 'Smoke test passed: container healthy, all supervised processes visible, noVNC responding on port %s.\n' \
  "${published_port}"
