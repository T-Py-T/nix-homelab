{
  # ==========================================================================
  # machines/darwin/flake.nix
  # Darwin (macOS) hosts, kept as a small sub-flake so the main (NixOS) flake
  # and its lock stay untouched. Build these on a Mac or a macOS CI runner -
  # a Linux container can evaluate a darwin config but never build it.
  #
  # No flake.lock is committed: run `nix flake lock` once (on a Mac) to pin the
  # inputs. It does NOT define any NixOS/Linux hosts - those live in ../nixos.
  # ==========================================================================
  description = "Darwin (macOS) hosts for the homelab (build on macOS only)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nix-darwin, ... }:
    {
      darwinConfigurations.ada = nix-darwin.lib.darwinSystem {
        modules = [ ./ada/configuration.nix ];
      };
    };
}
