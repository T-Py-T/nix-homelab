{
  pkgs,
  lib,
  config,
  ...
}:
# ============================================================================
# SERVICE: Matrix (Synapse + Element Call via LiveKit)
#
# Matrix homeserver with the well-known delegation served from the base domain
# and a LiveKit SFU + JWT service for Element Call. LiveKit's shared key is
# generated on first boot by the `livekit-key` unit.
#
# The reference ships a large oembed `providers.json`; it is omitted here (the
# default providers still work).
#
# NOTE: `registrationSecretFile` defaults to a build-time placeholder so the
# host evaluates - replace it with a real secret before use.
# ============================================================================
let
  service = "matrix";
  cfg = config.homelab.services.${service};
  hl = config.homelab;
  keyFile = "/run/livekit.key";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "chat.${hl.baseDomain}";
    };
    registrationSecretFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "matrix-registration-secret.yaml" ''
        registration_shared_secret: "changeme-changeme-changeme"
      '';
      defaultText = lib.literalMD "a build-time placeholder - override with a secret!";
      description = "Extra Synapse config file containing the registration shared secret.";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "matrix-synapse" ];
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Matrix";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Synapse Matrix homeserver";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "matrix.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.matrix-synapse = {
      isSystemUser = true;
      createHome = true;
      group = "matrix-synapse";
    };

    services.postgresql = {
      enable = true;
      initialScript = pkgs.writeText "synapse-init.sql" ''
        CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
        CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
          TEMPLATE template0
          LC_COLLATE = "C"
          LC_CTYPE = "C";
      '';
    };

    services.livekit = {
      enable = true;
      openFirewall = true;
      settings.room.auto_create = false;
      inherit keyFile;
    };
    services.lk-jwt-service = {
      enable = true;
      livekitUrl = "wss://${cfg.url}/livekit/sfu";
      inherit keyFile;
      port = 8068;
    };
    systemd.services.livekit-key = {
      before = [
        "lk-jwt-service.service"
        "livekit.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        livekit
        coreutils
        gawk
      ];
      script = ''
        echo "Key missing, generating key"
        echo "lk-jwt-service: $(livekit-server generate-keys | tail -1 | awk '{print $3}')" > "${keyFile}"
      '';
      serviceConfig.Type = "oneshot";
      unitConfig.ConditionPathExists = "!${keyFile}";
    };
    systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = cfg.url;

    services.caddy.virtualHosts =
      let
        serverConfig."m.server" = "${cfg.url}:443";
        clientConfig."m.identity_server".base_url = "https://vector.im";
        clientConfig."org.matrix.msc4143.rtc_foci" = [
          {
            type = "livekit";
            livekit_service_url = "https://${cfg.url}/livekit/jwt";
          }
        ];
        clientConfig."m.homeserver".base_url = "https://${cfg.url}";
      in
      {
        "${hl.baseDomain}".extraConfig = ''
          ${hl.mkCaddyTls}
          respond /.well-known/matrix/server `${builtins.toJSON serverConfig}`
          respond /.well-known/matrix/client `${builtins.toJSON clientConfig}`
          header /.well-known/matrix/* Content-Type application/json
          header /.well-known/matrix/* Access-Control-Allow-Origin *
        '';
        "${cfg.url}".extraConfig = ''
          ${hl.mkCaddyTls}
          @matrix path /_matrix/* /_matrix /_synapse/client/* /_synapse/client
          reverse_proxy @matrix http://[::1]:8008

          @jwt_service path /livekit/jwt/sfu/get /livekit/jwt/healthz
          handle @jwt_service {
            uri strip_prefix /livekit/jwt
            reverse_proxy http://[::1]:${toString config.services.lk-jwt-service.port} {
              header_up Host {host}
              header_up X-Forwarded-Server {host}
              header_up X-Real-IP {remote_host}
              header_up X-Forwarded-For {remote_host}
            }
          }

          @livekit_service path /livekit/sfu*
          handle @livekit_service {
            uri strip_prefix /livekit/sfu
            reverse_proxy http://[::1]:${toString config.services.livekit.settings.port} {
              header_up Host {host}
              header_up X-Forwarded-Server {host}
              header_up X-Real-IP {remote_host}
              header_up X-Forwarded-For {remote_host}
            }
          }

          respond / 404
        '';
      };

    services.matrix-synapse = {
      enable = true;
      extraConfigFiles = [ cfg.registrationSecretFile ];
      settings = {
        server_name = hl.baseDomain;
        public_baseurl = "https://${cfg.url}";
        enable_registration = false;
        allow_guest_access = false;
        experimental_features = {
          msc4140_enabled = true;
          msc4222_enabled = true;
          msc3266_enabled = true;
        };
        max_event_delay_duration = "24h";
        listeners = [
          {
            port = 8008;
            bind_addresses = [ "::1" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [
              {
                names = [
                  "client"
                  "federation"
                ];
                compress = true;
              }
            ];
          }
        ];
        secondary_directory_servers = [ "matrix.org" ];
      };
    };
  };
}
