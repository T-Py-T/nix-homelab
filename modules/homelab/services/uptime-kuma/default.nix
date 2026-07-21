{
  config,
  lib,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Uptime Kuma
#
# Self-hosted uptime/status monitoring. Minimal example of the service module
# pattern: enable the upstream NixOS service and register a Caddy vhost.
# ============================================================================
let
  service = "uptime-kuma";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  port = 3011;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "high";

    url = lib.mkOption {
      type = lib.types.str;
      default = "uptime.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Uptime Kuma";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Service monitoring tool";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;
      settings.PORT = toString port;
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString port}
    '';
  };
}
