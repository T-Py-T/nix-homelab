{ lib, config, ... }:
# ============================================================================
# HOMELAB CORE MODULE
#
# Defines the top-level `homelab.*` option namespace and the settings shared
# by every service (the service user/group, base domain, timezone, storage
# mount points). Individual services live under ./services and hang their own
# options off `homelab.services.<name>`; GPU support lives under ./gpu.
# ============================================================================
let
  cfg = config.homelab;
in
{
  imports = [
    ./services
    ./gpu
    ./motd
  ];

  options.homelab = {
    enable = lib.mkEnableOption "the homelab services and shared configuration";

    baseDomain = lib.mkOption {
      type = lib.types.str;
      default = "home.lan";
      description = ''
        Base domain that services are exposed under via the Caddy reverse
        proxy, e.g. `grafana.<baseDomain>`.
      '';
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "America/New_York";
      description = "Time zone used for the homelab services.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "share";
      description = "User the homelab services run as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "share";
      description = "Group the homelab services run as.";
    };

    mounts.config = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/homelab";
      description = "Base path for persistent service configuration/state.";
    };

    mounts.data = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/data";
      description = "Base path for bulk service data (media, backups, etc.).";
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = cfg.timeZone;

    users = {
      groups.${cfg.group} = {
        gid = lib.mkDefault 993;
      };
      users.${cfg.user} = {
        uid = lib.mkDefault 994;
        isSystemUser = true;
        group = cfg.group;
      };
    };
  };
}
