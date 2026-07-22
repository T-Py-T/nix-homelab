# nix-homelab

A modular NixOS homelab. Each machine is a flake output and every service is a
self-contained module, selected per host by importance tier. Modelled on
[notthebee/nix-config](https://git.notthebe.ee/notthebee/nix-config).

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

- [docs/nixos.md](docs/nixos.md) - set up a host, deploy, add services, tiers, TLS, and secrets.
- [docs/macos.md](docs/macos.md) - deploying from a macOS (Darwin) workstation.
