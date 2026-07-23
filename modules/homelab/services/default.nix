{
  config,
  options,
  lib,
  ...
}:
# ============================================================================
# HOMELAB SERVICES - shared infrastructure
#
# Everything common to the individual services lives here:
#   * the `homelab.services.enable` master switch
#   * `homelab.services.profiles` + `enabledProfiles`: turn services on in named
#     bundles (a host picks the profiles it should run)
#   * the reverse proxy (Caddy) and its TLS strategy
#   * a `homelab.mkCaddyTls` helper so each service applies the right TLS
#     directive without repeating the ACME-vs-internal logic
#   * the container runtime (Podman) used by container-based services
#
# Individual services are imported at the bottom of this file and each define
# their own `homelab.services.<name>` options.
# ============================================================================
let
  cfg = config.homelab;
  proxy = cfg.reverseProxy;

  # Every declared service module under `homelab.services.<name>`: an option
  # sub-tree that exposes `enable`. Derived from the *option declarations* (not
  # config values) so new service modules are picked up automatically and there
  # is no dependency cycle with the `enable`s we set below.
  serviceOpts = options.homelab.services;
  serviceNames = builtins.filter (
    name:
    let
      opt = serviceOpts.${name};
    in
    lib.isAttrs opt && !(opt ? _type) && opt ? enable
  ) (builtins.attrNames serviceOpts);

  # Services requested by the host's enabled profiles.
  enabledServices = lib.unique (
    lib.concatMap (p: cfg.services.profiles.${p} or [ ]) cfg.services.enabledProfiles
  );
  unknownProfiles = builtins.filter (p: !(cfg.services.profiles ? ${p})) cfg.services.enabledProfiles;
  unknownServices = builtins.filter (s: !(builtins.elem s serviceNames)) enabledServices;
in
{
  options.homelab = {
    services.enable = lib.mkEnableOption "the homelab services and reverse proxy";

    services.profiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      description = ''
        Named service bundles. A host enables whole profiles via
        `enabledProfiles`; every service listed in an enabled profile turns on
        (an explicit `<service>.enable` on the host always overrides this).
        Override or extend this attrset to add your own profiles.
      '';
      default = {
        # Monitoring + the dashboard: the baseline most hosts want.
        core = [
          "node-exporter"
          "prometheus"
          "grafana"
          "uptime-kuma"
          "homepage"
        ];
        # Model serving - shared by GPU/AI hosts (see homelab.gpu).
        ai = [
          "ollama"
          "open-webui"
        ];
        media = [
          "jellyfin"
          "audiobookshelf"
          "navidrome"
          "immich"
        ];
        arr = [
          "prowlarr"
          "sonarr"
          "radarr"
          "bazarr"
          "lidarr"
          "jellyseerr"
        ];
        downloads = [
          "deluge"
          "sabnzbd"
          "slskd"
        ];
        productivity = [
          "nextcloud"
          "paperless"
          "radicale"
          "vaultwarden"
          "miniflux"
          "microbin"
        ];
        git = [
          "forgejo"
          "forgejo-runner"
        ];
        comms = [ "matrix" ];
        analytics = [ "plausible" ];
        smarthome = [
          "homeassistant"
          "raspberrymatic"
        ];
        net = [ "wireguard-netns" ];
      };
    };

    services.enabledProfiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "core"
        "ai"
      ];
      description = ''
        Profiles to enable on this host. Every service in these profiles turns
        on automatically. Setting a service's `enable` explicitly on the host
        always overrides this.
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
    # PROFILE-BASED AUTO-ENABLE
    #
    # For every service requested by the host's enabled profiles, default its
    # `enable` to true. `mkDefault` (priority 1000) means an explicit
    # `<service>.enable = true/false` on the host (priority 100) still wins.
    # ------------------------------------------------------------------------
    assertions = [
      {
        assertion = unknownProfiles == [ ];
        message = "homelab.services.enabledProfiles references unknown profile(s): ${toString unknownProfiles}. Known profiles: ${toString (builtins.attrNames cfg.services.profiles)}.";
      }
      {
        assertion = unknownServices == [ ];
        message = "homelab.services.profiles reference unknown service(s): ${toString unknownServices}. These have no matching homelab.services.<name> module.";
      }
    ];

    # Keys come from the (static) option declarations; profile membership is
    # computed lazily in the value, so the key set never depends on the
    # `enabledProfiles` we read here (avoids an infinite recursion).
    homelab.services = lib.genAttrs serviceNames (name: {
      enable = lib.mkDefault (builtins.elem name enabledServices);
    });

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
      lib.lists.optionals config.virtualisation.podman.enable
        [ 53 ];
  };

  imports = [
    # Monitoring
    ./node-exporter
    ./monitoring/prometheus
    ./monitoring/grafana

    # AI / model serving
    ./ollama
    ./open-webui

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
