# Shared helpers for pure evaluation checks against the homelab flake.
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
        inputs = flake.inputs;
      };
      modules = [
        homelabModule
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          nixpkgs.config.allowUnfree = true;
        }
      ]
      ++ modules;
    };

  withServices =
    extra:
    mkHomelab (
      [
        {
          homelab.enable = true;
          homelab.baseDomain = "module-eval.test";
          homelab.services.enable = true;
        }
      ]
      ++ extra
    );

  assert_ = cond: message: if cond then null else throw message;

  caddyExtraConfig =
    system: host:
    system.config.services.caddy.virtualHosts.${host}.extraConfig or "";

  expectsCaddyReverseProxy =
    service: extraModules:
    let
      system = withServices (
        [
          {
            homelab.services.${service}.enable = true;
          }
        ]
        ++ extraModules
      );
      url = system.config.homelab.services.${service}.url;
      extra = caddyExtraConfig system url;
    in
    assert_ (
      lib.hasInfix "reverse_proxy" extra
        && lib.hasInfix "tls internal" extra
    ) "${service} should register a Caddy vhost with internal TLS and reverse_proxy";

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
    caddyExtraConfig
    expectsCaddyReverseProxy
    ;
}
