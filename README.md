# Nix Homelab

A modular NixOS homelab with reusable service modules, per-host profiles, and a
small `just` interface for building and deploying machines. Linux hosts are
exposed as flake outputs; the macOS AI host is managed by a separate
nix-darwin sub-flake.

The layout is based on
[notthebee/nix-config](https://git.notthebee.ee/notthebee/nix-config) and has
been adapted around this homelab's hosts, service tiers, GPU workloads, and
runtime-secret model.

## What is included

| Area | Location | Purpose |
| --- | --- | --- |
| NixOS hosts | [`machines/nixos/`](machines/nixos) | Shared host configuration plus machine-specific hardware and service selection |
| macOS hosts | [`machines/darwin/`](machines/darwin) | nix-darwin configuration for Apple Silicon systems |
| Service modules | [`modules/homelab/`](modules/homelab) | Reusable modules for media, monitoring, AI, collaboration, and home services |
| Deployment commands | [`justfile`](justfile) | Build, dry-activate, boot, and switch operations |
| Runtime secrets | [`docs/nixos.md#secrets`](docs/nixos.md#secrets) | File-based secret inputs that stay outside the repository |
| VM checks | [`tests/miniflux-grafana.nix`](tests/miniflux-grafana.nix) | Boots representative services and probes their health endpoints |

## Repository layout

```text
flake.nix                          # flake-parts entry point and inputs
justfile                           # common build and deploy commands
machines/nixos/
  _common/                         # users, SSH, and Nix settings shared by Linux hosts
  <host>/
    configuration.nix             # hardware and boot configuration
    hardware-configuration.nix    # generated hardware description
    homelab.nix                    # services enabled for this host
machines/darwin/                   # independent nix-darwin sub-flake
modules/homelab/
  default.nix                      # shared homelab options and reverse proxy
  services/<service>/default.nix   # one module per service
tests/                             # NixOS VM checks
```

`machines/nixos/default.nix` discovers every directory containing a
`configuration.nix` and exposes it as `nixosConfigurations.<host>`. Adding a
host therefore does not require editing the root flake.

Services use the `homelab.services.<name>` option namespace. Each service also
has an importance tier (`high`, `medium`, or `low`), allowing a host to enable
a useful group of services and override individual services when needed.

## Getting started

Enter the development shell:

```sh
nix develop
```

List the available commands:

```sh
just
just --list
```

Build a host configuration without activating it:

```sh
just build <host>
```

Dry-activate or deploy a host:

```sh
just dry-run <host>
just deploy <host>
```

The deployment commands expect SSH access to the target and any required
runtime secret files to already exist on that machine.

## Secrets

Tracked configuration contains paths to secrets, not the secret values.
Miniflux and Grafana, for example, expect these files on the target host:

```text
/run/secrets/miniflux-admin.env
/run/secrets/grafana-secret-key
```

Provision them through a secret manager or another out-of-band process before
activation. See [docs/nixos.md](docs/nixos.md#secrets) for the file formats and
service-specific requirements.

## Validation

Run formatting and flake evaluation locally:

```sh
just fmt
nix flake check --no-build
```

Build the representative Miniflux/Grafana VM check on an x86_64 Linux system:

```sh
nix build .#checks.x86_64-linux.miniflux-grafana-vm
```

The VM test supplies synthetic credentials, boots both services, and checks
their local health endpoints. The `machines/darwin` sub-flake has its own lock
file and should be evaluated on macOS.

## Documentation

- [NixOS operations](docs/nixos.md): profiles, first-host setup, TLS, commands,
  and secrets.
- [General services host](docs/general-homelab.md): services running on
  `alison`.
- [DGX Spark host](docs/dgx-spark.md): NVIDIA GPU and model-serving setup on
  `grace`.
- [macOS host](docs/macos.md): nix-darwin configuration for `ada`.

## License

See [LICENSE](LICENSE). The original notice is preserved; repository
provenance is documented in the project history and linked upstream source.
