{
  lib,
  modulesPath,
  ...
}:
# ============================================================================
# HARDWARE CONFIGURATION (placeholder - aarch64)
#
# Replace this file with the output of `nixos-generate-config` run on the DGX
# Spark (or copy /etc/nixos/hardware-configuration.nix from it). The values
# below are a generic aarch64 UEFI guest profile so the flake evaluates out of
# the box; they are NOT the real DGX Spark storage/boot layout.
# ============================================================================
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "nvme"
    "virtio_pci"
    "virtio_blk"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
