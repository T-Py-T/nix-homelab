# Tasks: GPU/AI hosts + service profiles

Branch: `gpu-ai-hosts`. Check items off as they land.

## Phase 1 - Profiles engine (replaces importance tiers)

- [ ] Add `homelab.services.profiles` (attrset catalog) and
      `homelab.services.enabledProfiles` options.
- [ ] Replace the tier auto-enable with a profile-union auto-enable
      (`mkDefault true` per enabled service) + assertions for unknown
      profiles/services.
- [ ] Remove `tiers` + `mkImportance` from `modules/homelab/default.nix`.
- [ ] Strip `importance = homelabLib.mkImportance ...` from all service modules
      and drop the now-unused `homelabLib` arg.
- [ ] Migrate `alison` to `enabledProfiles`.
- [ ] Add an "AI" category to the homepage dashboard.

## Phase 2 - AI + GPU

- [ ] `modules/homelab/gpu/default.nix`: `homelab.gpu` (NVIDIA + CUDA +
      container toolkit).
- [ ] `modules/homelab/services/ollama/default.nix`: `homelab.services.ollama`
      (CUDA when `homelab.gpu.enable`), Caddy vhost, homepage (AI).
- [ ] `modules/homelab/services/open-webui/default.nix`:
      `homelab.services.open-webui` (points at ollama), Caddy vhost, homepage (AI).
- [ ] Add both to the services `imports`; add `ai` to the profile catalog.

## Phase 3 - Hosts

- [ ] `machines/nixos/grace/` (DGX Spark, aarch64-linux): configuration.nix,
      hardware-configuration.nix (placeholder), homelab.nix (`core`+`ai`, GPU).
- [ ] Add `grace = "aarch64-linux"` to `systemArchMap`.

## Phase 4 - Verify

- [ ] `nix flake check` green in CI (push branch, watch).
- [ ] React to any aarch64/NVIDIA eval issues (pin driver / degrade module).

## Phase 5 - Mac + docs

- [ ] `machines/darwin/ada/` nix-darwin config (Ollama via launchd/Metal),
      activation-gated (unwired, no flake input added here).
- [ ] Update `docs/nixos.md` (profiles instead of tiers) and add GPU/AI serving.
- [ ] Update `docs/macos.md` with the `ada` activation steps.
- [ ] Final formatting + push.

## Blocked / needs Taylor (see PRD)

- Real DGX Spark hardware-configuration + GPU runtime verification.
- `nix flake lock` for the `nix-darwin` input + Mac deploy.
- Confirm hostnames, baseDomain, DNS.
