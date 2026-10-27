$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$skillScript = Join-Path $workspaceRoot "skills\db-analysis\scripts\db-analysis.ps1"
if (-not (Test-Path -LiteralPath $skillScript)) {
    throw "db-analysis skill script not found: $skillScript"
}

$forwardArgs = @($args)
$hasConfigPath = $false
foreach ($arg in $forwardArgs) {
    if ($arg -eq "-ConfigPath") {
        $hasConfigPath = $true
        break
    }
}

if ($hasConfigPath) {
    & $skillScript @forwardArgs
} else {
    $defaultConfig = Join-Path $PSScriptRoot "db-targets.json"
    & $skillScript -ConfigPath $defaultConfig @forwardArgs
}
exit $LASTEXITCODE
