{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Prometheus Node Exporter
#
# Host-level metrics (CPU, memory, disk, network). Not proxied - Prometheus
# scrapes it directly on the metrics port.
# ============================================================================
let
  service = "node-exporter";
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9100;
      description = "Port the node exporter listens on.";
    };

    enabledCollectors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "systemd"
        "textfile"
        "filesystem"
        "loadavg"
        "meminfo"
        "netdev"
        "stat"
      ];
      description = "Collectors to enable.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      port = cfg.port;
      enabledCollectors = cfg.enabledCollectors;
    };
  };
}
