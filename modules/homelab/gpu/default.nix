{
  config,
  lib,
  ...
}:
# ============================================================================
# GPU SUPPORT (NVIDIA / CUDA)
#
# A reusable capability a host opts into with `homelab.gpu.enable = true`. It
# loads the NVIDIA driver + CUDA userspace and wires GPUs into the container
# runtime (CDI), which is what LLM-serving workloads (e.g. the `ai` profile's
# Ollama) need. Enabling this makes `homelab.services.ollama` build against
# `ollama-cuda` automatically.
#
# It does NOT set a global `nixpkgs.config.cudaSupport` (that would rebuild the
# world); acceleration is scoped to the packages that need it.
# ============================================================================
let
  cfg = config.homelab.gpu;
in
{
  options.homelab.gpu = {
    enable = lib.mkEnableOption "NVIDIA GPU support (driver, CUDA, container toolkit) for compute/LLM workloads";

    open = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use the open-source NVIDIA kernel modules. Required for Turing and newer
        (including Ada/Hopper/Blackwell); set to false only for older GPUs.
      '';
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalMD "the stable driver for the running kernel";
      description = ''
        NVIDIA driver package. Left null, NixOS uses
        `config.boot.kernelPackages.nvidiaPackages.stable`. Override for very new
        GPUs (e.g. Grace-Blackwell / GB10) that need a newer or vendor driver
        than the stable branch ships.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Userspace GL/compute libraries (renamed from hardware.opengl).
    hardware.graphics.enable = true;

    # Registers the NVIDIA kernel module + blacklists nouveau. Needed even on a
    # headless box for CUDA; it does not start an X server on its own.
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      open = cfg.open;
      modesetting.enable = true;
      nvidiaSettings = false; # headless server: no settings GUI
      package = lib.mkIf (cfg.package != null) cfg.package;
    };

    # Expose GPUs to Podman/OCI containers via CDI. This is also exactly what a
    # Kubernetes GPU worker's device plugin builds on, so a standalone node here
    # and a future cluster node share the same enablement.
    hardware.nvidia-container-toolkit.enable = true;
  };
}
