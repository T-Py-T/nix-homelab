# Planned services (TODO)

Services we intend to add, tracked here. Each item notes what it is and the
wiring it needs. Tick it once it lands as a `homelab.services.<name>` module (or
homelab module) wired into a profile.

## Next up

- [ ] **Komodo** - open-source alternative to Portainer for building and
  deploying software: manage **Docker Compose stacks**, standalone containers,
  builds, and alerting across hosts. Architecture is **Komodo Core** (web UI +
  API) plus a lightweight **Periphery** agent on each managed host, backed by a
  database (Mongo / FerretDB / SQLite / Postgres). It has no nixpkgs module, so
  add it as OCI containers via `virtualisation.oci-containers` (podman backend is
  already enabled by `homelab.services.enable`): a `homelab.services.komodo`
  module running Core + a DB container, reverse-proxied at `komodo.<baseDomain>`,
  with Periphery enabled on each host we want it to manage. Put it in a new
  `ops` profile (or `core`).

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
