# Smoke-evaluate NixOS host configurations for the building system.
{
  pkgs,
  lib,
  nixosConfigurations,
  system,
}:
let
  hostsForSystem = lib.filter (
    host: nixosConfigurations.${host}.pkgs.stdenv.hostPlatform.system == system
  ) (builtins.attrNames nixosConfigurations);

  summaries = lib.map (
    host:
    let
      cfg = nixosConfigurations.${host}.config;
    in
    "${host}=${cfg.networking.hostName}@${cfg.nixpkgs.hostPlatform.system}"
  ) hostsForSystem;
in
pkgs.writeTextFile {
  name = "nixos-host-eval-smoke-${system}";
  text = lib.concatStringsSep "\n" summaries + "\n";
}
