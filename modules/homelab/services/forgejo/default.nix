{
  lib,
  config,
  ...
}:
# ============================================================================
# SERVICE: Forgejo
#
# Self-hosted Git forge (the successor to Gitea). Backed by SQLite for a
# zero-dependency single-node setup; switch `database.type` to "postgres" if
# you add a database.
# ============================================================================
let
  service = "forgejo";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  addr = "127.0.0.1";
  port = 3001;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "git.${homelab.baseDomain}";
    };
    appName = lib.mkOption {
      type = lib.types.str;
      default = "Homelab Git";
    };
    disableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Forgejo";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "A painless, self-hosted Git service";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "forgejo.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh.settings.AcceptEnv = [ "GIT_PROTOCOL" ];

    services.forgejo = {
      enable = true;
      database.type = "sqlite3";
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = cfg.url;
          ROOT_URL = "https://${cfg.url}/";
          HTTP_ADDR = addr;
          HTTP_PORT = port;
          SSH_PORT = lib.head config.services.openssh.ports;
        };
        service = {
          DISABLE_REGISTRATION = cfg.disableRegistration;
          REQUIRE_SIGNIN_VIEW = false;
        };
        repository = {
          DEFAULT_BRANCH = "main";
        };
        # Nightly database dump for backups.
        dump = {
          ENABLED = true;
          SCHEDULE = "@midnight";
          RETENTION_DAYS = 7;
        };
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
      request_body {
        max_size 10GB
      }
    '';
  };
}
