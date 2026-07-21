{
  lib,
  modulesPath,
  ...
}:
# ============================================================================
# HARDWARE CONFIGURATION (placeholder)
#
# Replace this file with the output of `nixos-generate-config` run on the
# target machine (or copy /etc/nixos/hardware-configuration.nix from it).
# The values below are a generic QEMU/KVM guest profile so the flake evaluates
# out of the box.
# ============================================================================
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "sr_mod"
    "virtio_blk"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
