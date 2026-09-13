# Test Miniflux and Grafana recovery on ARM64

This how-to runs a bounded recovery drill in a disposable ARM64 NixOS VM. The
test creates one synthetic marker in each service database. It backs up only
the marker tables, deletes them, restores them, and verifies the exact marker
and both health endpoints.

## Run the check

Use a clean checkout on an `aarch64-linux` system with Nix flakes enabled.

```sh
nix build .#checks.aarch64-linux.miniflux-grafana-vm \
  --print-build-logs \
  --out-link result-arm64-restore
```

The command boots a disposable NixOS test machine and runs these stages:

1. Start PostgreSQL, Miniflux, and Grafana. Verify both health endpoints.
2. Write `nix-homelab-restore-evidence-v1` to a dedicated table in each service
   database.
3. Export each marker table to a backup of at most 1 MiB.
4. Delete both marker tables and verify that they are absent.
5. Restore both tables. Verify the exact marker and both health endpoints.

Read the machine-readable result after the build succeeds:

```sh
cat result-arm64-restore/restore-evidence.json
```

The result records the source revision, the flake lock hash, the guest
architecture, the Nix version, stage durations, backup sizes and hashes, every
assertion, and the final status.

## Reproduce the check in UTM

Use a disposable clone instead of a VM that holds other work.

1. Clone a stopped ARM64 NixOS VM in UTM.
2. Keep the clone's inherited virtual hardware and network configuration.
3. Start only the clone. Confirm that `uname -m` reports `aarch64`.
4. Copy a clean checkout into a temporary guest directory.
5. Run the build command from that directory.
6. Copy `restore-evidence.json` into a bounded evidence packet.
7. Stop the clone after validation.

Do not run this check against a homelab host or a service database. The NixOS
test machine is disposable and contains only synthetic credentials and data.

## Interpret the evidence

The retained packet under `results/restore-evidence-v1/` binds one successful
run to the exact source revision, flake inputs, ARM64 guest, assertions, and
observed stage durations. The manifest hashes every retained artifact.

The drill proves only the marker-table recovery path. It does not prove a full
PostgreSQL or Grafana backup, recovery of real data, a recovery time objective,
or production readiness. Run a separate authorized drill before making any of
those claims.
