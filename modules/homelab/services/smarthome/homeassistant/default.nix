{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Home Assistant
#
# Home automation platform, run as an OCI container via podman (matches the
# reference, which uses the official image for full add-on support).
# ============================================================================
let
  service = "homeassistant";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  port = 8123;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable Home Assistant";

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.config}/homeassistant";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "home.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Home Assistant";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Home automation platform";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "home-assistant.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Smart Home";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.configDir} 0775 ${homelab.user} ${homelab.group} - -" ];

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString port}
    '';

    virtualisation = {
      podman.enable = true;
      oci-containers.containers.homeassistant = {
        image = "homeassistant/home-assistant:stable";
        autoStart = true;
        extraOptions = [ "--pull=newer" ];
        volumes = [ "${cfg.configDir}:/config" ];
        ports = [
          "127.0.0.1:${toString port}:8123"
          "127.0.0.1:8124:80"
        ];
        environment = {
          TZ = homelab.timeZone;
          PUID = toString config.users.users.${homelab.user}.uid;
          PGID = toString config.users.groups.${homelab.group}.gid;
        };
      };
    };
  };
}
