#!/usr/bin/env bash
# Ensures homelab.services.profiles only reference declared service modules.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"

unknown="$(
  nix-instantiate --eval --strict --json -E '
    let
      flake = builtins.getFlake (toString ./.);
      lib = flake.inputs.nixpkgs.lib;
      inherit (import ./tests/supplemental/lib.nix { inherit flake; })
        mkHomelab homelabServiceNames;
      system = mkHomelab [ { homelab.enable = true; } ];
      names = homelabServiceNames system;
      profiles = system.options.homelab.services.profiles.default;
      referenced = lib.unique (lib.concatLists (lib.attrValues profiles));
      missing = builtins.filter (s: !(builtins.elem s names)) referenced;
    in
    missing
  '
)"

if [[ "$unknown" != "[]" ]]; then
  echo "profile catalog references unknown services: $unknown" >&2
  exit 1
fi

echo "profile catalog ok ($unknown)"
