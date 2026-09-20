param(
    [Parameter(Mandatory = $true)]
    [string]$WorktreePath,

    [switch]$Preview,
    [switch]$Force,

    [string]$WorkspaceWorktreesRoot = "__WORKSPACE_ROOT__\worktrees",
    [string]$WorktreeRulesPath = "__WORKSPACE_ROOT__\rules\worktree.md"
)

$ErrorActionPreference = "Stop"

function Normalize-PathString {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Test-IsUnderPath {
    param(
        [Parameter(Mandatory = $true)][string]$Child,
        [Parameter(Mandatory = $true)][string]$Parent
    )
    $childPath = Normalize-PathString $Child
    $parentPath = Normalize-PathString $Parent
    return $childPath.StartsWith($parentPath + "\", [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-WorktreeRegistry {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    $items = @()
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|') {
            $items += [pscustomobject]@{
                Key = $Matches[1]
                RepoPath = Normalize-PathString $Matches[2]
                WorktreeParent = Normalize-PathString $Matches[4]
            }
        }
    }
    return $items
}

function Resolve-MainRepoFromRegistry {
    param([Parameter(Mandatory = $true)][string]$ProjectPath)
    foreach ($item in Get-WorktreeRegistry -Path $WorktreeRulesPath) {
        if (Test-IsUnderPath -Child $ProjectPath -Parent $item.WorktreeParent) {
            return $item.RepoPath
        }
    }
    return ""
}

$resolvedWorktreePath = Normalize-PathString $WorktreePath
$resolvedWorktreesRoot = Normalize-PathString $WorkspaceWorktreesRoot

if (-not (Test-IsUnderPath -Child $resolvedWorktreePath -Parent $resolvedWorktreesRoot)) {
    throw "Safety boundary rejected path: $resolvedWorktreePath"
}

$worktreePathExists = Test-Path -LiteralPath $resolvedWorktreePath
if (-not $worktreePathExists) {
    if (-not $Force) {
        throw "Worktree path does not exist: $resolvedWorktreePath"
    }
    Write-Host "Worktree path does not exist; continuing in residue cleanup mode because -Force was supplied."
}

$parent = Normalize-PathString (Split-Path -Parent $resolvedWorktreePath)
if ($parent.Equals($resolvedWorktreesRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Safety boundary rejected project worktree parent: $resolvedWorktreePath"
}

$isGitWorktree = $worktreePathExists
$dirty = @()
if ($isGitWorktree) {
    $dirty = git -c safe.directory=* -C $resolvedWorktreePath status --porcelain
}
if ($isGitWorktree -and $LASTEXITCODE -ne 0) {
    $isGitWorktree = $false
    if (-not $Force) {
        throw "Failed to read git status. Use -Force only if this is a known half-removed worktree: $resolvedWorktreePath"
    }
    Write-Host "Git status failed; continuing in residue cleanup mode because -Force was supplied."
}
if ($isGitWorktree -and $dirty -and -not $Force) {
    Write-Host "Dirty worktree; abort."
    $dirty
    exit 2
}

$mainRepo = ""
if ($isGitWorktree) {
    $worktreeList = git -c safe.directory=* -C $resolvedWorktreePath worktree list --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "git worktree list failed: $resolvedWorktreePath"
    }
    $mainRepo = ($worktreeList | Where-Object { $_ -match "^worktree\s+(.+)$" } | Select-Object -First 1) -replace "^worktree\s+", ""
    $mainRepo = Normalize-PathString $mainRepo
}
else {
    $mainRepo = Resolve-MainRepoFromRegistry -ProjectPath $resolvedWorktreePath
    if (-not $mainRepo) {
        throw "Unable to resolve main repository for residue cleanup: $resolvedWorktreePath"
    }
}

Write-Host "Worktree removal plan"
Write-Host "  worktree: $resolvedWorktreePath"
Write-Host "  main repo: $mainRepo"

if ($Preview) {
    exit 0
}

if (-not $Force) {
    $answer = Read-Host "Type YES to remove this worktree"
    if ($answer -ne "YES") {
        Write-Host "Cancelled."
        exit 1
    }
}

if ($isGitWorktree) {
    if ($Force) {
        git -c safe.directory=* -C $mainRepo worktree remove --force $resolvedWorktreePath
    }
    else {
        git -c safe.directory=* -C $mainRepo worktree remove $resolvedWorktreePath
    }
    if ($LASTEXITCODE -ne 0) {
        throw "git worktree remove failed. Close processes that use the worktree and retry."
    }
}
else {
    Write-Host "Skipping git worktree remove because this is already in residue cleanup mode."
}

if (Test-Path -LiteralPath $resolvedWorktreePath) {
    if (-not (Test-IsUnderPath -Child $resolvedWorktreePath -Parent $resolvedWorktreesRoot)) {
        throw "Residual path safety check failed: $resolvedWorktreePath"
    }
    Remove-Item -LiteralPath $resolvedWorktreePath -Recurse -Force
}

$gitMetaPath = Join-Path $mainRepo (".git\worktrees\" + (Split-Path -Leaf $resolvedWorktreePath))
if (Test-Path -LiteralPath $gitMetaPath) {
    $resolvedMeta = Normalize-PathString $gitMetaPath
    $allowedMeta = Normalize-PathString (Join-Path $mainRepo ".git\worktrees")
    if (-not (Test-IsUnderPath -Child $resolvedMeta -Parent $allowedMeta)) {
        throw "Git metadata residue safety check failed: $resolvedMeta"
    }
    Remove-Item -LiteralPath $resolvedMeta -Recurse -Force
}

Write-Host "Done."
Write-Host "Remember to update brief code mapping:"
Write-Host "  __WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md"
