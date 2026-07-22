# Mac Studio AI node (host: ada)

`ada` is the macOS AI node - a Mac Studio (Apple Silicon).

## What's loaded

Ollama serving models on **Metal** (a launchd agent from the nixpkgs `ollama`
package), config at `machines/darwin/ada/configuration.nix`. This is the macOS
side of the `ai` role: macOS is not a NixOS host, so it does not run the
`homelab.services` tree - Open WebUI and monitoring live on `grace`.

## Build and deploy

macOS uses **nix-darwin**, which needs a flake input + a `flake.lock` update, so
`ada` ships **unwired**. Activate it on a machine that has Nix:

1. Add the input to `flake.nix`:

   ```nix
   nix-darwin = {
     url = "github:nix-darwin/nix-darwin";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

2. Add a loader at `machines/darwin/default.nix`:

   ```nix
   { self, ... }:
   {
     flake.darwinConfigurations.ada = self.inputs.nix-darwin.lib.darwinSystem {
       specialArgs = { inherit (self) inputs; };
       modules = [ ./ada/configuration.nix ];
     };
   }
   ```

3. Wire it into `flake.nix` (add `./machines/darwin` to `imports`), then:

   ```sh
   nix flake lock                        # records the nix-darwin input
   darwin-rebuild switch --flake .#ada
   ```

Ollama then serves on `127.0.0.1:11434` (Metal). Front it with the Open WebUI on
`grace`, or set `OLLAMA_HOST = "0.0.0.0:11434"` in the agent to serve the LAN.

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
box in `nix.buildMachines`, or `nix-darwin`'s `nix.linux-builder.enable`).
