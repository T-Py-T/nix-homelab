# Regression evaluation checks for homelab modules not covered elsewhere.
# Run: nix-instantiate --eval --strict tests/regression/checks.nix
let
  flake = builtins.getFlake (toString ../../.);
  inherit (import ./lib.nix { inherit flake; })
    lib
    mkHomelab
    secretFixtures
    assert_
    ;

  urlHost =
    service:
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.baseDomain = "regression.test";
        }
      ];
    in
    system.config.homelab.services.${service}.url;

  withServices =
    modules:
    mkHomelab (
      [
        {
          homelab.enable = true;
          homelab.baseDomain = "regression.test";
          homelab.services.enable = true;
        }
      ]
      ++ modules
    );

  arrUrlsOk =
    let
      expected = {
        sonarr = "sonarr.regression.test";
        radarr = "radarr.regression.test";
        prowlarr = "prowlarr.regression.test";
        bazarr = "bazarr.regression.test";
        lidarr = "lidarr.regression.test";
        jellyseerr = "jellyseerr.regression.test";
      };
      actual = lib.mapAttrs (name: _: urlHost name) expected;
    in
    assert_ (actual == expected) "arr stack URLs should follow <service>.<baseDomain>";

  serviceUrlsOk = assert_ (
    (urlHost "miniflux" == "rss.regression.test")
    && (urlHost "matrix" == "chat.regression.test")
    && (urlHost "open-webui" == "chat.regression.test")
    && (urlHost "radicale" == "cal.regression.test")
    && (urlHost "forgejo" == "git.regression.test")
    && (urlHost "uptime-kuma" == "uptime.regression.test")
    && (urlHost "navidrome" == "music.regression.test")
    && (urlHost "audiobookshelf" == "audiobooks.regression.test")
    && (urlHost "sabnzbd" == "sabnzbd.regression.test")
    && (urlHost "plausible" == "numbers.regression.test")
    && (urlHost "slskd" == "slskd.regression.test")
    && (urlHost "deluge" == "deluge.regression.test")
  ) "service URL defaults should match documented hostnames";

  mountDefaultsOk =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.mounts.data = "/srv/data";
          homelab.mounts.config = "/srv/homelab";
        }
      ];
      slskd = system.config.homelab.services.slskd;
      navidrome = system.config.homelab.services.navidrome;
    in
    assert_ (
      slskd.musicDir == "/srv/data/Music/Library"
      && slskd.downloadDir == "/srv/data/Music/Import"
      && navidrome.musicDir == "/srv/data/Music"
    ) "homelab.mounts.data should flow into slskd and navidrome defaults";

  wireguardMonitoredServices =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
        }
      ];
      cfg = system.config.homelab.services.wireguard-netns;
    in
    assert_ (
      cfg.monitoredServices == [ cfg.namespace ] && cfg.namespace == "wg_client"
    ) "wireguard-netns should monitor its namespace unit by default";

  matrixMonitoredServices =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
        }
      ];
    in
    assert_ (
      system.config.homelab.services.matrix.monitoredServices == [ "matrix-synapse" ]
    ) "matrix should monitor matrix-synapse by default";

  homepageUsesBaseDomain =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.baseDomain = "dashboard.test";
        }
      ];
    in
    assert_ (
      system.config.homelab.services.homepage.url == "dashboard.test"
    ) "homepage should default to the bare homelab.baseDomain";

  caddyRegistersReverseProxy =
    service: secretModule:
    let
      system = withServices [
        secretModule
        {
          homelab.services.${service}.enable = true;
        }
      ];
      url = system.config.homelab.services.${service}.url;
      vhost = system.config.services.caddy.virtualHosts.${url} or null;
    in
    assert_ (
      vhost != null
      && lib.hasInfix "tls internal" (vhost.extraConfig or "")
      && lib.hasInfix "reverse_proxy" (vhost.extraConfig or "")
    ) "${service} should register a Caddy vhost with internal TLS and reverse_proxy";

  vaultwardenCaddy = caddyRegistersReverseProxy "vaultwarden" { };

  minifluxCaddy =
    caddyRegistersReverseProxy "miniflux" {
      homelab.services.miniflux.adminCredentialsFile = secretFixtures.minifluxCredentials;
    };

  matrixCaddy =
    caddyRegistersReverseProxy "matrix" {
      homelab.services.matrix.registrationSecretFile = secretFixtures.matrixRegistration;
    };

  grafanaProvisionsPrometheusDatasource =
    let
      system = withServices [
        {
          homelab.services.enabledProfiles = [ "core" ];
          homelab.services.grafana.secretKeyFile = secretFixtures.grafanaSecretKey;
        }
      ];
      datasources = system.config.services.grafana.provision.datasources.settings.datasources or [ ];
      prometheusDs = lib.findFirst (ds: ds.name == "Prometheus") null datasources;
    in
    assert_ (
      prometheusDs != null
      && lib.hasInfix "9090" (prometheusDs.url or "")
    ) "core profile should auto-provision Prometheus as Grafana's default datasource";

  checks = [
    arrUrlsOk
    serviceUrlsOk
    mountDefaultsOk
    wireguardMonitoredServices
    matrixMonitoredServices
    homepageUsesBaseDomain
    vaultwardenCaddy
    minifluxCaddy
    matrixCaddy
    grafanaProvisionsPrometheusDatasource
  ];
in
lib.all (x: x == null) checks
