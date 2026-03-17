<#
.SYNOPSIS
    Intune Remediation - Remediation: Convert old Word (.doc) to .docx in OneDrive and move originals to converted_old.

.DESCRIPTION
    Runs when detection found legacy .doc files. Converts each to .docx using Word COM, then moves
    the original into a local "converted_old" folder. Runs in SYSTEM context; processes all user
    OneDrive folders. Requires Word installed.

.NOTES
    Intune: Remediation script. Run after detection exits 1.
    Word SaveAs uses format 16 = wdFormatXMLDocument (.docx).
#>

$ConvertedFolderName = "converted_old"
$WordFormat = 16   # wdFormatXMLDocument
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

function Move-OldFile {
    param ([string]$filePath, [string]$convertedFolderName)
    $directory = [System.IO.Path]::GetDirectoryName($filePath)
    $convertedOldFolder = Join-Path -Path $directory -ChildPath $convertedFolderName
    if (-not (Test-Path -Path $convertedOldFolder)) {
        New-Item -ItemType Directory -Path $convertedOldFolder -Force | Out-Null
    }
    $newFilePath = Join-Path -Path $convertedOldFolder -ChildPath (Split-Path -Leaf $filePath)
    Move-Item -Path $filePath -Destination $newFilePath -Force
}

function Get-UniqueFileName {
    param ([string]$filePath)
    $directory = [System.IO.Path]::GetDirectoryName($filePath)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    $extension = [System.IO.Path]::GetExtension($filePath)
    $newFilePath = Join-Path -Path $directory -ChildPath "$fileName$extension"
    $counter = 1
    while (Test-Path -Path $newFilePath) {
        $newFilePath = Join-Path -Path $directory -ChildPath "$fileName ($counter)$extension"
        $counter++
    }
    return $newFilePath
}

try {
    $oneDrivePaths = Get-UserOneDrivePaths
    if ($env:OneDrive -and (Test-Path -LiteralPath $env:OneDrive) -and $env:OneDrive -notin $oneDrivePaths) {
        $oneDrivePaths += $env:OneDrive
    }
    $totalConverted = 0
    foreach ($oneDrivePath in $oneDrivePaths) {
        $wordFiles = Get-ChildItem -Path $oneDrivePath -Recurse -Include "*.doc" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch [regex]::Escape("\$ConvertedFolderName\") }
        foreach ($file in $wordFiles) {
            try {
                $word = New-Object -ComObject Word.Application
                $word.Visible = $false
                $word.DisplayAlerts = 0   # wdAlertsNone
                $document = $word.Documents.Open($file.FullName)
                $newFileName = [System.IO.Path]::ChangeExtension($file.FullName, ".docx")
                if (Test-Path -Path $newFileName) { $newFileName = Get-UniqueFileName -filePath $newFileName }
                $document.SaveAs([ref] $newFileName, [ref] $WordFormat)
                $document.Close()
                Move-OldFile -filePath $file.FullName -convertedFolderName $ConvertedFolderName
                $totalConverted++
            } catch {
                Write-Output "Failed to convert $($file.FullName): $_"
            } finally {
                try { $word.Quit() } catch { }
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }
        }
    }
    Write-Output "Remediation completed. Converted $totalConverted .doc file(s)."
    exit 0
} catch {
    Write-Output "Remediation error: $_"
    exit 1
}
