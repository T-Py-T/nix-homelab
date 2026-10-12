# Builds the generated MOTD script for a tiny homelab config (fast derivation).
let
  flake = builtins.getFlake (toString ../../.);
  inherit (import ./lib.nix { inherit flake; }) mkHomelab lib;
  system = mkHomelab [
    {
      homelab.enable = true;
      homelab.motd.enable = true;
      homelab.services.deluge.enable = true;
    }
  ];
  motdPkg = lib.findFirst (
    drv: (drv.meta.mainProgram or "") == "motd" || drv.pname == "motd"
  ) null system.config.environment.systemPackages;
in
if motdPkg == null then throw "motd package not found in environment.systemPackages" else motdPkg
