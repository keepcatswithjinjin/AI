param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [switch]$IncludeDbAnalysis,

    [switch]$IncludeYunxiao
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 is required. Run this installer with pwsh.exe.'
}
& (Join-Path $PSScriptRoot 'check-environment.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Environment check failed. No workspace files were written.' }
$version = ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION'))).Trim()
$source = Join-Path $PSScriptRoot "templates\workspace"
$optionsRoot = Join-Path $PSScriptRoot "templates\options"
$destination = [System.IO.Path]::GetFullPath($WorkspaceRoot)

if (-not (Test-Path -LiteralPath $source)) {
    throw "Workspace template not found: $source"
}
if (Test-Path -LiteralPath $destination) {
    $existing = Get-ChildItem -Force -LiteralPath $destination
    if ($existing.Count -gt 0) {
        throw "WorkspaceRoot must be empty: $destination"
    }
} else {
    New-Item -ItemType Directory -Path $destination | Out-Null
}

Get-ChildItem -Force -LiteralPath $source | Copy-Item -Destination $destination -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSE') -Destination (Join-Path $destination 'LICENSE')

if ($IncludeDbAnalysis) {
    $dbOption = Join-Path $optionsRoot "db-analysis"
    if (-not (Test-Path -LiteralPath $dbOption)) {
        throw "Optional db-analysis template not found: $dbOption"
    }
    Get-ChildItem -Force -LiteralPath $dbOption | Copy-Item -Destination $destination -Recurse -Force
    $dbSkillSource = Join-Path $PSScriptRoot "skills\db-analysis"
    $dbSkillParent = Join-Path $destination "skills"
    if (-not (Test-Path -LiteralPath $dbSkillSource)) {
        throw "Optional db-analysis skill not found: $dbSkillSource"
    }
    New-Item -ItemType Directory -Force -Path $dbSkillParent | Out-Null
    Copy-Item -LiteralPath $dbSkillSource -Destination (Join-Path $dbSkillParent "db-analysis") -Recurse -Force
}

if ($IncludeYunxiao) {
    $yunxiaoOption = Join-Path $optionsRoot "yunxiao"
    if (-not (Test-Path -LiteralPath $yunxiaoOption)) {
        throw "Optional yunxiao template not found: $yunxiaoOption"
    }
    Get-ChildItem -Force -LiteralPath $yunxiaoOption | Copy-Item -Destination $destination -Recurse -Force
}

$textFiles = Get-ChildItem -Force -Recurse -File -LiteralPath $destination |
    Where-Object { $_.Extension -in '.md', '.ps1', '.cmd', '.py', '.json', '.yaml', '.toml' }
foreach ($file in $textFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    $replacement = if ($file.Extension -eq '.json') {
        $destination.Replace('\', '\\')
    } else {
        $destination
    }
    $content = $content.Replace('__WORKSPACE_ROOT__', $replacement)
    Set-Content -NoNewline -Encoding UTF8 -LiteralPath $file.FullName -Value $content
}

$manifest = [ordered]@{ schemaVersion = 1; frameworkVersion = $version; installedAt = (Get-Date).ToUniversalTime().ToString('o'); options = @{ dbAnalysis = [bool]$IncludeDbAnalysis; yunxiao = [bool]$IncludeYunxiao } }
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $destination 'workstation-install.json')
Write-Host "Multi-project workstation installed at: $destination"
Write-Host "Workspace-local Codex and Claude hook templates were installed under .codex and .claude."
if ($IncludeDbAnalysis) {
    Write-Host "Optional db-analysis scripts and workspace-local skill were installed under scripts and skills."
} else {
    Write-Host "Optional db-analysis was not installed. Existing workspaces require a selective upgrade; do not rerun the installer over them."
}
if ($IncludeYunxiao) {
    Write-Host "Optional Yunxiao MCP and workspace skill templates were installed. Fill .codex\secrets locally and enable the MCP block in .codex\config.toml before use."
} else {
    Write-Host "Optional Yunxiao was not installed. Existing workspaces require a selective upgrade; do not rerun the installer over them."
}
Write-Host "Next: open the workspace root in Codex/Claude and trust the local hook definitions if prompted."
