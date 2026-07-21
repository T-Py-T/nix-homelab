{ lib, ... }:
# ============================================================================
# NIX DAEMON SETTINGS - applied to every host
# ============================================================================
{
  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 14d";
      persistent = true;
    };
    optimise = {
      automatic = true;
      dates = [ "daily" ];
    };
    settings = {
      experimental-features = lib.mkDefault [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "@wheel" ];
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };
}
