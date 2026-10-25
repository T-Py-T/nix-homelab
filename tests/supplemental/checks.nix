# Pure evaluation checks for homelab modules not covered by tests/eval (PR #29).
# Run: nix-instantiate --eval --strict tests/supplemental/checks.nix
let
  flake = builtins.getFlake (toString ../../.);
  supplemental = import ./lib.nix { inherit flake; };
  inherit (supplemental)
    lib
    pkgs
    mkHomelab
    assert_
    secretFixtures
    profileEnables
    homelabServiceNames
    ;

  grace = flake.nixosConfigurations.grace.config;
  alison = flake.nixosConfigurations.alison.config;

  urlFor =
    service:
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.baseDomain = "lab.test";
        }
      ];
    in
    system.config.homelab.services.${service}.url;

  coreStack = mkHomelab [
    {
      homelab.enable = true;
      homelab.baseDomain = "lab.test";
      homelab.services.enable = true;
      homelab.services.enabledProfiles = [ "core" ];
      homelab.services.grafana.secretKeyFile = secretFixtures.grafanaSecretKey;
    }
  ];

  gpuHost = mkHomelab [
    {
      homelab.enable = true;
      homelab.gpu.enable = true;
      homelab.services.enable = true;
      homelab.services.ollama.enable = true;
    }
  ];

  cpuOllamaHost = mkHomelab [
    {
      homelab.enable = true;
      homelab.services.enable = true;
      homelab.services.ollama.enable = true;
    }
  ];

  homepageHasGrafana =
    let
      homepage = coreStack.config.services.homepage-dashboard.services;
      observabilityBlock = lib.findFirst (block: block ? Observability) (_: { }) homepage;
      entries = observabilityBlock.Observability or [ ];
      names = lib.concatMap (entry: builtins.attrNames entry) entries;
    in
    builtins.elem "Grafana" names;

  checks = [
    (assert_ (builtins.elem "paperless" (homelabServiceNames coreStack)) "paperless service module should be registered")
    (assert_ (profileEnables "productivity" "paperless") "productivity profile should enable paperless-ngx")
    (assert_ (profileEnables "media" "jellyfin") "media profile should enable jellyfin")
    (assert_ (profileEnables "arr" "sonarr") "arr profile should enable sonarr")
    (assert_ (profileEnables "downloads" "sabnzbd") "downloads profile should enable sabnzbd")
    (assert_ (profileEnables "git" "forgejo") "git profile should enable forgejo")
    (assert_ (profileEnables "comms" "matrix") "comms profile should enable matrix")
    (assert_ (profileEnables "analytics" "plausible") "analytics profile should enable plausible")
    (assert_ (profileEnables "smarthome" "homeassistant") "smarthome profile should enable homeassistant")
    (assert_ (profileEnables "net" "wireguard-netns") "net profile should enable wireguard-netns")
    (assert_ (profileEnables "ai" "ollama") "ai profile should enable ollama")
    (assert_ (profileEnables "ai" "open-webui") "ai profile should enable open-webui")
    (assert_ (
      let
        system = mkHomelab [
          {
            homelab.enable = true;
            homelab.timeZone = "Europe/Berlin";
            homelab.user = "labuser";
            homelab.group = "labgroup";
          }
        ];
      in
      system.config.time.timeZone == "Europe/Berlin"
      && (system.config.users.users.labuser.isSystemUser or false)
      && (system.config.users.groups.labgroup.gid or 0) > 0
    ) "homelab core should propagate timezone and service user/group")
    (assert_ (
      coreStack.config.services.caddy.enable
      && coreStack.config.virtualisation.podman.enable
      && builtins.elem 80 coreStack.config.networking.firewall.allowedTCPPorts
      && builtins.elem 443 coreStack.config.networking.firewall.allowedTCPPorts
    ) "homelab.services.enable should wire Caddy, Podman, and HTTP(S) firewall ports")
    (assert_ (
      gpuHost.config.hardware.nvidia.open
      && builtins.elem "nvidia" gpuHost.config.services.xserver.videoDrivers
      && gpuHost.config.hardware.nvidia-container-toolkit.enable
    ) "homelab.gpu.enable should configure NVIDIA driver and container toolkit")
    (assert_ (
      cpuOllamaHost.config.services.ollama.package == pkgs.ollama
    ) "CPU host should use the stock ollama package when GPU support is off")
    (assert_ (
      gpuHost.config.services.ollama.package == pkgs.ollama-cuda
    ) "GPU host should use ollama-cuda when homelab.gpu.enable is true")
    (assert_ (urlFor "jellyfin" == "jellyfin.lab.test") "jellyfin URL should follow baseDomain")
    (assert_ (urlFor "grafana" == "grafana.lab.test") "grafana URL should follow baseDomain")
    (assert_ (urlFor "paperless" == "paperless.lab.test") "paperless URL should follow baseDomain")
    (assert_ (urlFor "nextcloud" == "cloud.lab.test") "nextcloud URL should follow baseDomain")
    (assert_ (urlFor "immich" == "photos.lab.test") "immich URL should follow baseDomain")
    (assert_ (urlFor "vaultwarden" == "pass.lab.test") "vaultwarden URL should follow baseDomain")
    (assert_ homepageHasGrafana "homepage dashboard should list Grafana under Observability when core profile is enabled")
    (assert_ (
      let
        acmeHost = mkHomelab [
          {
            homelab.enable = true;
            homelab.baseDomain = "lab.test";
            homelab.services.enable = true;
            homelab.reverseProxy.acme.enable = true;
            homelab.reverseProxy.acme.email = "ops@lab.test";
            homelab.reverseProxy.acme.dnsCredentialsFile = secretFixtures.grafanaSecretKey;
          }
        ];
      in
      acmeHost.config.security.acme.acceptTerms && acmeHost.config.security.acme.certs ? "lab.test"
    ) "ACME enablement should configure security.acme for the base domain")
    (assert_ (
      grace.homelab.gpu.enable && grace.homelab.services.ollama.enable
    ) "grace host should enable GPU support and Ollama via the ai profile")
    (assert_ (
      alison.homelab.services.jellyfin.enable && !(alison.homelab.services.ollama.enable or false)
    ) "alison host should run media services without the ai profile")
    (assert_ (
      coreStack.config.homelab.services.node-exporter.enable
      && !(coreStack.config.services.caddy.virtualHosts ? "9100")
    ) "node-exporter should enable without registering a Caddy vhost on its metrics port")
  ];
in
lib.all (x: x == null) checks
