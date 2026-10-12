#!/usr/bin/env bash
# Supplemental homelab tests: evaluation assertions and small script checks.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

export NIX_CONFIG="experimental-features = flakes nix-command"

nix_flags=(--extra-experimental-features 'nix-command flakes')

echo "==> Pure evaluation checks (tests/supplemental/checks.nix)"
nix-instantiate --eval --strict tests/supplemental/checks.nix

echo "==> MOTD script includes wireguard namespace unit from monitoredServices"
motd_pkg="$(nix build --no-link --print-out-paths "${nix_flags[@]}" --file tests/supplemental/motd-wireguard.nix)"
motd_bin="$(find "$motd_pkg" -name motd -type f | head -n1)"
grep -q 'get_service_status wg_client' "$motd_bin"

echo "==> Profile catalog script (every profile service is declared)"
bash tests/supplemental/scripts/profile-catalog.sh

echo "==> Flake host configurations evaluate (no build)"
nix "${nix_flags[@]}" flake check --no-build --print-build-logs

echo "All supplemental tests passed."
