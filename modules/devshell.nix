{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      # ------------------------------------------------------------------------
      # FORMATTING - `nix fmt` runs nixfmt + deadnix + shellcheck across the tree
      # ------------------------------------------------------------------------
      treefmt = {
        projectRootFile = "flake.nix";
        settings.global.excludes = [
          "*.lock"
          ".gitignore"
          ".envrc"
        ];
        programs.nixfmt.enable = true;
        programs.nixfmt.package = pkgs.nixfmt-rfc-style;
        programs.deadnix.enable = true;
        programs.shellcheck.enable = true;
      };

      # ------------------------------------------------------------------------
      # DEV SHELL - tooling for building and deploying the fleet
      # ------------------------------------------------------------------------
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.just
          pkgs.nixos-rebuild
        ];
      };
    };
}
