#!/usr/bin/env bash

# Script Name: bootstrap-syslog-enhanced.sh
# Description: Standalone script that installs the CEF/Syslog collector (Azure Sentinel
#              connector), configures log cleanup jobs, and installs cron jobs for
#              maintenance and Azure Monitor agent restart.
#
# Corporate Use License:
#   This script is provided "as is", without warranty of any kind, express or implied,
#   and is intended for use by Stream Datacenters employees or systems only. Unauthorized
#   use, distribution, or modification outside of Stream Datacenters is strictly prohibited.

set -euo pipefail

# -----------------------------------------------------------------------------
# Standalone helpers 
# -----------------------------------------------------------------------------

LOG_FILE="${LOG_FILE:-/var/log/bootstrap-syslog-enhanced.log}"

# Cleanup policy: only remove files that are OLD or LARGE (never wipe entire dirs).
CLEANUP_DAYS_AGO="${CLEANUP_DAYS_AGO:-7}"       # remove files older than N days
CLEANUP_DAYS_LOG="${CLEANUP_DAYS_LOG:-3}"      # /var/log generic
CLEANUP_LARGE_MB="${CLEANUP_LARGE_MB:-100}"    # remove files larger than N MiB in agent/cache dirs
KEEP_KERNELS="${KEEP_KERNELS:-2}"              # keep this many newest kernels (for /boot cleanup on RPM)

log() {
    local level="[INFO]"
    local message=""
    case "${1:-}" in
        -i|--info)  level="[INFO]";  message="${*:2}" ;;
        -w|--warn)  level="[WARN]";  message="${*:2}" ;;
        -e|--error) level="[ERROR]"; message="${*:2}" ;;
        *)          level="[INFO]";  message="$*" ;;
    esac
    echo "$(date +'%Y-%m-%d %H:%M:%S') $level - $message" | tee -a "$LOG_FILE"
    logger -p "user.info" -t "bootstrap-syslog-enhanced" "$level $message"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
}

add_cron_job_if_not_exists() {
    local cron_string=""
    local command=""
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --cron-string) shift; cron_string="$1" ;;
            --command)     shift; command="$1" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done
    if [ -z "$cron_string" ] || [ -z "$command" ]; then
        log --error "add_cron_job_if_not_exists: Both --cron-string and --command are required."
        return 1
    fi
    local cron_job="$cron_string $command"
    if ! (crontab -l 2>/dev/null | grep -Fq "$cron_job"); then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        log --info "Cron job added: $cron_job"
    else
        log --info "Cron job already exists: $cron_job"
    fi
}

# -----------------------------------------------------------------------------
# CEF / Syslog collector install
# -----------------------------------------------------------------------------

install_cef_collector() {
    # CEF collector (Azure Sentinel): requires WORKSPACE_ID and PRIMARY_KEY.
    if [ -z "${WORKSPACE_ID:-}" ] || [ -z "${PRIMARY_KEY:-}" ]; then
        log --warn "WORKSPACE_ID and PRIMARY_KEY not set. Skipping CEF collector install."
        return 0
    fi
    if ss -tulpn | grep -E ":6?514\b" >/dev/null 2>&1; then
        log --info "Port 514 or 6514 is already in use. Skipping CEF collector install."
        return 0
    fi
    log --info "Port 514/6514 not in use. Installing CEF collector (Azure Sentinel connector)..."
    local dir="${BASH_SOURCE%/*}"
    dir="$(cd "${dir:-.}" && pwd)"
    ( cd "$dir" && wget -q -O cef_installer.py "https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/DataConnectors/CEF/cef_installer.py" )
    python3 "$dir/cef_installer.py" "$WORKSPACE_ID" "$PRIMARY_KEY" >> "$LOG_FILE" 2>&1
    log --info "CEF collector install completed."
}

install_ama_forwarder() {
    # Azure Monitor / Syslog forwarder when ports 514/6514 are not in use.
    if ss -tulpn | grep -E ":6?514\b" >/dev/null 2>&1; then
        log --info "Port 514 or 6514 is already in use. Skipping AMA forwarder install."
        return 0
    fi
    log --info "Port 514/6514 not in use. Installing Azure Sentinel Syslog forwarder (AMA)..."
    local dir="${BASH_SOURCE%/*}"
    dir="$(cd "${dir:-.}" && pwd)"
    ( cd "$dir" && wget -q -O Forwarder_AMA_installer.py "https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/DataConnectors/Syslog/Forwarder_AMA_installer.py" )
    python3 "$dir/Forwarder_AMA_installer.py" >> "$LOG_FILE" 2>&1
    log --info "AMA forwarder install completed."
}

# -----------------------------------------------------------------------------
# OS detection (RPM vs Debian; Oracle Linux, RHEL, Ubuntu, etc.)
# -----------------------------------------------------------------------------

OS_ID=""
OS_ID_LIKE=""
IS_RPM=false
IS_DEBIAN=false

detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_ID_LIKE="${ID_LIKE:-}"
    fi
    case "$OS_ID" in
        rhel|centos|fedora|ol|rocky|almalinux|openEuler) IS_RPM=true ;;
        *) ;;
    esac
    case "$OS_ID_LIKE" in
        *rhel*|*fedora*|*centos*) IS_RPM=true ;;
        *) ;;
    esac
    case "$OS_ID" in
        debian|ubuntu|linuxmint|raspbian) IS_DEBIAN=true ;;
        *) ;;
    esac
    case "$OS_ID_LIKE" in
        *debian*) IS_DEBIAN=true ;;
        *) ;;
    esac
    log --info "Detected OS: id=$OS_ID id_like=$OS_ID_LIKE rpm=$IS_RPM debian=$IS_DEBIAN"
}

# -----------------------------------------------------------------------------
# Cleanup jobs (one-time and cron)
# -----------------------------------------------------------------------------
# Prefer file creation time (birth time) over mtime so logs that failed to rotate
# but kept growing still get cleaned when they're old by creation date.

# Delete files under $1 that are old by creation time (fallback: mtime) OR larger than $3 MiB.
# Usage: delete_old_or_large_by_creation <dir> [days] [size_mb] [name_glob] [maxdepth]
#   size_mb=0: don't use size. name_glob e.g. "*.log". maxdepth e.g. 1 for no recurse.
delete_old_or_large_by_creation() {
    local dir="$1"
    local days="${2:-$CLEANUP_DAYS_AGO}"
    local size_mb="${3:-$CLEANUP_LARGE_MB}"
    local name_glob="${4:-}"
    local maxdepth="${5:-}"
    [ -d "$dir" ] || return 0
    local cutoff
    cutoff=$(date -d "${days} days ago" +%s 2>/dev/null) || cutoff=$(($(date +%s) - days * 86400))
    export _cleanup_cutoff="$cutoff" _cleanup_size_mb="$size_mb"
    local find_args=("$dir")
    [ -n "$maxdepth" ] && find_args+=(-maxdepth "$maxdepth")
    [ -n "$name_glob" ] && find_args+=(-name "$name_glob")
    find "${find_args[@]}" -type f -exec sh -c '
        f="$1"
        bt=$(stat -c %W "$f" 2>/dev/null); mt=$(stat -c %Y "$f" 2>/dev/null); sz=$(stat -c %s "$f" 2>/dev/null)
        [ -z "$bt" ] || [ "$bt" = "0" ] && ts="$mt" || ts="$bt"
        old=0; [ -n "$ts" ] && [ "$ts" -lt "$_cleanup_cutoff" ] 2>/dev/null && old=1
        big=0
        if [ -n "$_cleanup_size_mb" ] && [ "$_cleanup_size_mb" -gt 0 ] 2>/dev/null; then
            [ "$sz" -gt $((_cleanup_size_mb * 1024 * 1024)) ] 2>/dev/null && big=1
        fi
        [ "$old" = "1" ] || [ "$big" = "1" ] && rm -f "$f"
    ' _ {} \; 2>/dev/null || true
}

run_cleanup_now() {
    log --info "Running one-time cleanup: remove log files older than 3 days under /var/log (by creation time)."
    delete_old_or_large_by_creation /var/log "$CLEANUP_DAYS_LOG" 0
    log --info "One-time cleanup finished."
}

# --- Common (all systems): AMA, journal, /var/log, audit, rsyslog state, tmp ---
# Remove only files that are old (by creation time) OR large (never wipe entire dirs).
cleanup_ama() {
    log --info "[cleanup] Azure Monitor Agent (events, log, cache) - old or large files only (by creation time)."
    for base in /var/opt/microsoft/azuremonitoragent/events /var/opt/microsoft/azuremonitoragent/log /var/lib/microsoft/azuremonitoragent; do
        delete_old_or_large_by_creation "$base" "$CLEANUP_DAYS_AGO" "$CLEANUP_LARGE_MB"
    done
}

cleanup_journal_and_var_log() {
    log --info "[cleanup] systemd journal and /var/log rotated/old files only (by creation time)."
    journalctl --vacuum-time=2weeks --vacuum-size=500M 2>/dev/null || true
    delete_old_or_large_by_creation /var/log 14 0 "*.log.*"
    delete_old_or_large_by_creation /var/log "$CLEANUP_DAYS_LOG" 0
    # dateext-style rotated logs (e.g. messages-20240315) - by creation time
    local cutoff
    cutoff=$(date -d "${CLEANUP_DAYS_AGO} days ago" +%s 2>/dev/null) || cutoff=$(($(date +%s) - CLEANUP_DAYS_AGO * 86400))
    export _cleanup_cutoff="$cutoff"
    find /var/log -type f -regextype posix-extended -regex '.*-[0-9]{8}([0-9]{2})?(\.[0-9]+)?(\.gz)?$' -exec sh -c '
        bt=$(stat -c %W "$1" 2>/dev/null); mt=$(stat -c %Y "$1" 2>/dev/null)
        [ -z "$bt" ] || [ "$bt" = "0" ] && ts="$mt" || ts="$bt"
        [ -n "$ts" ] && [ "$ts" -lt "$_cleanup_cutoff" ] 2>/dev/null && rm -f "$1"
    ' _ {} \; 2>/dev/null || true
}

cleanup_audit_logs() {
    log --info "[cleanup] Audit logs (old rotated/archived, by creation time)."
    [ -d /var/log/audit ] || return 0
    delete_old_or_large_by_creation /var/log/audit 14 0 "audit.log.*"
    delete_old_or_large_by_creation /var/log/audit "$CLEANUP_DAYS_AGO" 0 "*.old"
}

cleanup_rsyslog_state() {
    log --info "[cleanup] rsyslog imjournal state - only if old or large (by creation time)."
    [ -d /var/lib/rsyslog ] || return 0
    delete_old_or_large_by_creation /var/lib/rsyslog "$CLEANUP_DAYS_AGO" "$CLEANUP_LARGE_MB" "imjournal.state*" 1
}

cleanup_tmp() {
    log --info "[cleanup] /tmp and /var/tmp (files older than 7 days by creation time)."
    delete_old_or_large_by_creation /tmp "$CLEANUP_DAYS_AGO" 0
    delete_old_or_large_by_creation /var/tmp "$CLEANUP_DAYS_AGO" 0
}

# --- /boot: remove old kernel packages (RPM only; never delete files directly) ---
cleanup_boot() {
    local keep="${1:-$KEEP_KERNELS}"
    [ -d /boot ] || return 0
    # Prefer dnf (RHEL/OL 8+); fall back to package-cleanup (yum-utils).
    if command -v dnf &>/dev/null; then
        log --info "[cleanup] /boot: Removing old kernels via dnf installonly (keeping $keep newest)."
        local to_remove
        to_remove=$(dnf repoquery --installonly --latest-limit=-"$keep" -q 2>/dev/null) || true
        if [ -n "$to_remove" ]; then
            echo "$to_remove" | xargs -r dnf remove -y 2>>"$LOG_FILE" || true
        else
            log --info "[cleanup] /boot: No old kernel packages to remove (or dnf repoquery returned nothing)."
        fi
    elif [ -x /usr/bin/package-cleanup ]; then
        log --info "[cleanup] /boot: Removing old kernels via package-cleanup (keeping $keep newest)."
        package-cleanup --oldkernels --count="$keep" -y 2>>"$LOG_FILE" || true
    else
        log --warn "[cleanup] /boot: No dnf or package-cleanup (yum-utils); install yum-utils for old kernel removal."
    fi
}

# --- RPM (Oracle Linux, RHEL, CentOS, Fedora): DNF/YUM, Uptrack/Ksplice, /boot ---
cleanup_rpm() {
    log --info "[cleanup] RPM: DNF/YUM package cache - official clean + old/large files only (by creation time)."
    dnf clean all 2>/dev/null || true
    yum clean all 2>/dev/null || true
    for cache in /var/cache/dnf /var/cache/yum; do
        delete_old_or_large_by_creation "$cache" "$CLEANUP_DAYS_AGO" 200
    done

    if [ -x /usr/sbin/uptrack-upgrade ]; then
        log --info "[cleanup] RPM: Ksplice / Uptrack - official cleanup + old kernel cache dirs only."
        /usr/sbin/uptrack-upgrade --cleanup 2>/dev/null || true
        find /var/cache/uptrack -maxdepth 5 -type d -regextype posix-extended -regex '.*/Linux/x86_64/[0-9].*' -mtime +"$CLEANUP_DAYS_AGO" -exec rm -rf {} + 2>/dev/null || true
    fi

    cleanup_boot
}

# --- Debian/Ubuntu: APT, Snap ---
cleanup_debian() {
    log --info "[cleanup] Debian: APT - official clean + old files in cache/lists only (by creation time)."
    apt-get clean 2>/dev/null || true
    apt-get -y autoremove 2>/dev/null || true
    delete_old_or_large_by_creation /var/cache/apt/archives "$CLEANUP_DAYS_AGO" 0
    delete_old_or_large_by_creation /var/lib/apt/lists "$CLEANUP_DAYS_AGO" 0

    if command -v snap &>/dev/null; then
        log --info "[cleanup] Debian: Snap - disabled revisions only; cache old/large files only (by creation time)."
        LANG=C snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r snap rev; do
            [ -n "$snap" ] && snap remove "$snap" --revision="$rev" 2>/dev/null || true
        done
        delete_old_or_large_by_creation /var/lib/snapd/cache "$CLEANUP_DAYS_AGO" 100
    fi
}

# --- Optional: sysstat (sar), Docker, other known space hogs ---
cleanup_sysstat_sa() {
    if [ -d /var/log/sa ]; then
        log --info "[cleanup] Sysstat/sar data (keep last 7 days by creation time)."
        delete_old_or_large_by_creation /var/log/sa "$CLEANUP_DAYS_AGO" 0 "sa[0-9]*"
        delete_old_or_large_by_creation /var/log/sa "$CLEANUP_DAYS_AGO" 0 "sar[0-9]*"
    fi
}

cleanup_docker_optional() {
    if command -v docker &>/dev/null; then
        log --info "[cleanup] Docker - prune only containers/images older than 7 days."
        docker system prune -f --filter "until=168h" --volumes=false 2>/dev/null || true
    fi
}

cleanup_other_known_dirs() {
    # Azure/waagent logs and caches - old files only (by creation time)
    delete_old_or_large_by_creation /var/log/azure "$CLEANUP_DAYS_AGO" 0
    rm -f /var/log/waagent.log.1 /var/log/waagent.log.2 2>/dev/null || true
    delete_old_or_large_by_creation /var/lib/waagent "$CLEANUP_DAYS_AGO" 0
    delete_old_or_large_by_creation /var/crash 14 0
}

# Full disk cleanup: OS-aware and covers RPM, Debian, and common logging culprits.
run_disk_cleanup_now() {
    log --info "Running full disk cleanup (OS-aware: RPM/Debian, AMA, journal, logs, audit, tmp, snap, etc.)."
    detect_os

    cleanup_ama
    cleanup_journal_and_var_log
    cleanup_audit_logs
    cleanup_rsyslog_state
    cleanup_tmp
    cleanup_sysstat_sa
    cleanup_other_known_dirs

    "$IS_RPM" && cleanup_rpm
    "$IS_DEBIAN" && cleanup_debian

    # Optional aggressive (can be enabled via env or flag later)
    if [ "${CLEANUP_DOCKER:-0}" = "1" ]; then
        cleanup_docker_optional
    fi

    log --info "Disk cleanup finished."
}

# Optional: restart services after disk cleanup to recover from full-disk state.
restart_services_after_cleanup() {
    log --info "Restarting services after disk cleanup."
    systemctl restart rsyslog 2>/dev/null || true
    systemctl restart dnf-makecache.service 2>/dev/null || true
    systemctl restart uptrack-prefetch.service 2>/dev/null || true
    systemctl restart temp-disk-dataloss-warning.service 2>/dev/null || true
    systemctl restart cloud-init-local.service 2>/dev/null || true
    systemctl restart cloud-init.service 2>/dev/null || true
    systemctl restart cloud-config.service 2>/dev/null || true
    systemctl restart cloud-final.service 2>/dev/null || true
    systemctl restart kdump.service 2>/dev/null || true
    systemctl restart logrotate.service 2>/dev/null || true
    systemctl restart azuremonitoragent.service 2>/dev/null || true
    systemctl reset-failed 2>/dev/null || true
    log --info "Service restarts completed."
}

# -----------------------------------------------------------------------------
# Emergency fail-safe: if root filesystem usage exceeds threshold, run cleanup + restart
# -----------------------------------------------------------------------------

DISK_THRESHOLD_PERCENT="${DISK_THRESHOLD_PERCENT:-85}"

get_root_usage_percent() {
    local pct
    pct=$(df -P / 2>/dev/null | awk 'NR==2 {gsub(/%/,""); print $5}')
    echo "${pct:-0}"
}

run_emergency_cleanup_if_needed() {
    local usage
    usage=$(get_root_usage_percent)
    if [ -z "$usage" ] || [ "$usage" -lt "$DISK_THRESHOLD_PERCENT" ]; then
        return 0
    fi
    log --warn "FAIL-SAFE: root filesystem at ${usage}% (threshold ${DISK_THRESHOLD_PERCENT}%). Running aggressive cleanup."
    run_disk_cleanup_now
    # Aggressive journal shrink if still high
    journalctl --vacuum-time=7d --vacuum-size=100M 2>/dev/null || true
    usage=$(get_root_usage_percent)
    if [ -n "$usage" ] && [ "$usage" -ge "$DISK_THRESHOLD_PERCENT" ]; then
        log --warn "FAIL-SAFE: still at ${usage}%. Restarting services to release handles and retry."
        restart_services_after_cleanup
    fi
    log --info "FAIL-SAFE: emergency cleanup completed. Current usage: $(get_root_usage_percent)%"
}

install_cleanup_cron_jobs() {
    log --info "Creating CRON job to delete logs older than 3 days."
    add_cron_job_if_not_exists --cron-string "0 */4 * * *" \
        --command "/usr/bin/find /var/log -type f -mtime +3 -exec rm -f {} \;"

    log --info "Creating CRON job for dated log cleanup."
    add_cron_job_if_not_exists --cron-string "0 */4 * * *" \
        --command "/usr/bin/find /var/log -type f -exec bash -c 'file={}; suffix=\${file##*-}; cutoff=\$(date -d \"3 days ago\" +%Y%m%d%H); [[ \$suffix =~ ^[0-9]{10}\$ && \$suffix < \$cutoff ]] && rm -f \"\$file\"' \;"
}

# -----------------------------------------------------------------------------
# Maintenance and agent cron jobs
# -----------------------------------------------------------------------------

# Nightly maintenance: OS-aware (dnf vs apt), journal vacuum, rsyslog state, restart rsyslog.
install_maintenance_cron_jobs() {
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    detect_os

    if "$IS_DEBIAN"; then
        log --info "Creating CRON job for nightly maintenance (Debian/APT)."
        add_cron_job_if_not_exists --cron-string "0 3 * * *" \
            --command "apt-get -qq update && apt-get -y -qq upgrade && apt-get -y autoremove && apt-get clean && journalctl --vacuum-time=7d --vacuum-size=100M 2>/dev/null; rm -f /var/lib/rsyslog/imjournal.state* 2>/dev/null; systemctl restart rsyslog >> /var/log/maintenance.log 2>&1"
    else
        log --info "Creating CRON job for nightly maintenance (RPM/DNF)."
        add_cron_job_if_not_exists --cron-string "0 3 * * *" \
            --command "/usr/bin/dnf -y update --refresh && /usr/bin/dnf -y upgrade && /usr/bin/dnf clean all && /usr/bin/journalctl --vacuum-time=7d --vacuum-size=100M && rm -f /var/lib/rsyslog/imjournal.state* && systemctl restart rsyslog >> /var/log/maintenance.log 2>&1"
    fi

    log --info "Creating CRON job to restart the Azure Monitor agent periodically."
    add_cron_job_if_not_exists --cron-string "*/15 * * * *" \
        --command "/bin/systemctl restart azuremonitoragent 2>/dev/null || true"
}

# Daily disk cleanup (full OS-aware cleanup).
install_disk_cleanup_cron_job() {
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    log --info "Creating CRON job for daily disk cleanup (RPM/Debian, AMA, journal, logs, etc.)."
    add_cron_job_if_not_exists --cron-string "0 2 * * *" \
        --command "\"$script_path\" --disk-cleanup >> $LOG_FILE 2>&1"
}

# Fail-safe: every 6 hours check disk usage; if above threshold run emergency cleanup.
install_emergency_cron_job() {
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    log --info "Creating CRON job for emergency disk fail-safe (every 6h, threshold ${DISK_THRESHOLD_PERCENT}%)."
    add_cron_job_if_not_exists --cron-string "30 */6 * * *" \
        --command "\"$script_path\" --emergency >> $LOG_FILE 2>&1"
}

enable_crond() {
    if ! command -v systemctl &>/dev/null; then
        return 0
    fi
    # Debian/Ubuntu use cron.service; RPM uses crond.service
    if systemctl list-units --type=service 2>/dev/null | grep -q 'cron\.service'; then
        systemctl enable cron 2>/dev/null || true
        systemctl start cron 2>/dev/null || true
        log --info "cron (Debian) enabled and started."
    else
        systemctl enable crond 2>/dev/null || true
        systemctl start crond 2>/dev/null || true
        log --info "crond (RPM) enabled and started."
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Installs CEF/Syslog collector (when ports 514/6514 are free), sets log cleanup"
    echo "jobs (RPM + Debian aware), and configures cron jobs including emergency fail-safe."
    echo ""
    echo "Options:"
    echo "  --cef              Use CEF collector (requires WORKSPACE_ID and PRIMARY_KEY env vars)."
    echo "  --ama              Use Azure Sentinel Syslog AMA forwarder (default if no --cef)."
    echo "  --disk-cleanup     Only run full disk cleanup (OS-aware: RPM/Debian, AMA, journal, audit, snap, etc.)."
    echo "  --restart-services After --disk-cleanup, restart key services (for recovery)."
    echo "  --emergency        Check root fs usage; if above DISK_THRESHOLD_PERCENT (default 85), run cleanup + optional restart."
    echo "  -h                 Show this help."
    echo ""
    echo "Environment:"
    echo "  DISK_THRESHOLD_PERCENT  Trigger emergency cleanup when root usage exceeds this (default: 85)."
    echo "  CLEANUP_DOCKER=1        When set, include docker prune (only resources older than 7d) in disk cleanup."
    echo "  CLEANUP_DAYS_AGO       Remove files older than N days in cache/agent dirs (default: 7)."
    echo "  CLEANUP_DAYS_LOG      Remove /var/log files older than N days (default: 3)."
    echo "  CLEANUP_LARGE_MB      Remove files larger than N MiB in agent/cache dirs (default: 100)."
    echo "  KEEP_KERNELS         On RPM: keep this many newest kernels; remove rest from /boot (default: 2)."
    echo ""
    echo "Examples:"
    echo "  WORKSPACE_ID=... PRIMARY_KEY=... $0 --cef"
    echo "  $0 --ama"
    echo "  $0 --disk-cleanup                  # cron; full cleanup only"
    echo "  $0 --disk-cleanup --restart-services   # manual recovery after full disk"
    echo "  $0 --emergency                     # cron; run only if disk above threshold"
}

main() {
    require_root
    local use_cef=false
    local use_ama=true
    local disk_cleanup_only=false
    local restart_after_cleanup=false
    local emergency_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cef) use_cef=true; use_ama=false ;;
            --ama) use_ama=true; use_cef=false ;;
            --disk-cleanup) disk_cleanup_only=true ;;
            --restart-services) restart_after_cleanup=true ;;
            --emergency) emergency_only=true ;;
            -h|--help) usage; exit 0 ;;
            *) log --warn "Unknown option: $1" ;;
        esac
        shift
    done

    if "$emergency_only"; then
        log --info "Emergency fail-safe check (threshold ${DISK_THRESHOLD_PERCENT}%)."
        run_emergency_cleanup_if_needed
        return 0
    fi

    if "$disk_cleanup_only"; then
        log --info "Disk-cleanup-only mode."
        run_disk_cleanup_now
        [[ "$restart_after_cleanup" == true ]] && restart_services_after_cleanup
        log --info "Disk cleanup completed."
        return 0
    fi

    log --info "bootstrap-syslog-enhanced.sh started."

    if "$use_cef"; then
        install_cef_collector
    else
        install_ama_forwarder
    fi

    run_cleanup_now
    run_disk_cleanup_now
    install_cleanup_cron_jobs
    install_maintenance_cron_jobs
    install_disk_cleanup_cron_job
    install_emergency_cron_job
    enable_crond

    log --info "bootstrap-syslog-enhanced.sh completed."
}

main "$@"
