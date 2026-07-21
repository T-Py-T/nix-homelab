{ lib, config, ... }:
# ============================================================================
# HOMELAB CORE MODULE
#
# Defines the top-level `homelab.*` option namespace and the settings shared
# by every service (the service user/group, base domain, timezone, storage
# mount points). Individual services live under ./services and hang their own
# options off `homelab.services.<name>`.
# ============================================================================
let
  cfg = config.homelab;

  # --------------------------------------------------------------------------
  # IMPORTANCE TIERS
  #
  # Every service declares an `importance` tier. A host then opts a set of
  # tiers in via `homelab.services.enabledTiers`, and every service in those
  # tiers turns on automatically (an explicit `<service>.enable` on the host
  # still wins). This is what lets us run everything on one box today and, as
  # more machines come online, split the fleet by criticality / load simply by
  # handing different tiers to different hosts.
  # --------------------------------------------------------------------------
  tiers = [
    "high"
    "medium"
    "low"
  ];

  # Injected into every homelab submodule via `_module.args` so service
  # modules can call `homelabLib.mkImportance "high"` without an import.
  homelabLib = {
    inherit tiers;

    mkImportance =
      default:
      lib.mkOption {
        type = lib.types.enum tiers;
        inherit default;
        description = ''
          Criticality tier for this service. A host enables whole tiers via
          `homelab.services.enabledTiers`; every service in an enabled tier is
          switched on unless its `enable` is set explicitly on the host.
        '';
      };
  };
in
{
  imports = [
    ./services
    ./motd
  ];

  _module.args.homelabLib = homelabLib;

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
