{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Immich
#
# Self-hosted photo and video management. Runs as its own `immich` user (the
# NixOS module manages it) but joins the homelab group for media access.
# ============================================================================
let
  service = "immich";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  port = 2283;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Self-hosted photo and video management solution";

    mediaDir = lib.mkOption {
      type = lib.types.path;
      default = "${homelab.mounts.data}/Photos/Immich";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "photos.${homelab.baseDomain}";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "immich-server"
        "immich-machine-learning"
      ];
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Immich";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted photo and video management solution";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "immich.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.mediaDir} 0775 immich ${homelab.group} - -" ];

    users.users.immich.extraGroups = [
      "video"
      "render"
    ];

    services.${service} = {
      enable = true;
      group = homelab.group;
      port = port;
      mediaLocation = cfg.mediaDir;
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${config.services.immich.host}:${toString config.services.immich.port}
    '';
  };
}
