#!/usr/bin/env bash

# Script Name: install_intune.sh
# Description: Standalone script that installs the Microsoft Intune portal on Ubuntu.
#              Adds Microsoft package signing key and repository, then installs intune-portal.
#
# Usage: Run as root. Example: ./install_intune.sh

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

    local ubuntu_version codename
    ubuntu_version=$(lsb_release -rs)
    codename=$(lsb_release -sc)

    log --info "Adding Microsoft package signing key and repository."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f microsoft.gpg

    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/${ubuntu_version}/prod ${codename} main" \
        | tee /etc/apt/sources.list.d/microsoft-ubuntu-${codename}-prod.list > /dev/null

    log --info "Updating package lists and installing intune-portal."
    apt update
    apt install -y intune-portal

    log --info "Microsoft Intune app installed successfully."
}

main "$@"
