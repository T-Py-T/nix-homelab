# macOS (Darwin) notes

macOS is not a homelab node today - the hosts run NixOS. Two macOS topics are
worth noting anyway: driving deploys from a Mac workstation, and the option of
adding a Mac as a node later. The homelab setup itself is in
[nixos.md](./nixos.md).

## Deploying from a Mac workstation

A Mac can run the Nix tooling and deploy the fleet, but it **cannot build Linux
system closures locally**. Recipes that build on the remote target work from a
Mac; recipes that build locally do not:

| Recipe | Builds where | Works from macOS |
|---|---|---|
| `just deploy <host>` | on the target (`--build-host`) | yes |
| `just boot <host>` | on the target (`--build-host`) | yes |
| `just check` | evaluation only | yes |
| `just dry-run <host>` | locally | no - would build Linux on the Mac |
| `just build <host>` | locally | no - would build Linux on the Mac |

Install Nix (the [Determinate Systems installer](https://determinate.systems)
supports macOS) and use the dev shell as usual; on macOS `nixos-rebuild` acts
purely as a deploy driver. So from a Mac, deploy with `just deploy <host>`. To
preview or build a closure without switching, run those recipes from a Linux
machine, SSH into the target and build there, or configure a Linux builder.

## Optional: a local Linux builder

To make `just build` / `just dry-run` work from macOS, give Nix a Linux remote
builder so it offloads Linux builds:

- an existing NixOS box added to `nix.buildMachines` / `/etc/nix/machines`, or
- `nix-darwin`'s `nix.linux-builder.enable`, which runs a small NixOS builder VM
  on the Mac.

## A Mac as a future node

Apple Silicon is strong hardware for self-hosted AI, so a Mac may make sense as a
homelab node later. That would be a `nix-darwin` configuration under a
`machines/darwin/` tree, selected much like the NixOS hosts are - it is
intentionally not part of the repo yet.
