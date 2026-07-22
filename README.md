# nix-homelab

A modular NixOS homelab where each machine is a flake output and every service
is a self-contained module. Modelled on
[notthebee/nix-config](https://git.notthebe.ee/notthebee/nix-config).

## Overview

- **Modular services** - one module per service under `homelab.services.<name>`,
  exposed through a [Caddy](https://caddyserver.com) reverse proxy at
  `<service>.<baseDomain>` and auto-listed on a Homepage dashboard.
- **Importance tiers** - each service is tagged `high`, `medium`, or `low`. A
  host enables whole tiers via `enabledTiers`, so one box runs everything today
  and the fleet is split across machines later by load - no module changes.
- **Reproducible hosts** - drop a directory under `machines/nixos/<host>/` and it
  becomes `flake.nixosConfigurations.<host>` automatically; no flake edit.
- **LAN-friendly TLS** - Caddy issues internal certificates by default; opt into
  Let's Encrypt (Cloudflare DNS) once you have a public domain.
- **Simple deploys** - install a box once with `nixos-install`, then push every
  later change with `just deploy <host>`.

## Getting started

Quick path (your workstation already has Nix; a target machine can run NixOS):

```sh
git clone https://github.com/T-Py-T/nix-homelab
cd nix-homelab && nix develop        # dev shell: just + nixos-rebuild
```

Point the example host `alison` at your machine, then evaluate:

- swap in real hardware: `machines/nixos/alison/hardware-configuration.nix`
- pick services: `enabledTiers` in `machines/nixos/alison/homelab.nix`
- add your SSH key: `machines/nixos/_common/default.nix`

```sh
just check                                                 # evaluate the flake
nixos-install --flake github:T-Py-T/nix-homelab#alison     # on the target, once
just deploy alison                                         # every change after
```

Full walkthrough (partitioning, bootloader, SSH config, DNS/TLS) is in
[Set up the first box](#set-up-the-first-box).

## Layout

```
flake.nix                         # inputs + flake-parts entrypoint
justfile                          # build / deploy recipes
machines/                         # the hosts and their layered config
  nixos/
    default.nix                   # auto-discovers hosts -> nixosConfigurations
    _common/                      # config shared by every host (users, ssh, nix)
    <host>/
      configuration.nix           # host hardware/boot (+ imports homelab.nix)
      hardware-configuration.nix  # from `nixos-generate-config`
      homelab.nix                 # which service tiers this host runs
modules/                          # service / software definitions only
  devshell.nix                    # `nix develop` shell + `nix fmt` (treefmt)
  homelab/
    default.nix                   # `homelab.*` namespace + importance tiers
    motd/                         # login banner with live service status
    services/
      default.nix                 # reverse proxy (Caddy), podman, tier engine
      <service>/default.nix       # one module per service
```

Any directory under `machines/nixos/` that contains a `configuration.nix`
automatically becomes `flake.nixosConfigurations.<dirname>`, and its hostname is
set to the directory name. Adding a host needs no flake edit.

## How service selection works

Each service declares an importance tier in its module
(`importance = homelabLib.mkImportance "high"`). A host then enables whole tiers
at once; every service in an enabled tier turns on automatically.

- `high` - core infra, observability, critical data, the dashboard
- `medium` - general self-hosted apps and primary media
- `low` - the acquisition stack (arr/downloaders) and niche/infra bits

A host's `homelab.nix`:

```nix
homelab = {
  enable = true;
  baseDomain = "home.lan";
  services = {
    enable = true;
    enabledTiers = [ "high" "medium" "low" ];   # everything, for a single box

    # Per-service overrides always win over the tier default:
    #   jellyfin.enable = false;                 # pull one service out
    #   sonarr.enable = true;                    # pull one in
    prometheus.scrapeTargets = [ /* ... */ ];    # or just pass settings
  };
};
```

To spread the fleet later, give each host a different `enabledTiers` (a small
box gets `[ "high" ]`, a beefy one gets all three). No module changes needed.

Every enabled service registers a Caddy virtual host at `<service>.<baseDomain>`
and appears on the Homepage dashboard, grouped by category.

## Set up the first box

You need a machine that can run NixOS (bare metal or a VM) and a workstation to
drive deploys from. NixOS is installed once by hand; every change after that is
a one-line `just deploy`.

### 1. Prepare your workstation

Install Nix (the [Determinate Systems installer](https://determinate.systems)
is recommended), then clone the repo and enter the dev shell (it provides `just`
and `nixos-rebuild`; [direnv](https://direnv.net) loads it automatically via the
bundled `.envrc`):

```sh
git clone https://github.com/T-Py-T/nix-homelab
cd nix-homelab
nix develop            # or: direnv allow
```

### 2. Point the repo at your machine

The repo ships a ready example host, `alison`. Use it directly for your first
box, or copy it to a new name (`cp -r machines/nixos/alison machines/nixos/<host>`
- the directory name becomes the hostname). Then, in that host directory:

- **`hardware-configuration.nix`** - replace the placeholder with the real thing.
  Boot the target from the NixOS installer, partition and mount the disk at
  `/mnt`, then run `nixos-generate-config --root /mnt` and copy the generated
  `/mnt/etc/nixos/hardware-configuration.nix` into the host directory.
- **`configuration.nix`** - set the bootloader for your hardware. The example
  uses BIOS/GRUB on `/dev/vda`; for a modern UEFI machine use systemd-boot:

  ```nix
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  ```

- **`homelab.nix`** - set `baseDomain`, `timeZone`, and `enabledTiers`.

Finally add your SSH public key so you can log in and deploy. Edit
`machines/nixos/_common/default.nix` and replace the placeholder key on
`users.users.admin.openssh.authorizedKeys.keys` with your own. Commit the changes.

### 3. Install NixOS on the target

From the NixOS installer (disk mounted at `/mnt`, config committed and pushed),
install the whole flake config:

```sh
nixos-install --flake github:T-Py-T/nix-homelab#<host>
```

(Or clone the repo onto the installer and use `nixos-install --flake .#<host>`
if you would rather not push a half-configured tree.) Set a root password when
prompted, then `reboot`.

### 4. Make the host reachable, then deploy updates

The `admin` user has passwordless sudo and key-only SSH. Add an entry to your
workstation's `~/.ssh/config` so the host name resolves and connects as `admin`
with your key:

```
Host <host>
  HostName 192.168.1.50      # the box's IP or DNS name
  User admin
  IdentityFile ~/.ssh/id_ed25519
```

Confirm it evaluates, then apply every future change with a single command:

```sh
just check                  # nix flake check - evaluate all hosts
just dry-run <host>          # preview the activation (no changes)
just deploy <host>           # build on the target and switch
```

### 5. Reach the services

With no public domain, Caddy issues its own internal TLS certificates and the
service hostnames are not in DNS. On each client, point the names at the box
(e.g. in `/etc/hosts`) and trust Caddy's local CA:

```
192.168.1.50  home.lan grafana.home.lan git.home.lan photos.home.lan  # ...etc
```

Then open `https://home.lan` for the Homepage dashboard. To use real Let's
Encrypt certificates instead, see [TLS](#tls) below.

## Add another box

Once the first box is running, each additional machine is the same pattern with
a different tier selection - that is how load is spread across the fleet:

1. `cp -r machines/nixos/<existing> machines/nixos/<newhost>`.
2. Replace its `hardware-configuration.nix` (`nixos-generate-config` on the new
   machine) and set the bootloader in `configuration.nix`.
3. If it is a different CPU architecture, add it to `systemArchMap` in
   `machines/nixos/default.nix` (e.g. `<newhost> = "aarch64-linux";`).
4. In its `homelab.nix`, set `enabledTiers` to just the tiers this box should run
   (a low-power node might take only `[ "high" ]`; a NAS might take `[ "low" ]`
   for the download stack). Your key is already in `_common`, so no key edit.
5. Add an `~/.ssh/config` entry, then `nixos-install --flake ...#<newhost>` on
   the target and `just deploy <newhost>` from then on.

## TLS

By default Caddy issues its own **internal** certificates (`tls internal`),
ideal for a LAN with no public domain. To use real Let's Encrypt certificates
via the Cloudflare DNS-01 challenge:

```nix
homelab.reverseProxy.acme = {
  enable = true;
  email = "you@example.com";
  dnsCredentialsFile = "/run/secrets/cloudflare-dns"; # CF_DNS_API_TOKEN=...
};
```

## Commands

All recipes live in the `justfile` (run `just` to list them):

| Command | Description |
|---|---|
| `just check` | Evaluate the whole flake (`nix flake check`) |
| `just fmt` | Format the tree (nixfmt + deadnix + shellcheck) |
| `just build <host>` | Build a host's system closure locally |
| `just dry-run <host>` | Dry-activate on the target (no changes) |
| `just deploy <host>` | Build on the target and switch |
| `just boot <host>` | Apply on next boot |

`deploy`/`dry-run`/`boot` use `nixos-rebuild --target-host <host>`, so `<host>`
must be reachable over SSH as a user with passwordless sudo (see the SSH config
entry above).

## Adding a service

Create `modules/homelab/services/<name>/default.nix` following the existing
modules, then add it to the `imports` list in
`modules/homelab/services/default.nix`. The pattern:

```nix
{ config, lib, homelabLib, ... }:
let
  service = "myservice";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";
    importance = homelabLib.mkImportance "medium";   # high | medium | low
    url = lib.mkOption {
      type = lib.types.str;
      default = "myservice.${homelab.baseDomain}";
    };
    # homepage.{name,description,icon,category} make it appear on the dashboard
    homepage.name = lib.mkOption { type = lib.types.str; default = "My Service"; };
    homepage.description = lib.mkOption { type = lib.types.str; default = "..."; };
    homepage.icon = lib.mkOption { type = lib.types.str; default = "myservice.svg"; };
    homepage.category = lib.mkOption { type = lib.types.str; default = "Services"; };
  };

  config = lib.mkIf cfg.enable {
    services.myservice.enable = true;
    services.caddy.virtualHosts."${cfg.url}".extraConfig = ''
      ${homelab.mkCaddyTls}
      reverse_proxy http://127.0.0.1:1234
    '';
  };
}
```

Icons come from the [dashboard-icons](https://github.com/homarr-labs/dashboard-icons)
set that Homepage bundles.

## Secrets

Secrets are currently inline build-time placeholders (e.g. Miniflux admin
credentials, Grafana's secret key) so a host evaluates and boots out of the box.
**Change these before exposing any service.** Migrating to
[agenix](https://github.com/ryantm/agenix) - which encrypts secrets at rest and
decrypts them per host with each machine's SSH key - is the intended follow-up
once a second machine exists.

## Resources

- [notthebee/nix-config](https://git.notthebe.ee/notthebee/nix-config) - the reference this is modelled on
- [flake-parts](https://flake.parts)
- [NixOS + Flakes book](https://nixos-and-flakes.thiscute.world/)
