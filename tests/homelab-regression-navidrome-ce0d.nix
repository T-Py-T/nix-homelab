# Regression: Navidrome Caddy upstream must follow services.navidrome.settings.
{
  flake,
  pkgs,
}:
let
  lib = pkgs.lib;
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

  customPort = 14533;
  evaluated = mkHomelab [
    {
      homelab.enable = true;
      homelab.baseDomain = "regression.test";
      homelab.services.enable = true;
      homelab.services.navidrome.enable = true;
      services.navidrome.settings.Port = lib.mkForce customPort;
    }
  ];
  extraConfig = evaluated.config.services.caddy.virtualHosts."music.regression.test".extraConfig;

in
assert assert_
  (
    builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString customPort}.*" extraConfig != null
  )
  "Navidrome Caddy upstream must match services.navidrome.settings.Port (expected ${toString customPort})";
"ok"
