{
  pkgs,
  config,
  lib,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Wireguard network namespace
#
# Creates an isolated network namespace whose only route is through a Wireguard
# tunnel. Other services (Deluge, slskd) can be bound into it so their traffic
# only ever leaves via the VPN.
#
# This is infrastructure, not a web service, so it has no homepage entry.
#
# NOTE: `configFile`/`privateIP`/`dnsIP` default to placeholders so the host
# evaluates - set real values before enabling.
# ============================================================================
let
  homelab = config.homelab;
  cfg = homelab.services.wireguard-netns;
in
{
  options.homelab.services.wireguard-netns = {
    enable = lib.mkEnableOption "Wireguard client network namespace";

    importance = homelabLib.mkImportance "low";

    namespace = lib.mkOption {
      type = lib.types.str;
      default = "wg_client";
      description = "Name of the network namespace to create.";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ cfg.namespace ];
    };
    configFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "wg0.conf" ''
        [Interface]
        PrivateKey = 0000000000000000000000000000000000000000000=

        [Peer]
        PublicKey = 0000000000000000000000000000000000000000000=
        Endpoint = 127.0.0.1:51820
        AllowedIPs = 0.0.0.0/0
      '';
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "Wireguard config file (a plain `wg setconf` file, not wg-quick).";
    };
    privateIP = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.2/32";
      description = "Address assigned to the wg0 interface inside the namespace.";
    };
    dnsIP = lib.mkOption {
      type = lib.types.str;
      default = "9.9.9.9";
      description = "DNS server used inside the namespace.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services."netns@" = {
      description = "%I network namespace";
      before = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.iproute2}/bin/ip netns add %I";
        ExecStop = "${pkgs.iproute2}/bin/ip netns del %I";
      };
    };

    environment.etc."netns/${cfg.namespace}/resolv.conf".text = "nameserver ${cfg.dnsIP}";

    systemd.services.${cfg.namespace} = {
      description = "${cfg.namespace} network interface";
      bindsTo = [ "netns@${cfg.namespace}.service" ];
      requires = [ "network-online.target" ];
      after = [ "netns@${cfg.namespace}.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart =
          with pkgs;
          writers.writeBash "wg-up" ''
            set -e
            ${iproute2}/bin/ip link add wg0 type wireguard
            ${iproute2}/bin/ip link set wg0 netns ${cfg.namespace}
            ${iproute2}/bin/ip -n ${cfg.namespace} address add ${cfg.privateIP} dev wg0
            ${iproute2}/bin/ip netns exec ${cfg.namespace} \
              ${wireguard-tools}/bin/wg setconf wg0 ${cfg.configFile}
            ${iproute2}/bin/ip -n ${cfg.namespace} link set wg0 up
            ${iproute2}/bin/ip -n ${cfg.namespace} link set lo up
            ${iproute2}/bin/ip -n ${cfg.namespace} route add default dev wg0
          '';
        ExecStop =
          with pkgs;
          writers.writeBash "wg-down" ''
            set -e
            ${iproute2}/bin/ip -n ${cfg.namespace} route del default dev wg0
            ${iproute2}/bin/ip -n ${cfg.namespace} link del wg0
          '';
      };
    };
  };
}
