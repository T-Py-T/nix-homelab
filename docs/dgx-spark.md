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

## Confirm the build without the DGX

`grace` is Linux, so its closure builds anywhere with the right architecture -
no DGX and no GPU needed (building CUDA is compilation, not execution):

- **Container (devpod):** the `.devcontainer` runs `nixos/nix`. On Apple Silicon
  it is native aarch64 Linux, so from the repo root:
  `nix build .#nixosConfigurations.grace.config.system.build.toplevel`
  (give Docker enough disk - CUDA closures are large).
- **CI:** run the `check` workflow with host `grace` (Actions -> Run workflow);
  it builds on a native `ubuntu-24.04-arm` runner. A full CUDA build may exceed a
  shared runner's disk - point `runs-on` at a self-hosted aarch64 runner for
  heavy builds.

Install + SSH mechanics: [nixos.md](./nixos.md).
