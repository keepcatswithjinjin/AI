param(
    [string]$ProjectKey = "",
    [string]$Name = "",
    [ValidateSet("feature", "hotfix")]
    [string]$Type = "feature",
    [string]$BaseBranch = "master",
    [switch]$Preview,
    [switch]$SkipBaseUpdate,
    [string]$WorktreeRulesPath = "__WORKSPACE_ROOT__\rules\worktree.md"
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

$registry = @(Get-WorktreeRegistry -Path $WorktreeRulesPath)
if ($registry.Count -eq 0) {
    throw "No projects found in worktree registry."
}

$project = Select-Project -Registry $registry -Key $ProjectKey

if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = Read-Host "Worktree name"
}
Assert-WorktreeName -Value $Name

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

Write-Host "Done."
Write-Host "Open this path in Codex desktop:"
Write-Host "  $worktreePath"
Write-Host "Remember to update brief code mapping:"
Write-Host "  __WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md"
