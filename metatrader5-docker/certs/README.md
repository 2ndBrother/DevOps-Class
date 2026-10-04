# Optional noVNC TLS files

The secure default is an SSH tunnel, which does not require files here. To let
websockify terminate TLS directly, mount a certificate and key in this folder
and set, for example:

```dotenv
NOVNC_CERT_FILE=/certs/fullchain.pem
NOVNC_KEY_FILE=/certs/privkey.pem
```

The non-root container user must be able to read both bind-mounted files. A
secure host layout keeps the key owned by the host user and readable by numeric
group `10001`:

```bash
chmod 0644 certs/fullchain.pem
sudo chown "$(id -u):10001" certs/privkey.pem
chmod 0640 certs/privkey.pem
```

Do not commit private keys. Prefer the default SSH tunnel unless direct TLS
termination is operationally required.
