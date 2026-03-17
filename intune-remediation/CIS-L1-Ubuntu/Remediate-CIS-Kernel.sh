#!/usr/bin/env bash

# CIS L1 – Remediate: Kernel sysctl (CIS 1.5.x / 3.x).
# Idempotent: writes /etc/sysctl.d/99-cis-workstation.conf with redirects,
# syncookies, fs.file-max. Overwriting the file makes reruns safe.

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

    local conf="/etc/sysctl.d/99-cis-workstation.conf"

    log --info "CIS Kernel: Writing $conf."
    cat > "$conf" << 'EOF'
# CIS Level 1 Workstation - kernel parameters
# Idempotent: this file is overwritten on each run.

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
fs.file-max = 65535
EOF

    sysctl -p "$conf" >/dev/null 2>&1 || true

    log --info "CIS Kernel: Remediation complete."
}

main "$@"
