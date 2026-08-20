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
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
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
          { pkgs, system, ... }:
          {
            checks = lib.optionalAttrs (system == "x86_64-linux") {
              miniflux-grafana-vm = import ./tests/miniflux-grafana.nix { inherit pkgs; };
            };
          };
      }
    );
}
