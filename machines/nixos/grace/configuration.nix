{ ... }:
# ============================================================================
# HOST: grace
#
# The GPU model-serving node - a DGX Spark (NVIDIA Grace-Blackwell, aarch64).
# Hardware/boot lives here; the set of enabled homelab services + GPU support
# lives in ./homelab.nix to keep concerns separate.
#
# NOTE: this is a UEFI (systemd-boot) profile. Replace hardware-configuration.nix
# with the real `nixos-generate-config` output from the machine before deploying.
# ============================================================================
{
  imports = [
    ./hardware-configuration.nix
    ./homelab.nix
  ];

  # --------------------------------------------------------------------------
  # BOOTLOADER (UEFI)
  # --------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
