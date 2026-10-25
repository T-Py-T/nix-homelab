# Shared helpers for regression evaluation checks against this flake.
{
  flake ? builtins.getFlake (toString ../../.),
}:
let
  lib = flake.inputs.nixpkgs.lib;
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  homelabModule = flake + "/modules/homelab";

  mkHomelab =
    modules:
    lib.nixosSystem {
      specialArgs = {
        inherit pkgs;
        inputs = flake.inputs;
      };
      modules = [
        homelabModule
        {
          nixpkgs.hostPlatform = "x86_64-linux";
        }
      ]
      ++ modules;
    };

  secretFixtures = {
    grafanaSecretKey = pkgs.writeText "grafana-test-secret-key" "synthetic-test-only-grafana-key";
    minifluxCredentials = pkgs.writeText "miniflux-admin-test.env" ''
      ADMIN_USERNAME=regression-test-admin
      ADMIN_PASSWORD=synthetic-test-only-password
    '';
    matrixRegistration = pkgs.writeText "matrix-registration-secret.yaml" ''
      registration_shared_secret: "changeme-changeme-changeme"
    '';
  };

  assert_ = cond: message: if cond then null else throw message;

in
{
  inherit
    flake
    lib
    pkgs
    homelabModule
    mkHomelab
    secretFixtures
    assert_
    ;
}
