# Plan: GPU/AI hosts + service profiles

Branch: `gpu-ai-hosts` (merged later).

## Goal

Model GPU-enabled LLM-serving hosts declaratively, and replace the 3-level
importance tiers with flexible named **profiles** (service bundles). Add two
GPU/AI hosts sharing an `ai` profile:

- `grace` - DGX Spark (NVIDIA Grace-Blackwell, aarch64-linux, NixOS) - GPU node.
- `ada` - Mac Studio (Apple Silicon, aarch64-darwin, nix-darwin) - Metal node.

## Key decisions

1. **Profiles replace importance tiers.** One selection mechanism, not two
   (repo rule: no parallel conventions). A profile is a named list of services;
   there can be any number of them. A host sets `enabledProfiles`; every service
   in those profiles turns on (via `mkDefault`, so explicit `enable` still wins).
2. **Central profile catalog** lives in `modules/homelab/services/default.nix`
   as `homelab.services.profiles` (an overridable attrset), so profiles are a
   repo-level concept a host just references.
3. **GPU is a capability module** (`homelab.gpu`), separate from profiles:
   NVIDIA driver + CUDA libraries + `nvidia-container-toolkit`. Enabling it makes
   the `ollama` service build against `pkgs.ollama-cuda` automatically.
4. **`ai` profile = Ollama + Open WebUI.** Ollama is the model backend
   (`:11434`); Open WebUI is the chat UI (`:8083`), reverse-proxied + on the
   dashboard under a new "AI" category.
5. **NixOS/Darwin split is real.** `homelab.services.*` is a NixOS module tree;
   nix-darwin cannot consume it and has no `services.ollama`. The Mac runs Ollama
   via a `launchd.user.agents` agent (nixpkgs `ollama`, Metal). The shared thing
   is the *ai role* (serve models), not identical modules.

## Profile catalog (initial)

| Profile | Services |
|---|---|
| `core` | node-exporter, prometheus, grafana, uptime-kuma, homepage |
| `ai` | ollama, open-webui |
| `media` | jellyfin, audiobookshelf, navidrome, immich |
| `arr` | prowlarr, sonarr, radarr, bazarr, lidarr, jellyseerr |
| `downloads` | deluge, sabnzbd, slskd |
| `productivity` | nextcloud, paperless, radicale, vaultwarden, miniflux, microbin |
| `git` | forgejo, forgejo-runner |
| `comms` | matrix |
| `analytics` | plausible |
| `smarthome` | homeassistant, raspberrymatic |
| `net` | wireguard-netns |

(Service keys are the exact option names, e.g. paperless-ngx's key is `paperless`.)

## Ports

- ollama: `11434` (default). open-webui: `8083` (8080 default clashes with sabnzbd).

## Engine (services/default.nix)

- `serviceNames` = option keys under `homelab.services` that expose `enable`
  (discovered from `options`, not config values - no fixpoint cycle).
- `enabledServices` = union of the service lists of the host's `enabledProfiles`.
- `config`: `homelab.services.<s>.enable = mkDefault true` for each enabled
  service. Assertions catch unknown profile names and unknown service keys.

## Sequencing (so the testable core lands first)

1. Profiles engine; strip `importance`/`mkImportance`/`enabledTiers`; migrate
   `alison`; add "AI" homepage category.
2. `homelab.gpu` module; `ollama` + `open-webui` service modules; `ai` profile.
3. `grace` NixOS host (aarch64-linux) + `systemArchMap` entry.
4. `nix flake check` green in CI (this is the automated proof).
5. `ada` nix-darwin config (activation-gated) + docs.

## Constraints / risks (honest)

- **DGX Spark is aarch64 Grace-Blackwell.** Mainline nixpkgs NVIDIA support for
  GB10 is bleeding-edge; the driver package may need vendor overrides on real
  hardware. The recipe is a correct-shaped starting point, not a guarantee the
  stock driver binds GB10. If aarch64 + NVIDIA fails to even evaluate in CI, the
  gpu module degrades (container-toolkit + graphics, proprietary driver opt-in)
  and the caveat is documented.
- **Mac / flake.lock.** Adding the `nix-darwin` input requires `nix flake lock`,
  which needs `nix` - not available in the authoring sandbox. So `ada` ships
  complete but **unwired** (no input added, flake stays green); activation is a
  documented step. Darwin configs are also not verifiable on the Linux CI runner.
- **CI proves evaluation only.** GPU/CUDA/model runtime needs the real hardware.

## Out of scope

Kubernetes / KServe / Ray / vLLM and GPU time-slicing - those belong to the K8s
layer, not NixOS service modules. This recipe is the node-level, declarative
model-serving host.
