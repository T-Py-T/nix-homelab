{ pkgs, ... }:
# ============================================================================
# HOST: ada - Mac Studio (Apple Silicon) AI node (nix-darwin)
#
# The macOS counterpart of the `ai` role: it serves models with Ollama on
# Metal. macOS is not a NixOS host, so it does NOT consume the homelab.services
# module tree (nix-darwin has no services.ollama); instead Ollama runs as a
# launchd user agent from the nixpkgs package, Metal-accelerated on Apple
# Silicon out of the box.
#
# Built via ../flake.nix (`nix build .#darwinConfigurations.ada.system`) on a
# Mac or a macOS CI runner. It does NOT manage the Mac's desktop/apps - only
# the model-serving piece.
# ============================================================================
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 5;

  # nix-darwin needs the primary user for user-level (launchd) configuration.
  # Set this to your macOS login name.
  system.primaryUser = "taylor";

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
      # Bind to localhost; front it with the Open WebUI running on `grace`, or
      # set "0.0.0.0:11434" to serve the LAN directly.
      EnvironmentVariables.OLLAMA_HOST = "127.0.0.1:11434";
    };
  };
}
