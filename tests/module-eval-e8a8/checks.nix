# Evaluation/regression checks for homelab modules not covered by open draft PRs.
# Run: ./tests/module-eval-e8a8/run.sh
let
  flake = builtins.getFlake (toString ../../.);
  inherit (import ./lib.nix { inherit flake; })
    lib
    withServices
    mkHomelab
    assert_
    caddyExtraConfig
    expectsCaddyReverseProxy
    ;

  vaultwardenHost = withServices [
    {
      homelab.services.vaultwarden.enable = true;
    }
  ];

  radicaleHost = withServices [
    {
      homelab.services.radicale.enable = true;
    }
  ];

  plausibleHost = withServices [
    {
      homelab.services.plausible.enable = true;
    }
  ];

  wireguardHost = withServices [
    {
      homelab.services.wireguard-netns.enable = true;
    }
  ];

  delugeVpnHost = withServices [
    {
      homelab.services.wireguard-netns.enable = true;
      homelab.services.deluge.enable = true;
    }
  ];

  gpuHost = withServices [
    {
      homelab.gpu.enable = true;
    }
  ];

  cpuOllamaHost = withServices [
    {
      homelab.gpu.enable = false;
      homelab.services.ollama.enable = true;
    }
  ];

  nodeExporterHost = withServices [
    {
      homelab.services.node-exporter.enable = true;
    }
  ];

  forgejoRunnerHost = withServices [
    {
      homelab.services.forgejo-runner.enable = true;
    }
  ];

  uptimeKumaHost = withServices [
    {
      homelab.services.uptime-kuma.enable = true;
    }
  ];

  profilesHost = mkHomelab [
    {
      homelab.enable = true;
    }
  ];

  checks = [
    (expectsCaddyReverseProxy "vaultwarden" [ ])
    (expectsCaddyReverseProxy "radicale" [ ])
    (expectsCaddyReverseProxy "plausible" [ ])
    (expectsCaddyReverseProxy "uptime-kuma" [ ])

    (assert_ (
      let
        vw = vaultwardenHost.config.services.vaultwarden.config;
      in
      vw.SIGNUPS_ALLOWED == false
        && vw.ROCKET_PORT == 8222
        && vw.DOMAIN == "https://pass.module-eval.test"
    ) "vaultwarden should lock signups, listen on 8222, and set DOMAIN from homelab url")

    (assert_ (
      radicaleHost.config.systemd.services.radicale.serviceConfig.LoadCredential
      == "radicale.htpasswd:${radicaleHost.config.homelab.services.radicale.passwordFile}"
    ) "radicale should load htpasswd credentials via systemd LoadCredential")

    (assert_ (
      lib.hasInfix "127.0.0.1:5232" (caddyExtraConfig radicaleHost "cal.module-eval.test")
    ) "radicale Caddy vhost should reverse_proxy the loopback listener")

    (assert_ (
      plausibleHost.config.services.plausible.server.baseUrl == "https://numbers.module-eval.test"
    ) "plausible baseUrl should follow the default numbers.<baseDomain> hostname")

    (assert_ (
      wireguardHost.config.systemd.services."netns@" != null
        && wireguardHost.config.systemd.services.wg_client != null
        && wireguardHost.config.environment.etc."netns/wg_client/resolv.conf".text
        == "nameserver 9.9.9.9"
    ) "wireguard-netns should create netns@, wg_client, and namespace resolv.conf")

    (assert_ (
      let
        deluged = delugeVpnHost.config.systemd.services.deluged;
      in
      lib.elem "netns@wg_client.service" deluged.bindsTo
        && lib.elem "/var/run/netns/wg_client" deluged.serviceConfig.NetworkNamespacePath
        && delugeVpnHost.config.systemd.sockets."deluged-proxy".listenStreams == [ "58846" ]
    ) "deluge should join the wireguard namespace and expose an RPC socket proxy when VPN netns is enabled")

    (assert_ (
      lib.elem "nvidia" gpuHost.config.services.xserver.videoDrivers
        && gpuHost.config.hardware.nvidia-container-toolkit.enable
        && gpuHost.config.hardware.nvidia.open == true
    ) "homelab.gpu should enable the open NVIDIA driver stack and container toolkit")

    (assert_ (
      cpuOllamaHost.config.homelab.services.ollama.package.pname == "ollama"
        && cpuOllamaHost.config.services.ollama.host == "127.0.0.1"
        && cpuOllamaHost.config.services.ollama.port == 11434
    ) "Ollama should default to the CPU package on loopback port 11434 when GPU support is off")

    (assert_ (
      nodeExporterHost.config.services.prometheus.exporters.node.enable
        && nodeExporterHost.config.services.prometheus.exporters.node.port == 9100
        && lib.elem "systemd" nodeExporterHost.config.services.prometheus.exporters.node.enabledCollectors
        && !(nodeExporterHost.config.services.caddy.virtualHosts ? "node-exporter.module-eval.test")
    ) "node-exporter should expose Prometheus metrics on 9100 without a Caddy vhost")

    (assert_ (
      let
        atticUrl = forgejoRunnerHost.config.homelab.services.forgejo-runner.atticUrl;
        extra = caddyExtraConfig forgejoRunnerHost atticUrl;
      in
      atticUrl == "cache.module-eval.test"
        && lib.hasInfix "reverse_proxy http://127.0.0.1:8080" extra
        && lib.hasInfix "max_size 50GB" extra
    ) "forgejo-runner should front Attic on cache.<baseDomain> with a large upload limit")

    (assert_ (
      uptimeKumaHost.config.services.uptime-kuma.settings.PORT == "3011"
        && lib.hasInfix "127.0.0.1:3011" (caddyExtraConfig uptimeKumaHost "uptime.module-eval.test")
    ) "uptime-kuma should listen on 3011 and proxy through Caddy")

    (assert_ (
      profilesHost.config.homelab.services.profiles.net == [ "wireguard-netns" ]
    ) "the net profile should only enable wireguard-netns infrastructure")

    (assert_ (
      let
        infra = withServices [ ];
      in
      infra.config.services.caddy.enable
        && infra.config.virtualisation.podman.enable
        && infra.config.virtualisation.oci-containers.backend == "podman"
    ) "homelab.services.enable should turn on Caddy and Podman for containerized services")
  ];
in
lib.all (x: x == null) checks
