{
  config,
  lib,
  pkgs,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Grafana
#
# Dashboards for the metrics collected by Prometheus. The Prometheus module
# auto-provisions itself as the default datasource when both are enabled.
#
# NOTE: nixpkgs requires `security.secret_key` to be set via a file provider.
# A build-time placeholder is generated here so the host evaluates and boots
# out of the box - override `secretKeyFile` with a real secret (e.g. agenix)
# before exposing Grafana.
# ============================================================================
let
  service = "grafana";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  addr = "127.0.0.1";
  port = 3000;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "high";

    url = lib.mkOption {
      type = lib.types.str;
      default = "grafana.${homelab.baseDomain}";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "grafana-secret-key" "CHANGEME_generate_a_real_grafana_secret_key";
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "File containing Grafana's `security.secret_key`.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Grafana";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Platform for data analytics and monitoring";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "grafana.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
  };

  config = lib.mkIf cfg.enable {
    services.grafana = {
      enable = true;
      provision.enable = true;
      settings = {
        security.secret_key = "$__file{${cfg.secretKeyFile}}";
        server = {
          http_addr = addr;
          http_port = port;
          domain = cfg.url;
          root_url = "https://${cfg.url}/";
        };
        # Anonymous read-only access; tighten this once you add real auth.
        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
    '';
  };
}
