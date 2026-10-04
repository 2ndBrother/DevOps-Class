# MetaTrader 5 — single Docker container

This project builds an Ubuntu 24.04-based, amd64 Docker image containing Wine
Staging, MetaTrader 5, Microsoft WebView2, Xvfb, Openbox, x11vnc, noVNC,
Supervisor, a health check, and a journal forwarder. The Ubuntu host needs only
Docker Engine and the Docker Compose plugin; it does not need a physical display
or any Wine/desktop packages.

The running service is one container. You access its virtual desktop from a web
browser. MT5 installation data, settings, account database, market history,
profiles, Expert Advisors, and journals live in a named Docker volume so they
survive container replacement.

Current repository release: **1.0.0**. The image build and manual noVNC login
have been exercised on an amd64 Ubuntu VM, including access from Windows through
VirtualBox NAT and an SSH tunnel.

## Documentation

| Guide | Contents |
| --- | --- |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Component and image layers, startup sequence, data flow, security boundaries, and improvement roadmap |
| [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md) | Complete host, Ubuntu, Wine, graphical, browser, process, and proprietary dependency inventory |
| [`docs/OPERATIONS.md`](docs/OPERATIONS.md) | Deployment, Windows/VirtualBox access, lifecycle, configuration, backup, migration, and updates |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Build UID collision, secret permissions, SSH/NAT, browser, noVNC, Supervisor, and volume issues |
| [`VALIDATION.md`](VALIDATION.md) | Static checks and target-host evidence |

## Architecture

| Concern | Implementation |
| --- | --- |
| Windows application | WineHQ Staging in the image |
| Headless display | Xvfb with configurable resolution and 24-bit color |
| Window manager | Openbox |
| Browser desktop | x11vnc on container loopback + noVNC/websockify on port 6080 |
| Credentials/state | Named volume `mt5-data`; never baked into the reusable image |
| External settings | `.env` plus read-only `config/mt5.ini` |
| Lifecycle | Supervisor with automatic process restart and Docker health check |
| Monitoring | Process/VNC logs plus MT5/EA/tester journals forwarded as JSON lines |

## Requirements

- An x86-64/amd64 Ubuntu host (22.04 or 24.04 are suitable)
- Docker Engine 24+ and Docker Compose v2
- At least 2 GB RAM and roughly 8 GB free disk for build layers and the final image
- Outbound HTTPS during the image build

The image is Linux-host portable; the host distribution does not need to match
the Ubuntu release inside the container. ARM hosts are not supported natively.

## Quick start

```bash
unzip metatrader5-docker.zip
cd metatrader5-docker
./scripts/init.sh
docker compose build --pull
docker compose up -d
docker compose ps
./scripts/smoke-test.sh
```

The equivalent convenience commands are `make init`, `make build`, `make up`,
and `make smoke`.

The build downloads the current generic MT5 installer and WebView2 from their
official endpoints. On first start, Docker seeds the empty named volume from the
preinstalled Wine prefix. Later starts reuse that same volume.

The service binds to `127.0.0.1:6080` by default. From your workstation, create
an SSH tunnel to the Ubuntu VM. In Windows PowerShell, keep this on one line:

```powershell
ssh -N -o ExitOnForwardFailure=yes -L 16080:127.0.0.1:6080 ubuntu@YOUR_SERVER_IP
```

Then open:

```text
http://127.0.0.1:16080/vnc.html
```

Select **Connect** manually and enter the eight-character password printed by
`scripts/init.sh` (or read it on the server with
`cat secrets/vnc_password`). Manual connection avoids browser-cache and
automatic-connection edge cases on first use. Log into the broker from the MT5
GUI and enable password saving if desired. The login state remains in the
`mt5-data` volume across restarts and image/container replacement.

VirtualBox NAT guests commonly use `10.0.2.15`, which is not directly reachable
from Windows. Add a host `127.0.0.1:2222` to guest port `22` forwarding rule and
connect with `ssh -p 2222 ...`. The exact commands and a settings table are in
[`docs/OPERATIONS.md`](docs/OPERATIONS.md#virtualbox-nat).

## External configuration

Display size, timezone, port, image/volume names, logging behavior, and installer
URLs are controlled by `.env`. Change them and recreate the container:

```bash
docker compose up -d --force-recreate
```

For MT5 startup settings:

```bash
cp config/mt5.ini.example config/mt5.ini
chmod 644 config/mt5.ini
editor config/mt5.ini
docker compose restart mt5
```

The container converts UTF-8 configuration to the UTF-16LE format MT5 expects.
MT5 opens a custom startup configuration read-only, so UI changes are not
written back to this mounted file. Normal user/account state still persists in
the volume.

Do not put broker passwords in `.env` or `config/mt5.ini`: environment values
are visible through container inspection, while the read-only config bind mount
must be readable by the non-root container UID. Interactive login is preferred.

### Important `.env` values

| Variable | Default | Purpose |
| --- | --- | --- |
| `IMAGE_VERSION` | `1.0.0` | OCI image version label for this repository release |
| `NOVNC_BIND_ADDRESS` | `127.0.0.1` | Host interface used for browser access |
| `NOVNC_PORT` | `6080` | Host browser port |
| `DISPLAY_WIDTH/HEIGHT/DEPTH` | `1600/900/24` | Virtual screen geometry |
| `MT5_TIMEZONE` | `Etc/UTC` | Container and MT5 runtime timezone |
| `MT5_PORTABLE` | `true` | Keeps MT5 data beside the terminal within the persistent prefix |
| `MT5_CONFIG_FILE` | `/config/mt5.ini` | Optional read-only startup config |
| `MT5_TERMINAL_PATH` | auto-detect | Selects one terminal when a custom image contains more than one |
| `MT5_LOG_FORWARDING` | `true` | Streams MT5 journals to container stdout |
| `WINEDEBUG` | `-all` | Wine diagnostic channels; increase only while troubleshooting |
| `TRADER_UID/TRADER_GID` | `10001/10001` | Internal non-root account IDs; both must be unused in the base image |

## Broker-specific installer

Many brokers distribute a branded MT5 terminal. Put its trusted HTTPS URL in
`.env` as `MT5_INSTALLER_URL`, choose a different image tag and preferably a new
volume name, then rebuild:

```bash
docker compose build --no-cache mt5
docker compose up -d
```

The build fails unless the installer creates `terminal64.exe`. If a branded
installer creates more than one terminal, set `MT5_TERMINAL_PATH` to the desired
Linux path within the Wine prefix. Optional `MT5_INSTALLER_SHA256` and
`WEBVIEW2_INSTALLER_SHA256` values make the build reject unexpected installer
bytes; the observed hashes are also recorded in `/opt/mt5-meta/build-info.txt`.

## Monitoring and logs

```bash
docker compose logs -f --tail=200 mt5
./scripts/status.sh
./scripts/smoke-test.sh
docker inspect --format '{{json .State.Health}}' "$(docker compose ps -q mt5)"
```

The log stream includes:

- Xvfb, Openbox, x11vnc, noVNC, Wine, and MT5 process lifecycle events
- VNC connection/disconnection events
- MT5 terminal journals, EA journals, crash logs, and tester logs as JSON lines
- Docker health state for the web endpoint, X/VNC processes, and terminal process

The forwarder redacts obvious `password=...` patterns. MT5 journals can still
contain account numbers, order data, strategy names, and broker details, so log
access should be restricted. `compose.yaml` rotates Docker JSON logs at 10 MB
with five retained files.

This is operational monitoring, not a click-by-click audit trail. MT5 does not
expose a supported event for every GUI action. Account connections, trades, EA
activity, errors, and terminal events are normally visible in its journals.

## Persistence, backup, and migration

`docker compose down` preserves the named volume. **Do not use
`docker compose down -v`** unless you intend to delete saved logins and all MT5
state.

Create a consistent stopped-volume backup:

```bash
./scripts/backup-data.sh
```

The archive contains sensitive account state. Encrypt and access-control it.
If MT5 was running, the script stops it for consistency and starts it again even
when archive creation fails.

Export the reusable image:

```bash
./scripts/export-image.sh
```

On another amd64 Linux host:

```bash
gunzip -c backups/local_metatrader5-wine_latest.tar.gz | docker load
```

The image intentionally excludes runtime credentials. Move the protected volume
backup separately only when the configured user state must also migrate.

## Security and trading safeguards

- Keep the default loopback bind and use SSH tunneling. VNC authentication is
  legacy and only the first eight password characters are significant.
- If direct browser exposure is unavoidable, put MT5 behind an authenticated
  HTTPS reverse proxy or configure the optional websockify certificate/key.
- The container is non-root, has all Linux capabilities dropped, uses a
  read-only root filesystem, and permits writes only to its data/cache/tmp mounts.
- `AllowLiveTrading=0` is the safe example default. Test with a demo account and
  explicitly review Expert Advisor and DLL permissions before live use.
- MetaTrader 5 and WebView2 are proprietary components. Review their terms
  before sharing a built image, especially through a public registry.

## Updates and troubleshooting

- Rebuild the image regularly to refresh Ubuntu, Wine, noVNC, WebView2, and the
  generic MT5 installer: `docker compose build --pull --no-cache`.
- A build ending with exit code `4` at `groupadd` or `useradd` means the chosen
  numeric ID is already occupied. Ubuntu 24.04 uses UID/GID `1000`, so this
  project defaults to `10001`. Remove stale `TRADER_UID=1000` and
  `TRADER_GID=1000` entries from `.env`, or set both to unused IDs, then rebuild.
- MT5 can live-update inside the persistent Wine prefix. An existing volume
  takes precedence over the seed prefix in a newly built image; use a new volume
  for a completely clean MT5 installation.
- A blank browser page usually means x11vnc or Xvfb is restarting. Check
  `docker compose logs --tail=200 mt5` and `./scripts/status.sh`.
- If health remains `starting`, allow several minutes for the first launch. A
  persistent failure of the `mt5` program usually indicates an incompatible
  branded installer or an invalid `MT5_TERMINAL_PATH`.
- If the browser works but MT5 cannot reach the broker, verify DNS, outbound
  firewall rules, broker endpoints, and proxy settings in `config/mt5.ini`.
- If the full noVNC page reports a front-end error while the container is
  healthy, use manual connection in an InPrivate window and force-refresh cached
  assets. See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Repository development

Run the local checks with:

```bash
./scripts/update-checksums.sh
./scripts/validate.sh
```

GitHub Actions repeats Bash syntax, ShellCheck, Dockerfile linting, Python
parsing/unit tests, Compose rendering, and checksum verification on pushes and pull
requests. Full image construction remains an explicit release gate because it
is large, downloads separately licensed installers, and needs functional Wine
and GUI testing on amd64.

## Source basis

The implementation follows MetaQuotes' Linux approach (Wine plus WebView2),
MT5's documented `/portable` and `/config:` startup options, noVNC's websockify
architecture, and Docker named-volume persistence. See the official links in
`SOURCES.md`, dependency inventory in `docs/DEPENDENCIES.md`, and completed
checks in `VALIDATION.md`.
