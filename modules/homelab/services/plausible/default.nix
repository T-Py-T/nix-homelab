{
  lib,
  config,
  pkgs,
  ...
}:
# ============================================================================
# SERVICE: Plausible
#
# Privacy-friendly web analytics.
#
# NOTE: `secretKeybaseFile` defaults to a build-time placeholder so the host
# evaluates - replace it with a real 64-char secret before use.
# ============================================================================
let
  service = "plausible";
  cfg = config.homelab.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "numbers.${hl.baseDomain}";
    };
    secretKeybaseFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "plausible-keybase" "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "File containing the Plausible secret key base.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Plausible";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Open-source web analytics platform";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "plausible.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
  };

  config = lib.mkIf cfg.enable {
    services.plausible = {
      enable = true;
      server = {
        baseUrl = "https://${cfg.url}";
        secretKeybaseFile = cfg.secretKeybaseFile;
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${hl.mkCaddyTls}
      reverse_proxy http://${config.services.plausible.server.listenAddress}:${toString config.services.plausible.server.port}
    '';
  };
}
