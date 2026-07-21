{
  config,
  options,
  lib,
  pkgs,
  homelabLib,
  ...
}:
# ============================================================================
# HOMELAB SERVICES - shared infrastructure
#
# Everything common to the individual services lives here:
#   * the `homelab.services.enable` master switch
#   * `homelab.services.enabledTiers`: turn services on by importance tier
#   * the reverse proxy (Caddy) and its TLS strategy
#   * a `homelab.mkCaddyExtraConfig` helper so each service applies the right
#     TLS directive without repeating the ACME-vs-internal logic
#   * the container runtime (Podman) used by container-based services
#
# Individual services are imported at the bottom of this file and each define
# their own `homelab.services.<name>` options (including an `importance` tier).
# ============================================================================
let
  cfg = config.homelab;
  proxy = cfg.reverseProxy;

  # Every declared service module under `homelab.services.<name>`: an option
  # sub-tree that exposes both `enable` and `importance`. Derived from the
  # *option declarations* (not config values) so new service modules are picked
  # up automatically and there is no dependency cycle with the `enable`s we set
  # below.
  serviceOpts = options.homelab.services;
  serviceNames = builtins.filter (
    name:
    let
      opt = serviceOpts.${name};
    in
    lib.isAttrs opt && !(opt ? _type) && opt ? enable && opt ? importance
  ) (builtins.attrNames serviceOpts);
in
{
  options.homelab = {
    services.enable = lib.mkEnableOption "the homelab services and reverse proxy";

    services.enabledTiers = lib.mkOption {
      type = lib.types.listOf (lib.types.enum homelabLib.tiers);
      default = [ ];
      example = [
        "high"
        "medium"
      ];
      description = ''
        Importance tiers to enable on this host. Every service whose
        `importance` is in this list turns on automatically. Setting a
        service's `enable` explicitly on the host always overrides this.
      '';
    };

    reverseProxy = {
      acme = {
        enable = lib.mkEnableOption ''
          ACME/Let's Encrypt certificates via the Cloudflare DNS-01 challenge.
          When disabled (the default), Caddy issues its own internal TLS
          certificates, which is appropriate for a LAN with no public domain.
        '';

        email = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Contact e-mail for the ACME account.";
        };

        dnsCredentialsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/run/secrets/cloudflare-dns";
          description = ''
            Path to an EnvironmentFile containing the Cloudflare API token, e.g.
              CF_DNS_API_TOKEN=verybigsecret
          '';
        };
      };
    };

    # Helper used by services to render the correct per-vhost TLS directive.
    # Usage inside a service:
    #   services.caddy.virtualHosts.<url>.extraConfig = ''
    #     ${config.homelab.mkCaddyTls}
    #     reverse_proxy http://127.0.0.1:1234
    #   '';
    mkCaddyTls = lib.mkOption {
      type = lib.types.str;
      internal = true;
      readOnly = true;
      default = if proxy.acme.enable then "" else "tls internal";
      description = "TLS directive injected into each Caddy virtual host.";
    };
  };

  config = lib.mkIf cfg.services.enable {
    # ------------------------------------------------------------------------
    # TIER-BASED AUTO-ENABLE
    #
    # For every discovered service, default its `enable` to whether its tier is
    # in `enabledTiers`. `mkDefault` (priority 1000) means an explicit
    # `<service>.enable = true/false` on the host (priority 100) still wins.
    # ------------------------------------------------------------------------
    homelab.services = lib.genAttrs serviceNames (
      name:
      let
        svc = config.homelab.services.${name};
      in
      {
        enable = lib.mkDefault (lib.elem svc.importance cfg.services.enabledTiers);
      }
    );

    # ------------------------------------------------------------------------
    # FIREWALL - open HTTP/HTTPS for the reverse proxy
    # ------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    # ------------------------------------------------------------------------
    # ACME (only when a public domain + Cloudflare token is configured)
    # ------------------------------------------------------------------------
    security.acme = lib.mkIf proxy.acme.enable {
      acceptTerms = true;
      defaults.email = proxy.acme.email;
      certs.${cfg.baseDomain} = {
        reloadServices = [ "caddy.service" ];
        domain = cfg.baseDomain;
        extraDomainNames = [ "*.${cfg.baseDomain}" ];
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        dnsPropagationCheck = true;
        group = config.services.caddy.group;
        environmentFile = proxy.acme.dnsCredentialsFile;
      };
    };

    # ------------------------------------------------------------------------
    # CADDY REVERSE PROXY
    #
    # Services register their own `services.caddy.virtualHosts.<url>` entries.
    # ------------------------------------------------------------------------
    services.caddy = {
      enable = true;
      globalConfig = lib.mkIf proxy.acme.enable ''
        auto_https off
      '';
    };

    # ------------------------------------------------------------------------
    # CONTAINER RUNTIME (for services shipped as OCI containers)
    # ------------------------------------------------------------------------
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      autoPrune.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    virtualisation.oci-containers.backend = "podman";

    networking.firewall.interfaces.podman0.allowedUDPPorts =
      lib.lists.optionals config.virtualisation.podman.enable [ 53 ];
  };

  imports = [
    # Monitoring
    ./node-exporter
    ./monitoring/prometheus
    ./monitoring/grafana

    # Arr stack
    ./arr/prowlarr
    ./arr/sonarr
    ./arr/radarr
    ./arr/bazarr
    ./arr/lidarr
    ./arr/jellyseerr

    # Media
    ./jellyfin
    ./audiobookshelf
    ./navidrome
    ./immich

    # Downloads
    ./deluge
    ./sabnzbd
    ./slskd

    # Git hosting / CI
    ./forgejo
    ./forgejo-runner

    # General services
    ./miniflux
    ./microbin
    ./paperless-ngx
    ./radicale
    ./vaultwarden
    ./nextcloud
    ./matrix
    ./plausible
    ./uptime-kuma

    # Smart home
    ./smarthome/homeassistant
    ./smarthome/raspberrymatic

    # Infrastructure (no homepage entry)
    ./wireguard-netns

    # Dashboard (keep last: aggregates the services above)
    ./homepage
  ];
}
