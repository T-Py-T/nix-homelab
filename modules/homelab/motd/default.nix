{
  config,
  lib,
  pkgs,
  ...
}:
# ============================================================================
# MOTD - login banner showing host info and the status of enabled services
#
# The list of monitored services is derived automatically from every enabled
# `homelab.services.<name>`, so new services appear here with no extra wiring.
# ============================================================================
let
  cfg = config.homelab.motd;

  enabledServices = lib.attrsets.mapAttrsToList (name: _: name) (
    lib.attrsets.filterAttrs (
      name: value: name != "enable" && lib.isAttrs value && value ? enable && value.enable
    ) config.homelab.services
  );

  monitoredServices = lib.lists.flatten (
    lib.lists.forEach enabledServices (
      name:
      let
        svc = config.homelab.services.${name};
      in
      if (svc ? monitoredServices) then svc.monitoredServices else [ name ]
    )
  );

  motd = pkgs.writeShellScriptBin "motd" ''
    #! /usr/bin/env bash
    source /etc/os-release
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    BOLD="\e[1m"
    ENDCOLOR="\e[0m"
    LOAD1=$(awk '{print $1}' /proc/loadavg)
    LOAD5=$(awk '{print $2}' /proc/loadavg)
    LOAD15=$(awk '{print $3}' /proc/loadavg)
    MEMORY=$(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)", $3,$2,$3*100 / $2 }')

    uptime_secs=$(cut -f1 -d. /proc/uptime)
    upDays=$((uptime_secs/60/60/24))
    upHours=$((uptime_secs/60/60%24))
    upMins=$((uptime_secs/60%60))

    printf "$BOLD Welcome to $(hostname)!$ENDCOLOR\n\n"
    printf "$BOLD  * %-20s$ENDCOLOR %s\n" "Release" "$PRETTY_NAME"
    printf "$BOLD  * %-20s$ENDCOLOR %s\n" "Kernel" "$(uname -rs)"
    printf "$BOLD  * %-20s$ENDCOLOR %s\n" "CPU load" "$LOAD1, $LOAD5, $LOAD15 (1, 5, 15 min)"
    printf "$BOLD  * %-20s$ENDCOLOR %s\n" "Memory" "$MEMORY"
    printf "$BOLD  * %-20s$ENDCOLOR %s\n" "Uptime" "$upDays days $upHours hours $upMins minutes"
    printf "\n$BOLD Service status$ENDCOLOR\n"

    get_service_status() {
      if systemctl is-failed "$1" | grep -q 'failed'; then
        printf "$RED• $ENDCOLOR%-40s $RED[failed]$ENDCOLOR\n" "$1"
      elif systemctl is-active "$1" | grep -xq 'active'; then
        printf "$GREEN• $ENDCOLOR%-40s $GREEN[active]$ENDCOLOR\n" "$1"
      else
        printf "$YELLOW• $ENDCOLOR%-40s $YELLOW[inactive]$ENDCOLOR\n" "$1"
      fi
    }
    ${lib.strings.concatStrings (lib.lists.forEach monitoredServices (x: "get_service_status ${x}\n"))}
  '';
in
{
  options.homelab.motd = {
    enable = lib.mkEnableOption "the login MOTD banner";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ motd ];

    # Print the MOTD on interactive login shells.
    programs.bash.interactiveShellInit = ''
      if [[ $- == *i* ]] && [[ -z "$MOTD_SHOWN" ]]; then
        export MOTD_SHOWN=1
        ${motd}/bin/motd
      fi
    '';
  };
}
