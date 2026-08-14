param(
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory = $true)]
    [string]$TargetBranch,

    [Parameter(Mandatory = $true)]
    [string]$Files,

    [Parameter(Mandatory = $true)]
    [string]$CommitMessage,

    [switch]$Preview
)

$ErrorActionPreference = "Stop"
$script:LastGitExitCode = 0

function Normalize-PathString {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    # PowerShell 7.3+ can promote native stderr to NativeCommandError when
    # $ErrorActionPreference = Stop and PSNativeCommandUseErrorActionPreference
    # is enabled by the host/profile. Git writes normal progress information
    # such as "To <remote>" to stderr, especially for push/fetch. Capture both
    # streams, but decide failure only by the native exit code.
    $previousErrorActionPreference = $ErrorActionPreference
    $hasNativePreference = Test-Path variable:\PSNativeCommandUseErrorActionPreference
    if ($hasNativePreference) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $ErrorActionPreference = "Continue"
        $rawOutput = & git -c safe.directory=* -C $script:resolvedProjectPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($hasNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }

    $script:LastGitExitCode = $exitCode
    $output = @($rawOutput | ForEach-Object { [string]$_ })
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $text = ($output | Out-String).Trim()
        throw "git $($Arguments -join ' ') failed.$([Environment]::NewLine)$text"
    }
    return @($output)
}

function Get-CurrentBranch {
    $branch = (Invoke-Git -Arguments @('branch', '--show-current')).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "Detached HEAD is not supported. Checkout the source branch first."
    }
    return $branch
}

function Get-OperationInProgress {
    $gitDir = (Invoke-Git -Arguments @('rev-parse', '--git-dir')).Trim()
    $absoluteGitDir = if ([System.IO.Path]::IsPathRooted($gitDir)) { $gitDir } else { Join-Path $script:resolvedProjectPath $gitDir }
    $markers = @('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply')
    return @($markers | Where-Object { Test-Path -LiteralPath (Join-Path $absoluteGitDir $_) })
}

function Normalize-RepoRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or [System.IO.Path]::IsPathRooted($Path)) {
        throw "-Files must use repository-relative paths: $Path"
    }
    $normalized = $Path.Replace('\', '/').TrimStart('./')
    if ($normalized -eq '' -or $normalized -match '(^|/)\.\.(/|$)') {
        throw "-Files contains an unsafe repository-relative path: $Path"
    }
    return $normalized
}

function Get-ChangedPaths {
    $lines = Invoke-Git -Arguments @('status', '--porcelain=v1', '--untracked-files=all')
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($lineObject in $lines) {
        $line = [string]$lineObject
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Length -lt 4) { throw "Unable to safely parse git status output: $line" }
        $path = $line.Substring(3).Replace('\', '/')
        if ($path -match ' -> ') { throw "Renamed files require manual handling; do not publish through this script: $line" }
        $paths.Add($path)
    }
    return @($paths | Sort-Object -Unique)
}

function Get-WorktreeBranchLocations {
    $lines = Invoke-Git -Arguments @('worktree', 'list', '--porcelain')
    $items = @()
    $path = $null
    foreach ($lineObject in $lines) {
        $line = [string]$lineObject
        if ($line -match '^worktree\s+(.+)$') {
            $path = Normalize-PathString $Matches[1]
            continue
        }
        if ($line -match '^branch\s+refs/heads/(.+)$' -and $path) {
            $items += [pscustomobject]@{ Path = $path; Branch = $Matches[1] }
        }
    }
    return $items
}

function Assert-ExactChangedFiles {
    param([Parameter(Mandatory = $true)][string[]]$ExpectedFiles)
    $actual = @(Get-ChangedPaths)
    $expected = @($ExpectedFiles | Sort-Object -Unique)
    $unexpected = @($actual | Where-Object { $_ -notin $expected })
    $missing = @($expected | Where-Object { $_ -notin $actual })
    if ($unexpected.Count -gt 0 -or $missing.Count -gt 0) {
        $details = @()
        if ($unexpected.Count -gt 0) { $details += "Unexpected changed files: $($unexpected -join ', ')" }
        if ($missing.Count -gt 0) { $details += "Expected files without changes: $($missing -join ', ')" }
        throw "File scope check failed. $($details -join ' | ')"
    }
}

function Test-HeadMatchesCommitMessage {
    param([Parameter(Mandatory = $true)][string]$ExpectedMessage)
    $message = ((Invoke-Git -Arguments @('log', '-1', '--pretty=%B')) -join [Environment]::NewLine).Trim()
    return $message -eq $ExpectedMessage.Trim()
}

function Assert-TargetNotCheckedOutElsewhere {
    param(
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][string]$CurrentPath
    )
    $matches = @(Get-WorktreeBranchLocations | Where-Object {
        $_.Branch -eq $Branch -and -not $_.Path.Equals($CurrentPath, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($matches.Count -gt 0) {
        $locations = ($matches | ForEach-Object { $_.Path }) -join ', '
        throw "Target branch '$Branch' is checked out by another worktree: $locations. Stop and ask the user whether to use that worktree or release it."
    }
}

function Test-RefExists {
    param([Parameter(Mandatory = $true)][string]$Ref)
    Invoke-Git -Arguments @('show-ref', '--verify', '--quiet', $Ref) -AllowFailure | Out-Null
    return $script:LastGitExitCode -eq 0
}

$resolvedProjectPath = Normalize-PathString $ProjectPath
if (-not (Test-Path -LiteralPath $resolvedProjectPath)) { throw "Project path not found: $resolvedProjectPath" }

$inside = (Invoke-Git -Arguments @('rev-parse', '--is-inside-work-tree')).Trim()
if ($inside -ne 'true') { throw "Project path is not a Git worktree: $resolvedProjectPath" }

if ([string]::IsNullOrWhiteSpace($TargetBranch)) { throw "Invalid target branch name: $TargetBranch" }
Invoke-Git -Arguments @('check-ref-format', '--branch', $TargetBranch) -AllowFailure | Out-Null
if ($script:LastGitExitCode -ne 0) { throw "Invalid target branch name: $TargetBranch" }

$sourceBranch = Get-CurrentBranch
if ($sourceBranch -eq $TargetBranch) { throw "Source and target branch are both '$sourceBranch'." }

$operations = @(Get-OperationInProgress)
if ($operations.Count -gt 0) { throw "Git operation already in progress: $($operations -join ', '). Resolve it manually before publishing." }

$expectedFiles = @($Files -split ',' | ForEach-Object { Normalize-RepoRelativePath $_.Trim() } | Sort-Object -Unique)
if ($expectedFiles.Count -eq 0) { throw "At least one repository-relative file must be supplied with -Files. Use a comma-separated list." }

$changedFiles = @(Get-ChangedPaths)
$resumeFromExistingSourceCommit = $false
if ($changedFiles.Count -eq 0) {
    $resumeFromExistingSourceCommit = Test-HeadMatchesCommitMessage -ExpectedMessage $CommitMessage
    if (-not $resumeFromExistingSourceCommit) {
        Assert-ExactChangedFiles -ExpectedFiles $expectedFiles
    }
}
else {
    Assert-ExactChangedFiles -ExpectedFiles $expectedFiles
}
Assert-TargetNotCheckedOutElsewhere -Branch $TargetBranch -CurrentPath $resolvedProjectPath

$localTargetExists = Test-RefExists "refs/heads/$TargetBranch"
$remoteTargetExists = Test-RefExists "refs/remotes/origin/$TargetBranch"

Write-Host "Publish-to-branch plan"
Write-Host "  project: $resolvedProjectPath"
Write-Host "  source branch: $sourceBranch"
Write-Host "  source upstream after publish: origin/$sourceBranch"
Write-Host "  target branch: $TargetBranch"
Write-Host "  target local ref exists: $localTargetExists"
Write-Host "  target origin ref known locally: $remoteTargetExists"
Write-Host "  files:"
foreach ($file in $expectedFiles) { Write-Host "    - $file" }
Write-Host "  commit message: $CommitMessage"
Write-Host "  resume from existing source commit: $resumeFromExistingSourceCommit"
Write-Host "  behavior on conflict, branch occupation, remote rejection, or any failed git command: stop and require human direction"
if ($Preview) { exit 0 }

if (-not $remoteTargetExists) {
    Invoke-Git -Arguments @('fetch', 'origin', $TargetBranch)
    $remoteTargetExists = Test-RefExists "refs/remotes/origin/$TargetBranch"
}
if (-not $remoteTargetExists) { throw "Target branch '$TargetBranch' does not exist on origin. It will not be created automatically. Ask the user for direction." }

if (-not $resumeFromExistingSourceCommit) {
    Assert-ExactChangedFiles -ExpectedFiles $expectedFiles
}
Assert-TargetNotCheckedOutElsewhere -Branch $TargetBranch -CurrentPath $resolvedProjectPath

if ($resumeFromExistingSourceCommit) {
    $sourceCommit = (Invoke-Git -Arguments @('rev-parse', 'HEAD')).Trim()
}
else {
    Invoke-Git -Arguments (@('add', '--') + $expectedFiles) | Out-Null
    Invoke-Git -Arguments @('commit', '-m', $CommitMessage) | Out-Null
    $sourceCommit = (Invoke-Git -Arguments @('rev-parse', 'HEAD')).Trim()
}

# Always use -u so a source branch that inherited origin/master is repaired to origin/<source>.
Invoke-Git -Arguments @('push', '-u', 'origin', $sourceBranch) | Out-Null

Invoke-Git -Arguments @('fetch', 'origin', $TargetBranch) | Out-Null
Assert-TargetNotCheckedOutElsewhere -Branch $TargetBranch -CurrentPath $resolvedProjectPath

if (-not (Test-RefExists "refs/heads/$TargetBranch")) {
    Invoke-Git -Arguments @('switch', '--track', '-c', $TargetBranch, "origin/$TargetBranch") | Out-Null
} else {
    Invoke-Git -Arguments @('switch', $TargetBranch) | Out-Null
}
Invoke-Git -Arguments @('pull', '--ff-only', 'origin', $TargetBranch) | Out-Null

try {
    Invoke-Git -Arguments @('merge', '--no-ff', $sourceBranch) | Out-Null
} catch {
    throw "Merge stopped on target branch '$TargetBranch'. Resolve conflicts or abort the merge manually; the script will not switch branches automatically.$([Environment]::NewLine)$($_.Exception.Message)"
}

try {
    Invoke-Git -Arguments @('push', 'origin', $TargetBranch) | Out-Null
} catch {
    throw "Target branch '$TargetBranch' was merged locally but was not pushed. Stay on this branch and ask the user whether to retry, inspect, or roll back; the script will not switch branches automatically.$([Environment]::NewLine)$($_.Exception.Message)"
}

$targetCommit = (Invoke-Git -Arguments @('rev-parse', 'HEAD')).Trim()
Invoke-Git -Arguments @('switch', $sourceBranch) | Out-Null

Write-Host "Done."
Write-Host "  restored source branch: $sourceBranch"
Write-Host "  source commit: $sourceCommit"
Write-Host "  pushed target branch: $TargetBranch"
Write-Host "  target merge commit: $targetCommit"
