# External MT5 configuration

To enable an operator-controlled startup configuration:

```bash
cp config/mt5.ini.example config/mt5.ini
chmod 644 config/mt5.ini
```

Edit `mt5.ini`, then restart the service with `docker compose restart mt5`.
The mounted file is read-only to MT5. Mode `644` is required because the
container runs as UID `10001` and Compose bind mounts retain host ownership.
Do not put secrets in this file; use interactive MT5 login for broker
credentials. The startup script accepts UTF-8,
UTF-8-with-BOM, UTF-16LE, or UTF-16BE and creates a temporary UTF-16LE copy.

Do not commit a file containing broker, proxy, SMTP, or MQL5 passwords.
The preferred interactive flow is to log in through the browser desktop and
allow MT5 to store its account state in the persistent `mt5-data` volume.
