# Mac Studio AI node (host: ada)

`ada` is the macOS AI node - a Mac Studio (Apple Silicon).

## What's loaded

Ollama serving models on **Metal** (a launchd agent from the nixpkgs `ollama`
package), config at `machines/darwin/ada/configuration.nix`, built by the
`machines/darwin` sub-flake. This is the macOS side of the `ai` role: macOS is
not a NixOS host, so it does not run the `homelab.services` tree - Open WebUI and
monitoring live on `grace`. Set `system.primaryUser` in the config to your macOS
login name.

## Confirm the config (build it)

Darwin builds **only on macOS** - so build it on your Mac (no container can),
from the sub-flake:

```sh
cd machines/darwin
nix flake lock                               # first time: pin nix-darwin + nixpkgs
nix build .#darwinConfigurations.ada.system  # build the darwin system
```

Or in CI: run the `check` workflow with host `ada` (Actions -> Run workflow); it
builds on a macOS runner.

## Can an ARM container confirm it?

Only partly, and this is the one place the fleet truly diverges. A Linux Nix
container (devcontainer / devpod), even an arm64 one, is still **Linux**: it can
*evaluate* the darwin config to confirm it is well-formed and every derivation
resolves -

```sh
cd machines/darwin && nix flake lock
nix build --dry-run .#darwinConfigurations.ada.system
```

but it can never *build* a darwin system, because darwin compilation needs the
macOS SDK/stdenv. The full build is the macOS-only step above (your Mac, or the
macOS CI runner). Containers are for the Linux hosts (`grace`, `alison`).

## Deploy

```sh
cd machines/darwin
# first time (bootstraps nix-darwin):
sudo nix run nix-darwin -- switch --flake .#ada
# after that:
darwin-rebuild switch --flake .#ada
```

## Deploying the NixOS fleet from a Mac workstation

A Mac can drive deploys but **cannot build Linux closures locally**. Recipes that
build on the remote target work; those that build locally do not:

| Recipe | Builds where | Works from macOS |
|---|---|---|
| `just deploy <host>` | on the target (`--build-host`) | yes |
| `just boot <host>` | on the target (`--build-host`) | yes |
| `just check` | evaluation only | yes |
| `just dry-run <host>` | locally | no - would build Linux on the Mac |
| `just build <host>` | locally | no - would build Linux on the Mac |

To make the local-build recipes work, give Nix a Linux remote builder (a NixOS
box in `nix.buildMachines`, or `nix-darwin`'s `nix.linux-builder.enable`) - or
use the devcontainer, which is a native aarch64 Linux Nix environment.
