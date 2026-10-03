# Security policy

This public repository holds reproducible NixOS and nix-darwin homelab
configuration. Runtime secrets, live hostnames, and production-only overlays
belong on target machines or in private material outside this tree.

## Report a vulnerability

If you find a credential, private key, access token, or current sensitive
endpoint in the repository or its history, do not open a public issue. Use
GitHub's private vulnerability reporting when the repository Security tab
offers it. If that option is unavailable, contact the maintainer through the
GitHub profile before sharing sensitive details.

For other security-related defects in tracked configuration, describe the
affected module or file, expected behavior, and minimal reproduction steps
using synthetic data only. Do not include credentials, hostnames, private
addresses, or live configuration in the report.

## Scope

Do not commit secret values, decrypted configuration, private backups, or
host-specific evidence packets. See [docs/nixos.md#secrets](docs/nixos.md#secrets)
for how runtime secrets are referenced without storing values in git.

The recovery check in [`tests/miniflux-grafana.nix`](tests/miniflux-grafana.nix)
uses disposable NixOS test machines, synthetic credentials, and synthetic marker
tables. It does not connect to a homelab host or a real service database.

Public modules and documentation describe architecture; they do not by themselves
grant access to any deployment.

## Related documentation

| Document | Role |
| --- | --- |
| [README.md](README.md) | Overview, layout, and validation commands |
| [docs/nixos.md](docs/nixos.md) | NixOS operations, TLS, and secrets |
| [LICENSE](LICENSE) | License terms and upstream provenance |
