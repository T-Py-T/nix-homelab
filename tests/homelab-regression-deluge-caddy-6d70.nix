# Regression eval check: Deluge Caddy upstream must follow services.deluge.web.port.
# Run: nix-instantiate --eval --strict tests/homelab-regression-deluge-caddy-6d70.nix
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

  customPort = 18112;
  evaluated = mkHomelab [
    {
      homelab.enable = true;
      homelab.baseDomain = "regression.test";
      homelab.services.enable = true;
      homelab.services.deluge.enable = true;
      services.deluge.web.port = customPort;
    }
  ];
  extraConfig = evaluated.config.services.caddy.virtualHosts."deluge.regression.test".extraConfig;
in
assert (
  assert_ (
    builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString customPort}.*" extraConfig != null
  ) "Deluge Caddy upstream must match services.deluge.web.port (expected ${toString customPort})"
);
"ok"
