# Changelog

All notable changes are documented here. Version numbers follow Semantic
Versioning for the repository's orchestration code; they do not describe the
independently updated MetaTrader, WebView2, Wine, or Ubuntu components.

## 1.0.0 - 2026-10-04

### Added

- Single-container MetaTrader 5 runtime on WineHQ Staging.
- Headless Xvfb/Openbox desktop with x11vnc and browser-based noVNC access.
- Persistent Wine/MT5 named volume, external configuration, health checks,
  process supervision, log forwarding, backups, and image export.
- Windows and VirtualBox access guidance, architecture and dependency
  documentation, troubleshooting runbook, local validation, and GitHub CI.

### Fixed during target deployment

- Avoided Ubuntu 24.04's occupied UID/GID `1000` by using `10001`.
- Made the file-backed VNC secret readable by the non-root container process
  while protecting its host directory.
- Pointed status and smoke-test commands at `/tmp/mt5/supervisor.sock` through
  the shipped Supervisor configuration.
- Documented PowerShell SSH syntax, VirtualBox NAT forwarding, and noVNC manual
  connection for browser cache or automatic-connection failures.
