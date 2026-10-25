#!/usr/bin/env bash
# Runs module contract evaluation checks (no builds).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

export NIX_CONFIG="experimental-features = flakes nix-command"

echo "==> Module contract checks (tests/contracts/checks.nix)"
nix-instantiate --eval --strict tests/contracts/checks.nix

echo "==> MOTD wires monitored units for productivity stack"
motd_out="$(nix build --no-link --print-out-paths --file tests/contracts/motd-productivity.nix)"
grep -q 'get_service_status immich-server' "$motd_out/bin/motd"
grep -q 'get_service_status paperless-web' "$motd_out/bin/motd"
grep -q 'get_service_status phpfpm-nextcloud' "$motd_out/bin/motd"

echo "==> Flake host configurations evaluate (no build)"
nix --extra-experimental-features 'nix-command flakes' flake check --no-build --print-build-logs

echo "All module contract tests passed."
