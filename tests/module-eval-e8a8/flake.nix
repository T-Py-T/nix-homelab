{
  description = "Standalone flake check wrapper for homelab module eval tests";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    root.url = "path:../..";
    root.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      root,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      checks.${system}.homelab-module-eval-e8a8 = pkgs.runCommand "homelab-module-eval-e8a8" { } ''
        ${pkgs.nix}/bin/nix-instantiate --eval --strict ${root}/tests/module-eval-e8a8/checks.nix
        touch $out
      '';
    };
}
