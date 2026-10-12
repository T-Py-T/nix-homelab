# Shared helpers for pure evaluation checks against this flake.
{
  flake ? builtins.getFlake (toString ../../.),
}:
let
  lib = flake.inputs.nixpkgs.lib;
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  homelabModule = flake + "/modules/homelab";

  mkHomelab =
    modules:
    lib.nixosSystem {
      specialArgs = {
        inherit pkgs;
        inputs = flake.inputs;
      };
      modules = [
        homelabModule
        {
          nixpkgs.hostPlatform = "x86_64-linux";
        }
      ]
      ++ modules;
    };

  tryMkHomelab = modules: builtins.tryEval (mkHomelab modules);

  homelabServiceNames =
    system:
    let
      serviceOpts = system.options.homelab.services;
    in
    builtins.filter (
      name:
      let
        opt = serviceOpts.${name};
      in
      lib.isAttrs opt && !(opt ? _type) && opt ? enable
    ) (builtins.attrNames serviceOpts);

  assert_ = cond: message: if cond then null else throw message;

  failedAssertions = system: lib.filter (a: !(a.assertion or false)) system.config.assertions;

in
{
  inherit
    flake
    lib
    homelabModule
    mkHomelab
    homelabServiceNames
    assert_
    failedAssertions
    ;
}
