{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Miniflux
#
# Minimalist RSS/Atom feed reader (the modern replacement for the old FreshRSS
# module). Uses a local PostgreSQL database provisioned by the NixOS module.
#
# NOTE: `adminCredentialsFile` must point to a file provisioned outside the
# Nix store, for example by a secret manager such as agenix or sops-nix.
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

    url = lib.mkOption {
      type = lib.types.str;
      default = "rss.${homelab.baseDomain}";
    };
    adminCredentialsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/miniflux-admin.env";
      description = ''
        Runtime EnvironmentFile containing ADMIN_USERNAME and ADMIN_PASSWORD.
        The file must be provisioned separately and must not be stored in the
        Nix store.
      '';
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
    assertions = [
      {
        assertion = cfg.adminCredentialsFile != null;
        message = "homelab.services.miniflux.adminCredentialsFile must be set when Miniflux is enabled";
      }
    ];

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
