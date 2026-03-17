#!/usr/bin/env bash

# CIS L1 – Remediate: UFW default deny incoming, allow outgoing (CIS 3.6.x).
# Idempotent: installs ufw, sets defaults, enables. Safe to run repeatedly.
# Optional: set ALLOW_SUBNETS (e.g. "192.168.0.0/16 10.0.0.0/8") to allow corporate subnets.

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

    log --info "CIS Firewall: Ensuring UFW is installed."
    apt-get install -y ufw

    # Set defaults only if not already set (avoid re-running ufw commands that might prompt)
    local default_in
    default_in=$(ufw status verbose 2>/dev/null | grep -E '^Default:' | awk '{print $2}' || true)
    if [ "$default_in" != "deny" ]; then
        log --info "CIS Firewall: Setting default deny incoming."
        ufw default deny incoming
    fi

    local default_out
    default_out=$(ufw status verbose 2>/dev/null | grep -E '^Default:' | awk '{print $4}' || true)
    if [ "$default_out" != "allow" ]; then
        log --info "CIS Firewall: Setting default allow outgoing."
        ufw default allow outgoing
    fi

    # Optional: allow corporate subnets (no duplicate rules)
    if [ -n "${ALLOW_SUBNETS:-}" ]; then
        for subnet in $ALLOW_SUBNETS; do
            if ! ufw status numbered 2>/dev/null | grep -q "Allow from $subnet"; then
                log --info "CIS Firewall: Allowing $subnet."
                ufw allow from "$subnet"
            fi
        done
    fi

    # Enable only if not already active
    if ! ufw status 2>/dev/null | grep -q 'Status: active'; then
        log --info "CIS Firewall: Enabling UFW."
        ufw --force enable
    fi

    log --info "CIS Firewall: Remediation complete."
}

main "$@"
