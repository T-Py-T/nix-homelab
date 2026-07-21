{
  config,
  lib,
  pkgs,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Paperless-ngx
#
# Document management system with OCR.
#
# NOTE: `passwordFile` sets the initial admin password. It defaults to a
# build-time placeholder so the host evaluates - replace it before use.
# ============================================================================
let
  service = "paperless";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "high";

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.data}/Documents/Paperless/Documents";
    };
    consumptionDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.data}/Documents/Paperless/Import";
    };
    passwordFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "paperless-admin-password" "changeme";
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "File with the initial Paperless admin password.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "paperless.${homelab.baseDomain}";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "paperless-consumer"
        "paperless-scheduler"
        "paperless-task-queue"
        "paperless-web"
      ];
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Paperless-ngx";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Document management system";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "paperless.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      passwordFile = cfg.passwordFile;
      user = homelab.user;
      mediaDir = cfg.mediaDir;
      consumptionDir = cfg.consumptionDir;
      consumptionDirIsPublic = true;
      settings = {
        PAPERLESS_URL = "https://${cfg.url}";
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_OCR_USER_ARGS = {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString config.services.${service}.port}
    '';
  };
}
