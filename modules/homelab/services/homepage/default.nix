{
  config,
  lib,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Homepage dashboard
#
# A single landing page that automatically lists every enabled homelab
# service, grouped by the `homepage.category` each service declares. Adding a
# new service with homepage metadata makes it show up here with no extra work.
# ============================================================================
let
  service = "homepage-dashboard";
  cfg = config.homelab.services.homepage;
  homelab = config.homelab;
  hl = config.homelab.services;

  # Categories rendered on the dashboard, in display order.
  categories = [
    "Observability"
    "Media"
    "Downloads"
    "Services"
  ];

  # All enabled services that declare homepage metadata for a given category.
  servicesInCategory =
    category:
    lib.attrsets.filterAttrs (
      _name: value:
      lib.isAttrs value && (value.enable or false) && value ? homepage && value.homepage.category == category
    ) hl;
in
{
  options.homelab.services.homepage = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "high";

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = homelab.baseDomain;
      description = "Homepage is served at the bare base domain by default.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.listenPort;
      environmentFiles = [
        (builtins.toFile "homepage.env" "HOMEPAGE_ALLOWED_HOSTS=${cfg.url}")
      ];

      settings = {
        title = "Homelab";
        headerStyle = "clean";
        statusStyle = "dot";
        hideVersion = true;
      };

      services = lib.lists.forEach categories (
        category:
        let
          entries = servicesInCategory category;
        in
        {
          "${category}" = lib.attrsets.mapAttrsToList (name: _: {
            "${hl.${name}.homepage.name}" = {
              icon = hl.${name}.homepage.icon;
              description = hl.${name}.homepage.description;
              href = "https://${hl.${name}.url}";
              siteMonitor = "https://${hl.${name}.url}";
            };
          }) entries;
        }
      );
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString cfg.listenPort}
    '';
  };
}
