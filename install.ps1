param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [switch]$IncludeDbAnalysis,

    [switch]$IncludeYunxiao
)

$ErrorActionPreference = "Stop"
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

if ($IncludeDbAnalysis) {
    $dbOption = Join-Path $optionsRoot "db-analysis"
    if (-not (Test-Path -LiteralPath $dbOption)) {
        throw "Optional db-analysis template not found: $dbOption"
    }
    Get-ChildItem -Force -LiteralPath $dbOption | Copy-Item -Destination $destination -Recurse -Force
}

if ($IncludeYunxiao) {
    $yunxiaoOption = Join-Path $optionsRoot "yunxiao"
    if (-not (Test-Path -LiteralPath $yunxiaoOption)) {
        throw "Optional yunxiao template not found: $yunxiaoOption"
    }
    Get-ChildItem -Force -LiteralPath $yunxiaoOption | Copy-Item -Destination $destination -Recurse -Force
}

$textFiles = Get-ChildItem -Recurse -File -LiteralPath $destination |
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

Write-Host "Multi-project workstation installed at: $destination"
Write-Host "Workspace-local Codex and Claude hook templates were installed under .codex and .claude."
if ($IncludeDbAnalysis) {
    Write-Host "Optional db-analysis workspace scripts were installed. Copy skills\db-analysis to your Codex skills directory before use."
} else {
    Write-Host "Optional db-analysis workspace scripts were not installed. Re-run with -IncludeDbAnalysis if needed."
}
if ($IncludeYunxiao) {
    Write-Host "Optional Yunxiao MCP and workspace skill templates were installed. Fill .codex\secrets locally and enable the MCP block in .codex\config.toml before use."
} else {
    Write-Host "Optional Yunxiao MCP and workspace skill templates were not installed. Re-run with -IncludeYunxiao if needed."
}
Write-Host "Next: open the workspace root in Codex/Claude and trust the local hook definitions if prompted."
