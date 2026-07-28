{
  config,
  lib,
  pkgs,
  ...
}:
# ============================================================================
# SERVICE: Komodo
#
# Open-source alternative to Portainer for building and deploying software:
# manage Docker Compose stacks, containers, and builds across servers. Modelled
# on Komodo's official Mongo compose (https://komo.do):
#   * komodo-mongo  - MongoDB, the Core database (Komodo needs a Mongo-compatible DB)
#   * komodo-core   - the web UI + API (container), reverse-proxied at komodo.<domain>
#   * Periphery     - the agent that drives this host's containers (native nixpkgs module)
#
# Forgejo integration: Komodo can version-control Stacks/Syncs in a git repo and
# auto-deploy on push. Git providers can ONLY be set in the Core config file
# (not via env), so a `[[git_provider]]` block for the homelab Forgejo is mounted
# into Core below.
#
# NOTE: secrets here are inline build-time PLACEHOLDERS (like the rest of this
# repo, pending agenix) - change them before exposing. Pairing Core <-> Periphery
# (adding this host as a Server) and creating the `komodo` Forgejo account/token
# are runtime steps done in the Komodo UI / Forgejo after first deploy.
# ============================================================================
let
  service = "komodo";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  hl = config.homelab.services;
  corePort = 9120;
  network = "komodo";

  # --- Placeholder secrets - CHANGE before exposing (agenix is the follow-up) ---
  mongoUser = "komodo";
  mongoPassword = "changeme_mongo_password";
  sharedPasskey = "changeme_core_periphery_passkey";

  mongoEnv = pkgs.writeText "komodo-mongo.env" ''
    MONGO_INITDB_ROOT_USERNAME=${mongoUser}
    MONGO_INITDB_ROOT_PASSWORD=${mongoPassword}
  '';

  coreEnv = pkgs.writeText "komodo-core.env" ''
    KOMODO_DATABASE_USERNAME=${mongoUser}
    KOMODO_DATABASE_PASSWORD=${mongoPassword}
    KOMODO_PASSKEY=${sharedPasskey}
    KOMODO_INIT_ADMIN_USERNAME=admin
    KOMODO_INIT_ADMIN_PASSWORD=changeme_admin_password
  '';

  peripheryPasskey = pkgs.writeText "komodo-passkey" sharedPasskey;

  # Core config file - git providers CANNOT be set via env, so this is what
  # wires Komodo to the homelab Forgejo for version-controlling stacks.
  coreConfig = pkgs.writeText "core.config.toml" ''
    [[git_provider]]
    domain = "${hl.forgejo.url}"
    accounts = [
      { username = "komodo", token = "changeme_forgejo_access_token" },
    ]
  '';
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Komodo Docker compose stack & deployment manager";

    url = lib.mkOption {
      type = lib.types.str;
      default = "komodo.${homelab.baseDomain}";
    };

    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "komodo-periphery"
        "podman-komodo-core"
        "podman-komodo-mongo"
      ];
    };

    coreImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/moghtech/komodo-core:2.2.0";
      description = ''
        Komodo Core container image. Keep the version in sync with the Periphery
        agent (`pkgs.komodo`) so Core and Periphery match.
      '';
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Komodo";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Docker compose stack & deployment manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "komodo.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    # Podman API socket so the Periphery agent can drive this host's containers.
    virtualisation.podman.dockerSocket.enable = true;

    # Native Periphery agent. Runs as root for podman-socket access (Komodo's
    # container-based Periphery is given equivalent socket privilege). Uses the
    # legacy shared passkey to pair with Core's KOMODO_PASSKEY.
    services.komodo-periphery = {
      enable = true;
      user = "root";
      group = "root";
      dockerHost = "unix:///run/podman/podman.sock";
      passkeyFiles = peripheryPasskey;
      inbound.ssl.enable = false; # reached over localhost / tailscale
    };

    # Dedicated podman network so core <-> mongo resolve by container name.
    systemd.services.komodo-network = {
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-komodo-mongo.service"
        "podman-komodo-core.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.podman}/bin/podman network exists ${network} \
          || ${pkgs.podman}/bin/podman network create ${network}
      '';
    };

    virtualisation.oci-containers.containers = {
      komodo-mongo = {
        image = "mongo:8";
        cmd = [
          "--quiet"
          "--wiredTigerCacheSizeGB"
          "0.25"
        ];
        environmentFiles = [ mongoEnv ];
        volumes = [
          "komodo-mongo-data:/data/db"
          "komodo-mongo-config:/data/configdb"
        ];
        extraOptions = [ "--network=${network}" ];
      };

      komodo-core = {
        image = cfg.coreImage;
        dependsOn = [ "komodo-mongo" ];
        ports = [ "127.0.0.1:${toString corePort}:${toString corePort}" ];
        environment = {
          KOMODO_HOST = "https://${cfg.url}";
          KOMODO_TITLE = "Komodo";
          KOMODO_DATABASE_ADDRESS = "komodo-mongo:27017";
          KOMODO_LOCAL_AUTH = "true";
        };
        environmentFiles = [ coreEnv ];
        volumes = [
          "komodo-keys:/config/keys"
          "komodo-syncs:/syncs"
          "komodo-repo-cache:/repo-cache"
          "${coreConfig}:/config/config.toml:ro"
        ];
        extraOptions = [ "--network=${network}" ];
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:${toString corePort}
    '';
  };
}
