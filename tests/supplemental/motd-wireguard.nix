# Build the MOTD derivation for a host with wireguard-netns enabled.
{ }:
let
  flake = builtins.getFlake (toString ../../.);
  inherit (import ./lib.nix { inherit flake; }) mkHomelab lib;
  system = mkHomelab [
    {
      homelab.enable = true;
      homelab.motd.enable = true;
      homelab.services.enable = true;
      homelab.services.enabledProfiles = [ "net" ];
    }
  ];
  motdDrv = lib.findFirst (drv: (drv.name or "") == "motd") (
    _x: null
  ) system.config.environment.systemPackages;
in
if motdDrv == null then throw "motd package not found in environment.systemPackages" else motdDrv
