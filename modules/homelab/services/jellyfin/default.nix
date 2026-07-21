{
  config,
  lib,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Jellyfin
#
# Free software media system. Runs as the shared homelab user/group so it can
# read the media library.
# ============================================================================
let
  service = "jellyfin";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  port = 8096;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "medium";

    url = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Jellyfin";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "The Free Software Media System";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      user = homelab.user;
      group = homelab.group;
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString port}
    '';
  };
}
