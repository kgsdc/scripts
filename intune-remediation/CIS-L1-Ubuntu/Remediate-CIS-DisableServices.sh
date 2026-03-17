#!/usr/bin/env bash

# CIS L1 – Remediate: Disable Apport, Avahi; remove prelink.
# Idempotent: disable/mask only if enabled; remove prelink only if installed.

set -euo pipefail

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

log() {
    local level="[INFO]"
    local message=""
    case "${1:-}" in
        -i|--info)  level="[INFO]";  message="${*:2}" ;;
        -w|--warn)  level="[WARN]";  message="${*:2}" ;;
        -e|--error) level="[ERROR]"; message="${*:2}" ;;
        *)          level="[INFO]";  message="$*" ;;
    esac
    echo "$(date +'%Y-%m-%d %H:%M:%S') $level - $message"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    require_root

    export DEBIAN_FRONTEND=noninteractive

    # Apport: disable and mask if present and enabled
    if systemctl list-unit-files --type=service 2>/dev/null | grep -q 'apport.service'; then
        if systemctl is-enabled --quiet apport 2>/dev/null; then
            log --info "CIS DisableServices: Disabling and masking Apport."
            systemctl disable --now apport
            systemctl mask apport
        fi
    fi

    # Avahi: disable and stop if present and enabled (optional for corp; enable if you need mDNS)
    if systemctl list-unit-files --type=service 2>/dev/null | grep -q 'avahi-daemon.service'; then
        if systemctl is-enabled --quiet avahi-daemon 2>/dev/null; then
            log --info "CIS DisableServices: Disabling Avahi."
            systemctl disable --now avahi-daemon
        fi
    fi

    # Prelink: remove if installed
    if dpkg -l prelink 2>/dev/null | grep -q '^ii'; then
        log --info "CIS DisableServices: Removing prelink."
        apt-get remove -y prelink
    fi

    log --info "CIS DisableServices: Remediation complete."
}

main "$@"
