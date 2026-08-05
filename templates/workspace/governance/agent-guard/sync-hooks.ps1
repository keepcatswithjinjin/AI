param(
    [string]$CodexConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".codex\config.toml"),
    [string]$RegistryPath = "$PSScriptRoot\hook-registry.json"
)

$ErrorActionPreference = "Stop"
$configDir = Split-Path -Parent $CodexConfigPath
if (-not (Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
}
$registry = Get-Content -LiteralPath $RegistryPath -Raw | ConvertFrom-Json
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# >>> workspace-governance-hooks (generated; source: $RegistryPath)")
foreach ($item in $registry.hooks) {
    $scriptPath = Join-Path $PSScriptRoot $item.script
    $lines.Add("")
    $lines.Add("[[hooks.$($item.event)]]")
    $lines.Add("matcher = `"$($item.matcher)`"")
    $lines.Add("")
    $lines.Add("[[hooks.$($item.event).hooks]]")
    $lines.Add('type = "command"')
    $lines.Add("command = 'python `"$scriptPath`"'")
    $lines.Add("timeout = $($item.timeout)")
    $lines.Add("statusMessage = `"$($item.statusMessage)`"")
}
$lines.Add("")
$lines.Add("# <<< workspace-governance-hooks")
$block = $lines -join [Environment]::NewLine
$content = if (Test-Path -LiteralPath $CodexConfigPath) {
    Get-Content -LiteralPath $CodexConfigPath -Raw
} else {
    "[features]$([Environment]::NewLine)hooks = true$([Environment]::NewLine)$([Environment]::NewLine)"
}
if ($content -notmatch '(?m)^\[features\]\s*$') {
    $content = "[features]$([Environment]::NewLine)hooks = true$([Environment]::NewLine)$([Environment]::NewLine)" + $content
} elseif ($content -match '(?m)^hooks\s*=') {
    $content = [regex]::Replace($content, '(?m)^hooks\s*=.*$', 'hooks = true', 1)
} else {
    $content = [regex]::Replace($content, '(?m)^\[features\]\s*$', "[features]$([Environment]::NewLine)hooks = true", 1)
}
$pattern = '(?ms)^# >>> workspace-governance-hooks.*?^# <<< workspace-governance-hooks\r?\n?'
if ($content -match $pattern) {
    $content = [regex]::Replace($content, $pattern, $block + [Environment]::NewLine)
} else {
    $content = $content.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine
}
Set-Content -LiteralPath $CodexConfigPath -Value $content -Encoding UTF8
Write-Host "Synchronized $($registry.hooks.Count) workspace governance hook registrations to $CodexConfigPath."

