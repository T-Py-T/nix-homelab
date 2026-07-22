# Deploying from macOS (Darwin)

macOS is not a homelab host - the hosts run NixOS. A Mac can still drive builds
and deploys, but it **cannot build Linux system closures locally**. The homelab
setup itself is identical to [nixos.md](./nixos.md); this page only calls out
the Darwin-specific bits.

## Nix on macOS

Install Nix (the [Determinate Systems installer](https://determinate.systems)
supports macOS), then use the dev shell as usual:

```sh
nix develop            # provides just + nixos-rebuild
```

On macOS `nixos-rebuild` acts purely as a deploy driver; it does not build Linux
packages locally.

## Build on the target, not on the Mac

macOS cannot realise `x86_64-linux` / `aarch64-linux` derivations. Recipes that
build on the remote target work from a Mac; recipes that build locally do not:

| Recipe | Builds where | Works from macOS |
|---|---|---|
| `just deploy <host>` | on the target (`--build-host`) | yes |
| `just boot <host>` | on the target (`--build-host`) | yes |
| `just check` | evaluation only | yes |
| `just dry-run <host>` | locally | no - would build Linux on the Mac |
| `just build <host>` | locally | no - would build Linux on the Mac |

So from a Mac, deploy with `just deploy <host>`. To preview or build a closure
without switching, run those recipes from a Linux machine, SSH into the target
and build there, or configure a Linux builder (below).

## Optional: a local Linux builder

If you want `just build` / `just dry-run` to work from macOS, give Nix a Linux
remote builder so it offloads Linux builds:

- an existing NixOS box added to `nix.buildMachines` / `/etc/nix/machines`, or
- `nix-darwin`'s `nix.linux-builder.enable`, which runs a small NixOS builder VM
  on the Mac.

With a builder configured, the local recipes build via that machine instead of
failing.

## Managing the Mac itself

This repo only defines NixOS hosts. Managing the Mac's own configuration with
Nix is a separate `nix-darwin` concern and would live under its own
`machines/darwin/` tree - it is intentionally not part of the homelab hosts.
