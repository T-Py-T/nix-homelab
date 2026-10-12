{
  pkgs,
  sourceRevision ? "unknown",
}:
pkgs.testers.runNixOSTest {
  name = "microbin";

  nodes.machine =
    { ... }:
    {
      imports = [ ../modules/homelab ];

      homelab = {
        enable = true;
        baseDomain = "test.invalid";
        services = {
          enable = true;
          enabledProfiles = [ ];
          microbin.enable = true;
        };
      };

      environment.systemPackages = [
        pkgs.curl
        pkgs.coreutils
      ];
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("microbin.service")
    machine.wait_until_succeeds("curl --fail --silent http://127.0.0.1:8069/")
    machine.succeed("test -n '${sourceRevision}'")
  '';
}
