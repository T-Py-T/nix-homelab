{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks.homelab-regression-0039 = import ../tests/homelab-regression-0039.nix {
        inherit pkgs lib;
        flake = self;
      };
    };
}
