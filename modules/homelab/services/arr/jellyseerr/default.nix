{
  pkgs,
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Jellyseerr
#
# Media request and discovery manager. Upstream is packaged as `services.seerr`
# in current nixpkgs (the jellyseerr/overseerr fork), with the `seerr` package.
# ============================================================================
let
  service = "jellyseerr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
    };
    package = lib.mkPackageOption pkgs "seerr" { };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Jellyseerr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Media request and discovery manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "jellyseerr.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
    };
  };

  config = lib.mkIf cfg.enable {
    services.seerr = {
      enable = true;
      port = cfg.port;
      package = cfg.package;
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };
}
