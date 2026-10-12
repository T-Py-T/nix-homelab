# Module contract checks for homelab services not covered by other open test suites.
# Run: nix-instantiate --eval --strict tests/contracts/checks.nix
let
  flake = builtins.getFlake (toString ../../.);
  inherit (import ./lib.nix { inherit flake; })
    lib
    withServices
    assert_
    secretFixtures
    expectsCaddyReverseProxy
    motdPackage
    ;

  # motdPackage is exercised via tests/contracts/motd-productivity.nix (requires a build).

  productivityHost =
    withServices [
      {
        homelab.motd.enable = true;
        homelab.mounts.data = "/srv/bulk";
        homelab.mounts.config = "/srv/state";
        homelab.services.nextcloud.enable = true;
        homelab.services.paperless.enable = true;
        homelab.services.immich.enable = true;
      }
    ];

  prometheusHost =
    withServices [
      {
        homelab.services.prometheus.enable = true;
      }
    ];

  slskdHost =
    withServices [
      {
        homelab.mounts.data = "/srv/bulk";
        homelab.services.slskd = {
          enable = true;
          environmentFile = secretFixtures.slskdEnv;
        };
      }
    ];

  forgejoRunnerHost =
    withServices [
      {
        homelab.services.forgejo-runner.enable = true;
      }
    ];

  checks = [
    (expectsCaddyReverseProxy "jellyfin" [ ])
    (expectsCaddyReverseProxy "immich" [ ])
    (expectsCaddyReverseProxy "nextcloud" [ ])
    (expectsCaddyReverseProxy "paperless" [ ])
    (expectsCaddyReverseProxy "prometheus" [ ])
    (expectsCaddyReverseProxy "grafana" [
      {
        homelab.services.grafana.secretKeyFile = secretFixtures.grafanaSecretKey;
      }
    ])
    (expectsCaddyReverseProxy "sonarr" [ ])
    (expectsCaddyReverseProxy "forgejo" [ ])
    (expectsCaddyReverseProxy "microbin" [ ])
    (expectsCaddyReverseProxy "homeassistant" [ ])

    (assert_ (
      productivityHost.config.homelab.services.immich.mediaDir == "/srv/bulk/Photos/Immich"
      && productivityHost.config.homelab.services.nextcloud.dataDir == "/srv/bulk/Nextcloud"
      && productivityHost.config.homelab.services.paperless.mediaDir
      == "/srv/bulk/Documents/Paperless/Documents"
      && productivityHost.config.homelab.services.paperless.consumptionDir
      == "/srv/bulk/Documents/Paperless/Import"
    ) "immich, nextcloud, and paperless should derive storage paths from homelab.mounts.data")

    (assert_ (
      productivityHost.config.homelab.services.immich.monitoredServices == [
        "immich-server"
        "immich-machine-learning"
      ]
      && productivityHost.config.homelab.services.nextcloud.monitoredServices == [ "phpfpm-nextcloud" ]
      && productivityHost.config.homelab.services.paperless.monitoredServices == [
        "paperless-consumer"
        "paperless-scheduler"
        "paperless-task-queue"
        "paperless-web"
      ]
    ) "productivity/media services should declare MOTD-monitored systemd units")

    (assert_ (
      forgejoRunnerHost.config.homelab.services.forgejo-runner.forgejoUrl == "git.contracts.test"
      && forgejoRunnerHost.config.homelab.services.forgejo-runner.monitoredServices == [
        "gitea-runner-default"
      ]
    ) "forgejo-runner should default forgejoUrl and runner unit names from homelab settings")

    (assert_ (
      prometheusHost.config.services.prometheus.listenAddress == "127.0.0.1"
      && prometheusHost.config.services.prometheus.port == 9090
    ) "prometheus should listen on loopback port 9090 by default")

    (assert_ (
      motdPackage productivityHost != null
    ) "homelab.motd.enable should add the motd package when productivity services are enabled")

    (assert_ (
      let
        names = map (drv: drv.pname or drv.name) slskdHost.config.environment.systemPackages;
      in
      builtins.elem "beet-wrapped" names
      && slskdHost.config.homelab.services.slskd.beetsConfigFile != null
    ) "slskd should install beet-wrapped and generate a beets config when enabled")

    (assert_ (
      let
        haHost = withServices [
          {
            homelab.services.homeassistant.enable = true;
          }
        ];
        ha = haHost.config.virtualisation.oci-containers.containers.homeassistant;
      in
      ha.environment.TZ == haHost.config.time.timeZone
      && lib.hasInfix "homeassistant/home-assistant:stable" ha.image
    ) "homeassistant OCI container should use the official image and homelab timezone")
  ];
in
lib.all (x: x == null) checks
