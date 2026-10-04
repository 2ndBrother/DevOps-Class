# Troubleshooting runbook

Start every investigation from the repository directory on the Ubuntu VM:

```bash
docker compose ps -a
./scripts/status.sh
docker compose logs --tail=200 mt5
```

Remove broker credentials, account numbers, private keys, public IP addresses,
and sensitive trading events before sharing diagnostics.

## Symptom map

| Symptom | Likely boundary | First check |
| --- | --- | --- |
| Build exits with code `4` | Linux user/group creation | `TRADER_UID` and `TRADER_GID` in `.env` |
| Container repeatedly restarts | Entrypoint validation or secret permissions | `docker compose logs --tail=100 mt5` |
| Server-side `curl` fails | noVNC process or port publication | `docker compose ps` and `./scripts/status.sh` |
| Server `curl` works but Windows times out on SSH | VM network/SSH service | `systemctl status ssh`, hypervisor NAT/bridging |
| Browser page cannot be reached | Missing SSH tunnel or wrong local port | Keep the tunnel terminal open; test with `curl.exe` |
| noVNC page loads but reports a front-end error | Browser cache or automatic connection | InPrivate/manual connection and browser console |
| noVNC says connection failed | WebSocket or x11vnc path | Follow logs while selecting Connect |
| Container is healthy but MT5 screen is blank | Browser scaling/cache or window repaint | Manual connection, reload, inspect MT5/Wine logs |
| `supervisor.sock no such file` | Wrong default Supervisor config | Use the shipped config path or `./scripts/status.sh` |

## Build exit code 4

Ubuntu 24.04 already uses UID/GID `1000`. This repository defaults to
`10001:10001`. Remove stale values from `.env` or set unused IDs:

```dotenv
TRADER_UID=10001
TRADER_GID=10001
```

Then rebuild:

```bash
docker compose build --pull
```

The Dockerfile now checks both IDs and emits a direct collision message before
calling `groupadd` or `useradd`.

## VNC password is unreadable

Typical log message:

```text
Provide VNC_PASSWORD_FILE (recommended) or VNC_PASSWORD.
```

Run initialization again; it preserves the password while correcting safe host
permissions:

```bash
./scripts/init.sh
docker compose up -d --force-recreate
```

Expected host permissions are a mode-`700` `secrets` directory and a
mode-`644` password file. File-backed Compose secrets are bind mounts, so the
file must be readable by container UID `10001`; the private host directory
prevents other host users from traversing to it.

## Browser access fails

First prove noVNC works on the Ubuntu VM:

```bash
curl -I http://127.0.0.1:6080/vnc.html
```

An HTTP success means Docker and noVNC work; investigate SSH and the workstation
next. On Windows PowerShell, use a single-line command:

```powershell
ssh -N -o ExitOnForwardFailure=yes -L 16080:127.0.0.1:6080 user@server-address
```

Do not copy Bash trailing backslashes into PowerShell. Keep the tunnel window
open and test from a second window:

```powershell
curl.exe -I http://127.0.0.1:16080/vnc.html
```

If port `16080` is occupied, select another unused local port and use it in both
the `-L` option and browser URL.

## SSH to `10.0.2.15` times out

`10.0.2.15` is the common VirtualBox NAT guest address. Verify SSH inside the
guest:

```bash
whoami
sudo systemctl enable --now ssh
sudo ss -lntp | grep ':22'
```

If needed:

```bash
sudo apt-get update
sudo apt-get install -y openssh-server
```

Add a VirtualBox NAT rule from Windows `127.0.0.1:2222` to guest port `22`, then
run:

```powershell
ssh -p 2222 -N -o ExitOnForwardFailure=yes -L 16080:127.0.0.1:6080 linux-user@127.0.0.1
```

Bridged or host-only networking is an alternative when it matches the VM's
security requirements.

## noVNC encountered an error

If the container is healthy and `curl` returns the page, this wording commonly
indicates a browser-side JavaScript/cache problem rather than a stopped VNC
server.

1. Keep the SSH tunnel open.
2. Open an InPrivate/incognito window.
3. Browse to `http://127.0.0.1:16080/vnc.html` without query parameters.
4. Select **Connect** manually and enter the eight-character password.
5. Force reload with `Ctrl+Shift+R` if needed.
6. Test `vnc_lite.html` if the full UI still fails.

Watch server activity during the attempt:

```bash
docker compose logs -f mt5
```

A VNC connection produces websockify messages about a WebSocket connection and
the target `127.0.0.1:5900`. If no such lines appear, open browser Developer
Tools (`F12`), select **Console**, and capture the complete first red exception.

## Supervisor socket message

The project socket is `/tmp/mt5/supervisor.sock`, not Supervisor's default
`/var/run/supervisor.sock`. Use:

```bash
docker compose exec -T mt5 \
  supervisorctl -c /etc/supervisor/conf.d/mt5.conf status
```

The supplied status and smoke-test scripts already use this command.

## Normal nonfatal warnings

The following messages can appear in a healthy deployment:

- `_XSERVTransmkdir: euid != 0` while Xvfb uses the writable `/tmp` tmpfs.
- unresolved `XF86...` key symbols from `xkbcomp`.
- x11vnc's IPv6 bind warning when its IPv4 listener is already active.
- Openbox reporting a missing Debian application menu.
- Supervisor warning that its local Unix control socket has no HTTP
  authentication; the socket is mode `700` inside the container.

Treat Docker's `(healthy)` state and Supervisor's `RUNNING` states as the
deciding signals, not those informational warnings.

## Existing volume hides a new image seed

An existing `mt5-data` volume remains authoritative after a rebuild. If a new
installer was added to the image but the running container still shows the old
terminal, test with a new volume name in `.env`:

```dotenv
MT5_DATA_VOLUME=mt5-data-canary
```

Do not delete the production volume until its backup has been restored and
verified elsewhere.
