{ pkgs }:
let
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

      environment.systemPackages = [ pkgs.curl ];

      # Software-emulated CI and local runners can take several minutes to
      # initialize PostgreSQL on first boot. Keep the dependent Miniflux start
      # job alive while that deterministic initialization completes.
      systemd.services.postgresql.serviceConfig.TimeoutStartSec = "10min";
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("miniflux.service")
    machine.wait_for_unit("grafana.service")
    machine.wait_until_succeeds("curl --fail --silent http://127.0.0.1:8067/healthcheck")
    machine.wait_until_succeeds("curl --fail --silent http://127.0.0.1:3000/api/health | grep --quiet '\"database\": *\"ok\"'")
  '';
}
