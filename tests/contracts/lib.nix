# Shared helpers for pure evaluation contract checks against this flake.
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

  withServices =
    modules:
    mkHomelab (
      [
        {
          homelab.enable = true;
          homelab.baseDomain = "contracts.test";
          homelab.services.enable = true;
        }
      ]
      ++ modules
    );

  assert_ = cond: message: if cond then null else throw message;

  secretFixtures = {
    grafanaSecretKey = pkgs.writeText "grafana-secret-key" "synthetic-contract-test-key";
    slskdEnv = pkgs.writeText "slskd-env" ''
      SLSKD_USERNAME=slskd
      SLSKD_PASSWORD=changeme
      SLSKD_JWT=changemechangemechangemechangeme
    '';
  };

  caddyVhost =
    system: url:
    system.config.services.caddy.virtualHosts.${url} or null;

  expectsCaddyReverseProxy =
    service: extraModules:
    let
      system = withServices (
        extraModules
        ++ [
          {
            homelab.services.${service}.enable = true;
          }
        ]
      );
      url = system.config.homelab.services.${service}.url;
      vhost = caddyVhost system url;
    in
    assert_ (
      vhost != null
      && lib.hasInfix "tls internal" (vhost.extraConfig or "")
      && lib.hasInfix "reverse_proxy" (vhost.extraConfig or "")
    ) "${service} should expose ${url} via Caddy with internal TLS and reverse_proxy";

  motdPackage =
    system:
    lib.findFirst (drv: (drv.pname or drv.name or "") == "motd") (_: null) system.config.environment.systemPackages;

in
{
  inherit
    flake
    lib
    pkgs
    homelabModule
    mkHomelab
    withServices
    assert_
    secretFixtures
    caddyVhost
    expectsCaddyReverseProxy
    motdPackage
    ;
}
