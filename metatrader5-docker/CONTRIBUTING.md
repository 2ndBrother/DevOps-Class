# Contributing

Contributions should preserve the core constraints: one runtime container,
non-root execution, loopback-only browser exposure by default, persistent MT5
state outside the image, and no credentials in source control or image layers.

## Development workflow

1. Create a branch and make the smallest focused change.
2. Run `./scripts/validate.sh`.
3. Add or update tests when journal-forwarding logic changes.
4. Render the final model with `VNC_PASSWORD_FILE_HOST=/dev/null docker compose config`.
5. Rebuild when the Dockerfile or installation scripts change.
6. Run `./scripts/smoke-test.sh` on an amd64 Ubuntu host for runtime changes.
7. Update the relevant documentation and `CHANGELOG.md`.
8. Run `./scripts/update-checksums.sh`, then rerun validation.

Do not commit `.env`, `config/mt5.ini`, VNC passwords, TLS private keys,
backups, exported images, Wine prefixes, broker credentials, account numbers,
or terminal journals.

## Pull-request expectations

- Explain whether an existing `mt5-data` volume remains compatible.
- Include sanitized logs for runtime fixes.
- Keep URLs configurable; do not hard-code broker credentials or endpoints.
- Prefer official upstream download locations and document new dependencies.
- Avoid silently weakening the loopback bind, read-only filesystem, capability
  drop, or `no-new-privileges` settings.

The standard CI intentionally performs static checks only. Full image builds
download proprietary installers and are best run as an explicit release gate
on an authorized amd64 runner.
