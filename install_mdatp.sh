#!/usr/bin/env bash

# Script Name: install_mdatp.sh
# Description: Standalone script that installs Microsoft Defender for Endpoint (mdatp) on Ubuntu.
#              Adds Microsoft package signing key and repository, installs mdatp, and enables the daemon.
#
# Usage: Run as root. Example: ./install_mdatp.sh

set -euo pipefail

# -----------------------------------------------------------------------------
# Standalone helpers (no dependency on lib/)
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

    local ubuntu_version repo_url
    ubuntu_version=$(lsb_release -rs)
    repo_url="https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/prod.list"

    log --info "Adding Microsoft package signing key and repository for Ubuntu ${ubuntu_version}."
    wget -qO - https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    wget -qO - "$repo_url" | tee /etc/apt/sources.list.d/microsoft-prod.list > /dev/null

    log --info "Updating package list and installing Microsoft Defender for Endpoint."
    apt-get update
    apt-get install -y mdatp

    systemctl start mdatp
    systemctl enable mdatp

    log --info "Microsoft Defender for Endpoint installation and setup complete."
}

main "$@"
