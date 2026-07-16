param(
    [string]$StatePath = "__WORKSPACE_ROOT__\scripts\workspace-state.json",
    [string]$Tool,
    [string]$SessionName,
    [string]$SessionId = "",
    [bool]$Enabled = $true
)

$ErrorActionPreference = "Stop"

function Normalize-PathValue {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $PathValue
    }
    try {
        return (Resolve-Path -LiteralPath $PathValue).Path
    } catch {
        return $PathValue.Replace("/", "\")
    }
}

if (-not (Test-Path -LiteralPath $StatePath)) {
    throw "Workspace state file not found: $StatePath"
}

try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $repoRoot = (& git rev-parse --show-toplevel 2>$null)
    $ErrorActionPreference = $previousPreference
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "Current directory is not inside a git repository."
    }
    $repoRoot = Normalize-PathValue (($repoRoot -join "").Trim())
} finally {
    $ErrorActionPreference = $previousPreference
}

if ([string]::IsNullOrWhiteSpace($Tool)) {
    throw "Tool is required. Use -Tool codex or -Tool claude."
}

$normalizedTool = $Tool.ToLowerInvariant()
if ($normalizedTool -notin @("codex", "claude", "powershell")) {
    throw "Unsupported tool '$Tool'. Use codex, claude, or powershell."
}

if ([string]::IsNullOrWhiteSpace($SessionName)) {
    throw "SessionName is required. Provide the name used by the CLI resume command."
}

$state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
$sessions = New-Object System.Collections.ArrayList
foreach ($item in @($state.sessions)) {
    [void]$sessions.Add($item)
}

$target = $null
foreach ($item in $sessions) {
    if ((Normalize-PathValue $item.path) -eq $repoRoot) {
        $target = $item
        break
    }
}
if ($null -eq $target -and -not [string]::IsNullOrWhiteSpace($SessionId)) {
    foreach ($item in $sessions) {
        if ($item.sessionId -eq $SessionId) {
            $target = $item
            break
        }
    }
}
if ($null -eq $target) {
    $target = [PSCustomObject]@{
        sessionName = $SessionName
        sessionId = $SessionId
        path = $repoRoot
        tool = $normalizedTool
        enabled = $Enabled
    }
    [void]$sessions.Add($target)
} else {
    $target.sessionName = $SessionName
    $target.sessionId = $SessionId
    $target.path = $repoRoot
    $target.tool = $normalizedTool
    $target.enabled = $Enabled
}

$state.version = 2
$state.updatedAt = Get-Date -Format "yyyy-MM-dd"
$state.sessions = @($sessions)

$json = $state | ConvertTo-Json -Depth 6
Set-Content -LiteralPath $StatePath -Value $json -Encoding UTF8

[PSCustomObject]@{
    sessionName = $SessionName
    sessionId = $SessionId
    path = $repoRoot
    tool = $normalizedTool
    enabled = $Enabled
} | Format-Table -AutoSize
