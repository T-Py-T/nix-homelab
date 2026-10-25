# Regression eval checks: *arr Caddy upstream must follow services.*.settings.server.port.
# Run: nix-instantiate --eval --strict tests/homelab-regression-arr-caddy-6d70.nix
let
  flake = builtins.getFlake (toString ./..);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  homelabModule = import ../modules/homelab;

  evalConfig = import (flake.inputs.nixpkgs + "/nixos/lib/eval-config.nix");

  mkHomelab =
    modules:
    evalConfig {
      system = pkgs.system;
      modules = [
        homelabModule
        {
          nixpkgs.hostPlatform = pkgs.system;
        }
      ]
      ++ modules;
    };

  assert_ = cond: message: if cond then true else throw message;

  checkArrCaddy =
    service: customPort:
    let
      evaluated = mkHomelab [
        {
          homelab.enable = true;
          homelab.baseDomain = "regression.test";
          homelab.services.enable = true;
          homelab.services.${service}.enable = true;
          services.${service}.settings.server.port = customPort;
        }
      ];
      extraConfig = evaluated.config.services.caddy.virtualHosts."${service}.regression.test".extraConfig;
    in
    assert_
      (
        builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString customPort}.*" extraConfig != null
      )
      "${service} Caddy upstream must match services.${service}.settings.server.port (expected ${toString customPort})";

in
assert checkArrCaddy "radarr" 17878;
assert checkArrCaddy "lidarr" 18686;
assert checkArrCaddy "prowlarr" 19696;
"ok"
