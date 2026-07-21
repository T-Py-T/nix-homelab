{
  config,
  lib,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: SABnzbd
#
# Usenet binary downloader.
# ============================================================================
let
  service = "sabnzbd";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  port = 8080;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "low";

    url = lib.mkOption {
      type = lib.types.str;
      default = "sabnzbd.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "SABnzbd";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "The free and easy binary newsreader";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "sabnzbd.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Downloads";
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
