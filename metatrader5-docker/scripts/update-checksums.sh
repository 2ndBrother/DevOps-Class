#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

paths=()
while IFS= read -r -d '' path; do
  paths+=("${path}")
done < <(
  {
    find . -type f \
      ! -path './.git/*' \
      ! -path './.github/*' \
      ! -path './backups/*' \
      ! -path './certs/*' \
      ! -path './secrets/*' \
      ! -path './config/mt5.ini' \
      ! -path '*/__pycache__/*' \
      ! -name '*.pyc' \
      ! -name '.env' \
      ! -name 'SHA256SUMS' \
      ! -name '*.log' \
      -print0
    printf '%s\0' ./certs/README.md ./secrets/README.md
  } | sort -z
)

if [[ "${#paths[@]}" -eq 0 ]]; then
  echo "No repository files found for checksum generation" >&2
  exit 1
fi

sha256sum "${paths[@]}" > SHA256SUMS
printf 'Updated SHA256SUMS for %d repository files.\n' "${#paths[@]}"
