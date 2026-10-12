# Regression: Uptime Kuma Caddy upstream must follow services.uptime-kuma.settings.PORT.
{
  flake,
  pkgs,
}:
let
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

  customPort = 3999;
  evaluated = mkHomelab [
    {
      homelab.enable = true;
      homelab.baseDomain = "regression.test";
      homelab.services.enable = true;
      homelab.services.uptime-kuma = {
        enable = true;
        listenPort = customPort;
      };
    }
  ];
  extraConfig = evaluated.config.services.caddy.virtualHosts."uptime.regression.test".extraConfig;

in
assert assert_
  (
    builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString customPort}.*" extraConfig != null
  )
  "Uptime Kuma Caddy upstream must match homelab.services.uptime-kuma.listenPort (expected ${toString customPort})";
"ok"
