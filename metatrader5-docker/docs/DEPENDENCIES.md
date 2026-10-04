# Dependency inventory

The Ubuntu host needs only the container runtime, Compose, and an SSH service
for the recommended access path. Everything required to render and run MT5 is
installed inside the image.

## Host-side requirements

| Dependency | Required | Purpose |
| --- | --- | --- |
| amd64/x86-64 Linux kernel | Yes | Wine and `terminal64.exe` execution; ARM is not supported natively |
| Docker Engine 24 or newer | Yes | Image build, namespaces, networking, health checks, and volumes |
| Docker Compose v2 | Yes | Reproducible service configuration and lifecycle |
| OpenSSH server on the Ubuntu VM | Recommended | Secure transport to the loopback-bound noVNC service |
| OpenSSH client on the workstation | Recommended | Creates the local port forward; built into current Windows versions |
| Modern browser with WebSocket and Canvas support | Yes for GUI access | Runs the noVNC client |
| `bash`, `curl`, `sha256sum`, `gzip`, `tar` | Used by helper scripts | Initialization, validation, backup, export, and smoke tests; standard on Ubuntu |
| `make` | Optional | Convenience command aliases |
| ShellCheck and Hadolint | Optional locally | Static analysis; GitHub CI supplies them |

## Base and package sources

- Base image: `ubuntu:24.04` for `linux/amd64`.
- Wine packages: official WineHQ Noble repository and signing key.
- Ubuntu packages: Ubuntu Noble repositories configured in the base image.
- Multiarch: `i386` is enabled because Wine requires 32-bit Windows support
  libraries even though MT5 itself is 64-bit.

Production release builds should pin the Ubuntu image digest. Package versions
currently follow the selected Ubuntu and WineHQ repositories at build time so
security updates are obtained during a rebuild.

## Direct image packages

| Package | Stage | Role |
| --- | --- | --- |
| `ca-certificates` | Build/runtime | Trusted HTTPS certificate roots |
| `curl` | Build/runtime | Downloads installers and probes noVNC health |
| `gnupg` | Build | Imports the WineHQ repository key |
| `winehq-staging` | Build/runtime | Wine runtime and recommended amd64/i386 dependencies |
| `cabextract` | Build/runtime support | Extracts Microsoft cabinet-style content used by Wine workflows |
| `dbus-x11` | Runtime | D-Bus integration for the X11 desktop environment |
| `fonts-dejavu-core` | Runtime | General UI font coverage |
| `fonts-liberation` | Runtime | Metric-compatible common fonts for Windows-style layouts |
| `fonts-wine` | Runtime | Wine-specific Windows-compatible fonts |
| `libgl1-mesa-dri` | Runtime | Software OpenGL rendering on a headless host |
| `novnc` | Runtime | HTML5 VNC client served to the browser |
| `openbox` | Runtime | Lightweight X11 window manager |
| `procps` | Runtime | `pgrep` process checks used by the health check |
| `python3-minimal` | Runtime | MT5 journal forwarder and websockify runtime support |
| `supervisor` | Runtime | Starts and restarts the six cooperating runtime programs |
| `tini` | Runtime | PID 1 signal forwarding and zombie reaping |
| `tzdata` | Runtime | Configurable local timezone data |
| `websockify` | Runtime | WebSocket-to-VNC proxy and static noVNC web server |
| `winbind` | Runtime | Windows account/domain compatibility used by Wine components |
| `x11-utils` | Build/runtime | `xdpyinfo` readiness checks |
| `x11vnc` | Runtime | Exposes the Xvfb framebuffer through VNC/RFB |
| `xauth` | Runtime support | X11 authorization utilities |
| `xfonts-base` | Runtime | Core X11 bitmap fonts |
| `xvfb` | Build/runtime | In-memory X server for installation and normal operation |

WineHQ installs additional recommended dependencies transitively. To record the
exact installed package set for a built image:

```bash
docker run --rm --entrypoint /bin/bash \
  local/metatrader5-wine:latest \
  -lc "dpkg-query -W -f='\${binary:Package}\t\${Version}\n' | sort"
```

The Ubuntu base and direct packages also supply standard utilities used by the
scripts: Bash; coreutils (`cp`, `date`, `od`, `sha256sum`, `tail`, `timeout`,
and related tools); findutils; `grep`; `sed`; `awk`; `tar`; `gzip`; `iconv`;
`dpkg`/APT; and the shadow account tools (`groupadd` and `useradd`). The Python
journal forwarder uses only the Python standard library.

## Downloaded Windows components

| Component | Default source | Build-time control | Runtime purpose |
| --- | --- | --- | --- |
| MetaTrader 5 installer | MetaQuotes CDN | `MT5_INSTALLER_URL`, `MT5_INSTALLER_SHA256` | Installs `terminal64.exe` and application files into the seed Wine prefix |
| Microsoft Edge WebView2 bootstrapper | Microsoft redirect endpoint | `WEBVIEW2_INSTALLER_URL`, `WEBVIEW2_INSTALLER_SHA256` | Installs the embedded browser runtime used by MT5 web-backed screens |

These are proprietary components and are downloaded during the image build.
The repository does not redistribute their installers. The build records the
observed URLs, hashes, Wine version, and terminal path in
`/opt/mt5-meta/build-info.txt`.

## Runtime process inventory

| Supervisor program | Executable | Dependency relationship |
| --- | --- | --- |
| `xvfb` | `Xvfb` | Foundation for every graphical process |
| `openbox` | `openbox` | Waits for Xvfb and manages windows |
| `x11vnc` | `x11vnc` | Waits for Xvfb and serves display `:99` on loopback port `5900` |
| `novnc` | `websockify` | Serves noVNC on `6080` and proxies to `127.0.0.1:5900` |
| `mt5` | `wine terminal64.exe` | Waits for Xvfb and launches the terminal |
| `mt5-log-forwarder` | Python script | Watches journals inside the persistent Wine prefix |

## Update and pinning policy

There are two valid operating models:

1. **Tracking build:** leave package and installer versions unpinned, rebuild
   regularly, and smoke-test on a demo account. This receives current upstream
   fixes but can expose compatibility regressions.
2. **Controlled release:** pin the base image digest and both installer hashes,
   archive the resulting image, generate an SBOM, and promote only after
   functional testing. This is more reproducible but requires deliberate
   security updates.

For production trading, controlled releases plus a canary deployment provide
the safer balance.

## Licensing

The orchestration repository does not grant rights to Ubuntu, Wine, WebView2,
MetaTrader 5, fonts, or VNC components. Review `NOTICE.md`, the upstream license
metadata installed with packages, MetaQuotes terms, Microsoft WebView2 terms,
and broker-specific agreements before publishing a built image.
