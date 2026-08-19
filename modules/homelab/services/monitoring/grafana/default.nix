{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Grafana
#
# Dashboards for the metrics collected by Prometheus. The Prometheus module
# auto-provisions itself as the default datasource when both are enabled.
#
# NOTE: `secretKeyFile` must point to a file provisioned outside the Nix store,
# for example by a secret manager such as agenix or sops-nix.
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

    url = lib.mkOption {
      type = lib.types.str;
      default = "grafana.${homelab.baseDomain}";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/grafana-secret-key";
      description = ''
        Runtime file containing Grafana's `security.secret_key`. The file must
        be provisioned separately and must not be stored in the Nix store.
      '';
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
    assertions = [
      {
        assertion = cfg.secretKeyFile != null;
        message = "homelab.services.grafana.secretKeyFile must be set when Grafana is enabled";
      }
    ];

    services.grafana = {
      enable = true;
      provision.enable = true;
      settings = {
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
      }
      // lib.optionalAttrs (cfg.secretKeyFile != null) {
        security.secret_key = "$__file{${cfg.secretKeyFile}}";
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
    '';
  };
}
