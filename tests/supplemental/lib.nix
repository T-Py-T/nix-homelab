# Shared helpers for supplemental homelab evaluation checks (standalone from tests/eval).
{
  flake ? builtins.getFlake (toString ../../.),
}:
let
  lib = flake.inputs.nixpkgs.lib;
  pkgs = import flake.inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  homelabModule = flake + "/modules/homelab";

  secretFixtures = {
    grafanaSecretKey = pkgs.writeText "grafana-secret-key" "supplemental-test-grafana-key";
    minifluxAdmin = pkgs.writeText "miniflux-admin.env" ''
      ADMIN_USERNAME=supplemental-test
      ADMIN_PASSWORD=supplemental-test-only
    '';
  };

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
          # ollama-cuda pulls CUDA redistributables; allow for evaluation-only tests.
          nixpkgs.config.allowUnfree = true;
        }
      ]
      ++ modules;
    };

  homelabServiceNames =
    system:
    let
      serviceOpts = system.options.homelab.services;
    in
    builtins.filter (
      name:
      let
        opt = serviceOpts.${name};
      in
      lib.isAttrs opt && !(opt ? _type) && opt ? enable
    ) (builtins.attrNames serviceOpts);

  assert_ = cond: message: if cond then null else throw message;

  profileEnables =
    profile: service:
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.baseDomain = "lab.test";
          homelab.services.enable = true;
          homelab.services.enabledProfiles = [ profile ];
          homelab.services.grafana.secretKeyFile = secretFixtures.grafanaSecretKey;
          homelab.services.miniflux.adminCredentialsFile = secretFixtures.minifluxAdmin;
        }
      ];
    in
    system.config.homelab.services.${service}.enable or false;

in
{
  inherit
    flake
    lib
    pkgs
    homelabModule
    mkHomelab
    homelabServiceNames
    assert_
    secretFixtures
    profileEnables
    ;
}
