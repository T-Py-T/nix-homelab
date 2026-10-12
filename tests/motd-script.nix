# Syntax-check the generated login MOTD script.
{
  pkgs,
  lib,
}:
let
  inherit (import ./lib.nix { inherit pkgs; }) mkEval minifluxCredentials;

  evaluated = mkEval {
    modules = [
      {
        homelab.enable = true;
        homelab.baseDomain = "test.invalid";
        homelab.motd.enable = true;
        homelab.services.enable = true;
        homelab.services.enabledProfiles = [ ];
        homelab.services.miniflux = {
          enable = true;
          adminCredentialsFile = minifluxCredentials;
        };
      }
    ];
  };

  motdPkg = lib.findFirst (
    p: builtins.pathExists "${p}/bin/motd"
  ) null evaluated.config.environment.systemPackages;
in
assert motdPkg != null;
pkgs.runCommand "motd-script-syntax"
  {
    nativeBuildInputs = [ pkgs.bash ];
  }
  ''
    ${pkgs.bash}/bin/bash -n ${motdPkg}/bin/motd
    touch "$out"
  ''
