{
  config,
  lib,
  pkgs,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Deluge
#
# BitTorrent client with web UI. Optionally binds the daemon into the
# Wireguard network namespace (see the wireguard-netns service) so torrent
# traffic only ever leaves through the VPN; a socket-activated proxy exposes
# the daemon RPC back on localhost for the web UI.
# ============================================================================
let
  hl = config.homelab;
  cfg = hl.services.deluge;
  ns = hl.services.wireguard-netns.namespace;
  webPort = 8112;
in
{
  options.homelab.services.deluge = {
    enable = lib.mkEnableOption "Deluge torrent client (optionally bound to a Wireguard VPN namespace)";

    importance = homelabLib.mkImportance "low";

    url = lib.mkOption {
      type = lib.types.str;
      default = "deluge.${hl.baseDomain}";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "delugeweb"
        "deluged"
      ];
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Deluge";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Torrent client";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "deluge.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Downloads";
    };
  };

  config = lib.mkIf cfg.enable {
    services.deluge = {
      enable = true;
      user = hl.user;
      group = hl.group;
      web.enable = true;
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${hl.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString webPort}
    '';

    # Route the daemon through the Wireguard namespace when it is enabled.
    systemd = lib.mkIf hl.services.wireguard-netns.enable {
      services.deluged.bindsTo = [ "netns@${ns}.service" ];
      services.deluged.requires = [
        "network-online.target"
        "${ns}.service"
      ];
      services.deluged.serviceConfig.NetworkNamespacePath = [ "/var/run/netns/${ns}" ];
      sockets."deluged-proxy" = {
        enable = true;
        description = "Socket for proxy to the Deluge daemon RPC";
        listenStreams = [ "58846" ];
        wantedBy = [ "sockets.target" ];
      };
      services."deluged-proxy" = {
        enable = true;
        description = "Proxy to the Deluge daemon in the Wireguard namespace";
        requires = [
          "deluged.service"
          "deluged-proxy.socket"
        ];
        after = [
          "deluged.service"
          "deluged-proxy.socket"
        ];
        unitConfig.JoinsNamespaceOf = "deluged.service";
        serviceConfig = {
          User = config.services.deluge.user;
          Group = config.services.deluge.group;
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:58846";
          PrivateNetwork = "yes";
        };
      };
    };
  };
}
