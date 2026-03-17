<#
.SYNOPSIS
    Intune Remediation - Remediation: Convert legacy Office files in OneDrive to modern format and archive originals.

.DESCRIPTION
    Single remediation for .xls → .xlsx, .doc → .docx, and .ppt → .pptx. Uses Excel/Word/PowerPoint
    COM objects to open each file, save in Open XML format, then move the original into a local
    "converted_old" folder in the same directory. Runs as SYSTEM; processes all user OneDrive
    folders under C:\Users. Requires the corresponding Office application(s) to be installed
    for the file types you encounter.

.NOTES
    Intune: Remediation script. Run after detection exits 1.
    Format codes: Excel 51 = xlOpenXMLWorkbook, Word 16 = wdFormatXMLDocument,
                  PowerPoint 24 = ppSaveAsOpenXMLPresentation.
#>

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
$ConvertedFolderName = "converted_old"

# Save format constants for each Office app (used when calling SaveAs).
# These match the Open XML formats (.xlsx, .docx, .pptx).
$ExcelFormat = 51       # xlOpenXMLWorkbook
$WordFormat = 16        # wdFormatXMLDocument
$PowerPointFormat = 24  # ppSaveAsOpenXMLPresentation

# Continue on error so one bad path or file doesn't stop the whole run.
$ErrorActionPreference = "Continue"

# -----------------------------------------------------------------------------
# Get all user OneDrive root paths (graceful: errors swallowed, returns what we can)
# -----------------------------------------------------------------------------
function Get-UserOneDrivePaths {
    $paths = @()
    try {
        $usersPath = "C:\Users"
        if (-not (Test-Path -LiteralPath $usersPath -ErrorAction SilentlyContinue)) { return $paths }
        $exclude = @('Default', 'Default User', 'Public', 'All Users')
        $dirs = Get-ChildItem -Path $usersPath -Directory -ErrorAction SilentlyContinue
        if (-not $dirs) { return $paths }
        foreach ($dir in $dirs) {
            if ($dir.Name -in $exclude) { continue }
            try {
                $oneDriveDirs = Get-ChildItem -Path $dir.FullName -Directory -Filter "OneDrive*" -ErrorAction SilentlyContinue
                if ($oneDriveDirs) { foreach ($od in $oneDriveDirs) { $paths += $od.FullName } }
            } catch { }
        }
    } catch {
        Write-Output "Get-UserOneDrivePaths: $_"
    }
    return $paths
}

# -----------------------------------------------------------------------------
# Move the original file into a "converted_old" subfolder (graceful: returns $false on failure)
# -----------------------------------------------------------------------------
function Move-OldFile {
    param ([string]$filePath, [string]$convertedFolderName)
    try {
        if (-not (Test-Path -LiteralPath $filePath -ErrorAction SilentlyContinue)) { return $false }
        $directory = [System.IO.Path]::GetDirectoryName($filePath)
        $convertedOldFolder = Join-Path -Path $directory -ChildPath $convertedFolderName
        if (-not (Test-Path -Path $convertedOldFolder -ErrorAction SilentlyContinue)) {
            New-Item -ItemType Directory -Path $convertedOldFolder -Force -ErrorAction SilentlyContinue | Out-Null
        }
        $newFilePath = Join-Path -Path $convertedOldFolder -ChildPath (Split-Path -Leaf $filePath)
        Move-Item -Path $filePath -Destination $newFilePath -Force -ErrorAction Stop
        return $true
    } catch {
        Write-Output "Move-OldFile failed for '$filePath': $_"
        return $false
    }
}

# -----------------------------------------------------------------------------
# If the target .xlsx/.docx/.pptx already exists, generate a unique name (e.g. "File (1).xlsx")
# -----------------------------------------------------------------------------
function Get-UniqueFileName {
    param ([string]$filePath)
    try {
        $directory = [System.IO.Path]::GetDirectoryName($filePath)
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
        $extension = [System.IO.Path]::GetExtension($filePath)
        $newFilePath = Join-Path -Path $directory -ChildPath "$fileName$extension"
        $counter = 1
        while (Test-Path -Path $newFilePath -ErrorAction SilentlyContinue) {
            $newFilePath = Join-Path -Path $directory -ChildPath "$fileName ($counter)$extension"
            $counter++
        }
        return $newFilePath
    } catch {
        # Fallback: return a unique path so caller doesn't throw (e.g. timestamp or GUID suffix)
        $dir = [System.IO.Path]::GetDirectoryName($filePath)
        $fn = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
        $ext = [System.IO.Path]::GetExtension($filePath)
        return (Join-Path $dir "$fn-$([Guid]::NewGuid().ToString('N'))$ext")
    }
}

# -----------------------------------------------------------------------------
# Convert a single file based on extension; returns $true if successful
# -----------------------------------------------------------------------------
function Convert-OneOfficeFile {
    param ([System.IO.FileInfo]$file)

    $ext = $file.Extension.ToLowerInvariant()
    $fullPath = $file.FullName

    switch ($ext) {
        ".xls" {
            $excel = $null
            try {
                $excel = New-Object -ComObject Excel.Application
                $excel.DisplayAlerts = $false
                $workbook = $excel.Workbooks.Open($fullPath)
                $newFileName = [System.IO.Path]::ChangeExtension($fullPath, ".xlsx")
                if (Test-Path -Path $newFileName) { $newFileName = Get-UniqueFileName -filePath $newFileName }
                $workbook.SaveAs($newFileName, $ExcelFormat)
                $workbook.Close($false)
                if (Move-OldFile -filePath $fullPath -convertedFolderName $ConvertedFolderName) { return $true }
                return $false
            } catch {
                Write-Output "Failed to convert Excel $fullPath : $_"
                return $false
            } finally {
                try { if ($excel) { $excel.Quit() } } catch { }
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }
        }
        ".doc" {
            $word = $null
            try {
                $word = New-Object -ComObject Word.Application
                $word.Visible = $false
                $word.DisplayAlerts = 0  # wdAlertsNone
                $document = $word.Documents.Open($fullPath)
                $newFileName = [System.IO.Path]::ChangeExtension($fullPath, ".docx")
                if (Test-Path -Path $newFileName) { $newFileName = Get-UniqueFileName -filePath $newFileName }
                $document.SaveAs([ref] $newFileName, [ref] $WordFormat)
                $document.Close()
                if (Move-OldFile -filePath $fullPath -convertedFolderName $ConvertedFolderName) { return $true }
                return $false
            } catch {
                Write-Output "Failed to convert Word $fullPath : $_"
                return $false
            } finally {
                try { if ($word) { $word.Quit() } } catch { }
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }
        }
        ".ppt" {
            # PowerPoint COM: Visible=0. Open(FileName, ReadOnly=-1, Untitled=0, WithWindow=0). SaveAs(..., 24)=ppSaveAsOpenXMLPresentation (.pptx).
            $powerpoint = $null
            try {
                $powerpoint = New-Object -ComObject PowerPoint.Application
                $powerpoint.Visible = 0
                $presentation = $powerpoint.Presentations.Open($fullPath, -1, 0, 0)
                $newFileName = [System.IO.Path]::ChangeExtension($fullPath, ".pptx")
                if (Test-Path -Path $newFileName) { $newFileName = Get-UniqueFileName -filePath $newFileName }
                $presentation.SaveAs($newFileName, 24)
                $presentation.Close()
                if (Move-OldFile -filePath $fullPath -convertedFolderName $ConvertedFolderName) { return $true }
                return $false
            } catch {
                Write-Output "Failed to convert PowerPoint $fullPath : $_"
                return $false
            } finally {
                try { if ($powerpoint) { $powerpoint.Quit() } } catch { }
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }
        }
        default { return $false }
    }
}

# -----------------------------------------------------------------------------
# Main: discover all legacy Office files in OneDrive, convert each, then report
# Graceful: one path or file failure does not stop the run; errors are logged.
# -----------------------------------------------------------------------------
$LegacyExtensions = @("*.xls", "*.doc", "*.ppt")
$escapedExclude = [regex]::Escape("\$ConvertedFolderName\")

try {
    $oneDrivePaths = @(Get-UserOneDrivePaths)
    if ($env:OneDrive -and (Test-Path -LiteralPath $env:OneDrive -ErrorAction SilentlyContinue) -and $env:OneDrive -notin $oneDrivePaths) {
        $oneDrivePaths += $env:OneDrive
    }

    $totalConverted = 0
    $totalErrors = 0

    foreach ($oneDrivePath in $oneDrivePaths) {
        if (-not $oneDrivePath -or -not (Test-Path -LiteralPath $oneDrivePath -ErrorAction SilentlyContinue)) { continue }
        try {
            foreach ($ext in $LegacyExtensions) {
                $files = Get-ChildItem -Path $oneDrivePath -Recurse -Include $ext -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch $escapedExclude }
                if (-not $files) { continue }
                foreach ($file in $files) {
                    try {
                        if (Convert-OneOfficeFile -file $file) { $totalConverted++ }
                    } catch {
                        $totalErrors++
                        Write-Output "Remediate: error processing '$($file.FullName)': $_"
                    }
                }
            }
        } catch {
            Write-Output "Remediate: error scanning path '$oneDrivePath': $_"
        }
    }

    if ($totalErrors -gt 0) {
        Write-Output "Remediation finished. Converted $totalConverted file(s); $totalErrors error(s)."
        exit 1
    }
    Write-Output "Remediation completed. Converted $totalConverted legacy Office file(s)."
    exit 0
} catch {
    Write-Output "Remediation error: $_"
    exit 1
}