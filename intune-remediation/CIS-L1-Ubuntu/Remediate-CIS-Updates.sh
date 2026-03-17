#!/usr/bin/env bash

# CIS L1 – Remediate: Unattended security updates (CIS 1.2.x).
# Idempotent: installs unattended-upgrades, configures 50unattended-upgrades
# for -security only, enables service. Safe to run repeatedly.

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

    log --info "CIS Updates: Ensuring unattended-upgrades is installed."
    apt-get install -y unattended-upgrades

    local conf="/etc/apt/apt.conf.d/50unattended-upgrades"
    if [ ! -f "$conf" ]; then
        log --info "CIS Updates: Creating $conf."
        touch "$conf"
    fi

    # Ensure security origin is allowed (idempotent: add only if missing)
    if ! grep -q '"\${distro_id}:\${distro_codename}-security";' "$conf" 2>/dev/null; then
        log --info "CIS Updates: Adding security origin to $conf."
        if ! grep -q 'Unattended-Upgrade::Allowed-Origins' "$conf"; then
            echo 'Unattended-Upgrade::Allowed-Origins {' >> "$conf"
            echo '    "${distro_id}:${distro_codename}-security";' >> "$conf"
            echo '};' >> "$conf"
        fi
    fi

    # Disable automatic reboot if not already set
    if ! grep -q 'Unattended-Upgrade::Automatic-Reboot' "$conf" 2>/dev/null; then
        echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> "$conf"
    fi

    # Enable and start only if not already
    if ! systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
        log --info "CIS Updates: Enabling unattended-upgrades."
        systemctl enable unattended-upgrades
    fi
    if ! systemctl is-active --quiet unattended-upgrades 2>/dev/null; then
        log --info "CIS Updates: Starting unattended-upgrades."
        systemctl start unattended-upgrades
    fi

    log --info "CIS Updates: Remediation complete."
}

main "$@"
