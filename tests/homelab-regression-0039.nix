# Regression eval checks for MOTD systemd unit names and Immich Caddy upstream.
{
  pkgs,
  lib,
  flake,
}:
let
  alison = flake.nixosConfigurations.alison.config;
  systemdUnits = builtins.attrNames alison.systemd.services;

  nonServiceKeys = [
    "enable"
    "profiles"
    "enabledProfiles"
  ];

  systemdUnitAliases = {
    homepage = [ "homepage-dashboard" ];
    homeassistant = [ "podman-homeassistant" ];
    jellyseerr = [ "seerr" ];
    node-exporter = [ "prometheus-node-exporter" ];
    raspberrymatic = [ "podman-ccu" ];
  };

  enabledHomelabServices = builtins.filter (
    name:
    let
      value = alison.homelab.services.${name};
    in
    !(builtins.elem name nonServiceKeys) && lib.isAttrs value && value ? enable && value.enable
  ) (builtins.attrNames alison.homelab.services);

  motdMonitoredUnits = lib.concatLists (
    map (
      name:
      let
        svc = alison.homelab.services.${name};
      in
      if svc ? monitoredServices then svc.monitoredServices else systemdUnitAliases.${name} or [ name ]
    ) enabledHomelabServices
  );

  missingMotdUnits = builtins.filter (unit: !(builtins.elem unit systemdUnits)) motdMonitoredUnits;

  immichUrl = alison.homelab.services.immich.url;
  immichCaddy = alison.services.caddy.virtualHosts.${immichUrl}.extraConfig or "";

  ok =
    lib.assertMsg (missingMotdUnits == [ ]) (
      "MOTD references systemd units that are not defined on alison: ${toString missingMotdUnits}"
    )
    && lib.assertMsg (
      builtins.match ".*reverse_proxy http://127\\.0\\.0\\.1:2283.*" immichCaddy != null
    ) "Immich Caddy vhost must reverse-proxy to 127.0.0.1:2283 (got: ${immichCaddy})";
in
assert ok;
pkgs.writeText "homelab-regression-0039-ok" "ok\n"
