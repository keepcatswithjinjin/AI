param(
    [string]$ProjectKey = "",
    [string]$Name = "",
    [ValidateSet("feature", "hotfix")]
    [string]$Type = "feature",
    [string]$BaseBranch = "master",
    [ValidateSet("Ask", "Enable", "Disable")]
    [string]$Serena = "Ask",
    [switch]$Preview,
    [switch]$SkipBaseUpdate,
    [string]$WorktreeRulesPath = "__WORKSPACE_ROOT__\rules\worktree.md",
    [string]$SerenaExe = ""
)

$ErrorActionPreference = "Stop"

function Normalize-PathString {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Get-WorktreeRegistry {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Worktree rules file not found: $Path"
    }
    $items = @()
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|') {
            $items += [pscustomobject]@{
                Key = $Matches[1]
                RepoPath = Normalize-PathString $Matches[2]
                Description = $Matches[3].Trim()
                WorktreeParent = Normalize-PathString $Matches[4]
            }
        }
    }
    return $items
}

function Select-Project {
    param(
        [Parameter(Mandatory = $true)][object[]]$Registry,
        [string]$Key
    )
    if ([string]::IsNullOrWhiteSpace($Key)) {
        Write-Host "Available projects:"
        foreach ($item in $Registry) {
            Write-Host "  $($item.Key) -> $($item.RepoPath)"
        }
        $Key = Read-Host "ProjectKey"
    }
    $selected = @($Registry | Where-Object { $_.Key -eq $Key })
    if ($selected.Count -ne 1) {
        throw "Unknown ProjectKey: $Key"
    }
    return $selected[0]
}

function Assert-WorktreeName {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
        throw "Invalid worktree name. Use kebab-case, for example: salecombo-price"
    }
}

function Resolve-SerenaMode {
    param([Parameter(Mandatory = $true)][string]$Mode)
    if ($Mode -ne "Ask") {
        return $Mode
    }
    $answer = Read-Host "Enable Serena for this worktree? Type YES to enable"
    if ($answer -eq "YES") {
        return "Enable"
    }
    return "Disable"
}

function Resolve-SerenaExecutable {
    param([string]$ExplicitPath)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (Test-Path -LiteralPath $ExplicitPath) { return (Normalize-PathString $ExplicitPath) }
        throw "Serena executable not found: $ExplicitPath"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:SERENA_EXE)) {
        if (Test-Path -LiteralPath $env:SERENA_EXE) { return (Normalize-PathString $env:SERENA_EXE) }
        throw "SERENA_EXE points to a missing file: $env:SERENA_EXE"
    }
    $cmd = Get-Command serena -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "Serena executable was not found. Install Serena and make 'serena' available in PATH, set SERENA_EXE, or pass -SerenaExe <path>."
}

function Write-SerenaConfig {
    param(
        [Parameter(Mandatory = $true)][string]$WorktreePath,
        [Parameter(Mandatory = $true)][string]$ExecutablePath
    )
    if (-not (Test-Path -LiteralPath $ExecutablePath)) {
        throw "Serena executable not found: $ExecutablePath"
    }
    $codexDir = Join-Path $WorktreePath ".codex"
    $configPath = Join-Path $codexDir "config.toml"
    if (-not (Test-Path -LiteralPath $codexDir)) {
        New-Item -ItemType Directory -Path $codexDir | Out-Null
    }
    $block = @"

[mcp_servers.serena]
command = "$($ExecutablePath.Replace('\', '\\'))"
args = ["start-mcp-server", "--context=codex", "--project-from-cwd"]
startup_timeout_sec = 120
"@
    if (-not (Test-Path -LiteralPath $configPath)) {
        Set-Content -LiteralPath $configPath -Value $block.TrimStart() -Encoding UTF8
        return
    }
    $existing = Get-Content -LiteralPath $configPath -Raw
    if ($existing -match "(?im)^\s*\[mcp_servers\.serena\]") {
        if ($existing -notmatch [regex]::Escape($ExecutablePath.Replace('\', '\\'))) {
            throw "Existing Serena config is different. Please review manually: $configPath"
        }
        return
    }
    Add-Content -LiteralPath $configPath -Value $block -Encoding UTF8
}

$registry = @(Get-WorktreeRegistry -Path $WorktreeRulesPath)
if ($registry.Count -eq 0) {
    throw "No projects found in worktree registry."
}

$project = Select-Project -Registry $registry -Key $ProjectKey

if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = Read-Host "Worktree name"
}
Assert-WorktreeName -Value $Name

$serenaMode = Resolve-SerenaMode -Mode $Serena
$resolvedSerenaExe = if ($serenaMode -eq "Enable") { Resolve-SerenaExecutable -ExplicitPath $SerenaExe } else { "" }
$branchName = "$Type/$Name"
$worktreePath = Normalize-PathString (Join-Path $project.WorktreeParent $Name)

if (Test-Path -LiteralPath $worktreePath) {
    throw "Worktree path already exists: $worktreePath"
}

if (-not (Test-Path -LiteralPath $project.RepoPath)) {
    throw "Repository path not found: $($project.RepoPath)"
}

$inside = git -c safe.directory=* -C $project.RepoPath rev-parse --is-inside-work-tree
if ($LASTEXITCODE -ne 0 -or $inside.Trim() -ne "true") {
    throw "Repository path is not a git work tree: $($project.RepoPath)"
}

$existingBranch = git -c safe.directory=* -C $project.RepoPath show-ref --verify --quiet "refs/heads/$branchName"
if ($LASTEXITCODE -eq 0) {
    throw "Branch already exists: $branchName"
}

Write-Host "New worktree plan"
Write-Host "  project: $($project.Key)"
Write-Host "  repo: $($project.RepoPath)"
Write-Host "  worktree: $worktreePath"
Write-Host "  branch: $branchName"
Write-Host "  base branch: $BaseBranch"
Write-Host "  serena: $serenaMode"
if ($serenaMode -eq "Enable") {
    Write-Host "  serena exe: $resolvedSerenaExe"
}

if ($Preview) {
    exit 0
}

if (-not (Test-Path -LiteralPath $project.WorktreeParent)) {
    New-Item -ItemType Directory -Path $project.WorktreeParent | Out-Null
}

if ($BaseBranch -eq "master" -and -not $SkipBaseUpdate) {
    git -c safe.directory=* -C $project.RepoPath fetch origin master
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch origin master."
    }
    git -c safe.directory=* -C $project.RepoPath checkout master
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to checkout master."
    }
    git -c safe.directory=* -C $project.RepoPath pull --ff-only origin master
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fast-forward master."
    }
    $baseRef = "master"
}
else {
    git -c safe.directory=* -C $project.RepoPath fetch --all --prune
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch refs."
    }
    git -c safe.directory=* -C $project.RepoPath rev-parse --verify --quiet $BaseBranch
    if ($LASTEXITCODE -eq 0) {
        $baseRef = $BaseBranch
    }
    else {
        git -c safe.directory=* -C $project.RepoPath rev-parse --verify --quiet "origin/$BaseBranch"
        if ($LASTEXITCODE -ne 0) {
            throw "Base branch not found locally or on origin: $BaseBranch"
        }
        $baseRef = "origin/$BaseBranch"
    }
}

git -c safe.directory=* -C $project.RepoPath worktree add -b $branchName $worktreePath $baseRef
if ($LASTEXITCODE -ne 0) {
    throw "Failed to add worktree."
}

if ($serenaMode -eq "Enable") {
    Write-SerenaConfig -WorktreePath $worktreePath -ExecutablePath $resolvedSerenaExe
}

Write-Host "Done."
Write-Host "Open this path in Codex desktop:"
Write-Host "  $worktreePath"
Write-Host "Remember to update brief code mapping:"
Write-Host "  __WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md"
