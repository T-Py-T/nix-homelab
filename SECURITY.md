# Security policy

## Report a vulnerability

Do not include credentials, hostnames, private addresses, or configuration in
a public issue. Use GitHub's private vulnerability reporting when the
repository Security tab offers it. If that option is unavailable, contact the
maintainer through the GitHub profile before sharing sensitive details.

Include the affected file or module, the expected behavior, and the minimum
steps needed to reproduce the problem with synthetic data.

## Repository boundary

This repository defines NixOS systems and expects runtime secrets to exist
outside the repository. Never commit a secret value, decrypted configuration,
private backup, or host-specific evidence packet.

The recovery check uses disposable NixOS test machines, synthetic credentials,
and synthetic marker tables. It does not connect to a homelab host or a real
service database.
