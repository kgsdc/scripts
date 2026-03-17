<#
.SYNOPSIS
    Intune Remediation - Detection: Old Excel (.xls) files in OneDrive that need conversion to .xlsx.

.DESCRIPTION
    Returns exit 0 if no legacy .xls files are found (compliant). Exit 1 if any .xls files exist
    outside converted_old folders (remediation needed). Runs in SYSTEM context; enumerates all user
    OneDrive folders under C:\Users.

.NOTES
    Intune: Detection script. Exit 0 = compliant, Exit 1 = run remediation.
#>

$ConvertedFolderName = "converted_old"
$ErrorActionPreference = "Stop"

function Get-UserOneDrivePaths {
    $usersPath = "C:\Users"
    $exclude = @('Default', 'Default User', 'Public', 'All Users')
    $paths = @()
    if (-not (Test-Path -LiteralPath $usersPath)) { return $paths }
    Get-ChildItem -Path $usersPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $exclude } |
        ForEach-Object {
            Get-ChildItem -Path $_.FullName -Directory -Filter "OneDrive*" -ErrorAction SilentlyContinue |
                ForEach-Object { $paths += $_.FullName }
        }
    return $paths
}

try {
    $oneDrivePaths = Get-UserOneDrivePaths
    if ($env:OneDrive -and (Test-Path -LiteralPath $env:OneDrive) -and $env:OneDrive -notin $oneDrivePaths) {
        $oneDrivePaths += $env:OneDrive
    }
    $legacyCount = 0
    foreach ($path in $oneDrivePaths) {
        $files = Get-ChildItem -Path $path -Recurse -Include "*.xls" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch [regex]::Escape("\$ConvertedFolderName\") }
        $legacyCount += ($files | Measure-Object).Count
    }
    if ($legacyCount -gt 0) {
        Write-Output "Detected $legacyCount legacy .xls file(s) in OneDrive requiring conversion."
        exit 1
    }
    Write-Output "No legacy .xls files found. Compliant."
    exit 0
} catch {
    Write-Output "Detection error: $_"
    exit 1
}
