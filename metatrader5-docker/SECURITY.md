# Security policy

## Supported version

Security fixes target the latest repository release. Ubuntu, WineHQ, WebView2,
MetaTrader 5, and browser dependencies follow their own upstream lifecycles.

## Reporting

Use GitHub private vulnerability reporting when it is enabled for the
repository. Otherwise contact the repository owner privately. Do not place VNC
passwords, broker credentials, account numbers, private keys, public server
addresses, or sensitive trading data in a public issue.

## Deployment baseline

- Keep `NOVNC_BIND_ADDRESS=127.0.0.1` and connect through SSH.
- Treat VNC authentication as a compatibility layer, not an internet-facing
  security boundary.
- Protect `.env`, `secrets/`, `config/mt5.ini`, `certs/`, backups, and Docker
  daemon access.
- Test with a demo account before enabling live trading or DLL imports.
- Rebuild regularly and review upstream advisories for every dependency listed
  in `docs/DEPENDENCIES.md`.
- Pin installer checksums and an Ubuntu image digest for controlled releases.

The project does not claim to provide a hardened multi-user trading platform.
Each untrusted user or account should receive an isolated deployment and data
volume.
