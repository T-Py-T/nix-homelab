# Tasks: GPU/AI hosts + service profiles

Branch: `gpu-ai-hosts`.

## Phase 1 - Profiles engine (replaces importance tiers)

- [x] Add `homelab.services.profiles` (catalog) + `enabledProfiles` options.
- [x] Profile-union auto-enable (`mkDefault` per service) + assertions for
      unknown profiles/services.
- [x] Remove `tiers` + `mkImportance` from `modules/homelab/default.nix`.
- [x] Strip `importance` + the `homelabLib` arg from all service modules.
- [x] Migrate `alison` to `enabledProfiles`.
- [x] Add an "AI" category to the homepage dashboard.

## Phase 2 - AI + GPU

- [x] `modules/homelab/gpu/default.nix` (NVIDIA + CUDA + container toolkit).
- [x] `ollama` service module (CUDA when `homelab.gpu.enable`).
- [x] `open-webui` service module (points at ollama).
- [x] Imports + `ai` profile in the catalog.

## Phase 3 - Hosts

- [x] `machines/nixos/grace/` (DGX Spark, aarch64-linux) with `core`+`ai`+GPU.
- [x] `grace = "aarch64-linux"` in `systemArchMap`.

## Phase 4 - Verify

- [x] `nix flake check` green in CI (evaluates alison + grace, treefmt clean).
- [x] aarch64 + NVIDIA + ollama-cuda evaluates (no driver pin needed for eval).

## Phase 5 - Mac + docs

- [x] `machines/darwin/ada/configuration.nix` (Ollama via launchd/Metal),
      activation-gated (unwired; no flake input added here).
- [x] `docs/nixos.md`: profiles instead of tiers + GPU/AI serving section.
- [x] `docs/macos.md`: `ada` activation steps.
- [x] README: "profile" instead of "importance tier".

## Blocked / needs Taylor (see PRD)

- Real DGX Spark `hardware-configuration.nix` + GPU runtime verification
  (`nvidia-smi`, `ollama run`, Open WebUI). Confirm the GB10 driver situation so
  we can pin `homelab.gpu.package` if the stock driver does not bind it.
- `nix flake lock` for the `nix-darwin` input + `darwin-rebuild` on the Mac.
- Confirm hostnames (`grace`, `ada`), `baseDomain`, and DNS.
