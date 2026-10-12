# Ensure the justfile parses and lists recipes (script smoke test).
{
  pkgs,
  flakeRoot,
}:
pkgs.runCommand "justfile-smoke"
  {
    nativeBuildInputs = [ pkgs.just ];
    src = builtins.path {
      path = flakeRoot;
      name = "nix-homelab-src";
    };
  }
  ''
    set -euo pipefail
    cd "$src"
    ${pkgs.just}/bin/just --list > /dev/null
    ${pkgs.just}/bin/just --show check | grep -q 'nix flake check'
    touch "$out"
  ''
