{
  config,
  lib,
  pkgs,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Nextcloud
#
# File storage and collaboration. The NixOS module runs an internal nginx
# (here on 127.0.0.1:8009) which Caddy reverse-proxies to; TLS is terminated
# at Caddy, so `https`/`overwriteprotocol` are set accordingly.
#
# NOTE: `admin.passwordFile` defaults to a build-time placeholder so the host
# evaluates - replace it before use.
# ============================================================================
let
  service = "nextcloud";
  cfg = config.homelab.services.${service};
  hl = config.homelab;
  port = 8009;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "high";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${hl.mounts.data}/Nextcloud";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "cloud.${hl.baseDomain}";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "phpfpm-nextcloud" ];
    };
    admin.username = lib.mkOption {
      type = lib.types.str;
      default = "admin";
    };
    admin.passwordFile = lib.mkOption {
      type = lib.types.str;
      default = toString (pkgs.writeText "nextcloud-admin-password" "changeme");
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "File with the initial Nextcloud admin password.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Nextcloud";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Enterprise File Storage and Collaboration";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0775 nextcloud ${hl.group} - -"
    ];

    services.nginx.virtualHosts."nix-nextcloud".listen = [
      {
        addr = "127.0.0.1";
        inherit port;
      }
    ];

    fileSystems."${config.services.nextcloud.home}/data" = {
      device = cfg.dataDir;
      fsType = "none";
      options = [ "bind" ];
    };

    services.nextcloud = {
      enable = true;
      hostName = "nix-nextcloud";
      package = pkgs.nextcloud33;
      database.createLocally = true;
      configureRedis = true;
      maxUploadSize = "16G";
      https = true;
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        inherit
          calendar
          contacts
          notes
          tasks
          ;
      };
      settings = {
        overwriteprotocol = "https";
        default_phone_region = "US";
      };
      config = {
        dbtype = "pgsql";
        adminuser = cfg.admin.username;
        adminpassFile = cfg.admin.passwordFile;
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${hl.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString port}
    '';
  };
}
