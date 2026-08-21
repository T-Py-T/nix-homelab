# Nix Homelab

A modular NixOS homelab plus a separate nix-darwin AI host. Each Linux machine
is a flake output; services are self-contained modules selected per host by
profile; deploy, dry-run, and build operations share a small `just` interface.
The structure is modelled on
[notthebee/nix-config](https://git.notthebee.ee/notthebee/nix-config).

## At a glance

| Capability | Public evidence | What it demonstrates |
| --- | --- | --- |
| Fleet composition | [`machines/nixos/`](machines/nixos) | Shared host baseline plus role-specific NixOS configurations |
| Reusable service platform | [`modules/homelab/`](modules/homelab) | Option-driven modules for media, monitoring, AI, collaboration, and home services |
| GPU / AI nodes | [`docs/dgx-spark.md`](docs/dgx-spark.md), [`docs/macos.md`](docs/macos.md) | NVIDIA/NixOS and Apple Silicon/nix-darwin operating boundaries |
| Safe deployment interface | [`justfile`](justfile) | Separate build, dry-activate, boot, and switch paths |
| Runtime secret boundary | [`docs/nixos.md#secrets`](docs/nixos.md#secrets) | Tracked configuration references runtime files rather than embedding credentials |
| Executable reliability check | [`tests/miniflux-grafana.nix`](tests/miniflux-grafana.nix) | A NixOS VM boots representative services and probes health endpoints |

Deploying a new host or updating an existing one is a single command from the
dev shell - it builds the config on the target and switches:

```sh
just deploy <host>
```

## Layout

```
flake.nix                          # inputs + flake-parts entrypoint
justfile                           # build / deploy recipes
machines/nixos/                    # hosts; each <host>/ -> nixosConfigurations.<host>
  _common/                         # config shared by every host (users, ssh, nix)
  <host>/                          # configuration.nix, hardware-configuration.nix, homelab.nix
machines/darwin/                   # macOS (nix-darwin) hosts
modules/homelab/                   # the homelab.* namespace, profiles, GPU, reverse proxy
  services/<service>/default.nix   # one module per service
```

## Documentation

- [docs/nixos.md](docs/nixos.md) - how it works: profiles, first-host setup, TLS, commands, secrets.
- [docs/general-homelab.md](docs/general-homelab.md) - the general services host (`alison`): what runs + deploy.
- [docs/dgx-spark.md](docs/dgx-spark.md) - the GPU model-serving node (`grace`): what runs + deploy.
- [docs/macos.md](docs/macos.md) - the Mac Studio AI node (`ada`) + deploying from macOS.

## Secret and reliability checks

Enabled Miniflux and Grafana services require explicit runtime file paths for
their credentials. The tracked hosts use `/run/secrets/miniflux-admin.env` and
`/run/secrets/grafana-secret-key`; the flake does not create or populate those
files. Provision them on each host before activation with a secret manager or
another out-of-band mechanism described in [docs/nixos.md](docs/nixos.md#secrets).

The x86_64-linux flake checks include a NixOS VM test that supplies synthetic,
test-only files, boots Miniflux and Grafana, and probes both local health
endpoints:

```sh
nix build .#checks.x86_64-linux.miniflux-grafana-vm
```

This proves the representative module composition starts successfully; it does
not prove that a real host has provisioned its runtime files or completed an
activation.

## Validation model

```sh
just fmt
nix flake check --no-build
nix build .#checks.x86_64-linux.miniflux-grafana-vm
```

Agents run these checks locally before publishing work. The hosted workflow is
intentionally limited to pull requests and evaluates the flake without building
the heavier VM closure, keeping GitHub Actions as a merge gate rather than a
per-push test runner.

The `machines/darwin` directory is an independent sub-flake. Its lock file is
generated and validated on macOS; the main Linux flake and its committed lock do
not establish reproducibility for that sub-flake.
