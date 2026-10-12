# Regression checks for Matrix LiveKit homeserver matching and RaspberryMatic
# dependency on Home Assistant.
{
  pkgs,
  lib,
}:
let
  homelabModule = import ../modules/homelab;

  mkHost =
    extra:
    lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        homelabModule
        {
          fileSystems."/" = {
            device = "dummy";
            fsType = "ext4";
          };
          boot.loader.grub.enable = false;
        }
        extra
      ];
    };

  matrixHost = mkHost {
    homelab.enable = true;
    homelab.baseDomain = "example.test";
    homelab.services.enable = true;
    homelab.services.matrix.enable = true;
  };

  matrixCfg = matrixHost.config;
  serverName = matrixCfg.services.matrix-synapse.settings.server_name;
  livekitHomeservers =
    matrixCfg.systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS;

  raspberrymaticWithoutHa = mkHost {
    homelab.enable = true;
    homelab.services.enable = true;
    homelab.services.homeassistant.enable = false;
    homelab.services.raspberrymatic.enable = true;
  };

  failedAssertions = lib.filter (a: !a.assertion) raspberrymaticWithoutHa.config.assertions;

  assertOrFail =
    name: cond: msg:
    if cond then "" else "FAIL: ${name}: ${msg}\n";

  report =
    assertOrFail "matrix-livekit-homeserver" (serverName == livekitHomeservers)
      "expected LIVEKIT_FULL_ACCESS_HOMESERVERS (${livekitHomeservers}) to equal Synapse server_name (${serverName})"
    + assertOrFail "raspberrymatic-requires-homeassistant" (lib.any
      (a: lib.hasInfix "homeassistant" (lib.toLower a.message))
      failedAssertions
    ) "expected a failing assertion mentioning homeassistant when raspberrymatic is enabled alone";
in
pkgs.runCommand "matrix-raspberrymatic-regression" { } ''
    failures=$(
      cat <<'EOF'
  ${report}EOF
    )
    if [ -n "$failures" ]; then
      printf '%s' "$failures"
      exit 1
    fi
    echo "matrix-raspberrymatic regression checks passed"
    touch $out
''
