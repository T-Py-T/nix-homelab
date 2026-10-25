# Static regression checks for homelab service option defaults (homepage
# categories vs the dashboard list, unique default vhost hostnames).
{
  pkgs,
  lib,
}:
let
  homelabModule = import ../modules/homelab;

  optionsEval = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    system = pkgs.system;
    modules = [
      homelabModule
    ];
  };

  serviceOpts = optionsEval.options.homelab.services;

  serviceNamesWithHomepage = builtins.filter (
    name:
    let
      entry = serviceOpts.${name};
    in
    lib.isAttrs entry && entry ? homepage && entry.homepage ? category
  ) (builtins.attrNames serviceOpts);

  defaultHomepageCategories = map (
    name: serviceOpts.${name}.homepage.category.default
  ) serviceNamesWithHomepage;

  serviceNamesWithUrl = builtins.filter (
    name:
    let
      entry = serviceOpts.${name};
    in
    lib.isAttrs entry && entry ? url
  ) (builtins.attrNames serviceOpts);

  defaultServiceUrls = map (name: serviceOpts.${name}.url.default) serviceNamesWithUrl;

  countOccurrences =
    list:
    lib.foldl' (
      acc: item:
      acc
      // {
        ${item} = (acc.${item} or 0) + 1;
      }
    ) { } list;

  duplicateUrls = lib.attrNames (
    lib.filterAttrs (_: count: count > 1) (countOccurrences defaultServiceUrls)
  );

  homepageSource = builtins.readFile ../modules/homelab/services/homepage/default.nix;

  quotedStringsIn =
    text:
    let
      parts = lib.strings.splitString "\"" text;
      count = (builtins.length parts - 1) / 2;
    in
    lib.genList (i: builtins.elemAt parts (i * 2 + 1)) count;

  # Extract quoted category names from the `categories = [ ... ];` block.
  dashboardCategories =
    let
      afterMarker = lib.elemAt (lib.strings.splitString "categories = [" homepageSource) 1;
    in
    if afterMarker == null then
      throw "homepage/default.nix: could not find categories = ["
    else
      quotedStringsIn (lib.elemAt (lib.strings.splitString "];" afterMarker) 0);

  missingDashboardCategories = lib.lists.subtractLists dashboardCategories defaultHomepageCategories;

  ok =
    lib.assertMsg (missingDashboardCategories == [ ]) (
      "homepage dashboard categories missing: ${toString missingDashboardCategories}"
    )
    && lib.assertMsg (duplicateUrls == [ ]) (
      "duplicate homelab.services.*.url defaults: ${toString duplicateUrls}"
    );
in
assert ok;
pkgs.writeText "homelab-service-metadata-ok" "ok\n"
