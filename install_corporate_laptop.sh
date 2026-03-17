#!/usr/bin/env bash

# Script Name: install_corporate_laptop.sh
# Description: Corporate Linux laptop setup. Installs Microsoft Intune portal,
#              Microsoft Edge, Microsoft Defender for Endpoint (mdatp), and
#              Microsoft Teams on Ubuntu. Adds Microsoft package signing key and
#              repositories once, then installs all packages.
# Based on: https://learn.microsoft.com/en-us/intune/intune-service/user-help/microsoft-intune-app-linux
#           https://learn.microsoft.com/en-us/intune/intune-service/user-help/enroll-device-linux
#
# Usage: Run as root. Example: ./install_corporate_laptop.sh

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
# Hourly cron: Intune sync helper (runs as root, starts portal for active user)
# Intune on Linux has no CLI sync; launching the app lets it sync when user is signed in.
# -----------------------------------------------------------------------------
INTUNE_SYNC_SCRIPT='/usr/local/bin/corporate-intune-sync.sh'

install_intune_sync_script() {
    cat > "$INTUNE_SYNC_SCRIPT" << 'INTUNE_SCRIPT_EOF'
#!/usr/bin/env bash
# Start Intune Company Portal for the active graphical user so it can sync (no CLI sync on Linux).
set -euo pipefail
export DISPLAY=:0
user=""
for sid in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
    type=$(loginctl show-session -p Type -p State -p Remote "$sid" 2>/dev/null)
    if echo "$type" | grep -q 'State=active' && echo "$type" | grep -qE 'Type=(x11|wayland)' && echo "$type" | grep -q 'Remote=no'; then
        uid=$(loginctl show-session -p User "$sid" 2>/dev/null | awk -F= '/^User=/ {print $2}')
        [ -n "$uid" ] && user=$(getent passwd "$uid" | cut -d: -f1) && [ -n "$user" ] && break
    fi
done
if [ -n "$user" ] && command -v intune-portal &>/dev/null; then
    runuser -l "$user" -c "DISPLAY=:0 nohup intune-portal >/dev/null 2>&1 &"
fi
INTUNE_SCRIPT_EOF
    chmod 755 "$INTUNE_SYNC_SCRIPT"
}

# -----------------------------------------------------------------------------
# Hourly cron: install /etc/cron.d entry for Defender + Intune
# -----------------------------------------------------------------------------
install_hourly_cron() {
    local cron_file="/etc/cron.d/corporate-hourly"
    cat > "$cron_file" << 'CRON_EOF'
# Corporate laptop: hourly check-in with Company Portal/Intune and Defender sync
# Installed by install_corporate_laptop.sh
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Defender: product + definitions check (hourly at :00)
0 * * * * root env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get install -y --only-upgrade mdatp >> /var/log/corporate-defender.log 2>&1

# Intune: start Company Portal for active user so it can sync (hourly at :15)
15 * * * * root /usr/local/bin/corporate-intune-sync.sh >> /var/log/corporate-intune.log 2>&1
CRON_EOF
    chmod 644 "$cron_file"
    log --info "Installed hourly cron: $cron_file (Defender at :00, Intune/Company Portal at :15)."
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    require_root

    local ubuntu_version codename
    ubuntu_version=$(lsb_release -rs)
    codename=$(lsb_release -sc)

    log --info "Updating package list and upgrading system."
    apt update && apt upgrade -y

    log --info "Installing prerequisites (curl, gpg, lsb-release)."
    apt install -y curl gpg lsb-release

    log --info "Adding Microsoft signing key (modern keyring method)."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f microsoft.gpg

    log --info "Adding Microsoft repositories."
    # Microsoft prod repo (Intune portal + Defender for Endpoint)
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/${ubuntu_version}/prod ${codename} main" \
        | tee /etc/apt/sources.list.d/microsoft-ubuntu-${codename}-prod.list > /dev/null

    # Microsoft Edge repo
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" \
        | tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null

    # Microsoft Teams repo
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/ms-teams stable main" \
        | tee /etc/apt/sources.list.d/teams.list > /dev/null

    log --info "Updating repositories and installing Intune portal, Edge, Defender for Endpoint, and Teams."
    apt update
    apt install -y intune-portal microsoft-edge-stable mdatp teams

    log --info "Enabling and starting Microsoft Defender for Endpoint."
    systemctl start mdatp
    systemctl enable mdatp

    log --info "Installing hourly cron for Company Portal/Intune sync and Defender sync."
    install_intune_sync_script
    install_hourly_cron

    log --info "Corporate laptop setup complete: Intune portal, Edge, Defender for Endpoint, Teams, and hourly sync cron installed."
    echo ""
    echo "Next steps:"
    echo "  1. Reboot: sudo reboot"
    echo "  2. After reboot, open 'Microsoft Intune' from the app menu (or run: intune-portal)"
    echo "  3. Sign in with your work/school account and follow the enrollment wizard"
    echo ""
    echo "After enrollment, IT can manage configuration, compliance, and policies via the Intune admin center."
    echo "Docs: https://learn.microsoft.com/en-us/intune/intune-service/user-help/enroll-device-linux"
    echo ""
    echo "Hourly cron: Company Portal/Intune sync at :15, Defender sync at :00 (see /etc/cron.d/corporate-hourly)."
}

main "$@"
