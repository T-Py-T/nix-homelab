# DGX Spark GPU node (host: grace)

`grace` is the GPU model-serving node - a DGX Spark (NVIDIA Grace-Blackwell,
aarch64-linux).

## What's loaded

Profiles enabled in `machines/nixos/grace/homelab.nix`: `core` + `ai`, plus the
`homelab.gpu` capability.

- **core** - Prometheus, Grafana, node-exporter, Uptime Kuma, Homepage
- **ai** - **Ollama** (model backend, API at `ollama.<baseDomain>`) and
  **Open WebUI** (chat UI at `chat.<baseDomain>`)
- **homelab.gpu** - NVIDIA driver + CUDA + container toolkit (CDI); Ollama builds
  against `ollama-cuda` automatically

Preload models with `services.ollama.loadModels` (commented in the host file).

## Build and deploy

`grace` is aarch64; `just deploy` builds on the target, so a non-aarch64
workstation is fine.

1. **Hardware config** - replace `machines/nixos/grace/hardware-configuration.nix`
   with real output (`nixos-generate-config` on the DGX). Confirm the GB10
   driver: if the stock nixpkgs NVIDIA driver does not bind it, pin
   `homelab.gpu.package` to a newer/vendor driver.
2. **First install** (on the box): `nixos-install --flake github:T-Py-T/nix-homelab#grace`.
3. **Updates** (from your workstation): `just deploy grace`.
4. **Verify**: `nvidia-smi`, `systemctl status ollama`, `ollama run llama3.2`,
   and open `https://chat.<baseDomain>`.

CI evaluates `grace` on every run but does not build its aarch64/CUDA closure
(impractical on shared runners). To build it, run the `check` workflow's opt-in
`build host closure` job (Actions -> Run workflow -> host `grace`) pointed at a
self-hosted aarch64 runner, or just build on the DGX. Install + SSH mechanics:
[nixos.md](./nixos.md).
