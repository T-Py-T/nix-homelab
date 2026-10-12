{
  description = "A modular, extensible NixOS homelab built with flake-parts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        imports = [
          ./machines/nixos
          ./modules/devshell.nix
        ];

        perSystem =
          {
            pkgs,
            lib,
            system,
            ...
          }:
          let
            flake = self;
            sourceRevision = flake.rev or "dirty";
            flakeRoot = flake;
          in
          {
            checks = {
              unit-homelab = import ./tests/unit-homelab.nix { inherit pkgs lib; };
              host-eval = import ./tests/host-eval.nix {
                inherit pkgs lib system;
                nixosConfigurations = flake.nixosConfigurations;
              };
              motd-script = import ./tests/motd-script.nix { inherit pkgs lib; };
              justfile = import ./tests/justfile.nix {
                inherit pkgs;
                inherit flakeRoot;
              };
              scripts-smoke = import ./tests/scripts-smoke.nix {
                inherit pkgs;
                inherit flakeRoot;
              };
            }
            // lib.optionalAttrs (system == "x86_64-linux") {
              microbin-vm = import ./tests/microbin-vm.nix {
                inherit pkgs;
                inherit sourceRevision;
              };
            }
            // lib.optionalAttrs (system == "aarch64-linux") {
              miniflux-grafana-vm = import ./tests/miniflux-grafana.nix {
                inherit pkgs;
                inherit sourceRevision;
              };
            };
          };
      }
    );
}
