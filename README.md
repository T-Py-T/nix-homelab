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
modules/homelab/                   # the homelab.* namespace, tiers, reverse proxy
  services/<service>/default.nix   # one module per service
```

## Documentation

- [docs/nixos.md](docs/nixos.md) - install a host, deploy and update, add services, tiers, TLS, and secrets.
