# General homelab services (host: alison)

`alison` is the general-purpose node - everything that is not GPU/AI.

## What's loaded

Profiles enabled in `machines/nixos/alison/homelab.nix`: `core`, `media`, `arr`,
`downloads`, `productivity`, `git`, `comms`, `analytics`, `smarthome`, `net`.
That is:

- **core** - Prometheus, Grafana, node-exporter, Uptime Kuma, the Homepage dashboard
- **media** - Jellyfin, Audiobookshelf, Navidrome, Immich
- **arr / downloads** - Prowlarr, Sonarr, Radarr, Bazarr, Lidarr, Jellyseerr; Deluge, SABnzbd, slskd
- **productivity** - Nextcloud, Paperless, Radicale, Vaultwarden, Miniflux, Microbin
- **git / comms / analytics / smarthome / net** - Forgejo (+ runner), Matrix, Plausible, Home Assistant, RaspberryMatic, WireGuard netns

Each is reverse-proxied at `<service>.<baseDomain>` and listed on the Homepage
dashboard. Change what runs by editing `enabledProfiles` (or a per-service
`enable`) in `machines/nixos/alison/homelab.nix`.

## Build and deploy

From the dev shell (`nix develop`), with the host reachable over SSH as `admin`:

```sh
just check            # evaluate the flake
just deploy alison    # build on the target and switch
```

First-time install on a fresh box, the SSH config, and how profiles work: see
[nixos.md](./nixos.md).
