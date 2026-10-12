{
  config,
  lib,
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
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 3011;
      description = "TCP port for the Uptime Kuma web UI (also used for the Caddy upstream).";
    };

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
      settings.PORT = toString cfg.listenPort;
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${config.services.uptime-kuma.settings.PORT}
    '';
  };
}
