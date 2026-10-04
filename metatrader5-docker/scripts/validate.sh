#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

shell_files=(docker/*.sh scripts/*.sh)
bash -n "${shell_files[@]}"
echo "Bash syntax: OK"

python3 - <<'PY'
import ast
from pathlib import Path

ast.parse(Path("docker/mt5-log-forwarder.py").read_text(encoding="utf-8"))
print("Python syntax: OK")
PY

python3 -m unittest discover -s tests -v
echo "Python unit tests: OK"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${shell_files[@]}"
  echo "ShellCheck: OK"
else
  echo "ShellCheck: SKIPPED (install shellcheck for the full local check)"
fi

if command -v hadolint >/dev/null 2>&1; then
  hadolint Dockerfile
  echo "Hadolint: OK"
else
  echo "Hadolint: SKIPPED (CI runs the pinned Hadolint container)"
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  VNC_PASSWORD_FILE_HOST=/dev/null docker compose config --quiet
  echo "Compose model: OK"
else
  echo "Compose model: SKIPPED (Docker Compose is unavailable)"
fi

sha256sum --check SHA256SUMS
echo "Repository checksums: OK"
