#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! command -v nix >/dev/null 2>&1; then
  echo "nix is required on PATH" >&2
  exit 1
fi

export NIX_CONFIG="${NIX_CONFIG:-experimental-features = nix-command flakes}"

nix flake check --no-build --print-build-logs
