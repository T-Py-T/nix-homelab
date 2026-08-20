# nix-homelab

A modular NixOS homelab. Each machine is a flake output and every service is a
self-contained module, selected per host by profile. Modelled on
[notthebee/nix-config](https://git.notthebe.ee/notthebee/nix-config).

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
