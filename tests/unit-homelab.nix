# Pure Nix unit tests for homelab profile and TLS helpers.
{
  pkgs,
  lib,
}:
let
  inherit (import ./lib.nix { inherit pkgs; }) mkEval minifluxCredentials grafanaSecretKey;

  testSpecs = {
    caddyTlsUsesInternalByDefault = {
      expr =
        let
          evaluated = mkEval {
            modules = [
              {
                homelab.enable = true;
                homelab.services.enable = true;
              }
            ];
          };
        in
        evaluated.config.homelab.mkCaddyTls;
      expected = "tls internal";
    };

    productivityProfileEnablesMiniflux = {
      expr =
        let
          evaluated = mkEval {
            modules = [
              {
                homelab.enable = true;
                homelab.baseDomain = "test.invalid";
                homelab.services.enable = true;
                homelab.services.enabledProfiles = [ "productivity" ];
                homelab.services.miniflux.adminCredentialsFile = minifluxCredentials;
              }
            ];
          };
        in
        evaluated.config.homelab.services.miniflux.enable;
      expected = true;
    };

    coreProfileEnablesGrafana = {
      expr =
        let
          evaluated = mkEval {
            modules = [
              {
                homelab.enable = true;
                homelab.baseDomain = "test.invalid";
                homelab.services.enable = true;
                homelab.services.enabledProfiles = [ "core" ];
                homelab.services.grafana.secretKeyFile = grafanaSecretKey;
              }
            ];
          };
        in
        evaluated.config.homelab.services.grafana.enable;
      expected = true;
    };

    unknownProfileSurfacesAssertion = {
      expr =
        let
          evaluated = mkEval {
            modules = [
              {
                homelab.enable = true;
                homelab.services.enable = true;
                homelab.services.enabledProfiles = [ "not-a-real-profile" ];
              }
            ];
          };
        in
        lib.any (
          assertion: !assertion.assertion && lib.hasInfix "unknown profile" (lib.toLower assertion.message)
        ) evaluated.config.assertions;
      expected = true;
    };

    gpuHostSelectsDistinctOllamaPackage = {
      expr =
        let
          gpuEval = mkEval {
            modules = [
              {
                homelab.enable = true;
                homelab.baseDomain = "test.invalid";
                homelab.gpu.enable = true;
                homelab.services.enable = true;
                homelab.services.ollama.enable = true;
              }
            ];
          };
          cpuEval = mkEval {
            modules = [
              {
                homelab.enable = true;
                homelab.baseDomain = "test.invalid";
                homelab.services.enable = true;
                homelab.services.ollama.enable = true;
              }
            ];
          };
        in
        gpuEval.config.services.ollama.package.drvPath != cpuEval.config.services.ollama.package.drvPath;
      expected = true;
    };
  };

  results = lib.mapAttrs (
    _name: spec:
    spec
    // {
      passed = spec.expr == spec.expected;
    }
  ) testSpecs;

  failed = lib.filterAttrs (_: result: !result.passed) results;
in
pkgs.runCommand "homelab-unit-tests" { } ''
  set -euo pipefail
  ${lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: result: if result.passed then "echo \"PASS ${name}\"" else "echo \"FAIL ${name}\""
    ) results
  )}
  if [ ${toString (builtins.length (builtins.attrNames failed))} -ne 0 ]; then
    echo "homelab unit tests failed: ${lib.concatStringsSep ", " (builtins.attrNames failed)}"
    exit 1
  fi
  touch "$out"
''
