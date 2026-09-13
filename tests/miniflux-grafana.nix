{
  pkgs,
  sourceRevision ? "unknown",
}:
let
  flakeLockHash = builtins.hashFile "sha256" ../flake.lock;
  minifluxCredentials = pkgs.writeText "miniflux-admin-test.env" ''
    ADMIN_USERNAME=vm-test-admin
    ADMIN_PASSWORD=synthetic-test-only-password
  '';
  grafanaSecretKey = pkgs.writeText "grafana-test-secret-key" "synthetic-test-only-grafana-key";
in
pkgs.testers.runNixOSTest {
  name = "miniflux-grafana";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ../modules/homelab ];

      homelab = {
        enable = true;
        baseDomain = "test.invalid";
        services = {
          miniflux = {
            enable = true;
            url = "rss.test.invalid";
            adminCredentialsFile = minifluxCredentials;
          };
          grafana = {
            enable = true;
            url = "grafana.test.invalid";
            secretKeyFile = grafanaSecretKey;
          };
        };
      };

      environment.systemPackages = [
        pkgs.coreutils
        pkgs.curl
        pkgs.postgresql
        pkgs.sqlite
      ];

      # Software-emulated CI and local runners can take several minutes to
      # initialize PostgreSQL on first boot. Keep the dependent Miniflux start
      # job alive while that deterministic initialization completes.
      systemd.services.postgresql.serviceConfig.TimeoutStartSec = "10min";
    };

  testScript = ''
    import json
    import os
    import time
    from pathlib import Path

    marker = "nix-homelab-restore-evidence-v1"
    stage_durations_ms = {}
    assertions = []
    test_started = time.monotonic()

    def run_stage(name, action):
        started = time.monotonic()
        action()
        stage_durations_ms[name] = round((time.monotonic() - started) * 1000, 3)

    def start_and_seed():
        machine.start()
        machine.wait_for_unit("postgresql.service")
        machine.wait_for_unit("miniflux.service")
        machine.wait_for_unit("grafana.service")
        machine.wait_until_succeeds("curl --fail --silent http://127.0.0.1:8067/healthcheck")
        machine.wait_until_succeeds(
            "curl --fail --silent http://127.0.0.1:3000/api/health | grep --quiet '\"database\": *\"ok\"'"
        )
        machine.succeed(
            f"""runuser -u postgres -- psql --dbname=miniflux --set=ON_ERROR_STOP=1 --command="CREATE TABLE public.restore_evidence (marker text PRIMARY KEY); INSERT INTO public.restore_evidence(marker) VALUES ('{marker}');" """
        )
        machine.succeed("systemctl stop grafana.service")
        machine.succeed(
            f"""runuser -u grafana -- sqlite3 /var/lib/grafana/data/grafana.db "CREATE TABLE restore_evidence (marker text PRIMARY KEY); INSERT INTO restore_evidence(marker) VALUES ('{marker}');" """
        )
        machine.succeed("systemctl start grafana.service")
        machine.wait_for_unit("grafana.service")
        machine.wait_until_succeeds(
            "curl --fail --silent http://127.0.0.1:3000/api/health | grep --quiet '\"database\": *\"ok\"'"
        )

    run_stage("start_and_seed", start_and_seed)
    assertions.extend([
        "miniflux healthy before backup",
        "grafana healthy before backup",
        "exact synthetic marker written to both service databases",
    ])

    backup_sizes = {}
    backup_hashes = {}

    def create_backup():
        machine.succeed("install -d -m 0777 /tmp/restore-evidence-v1")
        machine.succeed(
            "runuser -u postgres -- pg_dump --format=custom --table=public.restore_evidence --file=/tmp/restore-evidence-v1/miniflux-marker.dump miniflux"
        )
        machine.succeed("systemctl stop grafana.service")
        machine.succeed(
            "runuser -u grafana -- sqlite3 /var/lib/grafana/data/grafana.db '.dump restore_evidence' > /tmp/restore-evidence-v1/grafana-marker.sql"
        )
        machine.succeed("systemctl start grafana.service")
        machine.wait_for_unit("grafana.service")
        for path in (
            "/tmp/restore-evidence-v1/miniflux-marker.dump",
            "/tmp/restore-evidence-v1/grafana-marker.sql",
        ):
            machine.succeed(f"""test "$(stat -c %s {path})" -gt 0""")
            machine.succeed(f"""test "$(stat -c %s {path})" -le 1048576""")

    run_stage("backup", create_backup)
    for service, path in {
        "miniflux": "/tmp/restore-evidence-v1/miniflux-marker.dump",
        "grafana": "/tmp/restore-evidence-v1/grafana-marker.sql",
    }.items():
        backup_sizes[service] = int(machine.succeed(f"stat -c %s {path}").strip())
        backup_hashes[service] = machine.succeed(f"sha256sum {path}").split()[0]
    assertions.append("both bounded marker backups are non-empty and no larger than 1 MiB")

    def inject_failure():
        machine.succeed(
            "runuser -u postgres -- psql --dbname=miniflux --set=ON_ERROR_STOP=1 --command='DROP TABLE public.restore_evidence;'"
        )
        machine.succeed("systemctl stop grafana.service")
        machine.succeed(
            "runuser -u grafana -- sqlite3 /var/lib/grafana/data/grafana.db 'DROP TABLE restore_evidence;'"
        )
        machine.succeed("systemctl start grafana.service")
        machine.wait_for_unit("grafana.service")
        machine.succeed(
            """test -z "$(runuser -u postgres -- psql --dbname=miniflux --tuples-only --no-align --command="SELECT to_regclass('public.restore_evidence');")" """
        )
        machine.succeed(
            """test "$(runuser -u grafana -- sqlite3 /var/lib/grafana/data/grafana.db "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='restore_evidence';")" = 0"""
        )

    run_stage("failure_injection", inject_failure)
    assertions.append("documented marker-table deletion removed both synthetic markers")

    def restore_and_verify():
        machine.succeed(
            "runuser -u postgres -- pg_restore --dbname=miniflux --exit-on-error /tmp/restore-evidence-v1/miniflux-marker.dump"
        )
        machine.succeed("systemctl stop grafana.service")
        machine.succeed(
            "runuser -u grafana -- sqlite3 /var/lib/grafana/data/grafana.db < /tmp/restore-evidence-v1/grafana-marker.sql"
        )
        machine.succeed("systemctl start grafana.service")
        machine.wait_for_unit("miniflux.service")
        machine.wait_for_unit("grafana.service")
        machine.wait_until_succeeds("curl --fail --silent http://127.0.0.1:8067/healthcheck")
        machine.wait_until_succeeds(
            "curl --fail --silent http://127.0.0.1:3000/api/health | grep --quiet '\"database\": *\"ok\"'"
        )
        machine.succeed(
            f"""runuser -u postgres -- psql --dbname=miniflux --tuples-only --no-align --command='SELECT marker FROM public.restore_evidence;' | grep --fixed-strings --line-regexp '{marker}'"""
        )
        machine.succeed(
            f"""runuser -u grafana -- sqlite3 /var/lib/grafana/data/grafana.db 'SELECT marker FROM restore_evidence;' | grep --fixed-strings --line-regexp '{marker}'"""
        )

    run_stage("restore_and_verify", restore_and_verify)
    assertions.extend([
        "miniflux healthy after restore",
        "grafana healthy after restore",
        "exact synthetic marker recovered from the Miniflux database",
        "exact synthetic marker recovered from the Grafana database",
    ])

    stage_durations_ms["total"] = round((time.monotonic() - test_started) * 1000, 3)
    evidence = {
        "schemaVersion": "1.0",
        "scenario": "bounded synthetic Miniflux and Grafana marker-table backup, deletion, and restore",
        "sourceRevision": "${sourceRevision}",
        "flakeLockSha256": "${flakeLockHash}",
        "guestArchitecture": machine.succeed("uname -m").strip(),
        "nixVersion": machine.succeed("nix --version").strip(),
        "marker": marker,
        "stageDurationsMs": stage_durations_ms,
        "backupSizesBytes": backup_sizes,
        "backupSha256": backup_hashes,
        "assertions": assertions,
        "result": "passed",
        "modelCalls": 0,
        "limitations": [
            "The drill restores synthetic marker tables only; it is not a full production backup.",
            "The drill does not use real hosts, service data, credentials, or private configuration.",
            "The observed durations describe one disposable aarch64 NixOS test run and are not an availability objective.",
        ],
    }
    out_path = Path(os.environ["out"])
    out_path.mkdir(parents=True, exist_ok=True)
    (out_path / "restore-evidence.json").write_text(
        json.dumps(evidence, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print("RESTORE_EVIDENCE_JSON=" + json.dumps(evidence, sort_keys=True))
  '';
}
