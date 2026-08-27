param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "db-targets.json"),
    [string]$CredentialsRoot = (Join-Path $PSScriptRoot "private\mysql"),
    [switch]$Preview,
    [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Config not found: $ConfigPath"
}

$config = (Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8) | ConvertFrom-Json
if (-not $config.targets) {
    throw "Config has no targets: $ConfigPath"
}

$pending = @()
foreach ($target in @($config.targets)) {
    $password = [string]$target.password
    $existingClientFile = ([string]$target.clientDefaultsFile).Trim()
    if ([string]::IsNullOrEmpty($password) -or $existingClientFile) {
        continue
    }
    if ($password -match "[\r\n]") {
        throw "Target '$($target.name)' has a password unsupported by option-file migration."
    }
    $safeName = ([string]$target.name) -replace "[^A-Za-z0-9._-]", "-"
    $pending += [pscustomobject]@{
        Target = $target
        Path = Join-Path $CredentialsRoot "$safeName.cnf"
        Password = $password
    }
}

if ($pending.Count -eq 0) {
    Write-Output "No legacy password entries require migration."
    exit 0
}

foreach ($item in $pending) {
    if ((Test-Path -LiteralPath $item.Path) -and -not $Overwrite) {
        throw "Credential file already exists: $($item.Path). Use -Overwrite only after manual review."
    }
    Write-Output "$(if ($Preview) { '[Preview] ' })Migrate target '$($item.Target.name)' to $($item.Path)"
}

if ($Preview) {
    exit 0
}

New-Item -ItemType Directory -Path $CredentialsRoot -Force | Out-Null
foreach ($item in $pending) {
    $contents = "[client]`r`npassword=$($item.Password)`r`n"
    [System.IO.File]::WriteAllText($item.Path, $contents, [System.Text.UTF8Encoding]::new($false))
    $item.Target.PSObject.Properties.Remove("password")
    $item.Target | Add-Member -NotePropertyName "clientDefaultsFile" -NotePropertyValue $item.Path
}

$json = $config | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($ConfigPath, "$json`r`n", [System.Text.UTF8Encoding]::new($false))
Write-Output "Migrated $($pending.Count) target(s). Passwords now reside only in local MySQL option files."
