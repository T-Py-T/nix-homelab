# Running the homelab on NixOS

The homelab hosts run NixOS. Each machine is a flake output, and services are
chosen per host by profile. This guide covers installing a box,
deploying changes, extending the fleet, and the day-to-day options.

## Service selection (profiles)

Services are chosen per host by **profile** - a named bundle of services defined
centrally in `modules/homelab/services/default.nix` (`homelab.services.profiles`).
A host lists the profiles it should run; every service in those profiles turns on
automatically.

Built-in profiles include `core` (monitoring + dashboard), `ai` (Ollama + Open
WebUI), `media`, `arr`, `downloads`, `productivity`, `git`, `comms`, `analytics`,
`smarthome`, and `net`. Edit or extend `homelab.services.profiles` to define your
own - there is no fixed set.

A host's `homelab.nix`:

```nix
homelab = {
  enable = true;
  baseDomain = "home.lan";
  services = {
    enable = true;
    enabledProfiles = [ "core" "media" "arr" ];  # the bundles this host runs

    # Per-service overrides always win over the profile default:
    #   jellyfin.enable = false;                  # pull one service out
    #   sonarr.enable = true;                      # pull one in
    prometheus.scrapeTargets = [ /* ... */ ];      # or just pass settings
  };
};
```

Unknown profile names or services fail evaluation with a clear error. To split
the fleet, give each host the profiles it should run - no module changes needed.

Every enabled service registers a [Caddy](https://caddyserver.com) virtual host
at `<service>.<baseDomain>` and appears on the Homepage dashboard, grouped by
category. New hosts are discovered automatically: any directory under
`machines/nixos/` with a `configuration.nix` becomes
`flake.nixosConfigurations.<dirname>`, and its hostname is the directory name.

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

- **`homelab.nix`** - set `baseDomain`, `timeZone`, and `enabledProfiles`.

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
4. In its `homelab.nix`, set `enabledProfiles` to just the profiles this box
   should run (a GPU node might take `[ "core" "ai" ]`; a NAS `[ "media" "arr"
   "downloads" ]`). Your key is already in `_common`, so no key edit.
5. Add an `~/.ssh/config` entry, then `nixos-install --flake ...#<newhost>` on
   the target and `just deploy <newhost>` from then on.

## GPU / AI model serving

The `ai` profile serves LLMs locally: **Ollama** (model backend, API at
`ollama.<baseDomain>`) and **Open WebUI** (chat UI at `chat.<baseDomain>`). On a
host with an NVIDIA GPU, enable `homelab.gpu` and Ollama automatically builds
against CUDA:

```nix
homelab = {
  enable = true;
  gpu.enable = true;                    # NVIDIA driver + CUDA + container toolkit
  services = {
    enable = true;
    enabledProfiles = [ "core" "ai" ];
    # ollama.loadModels = [ "llama3.2" ];   # optional: pull models on first boot
  };
};
```

`homelab.gpu` wires the NVIDIA driver, CUDA userspace, and the container toolkit
(CDI) - the same enablement a Kubernetes GPU worker builds on. Without a GPU the
`ai` profile still works (Ollama falls back to the CPU build).

The example GPU node is `grace` (a DGX Spark, aarch64). For a Mac Studio serving
models on Metal, see the `ada` host in [macos.md](./macos.md).

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
entry above). Recipes that build locally (`build`, `dry-run`) cannot run on a
macOS workstation - see [macos.md](./macos.md).

## Adding a service

Create `modules/homelab/services/<name>/default.nix` following the existing
modules, then add it to the `imports` list in
`modules/homelab/services/default.nix`. The pattern:

```nix
{ config, lib, ... }:
let
  service = "myservice";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";
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

List the new service in a profile (`homelab.services.profiles`) or enable it
directly on a host to turn it on. Icons come from the
[dashboard-icons](https://github.com/homarr-labs/dashboard-icons) set that
Homepage bundles.

## Secrets

Secrets are currently inline build-time placeholders (e.g. Miniflux admin
credentials, Grafana's secret key) so a host evaluates and boots out of the box.
**Change these before exposing any service.** Migrating to
[agenix](https://github.com/ryantm/agenix) - which encrypts secrets at rest and
decrypts them per host with each machine's SSH key - is the intended follow-up
once a second machine exists.
