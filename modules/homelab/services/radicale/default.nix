{
  config,
  lib,
  pkgs,
  ...
}:
# ============================================================================
# SERVICE: Radicale
#
# CalDAV/CardDAV server.
#
# NOTE: `passwordFile` is an htpasswd file for user auth. It defaults to a
# build-time placeholder (user `admin`, password `changeme`, stored plaintext)
# so the host evaluates - replace it before use.
# ============================================================================
let
  service = "radicale";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  addr = "127.0.0.1:5232";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Free and Open-Source CalDAV and CardDAV Server";

    url = lib.mkOption {
      type = lib.types.str;
      default = "cal.${homelab.baseDomain}";
    };
    passwordFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "radicale.htpasswd" "admin:changeme\n";
      defaultText = lib.literalMD "a build-time placeholder htpasswd - override with a secret!";
      description = "htpasswd file with Radicale user credentials.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Radicale";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Free and Open-Source CalDAV and CardDAV Server";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "radicale.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.radicale.serviceConfig.LoadCredential = "radicale.htpasswd:${cfg.passwordFile}";

    services.radicale = {
      enable = true;
      extraArgs = [
        "--auth-htpasswd-filename=%d/radicale.htpasswd"
        "--auth-htpasswd-encryption=plain"
      ];
      settings = {
        server.hosts = [ addr ];
        storage.filesystem_folder = "/var/lib/radicale/collections";
        auth.type = "htpasswd";
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${builtins.head config.services.radicale.settings.server.hosts}
    '';
  };
}
