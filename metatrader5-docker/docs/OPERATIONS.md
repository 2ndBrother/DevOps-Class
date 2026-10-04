# Operations guide

## First deployment

From the repository directory on the Ubuntu VM:

```bash
./scripts/init.sh
docker compose build --pull
docker compose up -d
./scripts/smoke-test.sh
```

Equivalent Make targets are available:

```bash
make init
make build
make up
make smoke
```

The initial image build is large because it installs Wine, WebView2, and MT5.
The first container creates and seeds the `mt5-data` volume. Do not interrupt
the image build or delete the volume after logging into a broker.

## Browser access through SSH

The default publication is `127.0.0.1:6080` on the Ubuntu VM. This is
intentional: it prevents direct network access to the VNC-compatible endpoint.

### Windows PowerShell

Use one line; Bash-style trailing backslashes are not PowerShell continuation
characters:

```powershell
ssh -N -o ExitOnForwardFailure=yes -L 16080:127.0.0.1:6080 user@server-address
```

With an identity file or nonstandard SSH port:

```powershell
ssh -i "C:\path\key.pem" -p 2222 -N -o ExitOnForwardFailure=yes -L 16080:127.0.0.1:6080 user@server-address
```

Keep that PowerShell window open. In a second window, verify the tunnel:

```powershell
curl.exe -I http://127.0.0.1:16080/vnc.html
```

### Linux or macOS workstation

```bash
ssh -N -o ExitOnForwardFailure=yes \
  -L 16080:127.0.0.1:6080 \
  user@server-address
```

### VirtualBox NAT

The common guest address `10.0.2.15` is behind VirtualBox NAT and is normally
not directly reachable from the Windows host. Add this VirtualBox port-forward
rule:

| Field | Value |
| --- | --- |
| Name | `SSH` |
| Protocol | `TCP` |
| Host IP | `127.0.0.1` |
| Host Port | `2222` |
| Guest IP | `10.0.2.15` or blank |
| Guest Port | `22` |

Then create both hops with:

```powershell
ssh -p 2222 -N -o ExitOnForwardFailure=yes -L 16080:127.0.0.1:6080 linux-user@127.0.0.1
```

Use the exact result of `whoami` inside Ubuntu; Linux usernames are
case-sensitive.

## Connect to the desktop

Open:

```text
http://127.0.0.1:16080/vnc.html
```

Manual connection is the most reliable first-use workflow:

1. Open the page.
2. Leave host and port at their page-derived defaults.
3. Ensure the WebSocket path is `websockify` if the advanced field is shown.
4. Select **Connect**.
5. Enter the eight-character password from the Ubuntu VM:

   ```bash
   cat secrets/vnc_password
   ```

After a successful manual connection, this optional URL enables automatic
connection and local scaling:

```text
http://127.0.0.1:16080/vnc.html?autoconnect=1&resize=scale&path=websockify
```

If the full UI has cached-asset problems, use an InPrivate window, force reload
with `Ctrl+Shift+R`, or test the lightweight client:

```text
http://127.0.0.1:16080/vnc_lite.html?host=127.0.0.1&port=16080&path=websockify
```

## Routine lifecycle

```bash
docker compose up -d                 # create/start
docker compose stop                  # stop without removing the container
docker compose start                 # restart an existing stopped container
docker compose restart mt5           # restart only the service
docker compose down                  # remove container/network, preserve volume
./scripts/status.sh                  # container and Supervisor state
docker compose logs -f --tail=200 mt5
```

Never run `docker compose down -v` unless permanent deletion of saved MT5 state
is intended.

## Configuration changes

Edit `.env` for deployment-level values and recreate the container:

```bash
editor .env
docker compose up -d --force-recreate
```

Enable the optional external MT5 configuration with:

```bash
cp config/mt5.ini.example config/mt5.ini
chmod 0644 config/mt5.ini
editor config/mt5.ini
docker compose restart mt5
```

Mode `0644` is necessary for the non-root container UID to read this bind mount.
Do not store broker passwords there. Interactive MT5 login keeps the sensitive
state in the named volume instead.

## Status and logs

```bash
./scripts/status.sh
./scripts/smoke-test.sh
docker compose logs --tail=200 mt5
docker inspect --format '{{json .State.Health}}' "$(docker compose ps -q mt5)"
```

The correct manual Supervisor command is:

```bash
docker compose exec -T mt5 \
  supervisorctl -c /etc/supervisor/conf.d/mt5.conf status
```

## Backup and migration

Create a consistent stopped-volume backup:

```bash
./scripts/backup-data.sh
```

Export the reusable image separately:

```bash
./scripts/export-image.sh
```

Both outputs and their SHA-256 files appear under `backups/`. The volume archive
contains sensitive saved login and account state. Encrypt it before moving it
off the host.

On another amd64 host, load the image with:

```bash
gunzip -c backups/local_metatrader5-wine_latest.tar.gz | docker load
```

Restore testing should be part of the operating procedure. A backup that has
never been restored is not yet proven recoverable.

## Updating

For a normal dependency refresh:

```bash
docker compose build --pull --no-cache
docker compose up -d --force-recreate
./scripts/smoke-test.sh
```

An existing named volume continues to override the image's seed Wine prefix.
Use a new `MT5_DATA_VOLUME` value for a clean canary installation before
upgrading a production volume.
