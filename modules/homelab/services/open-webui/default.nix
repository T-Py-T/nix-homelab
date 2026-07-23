{
  config,
  lib,
  ...
}:
# ============================================================================
# SERVICE: Open WebUI
#
# The chat front-end of the `ai` profile. Talks to the local Ollama backend and
# is reverse-proxied by Caddy at chat.<baseDomain>. First visit prompts you to
# create the admin account (auth is on by default).
#
# It does NOT run any models itself - it is a UI over the Ollama API.
# ============================================================================
let
  service = "open-webui";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  addr = "127.0.0.1";
  port = 8083;
  # The Ollama backend this UI points at (same host).
  ollamaPort = 11434;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Open WebUI chat interface for Ollama";

    url = lib.mkOption {
      type = lib.types.str;
      default = "chat.${homelab.baseDomain}";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Open WebUI";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Chat interface for local LLMs";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "open-webui.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "AI";
    };
  };

  config = lib.mkIf cfg.enable {
    services.open-webui = {
      enable = true;
      host = addr;
      inherit port;
      environment = {
        # Point the UI at the local Ollama backend.
        OLLAMA_BASE_URL = "http://127.0.0.1:${toString ollamaPort}";
        # Keep it self-contained and quiet by default.
        WEBUI_AUTH = "True";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
      };
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
    '';
  };
}
