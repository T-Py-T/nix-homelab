# Build the MOTD script for a host running immich, nextcloud, and paperless.
{ }:
let
  flake = builtins.getFlake (toString ../../.);
  inherit (import ./lib.nix { inherit flake; })
    withServices
    motdPackage
    ;

  system =
    withServices [
      {
        homelab.motd.enable = true;
        homelab.services.immich.enable = true;
        homelab.services.nextcloud.enable = true;
        homelab.services.paperless.enable = true;
      }
    ];

  drv = motdPackage system;
in
if drv == null then
  throw "motd package not found in environment.systemPackages"
else
  drv
