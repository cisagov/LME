param(
    [string]$Directory = $env:USERPROFILE
)

# Determine the base directory path based on the provided username
$baseDirectoryPath = if ($Directory -and ($Directory -ne $env:USERPROFILE)) {
    "C:\$Directory"
} else {
    "$env:USERPROFILE\Downloads"
}

$GPOBackupPath = "$baseDirectoryPath\LME\Chapter 2 Files\GPO Deployment\Group Policy Objects"

$gpoNames = @("LME-Sysmon-Task")

foreach ($gpoName in $gpoNames) {
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        New-GPO -Name $gpoName | Out-Null
        Write-Output "Created GPO: $gpoName"
    } else {
        Write-Output "GPO $gpoName already exists."
    }

    try {
        Import-GPO -BackupGpoName $gpoName -TargetName $gpoName -Path $GPOBackupPath -CreateIfNeeded -ErrorAction Stop
        Write-Output "Imported settings into GPO: $gpoName"
    } catch {
        Throw "Failed to import GPO: $gpoName. The GPODisplayName in bkupinfo.xml may not match or other import error occurred."
    }
}

Write-Output "LME Sysmon GPOs have been created and imported successfully."

