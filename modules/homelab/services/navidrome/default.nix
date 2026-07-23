{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Navidrome
#
# Self-hosted music streaming server (Subsonic-compatible).
#
# NOTE: the reference wires an optional last.fm/Spotify `environmentFile` via a
# secret manager. It is optional here; set it to a file with e.g.
# ND_LASTFM_APIKEY=... to enable those integrations.
# ============================================================================
let
  service = "navidrome";
  hl = config.homelab;
  cfg = hl.services.${service};
  addr = "127.0.0.1";
  port = 4533;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    musicDir = lib.mkOption {
      type = lib.types.str;
      default = "${hl.mounts.data}/Music";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "music.${hl.baseDomain}";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''
        pkgs.writeText "navidrome-env" '''
          ND_LASTFM_APIKEY=abcabc
          ND_LASTFM_SECRET=abcabc
        '''
      '';
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Navidrome";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted music streaming service";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "navidrome.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.musicDir} 0775 ${hl.user} ${hl.group} - -"
    ];

    systemd.services.navidrome.serviceConfig.EnvironmentFile = lib.mkIf (
      cfg.environmentFile != null
    ) cfg.environmentFile;

    services.${service} = {
      enable = true;
      user = hl.user;
      group = hl.group;
      settings = {
        Address = addr;
        Port = port;
        MusicFolder = cfg.musicDir;
        DefaultDownsamplingFormat = "aac";
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${hl.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
    '';
  };
}
