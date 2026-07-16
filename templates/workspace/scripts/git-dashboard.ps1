param(
    [string]$Root = "__WORKSPACE_ROOT__",
    [switch]$Fetch,
    [switch]$FullDirtyCheck,
    [switch]$Detailed,
    [switch]$Board
)

$ErrorActionPreference = "Stop"

$testBranches = @("test", "test-new", "testing")
$worktreeRulePath = Join-Path $Root "rules\worktree.md"
$effectiveDetailed = $Detailed -or $Board

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string[]]$Args
    )

    $previousOptionalLocks = $env:GIT_OPTIONAL_LOCKS
    $env:GIT_OPTIONAL_LOCKS = "0"
    try {
        $output = & git -C $Repo @Args 2>$null
    } catch {
        return $null
    } finally {
        if ($null -eq $previousOptionalLocks) {
            Remove-Item Env:\GIT_OPTIONAL_LOCKS -ErrorAction SilentlyContinue
        } else {
            $env:GIT_OPTIONAL_LOCKS = $previousOptionalLocks
        }
    }
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return $output
}

function Get-Projects {
    param([string]$RulePath)

    if (-not (Test-Path -LiteralPath $RulePath)) {
        throw "worktree rule file not found: $RulePath"
    }

    $projects = @()
    foreach ($line in Get-Content -LiteralPath $RulePath) {
        if ($line -match '^\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|') {
            $projects += [PSCustomObject]@{
                Key = $matches[1]
                RepoPath = $matches[2]
                Description = $matches[3].Trim()
                WorktreeRoot = $matches[4]
            }
        }
    }

    return $projects
}

function Get-BranchStatus {
    param(
        [string]$WorktreePath,
        [string]$Branch
    )

    if ([string]::IsNullOrWhiteSpace($Branch) -or $Branch -eq "HEAD") {
        return "-"
    }

    $upstream = Invoke-Git -Repo $WorktreePath -Args @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    if (-not $upstream) {
        return "no-upstream"
    }

    $counts = Invoke-Git -Repo $WorktreePath -Args @("rev-list", "--left-right", "--count", "HEAD...@{u}")
    if (-not $counts) {
        return "unknown"
    }

    $parts = ($counts -join " ").Trim() -split "\s+"
    $ahead = [int]$parts[0]
    $behind = [int]$parts[1]

    if ($ahead -eq 0 -and $behind -eq 0) {
        return "synced"
    }
    if ($ahead -gt 0 -and $behind -gt 0) {
        return "ahead $ahead, behind $behind"
    }
    if ($ahead -gt 0) {
        return "ahead $ahead"
    }
    return "behind $behind"
}

function Get-DirtyFlag {
    param([string]$WorktreePath)

    $statusArgs = if ($FullDirtyCheck) {
        @("status", "--porcelain")
    } else {
        @("status", "--porcelain", "--untracked-files=no")
    }
    $status = Invoke-Git -Repo $WorktreePath -Args $statusArgs
    if ($status -and $status.Count -gt 0) {
        return "dirty"
    }
    return "clean"
}

function Parse-WorktreeList {
    param(
        [string]$ProjectKey,
        [string]$RepoPath
    )

    $lines = Invoke-Git -Repo $RepoPath -Args @("worktree", "list", "--porcelain")
    if (-not $lines) {
        return @()
    }

    $items = @()
    $current = @{}
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($current.ContainsKey("worktree")) {
                $items += [PSCustomObject]$current
            }
            $current = @{}
            continue
        }

        $firstSpace = $line.IndexOf(" ")
        if ($firstSpace -lt 0) {
            $current[$line] = $true
            continue
        }

        $name = $line.Substring(0, $firstSpace)
        $value = $line.Substring($firstSpace + 1)
        $current[$name] = $value
    }
    if ($current.ContainsKey("worktree")) {
        $items += [PSCustomObject]$current
    }

    $rows = @()
    foreach ($item in $items) {
        $path = $item.worktree
        $branch = if ($item.PSObject.Properties.Name -contains "branch") {
            ($item.branch -replace '^refs/heads/', '')
        } elseif ($item.PSObject.Properties.Name -contains "detached") {
            "HEAD"
        } else {
            "-"
        }

        if ($effectiveDetailed) {
            $dirty = Get-DirtyFlag -WorktreePath $path
            $sync = Get-BranchStatus -WorktreePath $path -Branch $branch
            $lastCommit = Invoke-Git -Repo $path -Args @("log", "-1", "--pretty=format:%h %s")
        } else {
            $dirty = "-"
            $sync = "-"
            $lastCommit = $item.HEAD.Substring(0, [Math]::Min(8, $item.HEAD.Length))
        }
        $isTest = if ($testBranches -contains $branch) { "YES" } else { "-" }

        $rows += [PSCustomObject]@{
            Project = $ProjectKey
            Branch = $branch
            Dirty = $dirty
            Sync = $sync
            Test = $isTest
            Path = $path
            LastCommit = ($lastCommit -join "")
        }
    }

    return $rows
}

$projects = Get-Projects -RulePath $worktreeRulePath
if ($projects.Count -eq 0) {
    throw "no projects found in $worktreeRulePath"
}

if ($Fetch) {
    foreach ($project in $projects) {
        if (Test-Path -LiteralPath $project.RepoPath) {
            Write-Host "Fetching $($project.Key)..." -ForegroundColor DarkGray
            & git -C $project.RepoPath fetch --all --prune | Out-Null
        }
    }
}

$rows = @()
foreach ($project in $projects) {
    if (-not (Test-Path -LiteralPath $project.RepoPath)) {
        $rows += [PSCustomObject]@{
            Project = $project.Key
            Branch = "-"
            Dirty = "missing"
            Sync = "-"
            Test = "-"
            Path = $project.RepoPath
            LastCommit = "repo path not found"
        }
        continue
    }
    $rows += Parse-WorktreeList -ProjectKey $project.Key -RepoPath $project.RepoPath
}

if ($Board) {
    $testRows = @($rows | Where-Object { $_.Test -eq "YES" } | Sort-Object Project, Path)
    $dirtyRows = @($rows | Where-Object { $_.Dirty -eq "dirty" } | Sort-Object Project, Path)

    Write-Host "=== Test branch occupancy ===" -ForegroundColor Yellow
    if ($testRows.Count -gt 0) {
        $testRows | Format-Table Project, Branch, Dirty, Sync, Path -AutoSize
    } else {
        Write-Host "None"
    }

    Write-Host ""
    Write-Host "=== Dirty worktrees ===" -ForegroundColor Yellow
    if ($dirtyRows.Count -gt 0) {
        $dirtyRows | Format-Table Project, Branch, Sync, Path -AutoSize
    } else {
        Write-Host "None"
    }

    Write-Host ""
    Write-Host "=== Worktree board ===" -ForegroundColor Yellow
    $rows |
        Sort-Object Project, Path |
        Format-Table Project, Branch, Dirty, Sync, Test, Path -AutoSize
} else {
    $rows |
        Sort-Object Project, Path |
        Format-Table Project, Branch, Dirty, Sync, Test, Path, LastCommit -AutoSize

    $testRows = @($rows | Where-Object { $_.Test -eq "YES" })
    if ($testRows.Count -gt 0) {
        Write-Host ""
        Write-Host "Test branch occupancy:" -ForegroundColor Yellow
        $testRows | Format-Table Project, Branch, Dirty, Path -AutoSize
    }

    $dirtyRows = @($rows | Where-Object { $_.Dirty -eq "dirty" })
    if ($dirtyRows.Count -gt 0) {
        Write-Host ""
        Write-Host "Dirty worktrees:" -ForegroundColor Yellow
        $dirtyRows | Format-Table Project, Branch, Path -AutoSize
    }
}
