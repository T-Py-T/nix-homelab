{ ... }:
# ============================================================================
# HOST: grace - GPU model-serving node (DGX Spark)
#
# Runs the `core` monitoring stack plus the `ai` profile (Ollama + Open WebUI),
# with NVIDIA GPU support enabled so Ollama uses CUDA. This is the home-lab
# equivalent of a GPU worker node dedicated to serving models.
# ============================================================================
{
  homelab = {
    enable = true;
    baseDomain = "home.lan";
    timeZone = "America/New_York";

    # NVIDIA driver + CUDA + container toolkit. Makes Ollama build against
    # ollama-cuda automatically. See modules/homelab/gpu.
    gpu.enable = true;

    services = {
      enable = true;

      # A focused node: monitoring + model serving only.
      enabledProfiles = [
        "core"
        "ai"
      ];

      # Scrape this host's own node-exporter.
      prometheus.scrapeTargets = [
        {
          job_name = "node";
          static_configs = [
            { targets = [ "127.0.0.1:9100" ]; }
          ];
        }
      ];

      # Pull starter models on first boot (optional - uncomment to use):
      #   ollama.loadModels = [ "llama3.2" "qwen2.5-coder" ];
    };
  };
}
