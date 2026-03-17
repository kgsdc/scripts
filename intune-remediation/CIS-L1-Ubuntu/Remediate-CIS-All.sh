#!/usr/bin/env bash

# CIS L1 – Remediate: Run all CIS L1 Remediate scripts in order. Idempotent; safe to run repeatedly.

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

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    require_root

    for remediate in Remediate-CIS-Updates.sh Remediate-CIS-Firewall.sh Remediate-CIS-Kernel.sh \
                    Remediate-CIS-Password.sh Remediate-CIS-Audit.sh Remediate-CIS-DisableServices.sh \
                    Remediate-CIS-ScreenLock.sh Remediate-CIS-SSH.sh; do
        path="$SCRIPT_DIR/$remediate"
        if [ -x "$path" ]; then
            log --info "Running $remediate"
            "$path" || log --warn "$remediate returned non-zero"
        fi
    done

    log --info "CIS L1 All: Remediation complete. Reboot recommended if kernel/sysctl changed."
}

main "$@"
