#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
else
  echo "Kept existing .env"
fi

mkdir -p secrets backups certs
chmod 0700 secrets backups
chmod 0755 certs
if [[ ! -f secrets/vnc_password ]]; then
  umask 077
  if command -v openssl >/dev/null 2>&1; then
    password="$(openssl rand -hex 4)"
  else
    password="$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
  fi
  printf '%s\n' "${password}" > secrets/vnc_password
  # Compose bind-mounts file-backed secrets without remapping ownership. The
  # host directory remains private, while the mounted file must be readable by
  # the container's non-root trader account.
  chmod 0644 secrets/vnc_password
  printf 'Created secrets/vnc_password. Browser password: %s\n' "${password}"
else
  chmod 0644 secrets/vnc_password
  echo "Kept existing secrets/vnc_password"
fi

echo "Initialization complete. Review .env, then run: docker compose build --pull"
