# Nix Homelab

[![check](https://github.com/T-Py-T/nix-homelab/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/T-Py-T/nix-homelab/actions/workflows/check.yml?query=branch%3Amain)
[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-5277C3.svg?logo=nixos&logoColor=white)](https://nixos.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Turn on a whole homelab by listing profiles: media, monitoring, Git, smart
home, and local AI, all declared in Nix.**

A modular NixOS homelab built with flake-parts. You get 33 reusable service
modules behind one `homelab.services` namespace, host profiles that switch on
whole groups of services at once, and a small `just` interface for building
and deploying. Linux hosts are flake outputs. The macOS AI host has its own
nix-darwin sub-flake.

[Quick start](#quick-start) ·
[Profiles](#pick-services-by-profile) ·
[Recovery check](#recovery-check-on-arm64) ·
[Docs](#documentation) ·
[Contributing](#contributing)

## Why it's nice to run

- **Profiles, not checklists.** Set `enabledProfiles = [ "core" "media" ]`
  and every service in those profiles turns on. A per-service `enable`
  always wins.
- **Drop-in hosts.** Any directory under `machines/nixos/` with a
  `configuration.nix` becomes `nixosConfigurations.<host>`, so adding a host
  doesn't touch the root flake.
- **A GPU AI node.** One host profile enables NVIDIA drivers, CUDA, Ollama
  and Open WebUI. The Mac Studio serves models on Metal through nix-darwin.
- **Secrets stay out of Git.** Config holds paths such as
  `/run/secrets/grafana-secret-key`, never the values.
- **Checked on every pull request.** CI evaluates every Linux host with
  `nix flake check --no-build`. A NixOS VM test exercises a real
  backup-and-restore on ARM64.

## Pick services by profile

| Profile | Services |
| --- | --- |
| `core` | node-exporter, Prometheus, Grafana, Uptime Kuma, Homepage |
| `ai` | Ollama, Open WebUI |
| `media` | Jellyfin, Audiobookshelf, Navidrome, Immich |
| `arr` | Prowlarr, Sonarr, Radarr, Bazarr, Lidarr, Jellyseerr |
| `downloads` | Deluge, SABnzbd, slskd |
| `productivity` | Nextcloud, Paperless-ngx, Radicale, Vaultwarden, Miniflux, MicroBin |
| `git` | Forgejo, Forgejo runner |
| `comms` | Matrix |
| `analytics` | Plausible |
| `smarthome` | Home Assistant, RaspberryMatic |
| `net` | WireGuard network namespace |

```nix
# machines/nixos/<host>/homelab.nix
homelab = {
  enable = true;
  baseDomain = "home.lan";
  services = {
    enable = true;
    enabledProfiles = [ "core" "media" "git" ];
    miniflux.adminCredentialsFile = "/run/secrets/miniflux-admin.env";
  };
};
```

Each service sits behind a shared Caddy reverse proxy at
`<service>.<baseDomain>`, using internal TLS by default or ACME through
Cloudflare DNS-01.

## Example hosts

| Host | Platform | Role | Guide |
| --- | --- | --- | --- |
| `alison` | NixOS | General services: every profile except `ai` | [docs/general-homelab.md](docs/general-homelab.md) |
| `grace` | NixOS (DGX Spark) | `core` + `ai` with NVIDIA GPU support | [docs/dgx-spark.md](docs/dgx-spark.md) |
| `ada` | macOS (nix-darwin) | Ollama on Metal | [docs/macos.md](docs/macos.md) |

There are no screenshots or images in this repository.

## Quick start

You need Nix with flakes enabled. Start in the dev shell, which provides
`just` and `nixos-rebuild`:

```sh
git clone https://github.com/T-Py-T/nix-homelab.git
cd nix-homelab
nix develop
just --list
```

Build a host without activating it, then preview the activation:

```sh
just build <host>     # local build of the system closure
just dry-run <host>   # nixos-rebuild dry-activate on the target
```

Deploy when you're happy:

```sh
just deploy <host>    # switch now
just boot <host>      # or switch on next boot
```

Deployment needs SSH access to the target, and the runtime secret files must
already exist there. For first-time setup (installing NixOS, pointing the repo
at your machine, TLS), follow [docs/nixos.md](docs/nixos.md#set-up-the-first-box).

## Secrets

Tracked configuration holds paths to secrets, never the values. Miniflux and
Grafana, for example, expect these files on the target host:

```text
/run/secrets/miniflux-admin.env
/run/secrets/grafana-secret-key
```

Provision them through a secret manager or another out-of-band process before
activation. File formats are in [docs/nixos.md](docs/nixos.md#secrets).

## Validate a change

```sh
just fmt                     # nixfmt + deadnix + shellcheck through treefmt
nix flake check --no-build   # evaluate every Linux host, same as CI
```

The `machines/darwin` sub-flake has no committed lock file and isn't part of
CI. Build it on macOS (`cd machines/darwin && nix flake lock && nix build
.#darwinConfigurations.ada.system`). A Linux machine can only evaluate it,
not build it.

## Recovery check on ARM64

The `miniflux-grafana-vm` check boots a disposable NixOS VM, writes a synthetic
marker into the Miniflux and Grafana databases, backs up just those tables,
deletes them, restores them, and verifies the marker and both health
endpoints. It's defined for `aarch64-linux` only:

```sh
nix build .#checks.aarch64-linux.miniflux-grafana-vm --print-build-logs
```

One recorded run is kept in
[`results/restore-evidence-v1/`](results/restore-evidence-v1/README.md): an
ARM64 UTM guest with synthetic data only, with hashes you can verify with
`sha256sum --check manifest.sha256`. Its timings come from a single
software-emulated run, not a recovery-time objective. The procedure and its
limits are in [docs/operability.md](docs/operability.md).

## Repository layout

```text
flake.nix                          # flake-parts entry point and inputs
justfile                           # build, dry-run, deploy, boot, fmt, check
machines/nixos/
  _common/                         # users, SSH, and Nix settings shared by Linux hosts
  <host>/
    configuration.nix              # hardware and boot configuration
    hardware-configuration.nix     # generated hardware description
    homelab.nix                    # profiles and overrides for this host
machines/darwin/                   # independent nix-darwin sub-flake
modules/homelab/
  default.nix                      # shared options and reverse proxy
  services/<service>/default.nix   # one module per service
tests/                             # NixOS VM checks
results/                           # retained recovery-check evidence
```

## Documentation

- [NixOS operations](docs/nixos.md): profiles, first-host setup, TLS, commands,
  adding a service, and secrets.
- [General services host](docs/general-homelab.md): what runs on `alison`.
- [DGX Spark host](docs/dgx-spark.md): NVIDIA GPU and model serving on `grace`.
- [macOS host](docs/macos.md): nix-darwin configuration for `ada`.
- [Recovery check](docs/operability.md): running and interpreting the ARM64
  restore drill.

## Contributing

New service modules and fixes are welcome. Follow
[Adding a service](docs/nixos.md#adding-a-service), keep secret values out of
the tree, run `just fmt` and `nix flake check --no-build`, then open a pull
request. Report security issues privately as described in
[SECURITY.md](SECURITY.md).

## Credits and license

The layout is based on
[notthebee/nix-config](https://git.notthebee.ee/notthebee/nix-config) and
adapted to these hosts, service profiles, GPU workloads and the runtime-secret
model. See [LICENSE](LICENSE); the original MIT notice is preserved.
