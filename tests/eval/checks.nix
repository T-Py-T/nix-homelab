# Evaluation checks run via `nix-instantiate --eval --strict tests/eval/checks.nix`.
# Returns true when every assertion passes.
let
  flake = builtins.getFlake (toString ../../.);
  inherit (import ./lib.nix { inherit flake; })
    lib
    mkHomelab
    homelabServiceNames
    assert_
    failedAssertions
    ;

  hosts = builtins.attrNames flake.nixosConfigurations;

  alison = flake.nixosConfigurations.alison.config;
  grace = flake.nixosConfigurations.grace.config;

  profileCatalogOk =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
        }
      ];
      names = homelabServiceNames system;
      profiles = system.config.homelab.services.profiles;
      referenced = lib.unique (lib.concatLists (lib.attrValues profiles));
      unknown = builtins.filter (s: !(builtins.elem s names)) referenced;
    in
    assert_ (unknown == [ ]) "profile catalog references unknown services: ${toString unknown}";

  unknownProfileRejected =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.services.enable = true;
          homelab.services.enabledProfiles = [ "not-a-real-profile" ];
        }
      ];
      failed = failedAssertions system;
    in
    assert_ (lib.any (
      a: lib.hasInfix "unknown profile" (lib.toLower a.message)
    ) failed) "expected an assertion about unknown homelab.services.enabledProfiles";

  unknownServiceInProfileRejected =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.services.enable = true;
          homelab.services.profiles.broken = [ "not-a-real-service" ];
          homelab.services.enabledProfiles = [ "broken" ];
        }
      ];
      failed = failedAssertions system;
    in
    assert_ (lib.any (
      a: lib.hasInfix "unknown service" (lib.toLower a.message)
    ) failed) "expected an assertion about unknown services in homelab.services.profiles";

  explicitEnableOverridesProfile =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.services.enable = true;
          homelab.services.enabledProfiles = [ "core" ];
          homelab.services.grafana.enable = false;
        }
      ];
    in
    assert_ (
      !system.config.homelab.services.grafana.enable
    ) "explicit homelab.services.grafana.enable = false must override the core profile";

  caddyTlsInternalByDefault = assert_ (
    alison.homelab.mkCaddyTls == "tls internal"
  ) "alison should use Caddy internal TLS when ACME is disabled";

  caddyTlsEmptyWhenAcme =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.services.enable = true;
          homelab.reverseProxy.acme.enable = true;
        }
      ];
    in
    assert_ (system.config.homelab.mkCaddyTls == "") "mkCaddyTls should be empty when ACME is enabled";

  serviceUrlUsesBaseDomain =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
          homelab.baseDomain = "lab.example";
          homelab.services.microbin.enable = true;
        }
      ];
    in
    assert_ (
      system.config.homelab.services.microbin.url == "bin.lab.example"
    ) "microbin default URL should include homelab.baseDomain";

  delugeMonitoredServicesDefault =
    let
      system = mkHomelab [
        {
          homelab.enable = true;
        }
      ];
    in
    assert_ (
      system.config.homelab.services.deluge.monitoredServices == [
        "delugeweb"
        "deluged"
      ]
    ) "deluge should declare delugeweb and deluged as monitoredServices";

  checks = [
    (assert_ (
      builtins.elem "alison" hosts && builtins.elem "grace" hosts
    ) "expected nixosConfigurations alison and grace")
    (assert_ (grace.nixpkgs.hostPlatform.system == "aarch64-linux") "grace should target aarch64-linux")
    (assert_ (alison.nixpkgs.hostPlatform.system == "x86_64-linux") "alison should target x86_64-linux")
    profileCatalogOk
    unknownProfileRejected
    unknownServiceInProfileRejected
    explicitEnableOverridesProfile
    caddyTlsInternalByDefault
    caddyTlsEmptyWhenAcme
    serviceUrlUsesBaseDomain
    delugeMonitoredServicesDefault
  ];
in
lib.all (x: x == null) checks
