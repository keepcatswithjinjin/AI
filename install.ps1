param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot
)

$ErrorActionPreference = "Stop"
$source = Join-Path $PSScriptRoot "templates\workspace"
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
Write-Host "Next: open the workspace root in Codex/Claude and trust the local hook definitions if prompted."
