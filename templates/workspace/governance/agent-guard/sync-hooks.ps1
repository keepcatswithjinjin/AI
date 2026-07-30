param(
    [string]$CodexConfigPath = "$env:USERPROFILE\.codex\config.toml",
    [string]$RegistryPath = "$PSScriptRoot\hook-registry.json"
)

$ErrorActionPreference = "Stop"
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
$content = Get-Content -LiteralPath $CodexConfigPath -Raw
$pattern = '(?ms)^# >>> workspace-governance-hooks.*?^# <<< workspace-governance-hooks\r?\n?'
if ($content -notmatch $pattern) {
    throw "Managed Hook block is missing in $CodexConfigPath. Create it once through approved governance maintenance."
}
Set-Content -LiteralPath $CodexConfigPath -Value ([regex]::Replace($content, $pattern, $block + [Environment]::NewLine)) -Encoding UTF8
Write-Host "Synchronized $($registry.hooks.Count) workspace governance hook registrations."

