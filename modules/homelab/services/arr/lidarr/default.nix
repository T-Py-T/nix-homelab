{
  config,
  lib,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Lidarr
#
# Music collection manager for the *arr stack.
# ============================================================================
let
  service = "lidarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  port = 8686;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "low";

    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Lidarr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Music collection manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "lidarr.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
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
