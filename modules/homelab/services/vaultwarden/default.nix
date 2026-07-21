{
  config,
  lib,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Vaultwarden
#
# Bitwarden-compatible password manager.
# ============================================================================
let
  service = "vaultwarden";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  addr = "127.0.0.1";
  port = 8222;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "high";

    url = lib.mkOption {
      type = lib.types.str;
      default = "pass.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Vaultwarden";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Password manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      config = {
        DOMAIN = "https://${cfg.url}";
        SIGNUPS_ALLOWED = false;
        ROCKET_ADDRESS = addr;
        ROCKET_PORT = port;
        EXTENDED_LOGGING = true;
        LOG_LEVEL = "warn";
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
    '';
  };
}
