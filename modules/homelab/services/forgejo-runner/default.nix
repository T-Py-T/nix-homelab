{
  lib,
  pkgs,
  config,
  ...
}:
# ============================================================================
# SERVICE: Forgejo Actions runner (+ Attic binary cache)
#
# A CI runner registered against a Forgejo instance, plus an Attic binary cache
# to speed up Nix-based CI. Both are optional building blocks for a self-hosted
# CI setup.
#
# NOTE: `tokenFile`/`atticTokenFile` default to build-time placeholders so the
# host evaluates - replace them with real secrets before use.
# ============================================================================
let
  service = "forgejo-runner";
  cfg = config.homelab.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    runnerName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      example = "runner-1";
    };
    forgejoUrl = lib.mkOption {
      type = lib.types.str;
      default = "git.${hl.baseDomain}";
      example = "git.foo.bar";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "gitea-runner-default" ];
    };
    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "forgejo-runner-token" ''
        TOKEN=changeme
      '';
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "EnvironmentFile with the runner registration TOKEN.";
    };
    atticTokenFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "attic-token" ''
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=changeme
      '';
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "EnvironmentFile with the Attic RS256 secret.";
    };
    atticUrl = lib.mkOption {
      type = lib.types.str;
      default = "cache.${hl.baseDomain}";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman.enable = true;

    services.atticd = {
      enable = true;
      environmentFile = cfg.atticTokenFile;
      settings = {
        listen = "127.0.0.1:8080";
        allowed-hosts = [ cfg.atticUrl ];
        api-endpoint = "https://${cfg.atticUrl}/";
        jwt = { };
      };
    };

    services.caddy.virtualHosts."${cfg.atticUrl}".extraConfig = ''
      ${hl.mkCaddyTls}
      reverse_proxy http://${toString config.services.atticd.settings.listen}
      request_body {
        max_size 50GB
      }
    '';

    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.default = {
        enable = true;
        url = "https://${cfg.forgejoUrl}";
        name = cfg.runnerName;
        tokenFile = cfg.tokenFile;
        hostPackages = with pkgs; [
          nodejs
          buildah
          fuse-overlayfs
          bash
          coreutils
          curl
          gawk
          gitMinimal
          gnused
          wget
        ];
        settings.runner.capacity = 2;
        labels = [
          "debian-latest:docker://node:current-trixie"
          "buildah:docker://quay.io/containers/buildah:latest"
        ];
      };
    };
  };
}
