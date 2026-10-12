#!/usr/bin/env bash
# Smoke-test the MOTD service-status helper against mocked systemctl output.
set -euo pipefail

systemctl() {
  case "$1" in
    is-failed)
      case "$2" in
        broken.service) echo "failed" ;;
        *) echo "active" ;;
      esac
      ;;
    is-active)
      case "$2" in
        running.service) echo "active" ;;
        stopped.service) echo "inactive" ;;
        *) echo "inactive" ;;
      esac
      ;;
    *)
      echo "unexpected systemctl invocation: $*" >&2
      return 1
      ;;
  esac
}
export -f systemctl

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

get_service_status() {
  if systemctl is-failed "$1" | grep -q 'failed'; then
    printf "$RED• $ENDCOLOR%-40s ${RED}[failed]$ENDCOLOR\n" "$1"
  elif systemctl is-active "$1" | grep -xq 'active'; then
    printf "$GREEN• $ENDCOLOR%-40s ${GREEN}[active]$ENDCOLOR\n" "$1"
  else
    printf "$YELLOW• $ENDCOLOR%-40s ${YELLOW}[inactive]$ENDCOLOR\n" "$1"
  fi
}

output="$(get_service_status running.service)"
echo "$output" | grep -q '\[active\]'

output="$(get_service_status stopped.service)"
echo "$output" | grep -q '\[inactive\]'

output="$(get_service_status broken.service)"
echo "$output" | grep -q '\[failed\]'
