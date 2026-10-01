# Hireability and discoverability

> Tip-cite bank: base main `1cb38c4` (Ship 264) + Ship 268 pending Steward; provenance
> only; never `READY`.

This page orients reviewers and search tools on **nix-homelab** without claiming
release readiness, operational authorization, benchmark scores, or a homelab
“bake-off” result.

## Purpose

Public, reproducible NixOS homelab configuration built with flake-parts: shared
host baselines, per-machine hardware and service selection, and reusable
`homelab.services.*` modules behind Caddy. Runtime secrets stay outside the
repository; the layout follows patterns from
[notthebee/nix-config](https://git.notthebee.ee/notthebee/nix-config) adapted
for this environment.

## Stack (operating model)

| Area | Technologies |
| --- | --- |
| OS & packaging | NixOS, nix-darwin (macOS sub-flake) |
| Flake structure | flake-parts, auto-discovered `nixosConfigurations` |
| Services | Modular `homelab.services.*` with importance tiers |
| Reverse proxy | Caddy (`tls internal` or optional ACME) |
| Containers | Podman (`oci-containers` backend) |
| Operations | `just` build, dry-run, deploy, and `nix flake check` |

Concrete hostnames, secret values, and production-only tuning belong on target
machines or private overlays, not in this public tree.

## Smallest verifiable demo

This repository evaluates locally and in CI; it does not activate a homelab host
or read real secret files.

```bash
git clone https://github.com/T-Py-T/nix-homelab.git
cd nix-homelab
nix develop
just fmt
nix flake check --no-build
```

On ARM64 Linux, the synthetic Miniflux/Grafana VM check can be built as described
in [README.md](../README.md#validation). That path uses disposable test machines
and synthetic credentials; it is not live homelab evidence.

## Review path (hiring-oriented)

1. [README.md](../README.md) — layout, service tiers, getting started, and validation
   framing.
2. [nixos.md](nixos.md) — profiles, TLS, commands, and runtime secret paths.
3. [operability.md](operability.md) — recovery drill procedure and evidence limits.
4. [`machines/nixos/`](../machines/nixos/) and [`modules/homelab/`](../modules/homelab/) —
   host discovery and service module pattern.

This shows inspectable infrastructure-as-code and bounded checks; it implies no
score or `READY` status.

## Suggested GitHub topics

Repository maintainers may apply topic tags such as:

`nixos`, `nix`, `homelab`, `flake-parts`, `infrastructure-as-code`, `caddy`,
`devops`

Topics aid search only; they do not certify operational readiness or results.

## License

Repository configuration and documentation are under the
[MIT License](../LICENSE). See the license file and project history for
upstream provenance.

## Related docs

| Document | Role |
| --- | --- |
| [../README.md](../README.md) | Overview, layout, and validation commands |
| [nixos.md](nixos.md) | NixOS operations, TLS, and secrets |
| [operability.md](operability.md) | Synthetic recovery drill and limits |
| [general-homelab.md](general-homelab.md) | General services host notes |
| [dgx-spark.md](dgx-spark.md) | GPU and model-serving host notes |
| [macos.md](macos.md) | nix-darwin host notes |
| [../SECURITY.md](../SECURITY.md) | Reporting sensitive material in this public repo |

Related public repositories:
[`kubernetes-gitops-homelab`](https://github.com/T-Py-T/kubernetes-gitops-homelab),
[`devops-install-scripts`](https://github.com/T-Py-T/devops-install-scripts).
