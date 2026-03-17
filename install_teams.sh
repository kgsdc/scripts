#!/usr/bin/env bash

# Script Name: install_teams.sh
# Description: Standalone script that installs Microsoft Teams on Ubuntu.
#              Adds Microsoft GPG key and Teams repository, then installs the teams package.
#
# Usage: Run as root. Example: ./install_teams.sh

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

    log --info "Adding Microsoft GPG key and Teams repository."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/ms-teams stable main" \
        > /etc/apt/sources.list.d/teams.list

    log --info "Updating package lists and installing Microsoft Teams."
    apt update
    apt install -y teams

    log --info "Microsoft Teams installation completed."
}

main "$@"
