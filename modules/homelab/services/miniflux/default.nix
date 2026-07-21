{
  config,
  lib,
  pkgs,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Miniflux
#
# Minimalist RSS/Atom feed reader (the modern replacement for the old FreshRSS
# module). Uses a local PostgreSQL database provisioned by the NixOS module.
#
# NOTE: `adminCredentialsFile` should be provided via a secret manager (e.g.
# agenix) in production. A build-time placeholder is generated here so the
# host evaluates and boots out of the box - CHANGE THIS before exposing it.
# ============================================================================
let
  service = "miniflux";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  addr = "127.0.0.1";
  port = 8067;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "medium";

    url = lib.mkOption {
      type = lib.types.str;
      default = "rss.${homelab.baseDomain}";
    };
    adminCredentialsFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "miniflux-admin.env" ''
        ADMIN_USERNAME=admin
        ADMIN_PASSWORD=changeme
      '';
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "EnvironmentFile with ADMIN_USERNAME and ADMIN_PASSWORD.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Miniflux";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Minimalist and opinionated feed reader";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "miniflux-light.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      adminCredentialsFile = cfg.adminCredentialsFile;
      config = {
        BASE_URL = "https://${cfg.url}";
        CREATE_ADMIN = 1;
        LISTEN_ADDR = "${addr}:${toString port}";
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
    '';
  };
}
