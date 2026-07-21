# Repository Guidelines

This homelab is a NixOS flake built with flake-parts and deployed with
`nixos-rebuild`. Keep host reproducibility and the modular service pattern
front of mind.

## Project Structure & Module Organization
- Top-level `machines/` holds the hosts (machines) and their layered config; `modules/` holds only service/software definitions. Never put host definitions under `modules/`.
- `flake.nix` wires inputs and imports the flake-parts modules.
- `machines/nixos/default.nix` auto-discovers every `<host>/configuration.nix`
  and exposes it as `flake.nixosConfigurations.<host>`. Adding a host needs no flake edit.
- `machines/nixos/_common/` holds config shared by all hosts (users, SSH, nix daemon).
- Per-host config lives in `machines/nixos/<host>/`: `configuration.nix`
  (hardware/boot), `hardware-configuration.nix`, and `homelab.nix` (service selection).
- Services live in `modules/homelab/services/<name>/default.nix`, exposed under the
  `homelab.services.<name>` option namespace, and imported from
  `modules/homelab/services/default.nix`.
- Each service declares an importance tier with `homelabLib.mkImportance "<tier>"`
  (`high`/`medium`/`low`). Hosts enable services in bulk via
  `homelab.services.enabledTiers`; explicit `<name>.enable` overrides the tier.
- Shared homelab settings and the reverse proxy live in `modules/homelab/default.nix`
  and `modules/homelab/services/default.nix`.

## Build, Test, and Development Commands
- `nix develop` (or direnv) enters the dev shell with `just` and `nixos-rebuild`.
- `just check` / `nix flake check` evaluates every host and the formatter config.
- `just build <host>` builds a host closure locally without deploying.
- `just dry-run <host>` dry-activates on the target; `just deploy <host>` switches.
- `just fmt` / `nix fmt` runs treefmt (nixfmt-rfc-style, deadnix, shellcheck).

## Coding Style & Naming Conventions
- Two-space indentation; format with `nix fmt` before committing.
- Each service module starts with `let service = "<name>"; cfg = config.homelab.services.${service}; in`.
- Service modules take `homelabLib` as a module arg and declare
  `importance = homelabLib.mkImportance "<tier>";` alongside `enable`.
- Expose user-tunable settings via `lib.mkOption` with sensible defaults.
- Every user-facing service should define `homepage.{name,description,icon,category}`
  so it appears on the Homepage dashboard.
- Reverse-proxied services register `services.caddy.virtualHosts.<url>` and inject
  `${config.homelab.mkCaddyTls}` as the first line of `extraConfig`.
- Section banners use `# ===`/`# ---`; keep `options` above `config`.

## Testing Guidelines
- Run `just check` before every review; it must evaluate cleanly for all hosts.
- For behavioural changes, run `just dry-run <host>` and note the result in the PR.
- New services: confirm the Caddy vhost and (if applicable) the Homepage entry appear.

## Commit & Pull Request Guidelines
- Short, lower-case imperative commit summaries (e.g. `add vaultwarden service`).
- PRs should explain motivation, list affected hosts/services, and call out any
  required secrets, DNS, or `/etc/hosts` entries.
