# vim: set ft=make :
set quiet

# List available recipes
default:
  just --list

# Update all flake inputs
update:
  nix flake update

# Evaluate the whole flake (all hosts + formatting)
check:
  nix flake check

# Format the entire tree with treefmt (nixfmt/deadnix/shellcheck)
fmt:
  nix fmt

# Build a host's system closure locally without deploying
build host:
  nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel

# Dry-run an activation on the target host (no changes applied)
dry-run host:
  nixos-rebuild dry-activate --flake .#{{host}} --target-host {{host}} --sudo

# Deploy: build on the target host and switch to the new configuration
deploy host:
  nixos-rebuild switch --flake .#{{host}} --target-host {{host}} --build-host {{host}} --sudo

# Deploy on next boot instead of immediately
boot host:
  nixos-rebuild boot --flake .#{{host}} --target-host {{host}} --build-host {{host}} --sudo
