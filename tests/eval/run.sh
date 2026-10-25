#!/usr/bin/env bash
# Runs evaluation assertions and a small flake smoke suite (no builds).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

export NIX_CONFIG="experimental-features = flakes nix-command"

nix_flags=(--extra-experimental-features 'nix-command flakes')

echo "==> Pure evaluation checks (tests/eval/checks.nix)"
nix-instantiate --eval --strict tests/eval/checks.nix

echo "==> MOTD script wires deluge monitored systemd units"
motd_out="$(nix build --no-link --print-out-paths --file tests/eval/motd-package.nix)"
grep -q 'get_service_status delugeweb' "$motd_out/bin/motd"
grep -q 'get_service_status deluged' "$motd_out/bin/motd"

echo "==> Flake host configurations evaluate (no build)"
nix "${nix_flags[@]}" flake check --no-build --print-build-logs

echo "==> Formatter derivation evaluates"
nix "${nix_flags[@]}" eval .#formatter.x86_64-linux.drvPath --raw >/dev/null

echo "All evaluation tests passed."
