{ ... }:
# ============================================================================
# HOST: alison - homelab service selection
#
# Services are selected by *profile* rather than one-by-one. Set
# `services.enabledProfiles` and every service in those profiles turns on
# automatically. You can still flip an individual service explicitly (see the
# overrides block) and that always wins over the profile default.
#
# Profiles are defined centrally in modules/homelab/services/default.nix
# (`homelab.services.profiles`). This box is the general-purpose node, so it
# runs everything except the GPU-only `ai` profile (see the `grace` host).
# ============================================================================
{
  homelab = {
    enable = true;

    # Base domain that every service hangs off of, e.g. grafana.<baseDomain>.
    # For a LAN with no public DNS, add these names to your /etc/hosts (or a
    # local DNS server) pointing at this host, and keep reverseProxy.acme off
    # so Caddy serves its own internal TLS certificates.
    baseDomain = "home.lan";
    timeZone = "America/New_York";

    services = {
      enable = true;

      # Turn on whole profiles at once.
      enabledProfiles = [
        "core"
        "media"
        "arr"
        "downloads"
        "productivity"
        "git"
        "comms"
        "analytics"
        "smarthome"
        "net"
      ];

      # ----------------------------------------------------------------------
      # PER-SERVICE OVERRIDES
      #
      # These win over the profile defaults above. Use them to pull a single
      # service in or out without changing a whole profile, or to pass settings.
      # ----------------------------------------------------------------------

      # Prometheus needs its scrape targets configured regardless of profile.
      prometheus.scrapeTargets = [
        {
          job_name = "node";
          static_configs = [
            { targets = [ "127.0.0.1:9100" ]; }
          ];
        }
      ];
    };
  };
}
