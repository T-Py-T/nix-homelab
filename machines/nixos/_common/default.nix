{
  pkgs,
  lib,
  ...
}:
# ============================================================================
# COMMON HOST CONFIGURATION
#
# Baseline shared by every NixOS host: nix settings, users, SSH, locale, and
# a small set of always-present packages. Host-specific configuration lives in
# `modules/machines/nixos/<host>/configuration.nix`.
# ============================================================================
{
  imports = [
    ./nix
  ];

  # --------------------------------------------------------------------------
  # USERS
  #
  # NOTE: replace the placeholder SSH key below with your own public key, or
  # you will not be able to log in / deploy to the host.
  # --------------------------------------------------------------------------
  users.users.admin = {
    isNormalUser = true;
    description = "Homelab administrator";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    openssh.authorizedKeys.keys = [
      # TODO: put your real public key here
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzLokg14/USYIlrHwqWavA3DVPiLk+l9PlqwSi3l8Pa admin@homelab"
    ];
  };

  # Passwordless sudo for the wheel group (key-based SSH only).
  security.sudo.wheelNeedsPassword = false;

  # --------------------------------------------------------------------------
  # NETWORKING
  # --------------------------------------------------------------------------
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # --------------------------------------------------------------------------
  # SSH
  # --------------------------------------------------------------------------
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # --------------------------------------------------------------------------
  # LOCALE & TIME
  # --------------------------------------------------------------------------
  time.timeZone = lib.mkDefault "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # --------------------------------------------------------------------------
  # MOTD - shows host + service health on login
  # --------------------------------------------------------------------------
  homelab.motd.enable = true;

  # --------------------------------------------------------------------------
  # BASE PACKAGES
  # --------------------------------------------------------------------------
  programs.git.enable = true;
  environment.systemPackages = with pkgs; [
    neovim
    wget
    curl
    htop
  ];

  system.stateVersion = "25.05";
}
