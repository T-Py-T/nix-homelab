# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Architecture Overview

A NixOS homelab built with **flake-parts** and deployed with **nixos-rebuild**.
Modelled on [notthebee/nix-config](https://git.notthebe.ee/notthebee/nix-config).

### Core components
- **machines/** holds hosts and their layered config; **modules/** holds only service/software definitions.
- **flake.nix**: inputs (`nixpkgs`, `flake-parts`, `treefmt-nix`) and the flake-parts entrypoint.
- **machines/nixos/default.nix**: auto-discovers each `<host>/configuration.nix`
  and produces `flake.nixosConfigurations.<host>`. No flake edit is needed to add a host.
- **machines/nixos/_common/**: baseline shared by all hosts (users, SSH, nix settings).
- **modules/homelab/**: the `homelab.*` option namespace and shared infrastructure.
- **modules/homelab/services/**: one module per service, each under `homelab.services.<name>`.

### The homelab namespace
- `homelab.enable`, `homelab.baseDomain`, `homelab.timeZone`, `homelab.user/group`, `homelab.mounts.*`
- `homelab.services.enable`: master switch that turns on Caddy + podman.
- `homelab.services.enabledTiers`: list of importance tiers (`high`/`medium`/`low`)
  to enable on a host. Every service whose `importance` is in the list turns on
  automatically (via `mkDefault`), so an explicit `<name>.enable` still wins.
- `homelab.services.<name>.enable`: per-service override.
- `homelab.services.<name>.importance`: the service's tier, declared with
  `homelabLib.mkImportance "<tier>"` (injected via `_module.args`).
- `homelab.reverseProxy.acme.*`: opt-in Let's Encrypt via Cloudflare DNS. Off by
  default -> Caddy uses `tls internal` (LAN-friendly).
- `homelab.mkCaddyTls`: read-only helper string that services inject into their
  Caddy `extraConfig` to apply the correct TLS directive.

### Service module pattern
```nix
let service = "<name>"; cfg = config.homelab.services.${service}; homelab = config.homelab; in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";
    importance = homelabLib.mkImportance "medium";   # high | medium | low
    url = lib.mkOption { type = lib.types.str; default = "<name>.${homelab.baseDomain}"; };
    homepage.{name,description,icon,category} = ...;   # dashboard metadata
  };
  config = lib.mkIf cfg.enable {
    services.<name>.enable = true;
    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:<port>
    '';
  };
}
```

## Development Commands

```bash
nix develop            # dev shell (just, nixos-rebuild)
just check             # nix flake check - evaluate all hosts
just fmt               # treefmt: nixfmt + deadnix + shellcheck
just build <host>      # build a host closure locally
just dry-run <host>    # dry-activate on the target host
just deploy <host>     # build on target + switch
```

## Adding things

### A new host
1. Copy an existing dir under `machines/nixos/` (e.g. `alison`).
2. Replace `hardware-configuration.nix` with `nixos-generate-config` output.
3. Edit `<host>/homelab.nix` for `baseDomain` and enabled services.
It is picked up automatically - no flake edit.

### A new service
1. Create `modules/homelab/services/<name>/default.nix` using the pattern above.
2. Add it to the `imports` list in `modules/homelab/services/default.nix`.
3. Enable it from a host's `homelab.nix`.

## Notes
- Prefer real upstream NixOS `services.*` modules; wrap them in the `homelab.services.<name>` namespace.
- Container-based services use podman (`virtualisation.oci-containers.backend = "podman"`).
- Secrets are currently inline build-time placeholders (Miniflux admin creds,
  Grafana `secretKeyFile`). Override these before exposing services; migrating to
  agenix is the intended follow-up.
```
