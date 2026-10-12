# Regression eval checks for Attic/SABnzbd port separation and Sonarr Caddy upstream.
# Run: nix-instantiate --eval --strict tests/homelab-regression-7764.nix
let
  flake = builtins.getFlake (toString ./..);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  homelabModule = import ../modules/homelab;

  evalConfig = import (flake.inputs.nixpkgs + "/nixos/lib/eval-config.nix");

  mkHomelab =
    modules:
    evalConfig {
      system = pkgs.system;
      specialArgs = {
        inherit pkgs;
        inputs = flake.inputs;
      };
      modules = [
        homelabModule
        {
          nixpkgs.hostPlatform = pkgs.system;
        }
      ]
      ++ modules;
    };

  assert_ = cond: message: if cond then true else throw message;

  alison = flake.nixosConfigurations.alison.config;

  atticSabnzbdPortsDistinct =
    let
      sabnzbdEnabled = alison.homelab.services.sabnzbd.enable;
      runnerEnabled = alison.homelab.services.forgejo-runner.enable;
      atticListen = alison.services.atticd.settings.listen;
      sabnzbdCaddy =
        alison.services.caddy.virtualHosts."sabnzbd.${alison.homelab.baseDomain}".extraConfig;
      cacheCaddy = alison.services.caddy.virtualHosts."cache.${alison.homelab.baseDomain}".extraConfig;
    in
    assert_ (
      sabnzbdEnabled
      && runnerEnabled
      && atticListen != "127.0.0.1:8080"
      && builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:8080.*" sabnzbdCaddy != null
      && builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:8088.*" cacheCaddy != null
    ) "atticd and SABnzbd must use distinct localhost ports (attic=${atticListen})";

  sonarrCaddyFollowsConfiguredPort =
    let
      customPort = 18989;
      evaluated = mkHomelab [
        {
          homelab.enable = true;
          homelab.baseDomain = "regression.test";
          homelab.services.enable = true;
          homelab.services.sonarr.enable = true;
          services.sonarr.settings.server.port = customPort;
        }
      ];
      extraConfig = evaluated.config.services.caddy.virtualHosts."sonarr.regression.test".extraConfig;
    in
    assert_
      (
        builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:${toString customPort}.*" extraConfig != null
      )
      "Sonarr Caddy upstream must match services.sonarr.settings.server.port (expected ${toString customPort})";

in
assert atticSabnzbdPortsDistinct;
assert sonarrCaddyFollowsConfiguredPort;
"ok"
