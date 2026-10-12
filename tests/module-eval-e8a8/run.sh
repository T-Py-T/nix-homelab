#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "==> homelab module eval (e8a8)"
nix-instantiate --eval --strict tests/module-eval-e8a8/checks.nix

echo "==> nix flake check (repository root)"
nix flake check --no-build

echo "All local checks passed."
