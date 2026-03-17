#!/usr/bin/env bash

# CIS L1 – Remediate: auditd (and audispd-plugins) installed and enabled (CIS 4.x).
# Idempotent: apt install; enable/start only if not already.

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

    log --info "CIS Audit: Ensuring auditd and audispd-plugins are installed."
    apt-get install -y auditd audispd-plugins

    if ! systemctl is-enabled --quiet auditd 2>/dev/null; then
        log --info "CIS Audit: Enabling auditd."
        systemctl enable auditd
    fi
    if ! systemctl is-active --quiet auditd 2>/dev/null; then
        log --info "CIS Audit: Starting auditd."
        systemctl start auditd
    fi

    log --info "CIS Audit: Remediation complete."
}

main "$@"
