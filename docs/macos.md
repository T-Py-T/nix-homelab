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

## Mac Studio as an AI node (`ada`)

Apple Silicon is strong hardware for local AI, so the repo defines a Mac Studio
node, `ada`, that serves models with Ollama on Metal (the macOS side of the `ai`
role). Its config is at `machines/darwin/ada/configuration.nix` - Ollama as a
launchd agent. Because macOS is not a NixOS host, this uses **nix-darwin**, which
needs a flake input and a `flake.lock` update, so `ada` ships **unwired**.
Activate it on a machine that has Nix:

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
