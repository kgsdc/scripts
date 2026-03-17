<#
.SYNOPSIS
    Intune Remediation - Detection: Legacy Microsoft Office files in OneDrive that need conversion.

.DESCRIPTION
    Single detection script for all legacy Office formats: .xls (Excel), .doc (Word), and .ppt (PowerPoint).
    Scans all user OneDrive folders under C:\Users (runs as SYSTEM). Returns exit 0 if no legacy
    files are found (compliant); exit 1 if any are found (remediation needed).
    Files already inside a "converted_old" folder are ignored.

.NOTES
    Intune: Detection script. Exit 0 = compliant, Exit 1 = run remediation.
    This is the standard approach: one detect script for "any legacy Office file" instead of
    separate scripts per application.
#>

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
# Folder name where we move originals after conversion; paths containing this
# are excluded from the scan so we don't re-detect already-converted files.
$ConvertedFolderName = "converted_old"

# Legacy extensions we care about (binary Office formats → modern Open XML).
# Add or remove here if you want to limit scope (e.g. only Excel and Word).
$LegacyExtensions = @("*.xls", "*.doc", "*.ppt")

# Use Continue so one inaccessible path or error doesn't terminate the script.
$ErrorActionPreference = "Continue"

# -----------------------------------------------------------------------------
# Get all user OneDrive root paths (graceful: errors are swallowed, returns what we can)
# -----------------------------------------------------------------------------
# When Intune runs this as SYSTEM, $env:OneDrive is usually empty. We discover
# OneDrive by scanning C:\Users\<username>\ for folders named "OneDrive" or
# "OneDrive - CompanyName" (business).
function Get-UserOneDrivePaths {
    $paths = @()
    try {
        $usersPath = "C:\Users"
        if (-not (Test-Path -LiteralPath $usersPath -ErrorAction SilentlyContinue)) {
            return $paths
        }
        $exclude = @('Default', 'Default User', 'Public', 'All Users')
        $dirs = Get-ChildItem -Path $usersPath -Directory -ErrorAction SilentlyContinue
        if (-not $dirs) { return $paths }
        foreach ($dir in $dirs) {
            if ($dir.Name -in $exclude) { continue }
            try {
                $oneDriveDirs = Get-ChildItem -Path $dir.FullName -Directory -Filter "OneDrive*" -ErrorAction SilentlyContinue
                if ($oneDriveDirs) {
                    foreach ($od in $oneDriveDirs) { $paths += $od.FullName }
                }
            } catch {
                # Skip this user profile and continue
            }
        }
    } catch {
        Write-Output "Get-UserOneDrivePaths: $_"
    }
    return $paths
}

# -----------------------------------------------------------------------------
# Main detection logic (per-path errors are non-fatal; we count what we can)
# -----------------------------------------------------------------------------
try {
    $oneDrivePaths = @(Get-UserOneDrivePaths)
    if ($env:OneDrive -and (Test-Path -LiteralPath $env:OneDrive -ErrorAction SilentlyContinue) -and $env:OneDrive -notin $oneDrivePaths) {
        $oneDrivePaths += $env:OneDrive
    }

    $legacyCount = 0
    $escapedExclude = [regex]::Escape("\$ConvertedFolderName\")

    foreach ($path in $oneDrivePaths) {
        if (-not $path -or -not (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue)) { continue }
        try {
            foreach ($ext in $LegacyExtensions) {
                $files = $null
                $files = Get-ChildItem -Path $path -Recurse -Include $ext -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch $escapedExclude }
                if ($files) { $legacyCount += (@($files).Count) }
            }
        } catch {
            Write-Output "Detect: error scanning path '$path': $_"
            # Continue to next path
        }
    }

    if ($legacyCount -gt 0) {
        Write-Output "Detected $legacyCount legacy Office file(s) (.xls/.doc/.ppt) in OneDrive requiring conversion."
        exit 1
    }

    Write-Output "No legacy Office files found. Compliant."
    exit 0
} catch {
    Write-Output "Detection error: $_"
    exit 1
}
