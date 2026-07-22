{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Microbin
#
# Minimal pastebin/file-sharing service.
#
# The reference bundles custom Nord-theme highlight.js assets and an
# oauth2-proxy forward-auth in front; both are dropped here to keep the module
# self-contained. `passwordFile` (optional) enables admin/uploader auth.
# ============================================================================
let
  service = "microbin";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  addr = "127.0.0.1";
  port = 8069;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "bin.${homelab.baseDomain}";
    };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''
        pkgs.writeText "microbin-secret.txt" '''
          MICROBIN_ADMIN_USERNAME=admin
          MICROBIN_ADMIN_PASSWORD=changeme
          MICROBIN_UPLOADER_PASSWORD=changeme
        '''
      '';
      description = "EnvironmentFile with MICROBIN_* admin/uploader credentials.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Microbin";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "A minimal pastebin";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "microbin.png";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      passwordFile = lib.mkIf (cfg.passwordFile != null) cfg.passwordFile;
      settings = {
        MICROBIN_WIDE = true;
        MICROBIN_MAX_FILE_SIZE_UNENCRYPTED_MB = 2048;
        MICROBIN_PUBLIC_PATH = "https://${cfg.url}/";
        MICROBIN_BIND = addr;
        MICROBIN_PORT = port;
        MICROBIN_HIDE_LOGO = true;
        MICROBIN_HIGHLIGHTSYNTAX = true;
        MICROBIN_HIDE_HEADER = true;
        MICROBIN_HIDE_FOOTER = true;
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
    '';
  };
}
