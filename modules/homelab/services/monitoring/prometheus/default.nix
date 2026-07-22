{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Prometheus
#
# Metrics collection + time-series database. Scrape targets are supplied per
# host via `homelab.services.prometheus.scrapeTargets`.
# ============================================================================
let
  service = "prometheus";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  prometheusUrl = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "prometheus.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
    };
    scrapeTargets = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Prometheus scrape_configs entries.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Prometheus";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Monitoring system & time series database";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "prometheus.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = cfg.listenAddress;
      port = cfg.port;
      globalConfig.scrape_interval = "15s";
      scrapeConfigs = cfg.scrapeTargets;
    };

    # Auto-register Prometheus as a Grafana datasource when Grafana is present.
    services.grafana.provision.datasources.settings.datasources =
      lib.mkIf config.services.grafana.enable
        [
          {
            name = "Prometheus";
            type = "prometheus";
            url = prometheusUrl;
            isDefault = true;
            editable = false;
          }
        ];

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy ${prometheusUrl}
    '';
  };
}
