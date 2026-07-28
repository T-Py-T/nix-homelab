# Planned services (TODO)

Services we intend to add, tracked here. Each item notes what it is and the
wiring it needs. Tick it once it lands as a `homelab.services.<name>` module (or
homelab module) wired into a profile.

## Landed

- [x] **Komodo** - Docker Compose stack & deployment manager (open-source
  Portainer alternative). `homelab.services.komodo` runs Komodo **Core** + **Mongo**
  as podman containers plus the native `services.komodo-periphery` agent, in the
  new `ops` profile (enabled on `alison`), at `komodo.<baseDomain>`. The homelab
  **Forgejo** is wired in as a git provider (mounted Core config) so Stacks/Syncs
  are version-controlled and auto-deploy on push.

  Komodo is configured partly in its own UI by design, so after deploy:
  - Replace the placeholder secrets in the module (Mongo password, admin
    password, Core<->Periphery passkey, Forgejo token).
  - Create a `komodo` user + access token in Forgejo for the git provider.
  - Add this host as a Server in the Komodo UI (Core <-> Periphery pairing).
  - Verify Periphery reaches the podman socket and `docker compose` works under
    podman for stack deploys.

## From the reference (notthebee/nix-config), not yet ported

Non-AI services he runs that we do not have yet (confirmed against his active
imports):

- [ ] **keycloak** - SSO / identity provider (auth for the fleet). nixpkgs
  `services.keycloak` + PostgreSQL + an admin/DB secret + his custom login theme
  and "trusted-device" patch.
- [ ] **invoiceplane** - self-hosted invoicing (PHP). Needs a **custom flake
  input** (`git+https://git.notthebe.ee/notthebee/invoiceplane-nixos`); not in
  nixpkgs.
- [ ] **shelly_plug_exporter** - Prometheus exporter for Shelly smart-plug power
  metrics. Custom Go package; only useful if you own Shelly plugs.

He also ships `arr/lidarr` and `deemix` but has them commented out. We already
run `lidarr`; `deemix` (Deezer downloader) is not planned.

## Node features (not `services/`, but part of a full node)

- [x] **tailscale** - mesh VPN on every NixOS node (via `_common`; run
  `sudo tailscale up` once per host, or set an auth key).
- [ ] **samba** - SMB / NAS file shares.
- [ ] **backup** - restic backups (local + S3).
- [ ] **fail2ban-cloudflare** - fail2ban with Cloudflare integration.
- [ ] **frp / networks** - reverse-proxy tunnel to expose services via a VPS
  (we use plain Caddy today).

## Conventions for adding one

- Container-based services use `virtualisation.oci-containers` (podman); native
  services wrap the upstream `services.*` module. See the pattern in
  [nixos.md](./nixos.md#adding-a-service).
- Add each behind a profile in `homelab.services.profiles` so hosts opt in.
- Secrets stay inline build-time placeholders until agenix lands - override
  before exposing anything.
