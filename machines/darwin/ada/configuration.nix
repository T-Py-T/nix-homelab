{ pkgs, ... }:
# ============================================================================
# HOST: ada - Mac Studio (Apple Silicon) AI node (nix-darwin)
#
# The macOS counterpart of the `ai` role: it serves models with Ollama on
# Metal. macOS is not a NixOS host, so it does NOT consume the homelab.services
# module tree (nix-darwin has no services.ollama); instead Ollama runs as a
# launchd user agent from the nixpkgs package, which is Metal-accelerated on
# Apple Silicon out of the box.
#
# This file is NOT wired into flake.nix yet: doing so needs the `nix-darwin`
# input and a `flake.lock` update, which must be run on a machine with Nix.
# See docs/macos.md for the exact activation steps. It does NOT manage the
# Mac's desktop/apps - only the model-serving piece.
# ============================================================================
{
  # nix-darwin system basics.
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 5;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Ollama backend, Metal-accelerated on Apple Silicon.
  environment.systemPackages = [ pkgs.ollama ];

  launchd.user.agents.ollama = {
    command = "${pkgs.ollama}/bin/ollama serve";
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/ollama.out.log";
      StandardErrorPath = "/tmp/ollama.err.log";
      # Bind to localhost; front it with the Open WebUI running on `grace`,
      # or set "0.0.0.0:11434" to serve the LAN directly.
      EnvironmentVariables.OLLAMA_HOST = "127.0.0.1:11434";
    };
  };
}
