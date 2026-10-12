#!/usr/bin/env bash
# Runs regression evaluation assertions (no VM builds).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

export NIX_CONFIG="experimental-features = flakes nix-command"

nix_flags=(--extra-experimental-features 'nix-command flakes')

echo "==> Pure evaluation checks (tests/regression/checks.nix)"
nix-instantiate --eval --strict tests/regression/checks.nix

echo "==> Flake host configurations evaluate (no build)"
nix "${nix_flags[@]}" flake check --no-build --print-build-logs

echo "All regression evaluation tests passed."
