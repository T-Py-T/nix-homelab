# Shared helpers for homelab flake checks.
{ pkgs }:
let
  homelabModule = import ../modules/homelab;
in
{
  homelabModule = homelabModule;

  /**
    Evaluate a minimal NixOS configuration with the homelab module and extra modules.
  */
  mkEval =
    {
      system ? pkgs.stdenv.hostPlatform.system,
      modules ? [ ],
    }:
    import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        homelabModule
        {
          nixpkgs.config.allowUnfree = true;
        }
      ]
      ++ modules;
    };

  minifluxCredentials = pkgs.writeText "miniflux-admin-test.env" ''
    ADMIN_USERNAME=vm-test-admin
    ADMIN_PASSWORD=synthetic-test-only-password
  '';

  grafanaSecretKey = pkgs.writeText "grafana-test-secret-key" "synthetic-test-only-grafana-key";
}
