# Validation record

Validation date: 2026-10-04

## Passed checks

- All Bash entrypoint, runtime, backup, export, status, initialization,
  validation, and smoke-test scripts pass `bash -n`. The original runtime set
  passed ShellCheck 0.10.0; GitHub CI reruns ShellCheck for every revision.
- The Dockerfile parses cleanly with Hadolint 2.12.0. Its deliberate policy is
  to track current Ubuntu/WineHQ security packages and install WineHQ's
  recommended dependencies rather than pinning stale package versions.
- `compose.yaml` renders successfully with Docker Compose 2.40.3, including
  build arguments, loopback-only port publication, named-volume persistence,
  read-only mounts, dropped capabilities, tmpfs paths, secret mount, and log
  rotation.
- The internal account defaults to UID/GID `10001`, avoiding Ubuntu 24.04's
  pre-existing UID/GID `1000`. Dockerfile collision guards provide a direct
  diagnostic if custom account IDs are already occupied.
- The Python journal forwarder parses successfully and was exercised against
  UTF-8 and UTF-16LE MT5-style logs. Initial tailing, appended events, JSON
  output, and password-pattern redaction passed.
- `run-mt5.sh` was exercised with command stubs. Terminal discovery,
  `/portable`, `/config:`, and UTF-8 to UTF-16LE configuration conversion
  passed.
- `scripts/init.sh` was exercised in a clean temporary project. It generated an
  eight-character password, created `.env`, and produced a valid Compose model.
  The release uses a mode-`700` host secrets directory and mode-`644` mounted
  password file because file-backed Compose secrets do not remap ownership to
  the non-root container UID.
- The official download endpoints returned valid Windows PE installers:
  - MT5: PE32+ x86-64, observed SHA-256
    `a879492dd9d7b168d0538edd1c0dc5604ca43dc0951825b3501818e8b18f4c93`
  - WebView2 bootstrapper: PE32 x86, observed SHA-256
    `83004a28553bcf2f932bf03564fbab407b8e1f59cd265f8dc99cc53d028e459c`

Installer endpoints are evergreen, so these hashes can change legitimately.
Set the optional checksum variables only when intentionally pinning the exact
download bytes.

## Target-host deployment evidence

The operator completed an end-to-end deployment on an amd64 Ubuntu VM on
2026-10-04:

- `docker compose build --pull` completed successfully after changing the
  internal account default from the occupied UID/GID `1000` to `10001`.
- The resulting `local/metatrader5-wine:latest` container reported `healthy`.
- Logs confirmed successful startup of Xvfb, Openbox, x11vnc, noVNC/websockify,
  Wine/MT5, and the journal forwarder.
- x11vnc listened on container loopback port `5900`; websockify served `6080`
  and proxied to it.
- Windows reached the Ubuntu VirtualBox NAT guest through an SSH host-port
  forward and a second local forward to noVNC.
- Manual noVNC connection and VNC authentication succeeded and displayed the
  running terminal.

The observed X key-symbol, Openbox menu, non-root X socket, and x11vnc IPv6
messages did not prevent the container from becoming healthy.

## Release checks

The repository includes `.github/workflows/validate.yml`, which checks Bash,
ShellCheck, Python syntax, Compose rendering, Hadolint, and `SHA256SUMS` on
pushes and pull requests. A local equivalent is:

```bash
./scripts/validate.sh
```

This workspace cannot start a Docker daemon, so the final documentation/CI
packaging revision was checked statically here. Its image-affecting difference
from the successful target build is an OCI version label; the operational fixes
are host initialization and diagnostic-script changes. A fresh image build plus
`./scripts/smoke-test.sh` remains the release gate before production promotion.
