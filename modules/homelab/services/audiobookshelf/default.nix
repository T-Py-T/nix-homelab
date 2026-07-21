{
  config,
  lib,
  homelabLib,
  ...
}:
# ============================================================================
# SERVICE: Audiobookshelf
#
# Audiobook and podcast server.
# ============================================================================
let
  service = "audiobookshelf";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  port = 8113;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    importance = homelabLib.mkImportance "medium";

    url = lib.mkOption {
      type = lib.types.str;
      default = "audiobooks.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Audiobookshelf";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Audiobook and podcast player";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "audiobookshelf.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      user = homelab.user;
      group = homelab.group;
      port = port;
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString config.services.${service}.port}
    '';
  };
}
