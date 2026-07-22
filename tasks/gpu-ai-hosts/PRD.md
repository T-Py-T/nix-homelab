# PRD: GPU/AI hosts + service profiles

## Problem

The homelab has no GPU/LLM-serving host, and service selection is a rigid
3-level importance tier. We want (a) a declarative GPU model-serving host, and
(b) a flexible, open-ended way to bundle services per host type.

## Goal

Replace importance tiers with named **profiles**, add an `ai` profile (Ollama +
Open WebUI) and a reusable `homelab.gpu` capability module, and define two
GPU/AI hosts - `grace` (DGX Spark, NixOS) and `ada` (Mac Studio, nix-darwin) -
that share the model-serving role.

## Users

A platform engineer running GPU worker nodes at home who wants reproducible,
declarative model-serving hosts and per-host service selection by capability.

## Requirements

- **R1** Profiles are the single selection mechanism; importance tiers are
  removed entirely (no dual convention left behind).
- **R2** Profiles are centrally defined, named, unlimited in number, each listing
  its services. A host selects them via `homelab.services.enabledProfiles`.
- **R3** An explicit per-service `enable` on a host overrides the profile default.
- **R4** Unknown profile names or service keys fail evaluation with a clear
  assertion (no silent typos).
- **R5** An `ai` profile provides Ollama (model backend) and Open WebUI (chat
  UI), reverse-proxied through Caddy and shown on the dashboard ("AI" category).
- **R6** A `homelab.gpu` module enables NVIDIA drivers, CUDA, and the container
  toolkit; enabling it makes Ollama use `pkgs.ollama-cuda` automatically (CPU
  otherwise).
- **R7** `grace` (DGX Spark) is an aarch64-linux NixOS host running `core` + `ai`
  with `homelab.gpu.enable = true`.
- **R8** `ada` (Mac Studio) is a nix-darwin host serving Ollama on Metal via a
  launchd agent (the ai role), shipped complete but activation-gated.
- **R9** `nix flake check` stays green for every NixOS host (automated proof).
- **R10** Docs updated (profiles model, GPU/AI serving, the two hosts). All work
  on the `gpu-ai-hosts` branch.

## Non-goals

- Kubernetes / KServe / Ray Serve / vLLM and GPU time-slicing (K8s-layer, not
  NixOS service modules).
- Managing the Mac's full desktop environment; only the model-serving pieces.
- Guaranteeing the stock nixpkgs NVIDIA driver binds the DGX Spark's GB10 (see
  risks); the recipe is the correct declarative shape.

## Acceptance criteria

- **A1** `homelab.services.enabledProfiles = [ "core" "ai" ]` on a host enables
  exactly those services; explicit overrides win. Verified by evaluation.
- **A2** No `importance` / `mkImportance` / `enabledTiers` remain anywhere.
- **A3** `nix flake check` is green (evaluates `alison` and `grace`, plus
  treefmt) in CI.
- **A4** `grace` evaluates with GPU + Ollama (CUDA) + Open WebUI; the Caddy vhosts
  and "AI" dashboard entries are present.
- **A5** `ada` config exists and documents the exact activation steps.

## Test plan

- **Automated (this branch):** `nix flake check` in CI proves the whole flake
  evaluates and is formatted. This is the only proof achievable without hardware.
- **Hardware (needs Taylor):** see "What we need from you".

## What we need from you (Taylor) to test end to end

1. **DGX Spark (`grace`)**: run `nixos-generate-config` there and share/commit its
   `hardware-configuration.nix`; deploy and report `nvidia-smi`, `systemctl status
   ollama`, `ollama run llama3.2` output, and whether Open WebUI loads at
   `https://chat.<baseDomain>`. Confirm the GB10 driver situation (stock nixpkgs
   driver vs. vendor driver) so we can pin `homelab.gpu.package` if needed.
2. **Mac Studio (`ada`)**: after we add the `nix-darwin` input, run `nix flake
   lock` (needs `nix` on a real machine) and `darwin-rebuild switch --flake
   .#ada`; report whether the Ollama launchd agent serves on `:11434` with Metal.
3. **Naming**: confirm the hostnames `grace` (DGX) and `ada` (Mac) or give
   preferred names.
4. **Base domain / DNS**: confirm `baseDomain` and how these hosts resolve
   (`/etc/hosts` vs. real DNS) so the Caddy vhosts are reachable.

## Risks

- aarch64 + NVIDIA GB10 driver support in mainline nixpkgs is bleeding-edge;
  runtime GPU binding may need vendor overrides.
- The Mac path (nix-darwin input + `flake.lock`) can't be completed or
  CI-verified in the authoring sandbox; it is documented and gated.
