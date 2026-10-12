{
  pkgs,
  flakeRoot,
}:
pkgs.runCommand "homelab-scripts-smoke"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.gnugrep
    ];
    src = builtins.path {
      path = flakeRoot;
      name = "nix-homelab-src";
    };
  }
  ''
    set -euo pipefail
    cd "$src"
    bash tests/scripts/motd-service-status.sh
    touch "$out"
  ''
