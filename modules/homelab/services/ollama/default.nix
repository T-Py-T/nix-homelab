{
  config,
  lib,
  pkgs,
  ...
}:
# ============================================================================
# SERVICE: Ollama
#
# Local LLM model server - the backend of the `ai` profile. Serves an HTTP API
# on 127.0.0.1:11434 (reverse-proxied by Caddy). On a GPU host
# (`homelab.gpu.enable`) it builds against `ollama-cuda` for NVIDIA
# acceleration; otherwise it falls back to the CPU build.
#
# It does NOT itself provide a chat UI - see the open-webui module.
# ============================================================================
let
  service = "ollama";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  addr = "127.0.0.1";
  port = 11434;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Ollama local LLM model server";

    url = lib.mkOption {
      type = lib.types.str;
      default = "ollama.${homelab.baseDomain}";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = if homelab.gpu.enable then pkgs.ollama-cuda else pkgs.ollama;
      defaultText = lib.literalMD "`ollama-cuda` when `homelab.gpu.enable`, otherwise `ollama` (CPU)";
      description = "Ollama package to run; selects the hardware acceleration backend.";
    };

    loadModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "llama3.2"
        "qwen2.5-coder"
      ];
      description = ''
        Models to `ollama pull` in the background once the service is up.
        Left empty (the default) nothing is downloaded at activation.
      '';
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Ollama";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Local LLM model server";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "ollama.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "AI";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = cfg.package;
      host = addr;
      inherit port;
      loadModels = cfg.loadModels;
    };

    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://${addr}:${toString port}
    '';
  };
}
