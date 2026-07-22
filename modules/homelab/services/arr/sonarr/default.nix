{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Sonarr
#
# TV show collection manager for the *arr stack.
# ============================================================================
let
  service = "sonarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  port = 8989;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Sonarr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "TV show collection manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "sonarr.svg";
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
