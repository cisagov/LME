param(
    [string]$directory = $env:USERPROFILE
)

# Determine the base directory path based on the provided username
$baseDirectoryPath = if ($directory -and ($directory -ne $env:USERPROFILE)) {
    "C:$directory"
} else {
    "$env:USERPROFILE\Downloads"
}

$GPOBackupPath = "$baseDirectoryPath\LME\Chapter 1 Files\Group Policy Objects"

$gpoNames = @("LME-WEC-Client", "LME-WEC-Server")

foreach ($gpoName in $gpoNames) {
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        New-GPO -Name $gpoName | Out-Null
        Write-Host "Created GPO: $gpoName"
    } else {
        Write-Host "GPO $gpoName already exists."
    }

    try {
        Import-GPO -BackupGpoName $gpoName -TargetName $gpoName -Path $GPOBackupPath -CreateIfNeeded -ErrorAction Stop
        Write-Host "Imported settings into GPO: $gpoName"
    } catch {
        Throw "Failed to import GPO: $gpoName. The GPODisplayName in bkupinfo.xml may not match or other import error occurred."
    }
}

Write-Host "LME GPOs have been created and imported successfully."

