# nix-homelab

A modular, extensible NixOS homelab. Each machine is a flake output built with
[flake-parts](https://flake.parts), and every service is a self-contained
module under the `homelab.*` option namespace. Services are grouped into
**importance tiers**, so a host turns on whole classes of services at once
(and can still override any single one). Adding a new service is a single
`default.nix`.

The architecture follows [notthebee/nix-config](https://git.notthebe.ee/notthebee/nix-config).

## Layout

```
flake.nix                         # inputs + flake-parts entrypoint
justfile                          # build / deploy recipes
machines/                         # the hosts (machines) and their layered config
  nixos/
    default.nix                   # auto-discovers hosts -> nixosConfigurations
    _common/                      # config shared by every host (users, ssh, nix)
    <host>/
      configuration.nix           # host hardware/boot (+ imports homelab.nix)
      hardware-configuration.nix  # from `nixos-generate-config`
      homelab.nix                 # which services this host runs
modules/                          # service / software definitions only
  devshell.nix                    # `nix develop` shell + `nix fmt` (treefmt)
  homelab/
    default.nix                   # `homelab.*` namespace + shared user/group
    motd/                         # login banner with live service status
    services/
      default.nix                 # reverse proxy (Caddy), podman, service imports
      <service>/default.nix       # one module per service
```

## How it works

Every directory under `machines/nixos/` that contains a
`configuration.nix` automatically becomes an entry in
`flake.nixosConfigurations` - no flake edits needed to add a host.

Each host imports the `homelab` module, which provides the `homelab.*` options.
A host's `homelab.nix` selects and configures services, e.g.:

```nix
homelab = {
  enable = true;
  baseDomain = "home.lan";
  services = {
    enable = true;
    # Turn on whole tiers at once ...
    enabledTiers = [ "high" "medium" ];
    # ... and still override individual services when you need to.
    forgejo.enable = true;   # force on regardless of tier
    slskd.enable = false;    # force off even if its tier is enabled
  };
};
```

### Importance tiers

Each service declares an `importance` tier in its module:

| Tier | Meaning |
|---|---|
| `high` | Core infrastructure, observability, critical data, the dashboard |
| `medium` | General self-hosted apps and primary media |
| `low` | Acquisition stack (arr/downloaders) and niche/infra bits |

A host opts tiers in with `homelab.services.enabledTiers`; every service in an
enabled tier switches on automatically. An explicit
`homelab.services.<name>.enable` on the host always wins over the tier default,
so you can pull a single service in or out without touching a whole tier.

This is how the fleet scales: run every tier on one box today, and as more
machines come online hand each host a different set of tiers to spread the
load by criticality.

Every enabled service registers a [Caddy](https://caddyserver.com) virtual host
at `<service>.<baseDomain>` and shows up automatically on the Homepage
dashboard, grouped by category.

### TLS

By default Caddy issues its own **internal** certificates (`tls internal`),
which is ideal for a LAN with no public domain. Point the service hostnames at
the host via `/etc/hosts` or local DNS and trust Caddy's local CA.

To use real Let's Encrypt certificates via the Cloudflare DNS challenge:

```nix
homelab.reverseProxy.acme = {
  enable = true;
  email = "you@example.com";
  dnsCredentialsFile = "/run/secrets/cloudflare-dns"; # CF_DNS_API_TOKEN=...
};
```

## Getting started

Install Nix (the [Determinate Systems installer](https://determinate.systems/)
is recommended). With [direnv](https://direnv.net) the included `.envrc` loads
the dev shell automatically; otherwise run `nix develop`.

1. Copy `machines/nixos/alison` to a new directory named after your host.
2. Replace `hardware-configuration.nix` with the output of
   `nixos-generate-config` on the target machine.
3. Put your SSH public key in `machines/nixos/_common/default.nix`.
4. Edit `<host>/homelab.nix` to set `baseDomain` and pick `services.enabledTiers`
   (and any per-service overrides).
5. Deploy.

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
must be reachable over SSH as a user with passwordless sudo.

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
    # Importance tier: high | medium | low. Hosts enable services by tier.
    importance = homelabLib.mkImportance "medium";
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

## Bundled services

| Service | Tier | Default hostname |
|---|---|---|
| Forgejo | `high` | `git.<baseDomain>` |
| Grafana | `high` | `grafana.<baseDomain>` |
| Homepage | `high` | `<baseDomain>` |
| Immich | `high` | `photos.<baseDomain>` |
| Nextcloud | `high` | `cloud.<baseDomain>` |
| Node Exporter | `high` | (scraped directly, not proxied) |
| Paperless-ngx | `high` | `paperless.<baseDomain>` |
| Prometheus | `high` | `prometheus.<baseDomain>` |
| Radicale | `high` | `cal.<baseDomain>` |
| Uptime Kuma | `high` | `uptime.<baseDomain>` |
| Vaultwarden | `high` | `pass.<baseDomain>` |
| Audiobookshelf | `medium` | `audiobooks.<baseDomain>` |
| Forgejo Runner | `medium` | `cache.<baseDomain>` (attic) |
| Home Assistant | `medium` | `home.<baseDomain>` |
| Jellyfin | `medium` | `jellyfin.<baseDomain>` |
| Matrix | `medium` | `chat.<baseDomain>` |
| MicroBin | `medium` | `bin.<baseDomain>` |
| Miniflux | `medium` | `rss.<baseDomain>` |
| Navidrome | `medium` | `music.<baseDomain>` |
| Plausible | `medium` | `numbers.<baseDomain>` |
| Bazarr | `low` | `bazarr.<baseDomain>` |
| Deluge | `low` | `deluge.<baseDomain>` |
| Jellyseerr | `low` | `jellyseerr.<baseDomain>` |
| Lidarr | `low` | `lidarr.<baseDomain>` |
| Prowlarr | `low` | `prowlarr.<baseDomain>` |
| Radarr | `low` | `radarr.<baseDomain>` |
| RaspberryMatic | `low` | `ccu.<baseDomain>` |
| SABnzbd | `low` | `sabnzbd.<baseDomain>` |
| slskd | `low` | `slskd.<baseDomain>` |
| Sonarr | `low` | `sonarr.<baseDomain>` |
| WireGuard netns | `low` | (infra, no vhost) |

## Resources

- [notthebee/nix-config](https://git.notthebe.ee/notthebee/nix-config) - the reference this is modelled on
- [flake-parts](https://flake.parts)
- [NixOS + Flakes book](https://nixos-and-flakes.thiscute.world/)
