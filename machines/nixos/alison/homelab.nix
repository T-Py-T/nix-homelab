{ ... }:
# ============================================================================
# HOST: alison - homelab service selection
#
# Services are selected by *importance tier* rather than one-by-one. Set
# `services.enabledTiers` and every service in those tiers turns on
# automatically. You can still flip an individual service explicitly (see the
# overrides block) and that always wins over the tier default.
#
# Tiers (a service's tier is declared in its module, `importance = ...`):
#   high   - core infra, observability, critical data, the dashboard
#   medium - general self-hosted apps and primary media
#   low    - acquisition stack (arr/downloaders) and niche/infra bits
#
# For now this single box runs everything; as more machines come online, give
# each host a different set of tiers to spread the load.
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

      # Turn on whole tiers of services at once. Everything runs here for now.
      enabledTiers = [
        "high"
        "medium"
        "low"
      ];

      # ----------------------------------------------------------------------
      # PER-SERVICE OVERRIDES
      #
      # These win over the tier defaults above. Use them to pull a single
      # service in or out without changing a whole tier, or to pass settings.
      # ----------------------------------------------------------------------

      # Prometheus needs its scrape targets configured regardless of tier.
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
