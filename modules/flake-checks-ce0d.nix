{ self, ... }:
let
  pkgs = self.inputs.nixpkgs.legacyPackages.x86_64-linux;
  navidromeRegressionOk = import ../tests/homelab-regression-navidrome-ce0d.nix {
    flake = self;
    inherit pkgs;
  };
  uptimeKumaRegressionOk = import ../tests/homelab-regression-uptime-kuma-ce0d.nix {
    flake = self;
    inherit pkgs;
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        homelab-regression-navidrome-ce0d = pkgs.runCommand "homelab-regression-navidrome-ce0d" { } ''
          test "${navidromeRegressionOk}" = "ok"
          touch $out
        '';

        homelab-regression-uptime-kuma-ce0d = pkgs.runCommand "homelab-regression-uptime-kuma-ce0d" { } ''
          test "${uptimeKumaRegressionOk}" = "ok"
          touch $out
        '';
      };
    };
}
