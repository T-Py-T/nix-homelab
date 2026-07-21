{ ... }:
# ============================================================================
# HOST: alison
#
# The main homelab node. Hardware/boot lives here; the set of enabled homelab
# services lives in ./homelab.nix to keep concerns separate.
# ============================================================================
{
  imports = [
    ./hardware-configuration.nix
    ./homelab.nix
  ];

  # --------------------------------------------------------------------------
  # BOOTLOADER
  # --------------------------------------------------------------------------
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
    useOSProber = true;
  };
}
