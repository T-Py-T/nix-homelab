{
  lib,
  self,
  ...
}:
# ============================================================================
# NIXOS MACHINE LOADER
#
# Every directory under this one that contains a `configuration.nix` is
# automatically turned into an entry in `flake.nixosConfigurations`. To add a
# new host you only need to create `machines/nixos/<name>/` with a
# `configuration.nix` (and usually a `hardware-configuration.nix`) - no edits
# to the flake are required.
# ============================================================================
let
  entries = builtins.attrNames (builtins.readDir ./.);
  configs = builtins.filter (dir: builtins.pathExists (./. + "/${dir}/configuration.nix")) entries;

  # Per-host CPU architecture. Anything not listed here defaults to x86_64.
  systemArchMap = {
    # example: rpi = "aarch64-linux";
  };
in
{
  flake.nixosConfigurations = lib.listToAttrs (
    builtins.map (
      name:
      lib.nameValuePair name (
        self.inputs.nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit (self) inputs;
          };

          modules = [
            {
              networking.hostName = name;
              nixpkgs.hostPlatform = lib.attrsets.attrByPath [ name ] "x86_64-linux" systemArchMap;
            }
            ../../modules/homelab
            (./. + "/_common/default.nix")
            (./. + "/${name}/configuration.nix")
          ];
        }
      )
    ) configs
  );
}
