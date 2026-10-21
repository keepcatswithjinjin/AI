param(
    [Parameter(Mandatory = $true)]
    [string]$WorktreePath,

    [switch]$Preview,
    [switch]$Force,
    [switch]$Confirm,
    [ValidateSet("Human", "Json")]
    [string]$OutputFormat = "Human",

    [string]$RequirementKey = "",
    [ValidateSet("", "backend", "frontend")]
    [string]$Role = "",

    [string]$WorkspaceWorktreesRoot = "__WORKSPACE_ROOT__\worktrees",
    [string]$WorktreeRulesPath = "__WORKSPACE_ROOT__\rules\worktree.md",
    [string]$WorktreeIndexPath = "__WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md"
)

$ErrorActionPreference = "Stop"
$ResultState = [ordered]@{}
$ResultEffects = [System.Collections.Generic.List[object]]::new()

function Write-Host {
    param([Parameter(ValueFromRemainingArguments = $true)][object[]]$Object)
    if ($OutputFormat -eq "Human") {
        Microsoft.PowerShell.Utility\Write-Host @Object
    }
}

function Complete-WorkflowResult {
    param(
        [Parameter(Mandatory = $true)][string]$Outcome,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [string]$NextAction = "",
        [string]$ErrorMessage = ""
    )
    if ($OutputFormat -eq "Json") {
        [pscustomobject][ordered]@{
            schemaVersion = "workflow-result.v1"
            operation = "worktree.remove"
            mode = if ($Preview) { "preview" } else { "execute" }
            outcome = $Outcome
            exitCode = $ExitCode
            effects = @($ResultEffects)
            state = [pscustomobject]$ResultState
            humanActionRequired = $Outcome -in @("planned", "blocked", "cancelled", "failed", "partial")
            nextAction = $NextAction
            error = $ErrorMessage
        } | ConvertTo-Json -Depth 8 -Compress
    }
    elseif ($ErrorMessage) {
        Microsoft.PowerShell.Utility\Write-Host $ErrorMessage
    }
    exit $ExitCode
}

trap {
    Complete-WorkflowResult -Outcome "failed" -ExitCode 1 -NextAction "Review the error and decide whether to correct inputs or worktree state." -ErrorMessage $_.Exception.Message
}

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

function Get-MarkdownTableCells {
    param([AllowEmptyString()][string]$Line)
    if (-not $Line.Trim().StartsWith("|")) {
        return $null
    }
    $parts = $Line.Trim() -split "\|"
    if ($parts.Count -lt 3) {
        return $null
    }
    return @($parts[1..($parts.Count - 2)] | ForEach-Object { $_.Trim() })
}

function Get-MarkdownCellValue {
    param([Parameter(Mandatory = $true)][string]$Cell)
    return $Cell.Trim().Replace('`', '')
}

function Resolve-WorktreeIndexMapping {
    param(
        [Parameter(Mandatory = $true)][string]$Requirement,
        [Parameter(Mandatory = $true)][string]$RequestedRole,
        [Parameter(Mandatory = $true)][string]$ExpectedPath,
        [Parameter(Mandatory = $true)][string]$IndexPath
    )
    if ($Requirement -notmatch '^(cross|backend|frontend):([a-z0-9]+(?:-[a-z0-9]+)*)$') {
        throw "RequirementKey must be type:name in kebab-case: $Requirement"
    }
    if (-not (Test-Path -LiteralPath $IndexPath)) {
        throw "Worktree index does not exist: $IndexPath"
    }

    $requirementType = $Matches[1]
    $requirementName = $Matches[2]
    if ($requirementType -eq 'cross' -and $RequestedRole -notin @('backend', 'frontend')) {
        throw "Cross requirement cleanup requires Role backend or frontend."
    }
    if ($requirementType -ne 'cross' -and $RequestedRole -and $RequestedRole -ne $requirementType) {
        throw "Role $RequestedRole does not match requirement type $requirementType."
    }
    if (-not $RequestedRole) {
        $RequestedRole = $requirementType
    }

    $bytes = [System.IO.File]::ReadAllBytes($IndexPath)
    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $content = [System.IO.File]::ReadAllText($IndexPath, [System.Text.Encoding]::UTF8)
    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = @($content -split '\r?\n')
    $section = ""
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^##\s+(cross|backend|frontend)\s*$') {
            $section = $Matches[1].ToLowerInvariant()
            continue
        }
        if ($section -ne $requirementType) {
            continue
        }
        $cells = Get-MarkdownTableCells -Line $lines[$index]
        if ($null -eq $cells -or $cells.Count -lt 2 -or (Get-MarkdownCellValue $cells[0]) -ne $requirementName) {
            continue
        }
        if ($requirementType -eq 'cross') {
            if ($cells.Count -lt 7) { throw "Cross worktree index row is malformed for $Requirement." }
            $pathIndex = if ($RequestedRole -eq 'backend') { 2 } else { 4 }
            $branchIndex = $pathIndex + 1
            $noteIndex = 6
        }
        else {
            if ($cells.Count -lt 5) { throw "Worktree index row is malformed for $Requirement." }
            $pathIndex = 2
            $branchIndex = 3
            $noteIndex = 4
        }
        $mappedPath = Get-MarkdownCellValue $cells[$pathIndex]
        if (-not $mappedPath -or $mappedPath -eq '—') {
            throw "Requirement $Requirement has no active $RequestedRole worktree mapping."
        }
        if (-not (Normalize-PathString $mappedPath).Equals((Normalize-PathString $ExpectedPath), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Worktree index mapping does not match requested path for $Requirement."
        }
        return [pscustomobject]@{
            IndexPath = $IndexPath
            Content = $content
            Lines = $lines
            Newline = $newline
            RowIndex = $index
            Cells = $cells
            Encoding = [System.Text.UTF8Encoding]::new($hasUtf8Bom)
            PathIndex = $pathIndex
            BranchIndex = $branchIndex
            NoteIndex = $noteIndex
            RequirementKey = $Requirement
            Role = $RequestedRole
            Branch = Get-MarkdownCellValue $cells[$branchIndex]
        }
    }
    throw "Requirement $Requirement was not found in worktree index."
}

function Sync-WorktreeIndex {
    param([Parameter(Mandatory = $true)][psobject]$Mapping)
    $cells = @($Mapping.Cells)
    $cells[$Mapping.PathIndex] = '—'
    $cells[$Mapping.BranchIndex] = '—'
    $date = Get-Date -Format 'yyyy-MM-dd'
    $cleanupNote = "已由工作站脚本清理于 $date"
    if ($Mapping.Branch -and $Mapping.Branch -ne '—') {
        $cleanupNote += "；保留分支 $($Mapping.Branch)"
    }
    $existingNote = Get-MarkdownCellValue $cells[$Mapping.NoteIndex]
    $cells[$Mapping.NoteIndex] = if ($existingNote -and $existingNote -ne '—') { "$existingNote；$cleanupNote" } else { $cleanupNote }
    $Mapping.Lines[$Mapping.RowIndex] = '| ' + ($cells -join ' | ') + ' |'
    $temporary = "$($Mapping.IndexPath).tmp"
    [System.IO.File]::WriteAllText($temporary, ($Mapping.Lines -join $Mapping.Newline), $Mapping.Encoding)
    Move-Item -LiteralPath $temporary -Destination $Mapping.IndexPath -Force
}

$resolvedWorktreePath = Normalize-PathString $WorktreePath
$resolvedWorktreesRoot = Normalize-PathString $WorkspaceWorktreesRoot
$ResultState.worktreePath = $resolvedWorktreePath
$ResultState.worktreesRoot = $resolvedWorktreesRoot
$ResultState.force = [bool]$Force
$ResultState.confirmed = [bool]$Confirm
$ResultState.requirementKey = $RequirementKey
$ResultState.role = $Role

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

$indexMapping = $null
if ($RequirementKey) {
    $indexMapping = Resolve-WorktreeIndexMapping -Requirement $RequirementKey -RequestedRole $Role -ExpectedPath $resolvedWorktreePath -IndexPath $WorktreeIndexPath
    $ResultState.indexSync = [ordered]@{
        status = if ($Preview) { 'planned' } else { 'pending' }
        indexPath = $WorktreeIndexPath
        requirementKey = $indexMapping.RequirementKey
        role = $indexMapping.Role
    }
    [void]$ResultEffects.Add([pscustomobject]@{ type = 'worktree.index-update'; status = 'planned'; requirementKey = $indexMapping.RequirementKey; role = $indexMapping.Role })
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
    if ($OutputFormat -eq "Human") {
        $dirty
    }
    $ResultState.dirtyFiles = @($dirty)
    Complete-WorkflowResult -Outcome "blocked" -ExitCode 2 -NextAction "Obtain explicit human approval before retrying with -Force, or commit/stash the listed changes."
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

$ResultState.mainRepositoryPath = $mainRepo

Write-Host "Worktree removal plan"
Write-Host "  worktree: $resolvedWorktreePath"
Write-Host "  main repo: $mainRepo"

if ($Preview) {
    Complete-WorkflowResult -Outcome "planned" -ExitCode 0 -NextAction "Obtain human confirmation, then rerun without -Preview and with -Confirm."
}

if (-not $Confirm) {
    $answer = Read-Host "Type YES to remove this worktree"
    if ($answer -ne "YES") {
        Write-Host "Cancelled."
        Complete-WorkflowResult -Outcome "cancelled" -ExitCode 1 -NextAction "Obtain human confirmation before rerunning with -Confirm."
    }
}

if ($isGitWorktree) {
    if ($Force) {
        git -c safe.directory=* -C $mainRepo worktree remove --force $resolvedWorktreePath 2>&1 | Out-Null
    }
    else {
        git -c safe.directory=* -C $mainRepo worktree remove $resolvedWorktreePath 2>&1 | Out-Null
    }
    if ($LASTEXITCODE -ne 0) {
        if (-not $Force) {
            throw "git worktree remove failed. Close processes that use the worktree and retry."
        }
        Write-Warning "git worktree remove failed under -Force; continuing with bounded residue cleanup."
    }
    else {
        [void]$ResultEffects.Add([pscustomobject]@{ type = "worktree.removed"; path = $resolvedWorktreePath })
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
if ($indexMapping) {
    try {
        Sync-WorktreeIndex -Mapping $indexMapping
        $ResultState.indexSync.status = 'succeeded'
        [void]$ResultEffects.Add([pscustomobject]@{ type = 'worktree.index-updated'; requirementKey = $indexMapping.RequirementKey; role = $indexMapping.Role })
    }
    catch {
        $ResultState.indexSync.status = 'failed'
        $ResultState.indexSync.error = $_.Exception.Message
        Complete-WorkflowResult -Outcome "partial" -ExitCode 3 -NextAction "Worktree was removed, but synchronize WORKTREE-INDEX.md before treating cleanup as complete." -ErrorMessage $_.Exception.Message
    }
}
elseif ($OutputFormat -eq 'Human') {
    Write-Host "Remember to update brief code mapping:"
    Write-Host "  __WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md"
}
$completionNextAction = if ($indexMapping) { "Worktree and WORKTREE-INDEX.md were synchronized." } else { "Update briefs/WORKTREE-INDEX.md if this worktree is mapped to a requirement." }
Complete-WorkflowResult -Outcome "succeeded" -ExitCode 0 -NextAction $completionNextAction
