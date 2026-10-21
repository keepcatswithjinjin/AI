param(
    [string]$ProjectKey = "",
    [string]$Name = "",
    [ValidateSet("feature", "hotfix")]
    [string]$Type = "feature",
    [string]$BaseBranch = "master",
    [switch]$Preview,
    [switch]$SkipBaseUpdate,
    [ValidateSet("Human", "Json")]
    [string]$OutputFormat = "Human",
    [string]$RequirementKey = "",
    [ValidateSet("", "backend", "frontend")]
    [string]$Role = "",
    [string]$WorktreeRulesPath = "__WORKSPACE_ROOT__\rules\worktree.md",
    [string]$WorktreeIndexPath = "__WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md"
)

$ErrorActionPreference = "Stop"
$ResultState = [ordered]@{}
$ResultEffects = [System.Collections.Generic.List[object]]::new()

# Keep existing human output unchanged while making Json mode a single machine-readable result.
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
            operation = "worktree.create"
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
    Complete-WorkflowResult -Outcome "failed" -ExitCode 1 -NextAction "Review the error and decide whether to correct inputs or repository state." -ErrorMessage $_.Exception.Message
}

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

function Update-MasterBaseline {
    param([Parameter(Mandatory = $true)][string]$RepositoryPath)

    # Reusable workspaces must preserve users' existing root-repository work.
    $dirty = @(git -c safe.directory=* -C $RepositoryPath status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw "Failed to read root repository status: $RepositoryPath" }
    if ($dirty.Count) { throw "Root repository has uncommitted changes; refusing baseline update: $RepositoryPath" }
    git -c safe.directory=* -C $RepositoryPath fetch origin master 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to fetch origin master." }
    git -c safe.directory=* -C $RepositoryPath checkout master 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to switch root repository to master: $RepositoryPath" }
    git -c safe.directory=* -C $RepositoryPath merge --ff-only origin/master 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to fast-forward master; preserve the repository and request human direction." }
    return 'fast-forward-origin/master'
}

function Get-MarkdownTableCells {
    param([AllowEmptyString()][string]$Line)
    if (-not $Line.Trim().StartsWith("|")) { return $null }
    $parts = $Line.Trim() -split "\|"
    if ($parts.Count -lt 3) { return $null }
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
        [Parameter(Mandatory = $true)][string]$IndexPath
    )
    if ($Requirement -notmatch '^(cross|backend|frontend):([a-z0-9]+(?:-[a-z0-9]+)*)$') {
        throw "RequirementKey must be type:name in kebab-case: $Requirement"
    }
    if (-not (Test-Path -LiteralPath $IndexPath)) { throw "Worktree index does not exist: $IndexPath" }
    $requirementType = $Matches[1]
    $requirementName = $Matches[2]
    if ($requirementType -eq 'cross' -and $RequestedRole -notin @('backend', 'frontend')) { throw "Cross requirement creation requires Role backend or frontend." }
    if ($requirementType -ne 'cross' -and $RequestedRole -and $RequestedRole -ne $requirementType) { throw "Role $RequestedRole does not match requirement type $requirementType." }
    if (-not $RequestedRole) { $RequestedRole = $requirementType }

    $bytes = [System.IO.File]::ReadAllBytes($IndexPath)
    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $content = [System.IO.File]::ReadAllText($IndexPath, [System.Text.Encoding]::UTF8)
    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = @($content -split '\r?\n')
    $section = ""
    $sectionStart = -1
    $sectionEnd = $lines.Count
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^##\s+(cross|backend|frontend)\s*$') {
            if ($sectionStart -ge 0 -and $section -eq $requirementType) { $sectionEnd = $index; break }
            $section = $Matches[1].ToLowerInvariant()
            if ($section -eq $requirementType) { $sectionStart = $index }
        }
    }
    if ($sectionStart -lt 0) { throw "WORKTREE-INDEX is missing type section: $requirementType" }

    $rowIndex = -1
    $cells = $null
    for ($index = $sectionStart + 1; $index -lt $sectionEnd; $index++) {
        $candidate = Get-MarkdownTableCells -Line $lines[$index]
        if ($null -ne $candidate -and $candidate.Count -ge 2 -and (Get-MarkdownCellValue $candidate[0]) -eq $requirementName) {
            $rowIndex = $index; $cells = $candidate; break
        }
    }
    if ($requirementType -eq 'cross') {
        $pathIndex = if ($RequestedRole -eq 'backend') { 2 } else { 4 }
        $branchIndex = $pathIndex + 1
        $noteIndex = 6
        if ($rowIndex -lt 0) { $cells = @(('`' + $requirementName + '`'), ('`briefs/cross/' + $requirementName + '/`'), '—', '—', '—', '—', '工作站创建的执行 worktree') }
        elseif ($cells.Count -lt 7) { throw "Cross worktree index row is malformed for $Requirement." }
    }
    else {
        $pathIndex = 2; $branchIndex = 3; $noteIndex = 4
        if ($rowIndex -lt 0) { $cells = @(('`' + $requirementName + '`'), ('`briefs/' + $requirementType + '/' + $requirementName + '/`'), '—', '—', '工作站创建的执行 worktree') }
        elseif ($cells.Count -lt 5) { throw "Worktree index row is malformed for $Requirement." }
    }
    if ((Get-MarkdownCellValue $cells[$pathIndex]) -notin @('', '—')) { throw "Requirement $Requirement already has an active $RequestedRole worktree mapping." }
    if ($rowIndex -lt 0) {
        $separator = -1
        for ($index = $sectionStart + 1; $index -lt $sectionEnd; $index++) { if ($lines[$index] -match '^---\s*$') { $separator = $index; break } }
        $rowIndex = if ($separator -ge 0) { if ($separator -gt 0 -and -not $lines[$separator - 1].Trim()) { $separator - 1 } else { $separator } } else { $sectionEnd }
        $lines = @($lines[0..($rowIndex - 1)] + @('') + $lines[$rowIndex..($lines.Count - 1)])
    }
    return [pscustomobject]@{ IndexPath = $IndexPath; Lines = $lines; Newline = $newline; Encoding = [System.Text.UTF8Encoding]::new($hasUtf8Bom); RowIndex = $rowIndex; Cells = $cells; PathIndex = $pathIndex; BranchIndex = $branchIndex; NoteIndex = $noteIndex; RequirementKey = $Requirement; Role = $RequestedRole }
}

function Sync-WorktreeIndex {
    param([Parameter(Mandatory = $true)][psobject]$Mapping, [Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Branch)
    $cells = @($Mapping.Cells)
    $cells[$Mapping.PathIndex] = ('`' + $Path + '`')
    $cells[$Mapping.BranchIndex] = ('`' + $Branch + '`')
    $date = Get-Date -Format 'yyyy-MM-dd'
    $note = "工作站脚本创建于 $date"
    $existingNote = Get-MarkdownCellValue $cells[$Mapping.NoteIndex]
    $cells[$Mapping.NoteIndex] = if ($existingNote -and $existingNote -ne '—') { "$existingNote；$note" } else { $note }
    $Mapping.Lines[$Mapping.RowIndex] = '| ' + ($cells -join ' | ') + ' |'
    $temporary = "$($Mapping.IndexPath).tmp"
    [System.IO.File]::WriteAllText($temporary, ($Mapping.Lines -join $Mapping.Newline), $Mapping.Encoding)
    Move-Item -LiteralPath $temporary -Destination $Mapping.IndexPath -Force
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
$ResultState.projectKey = $project.Key
$ResultState.repositoryPath = $project.RepoPath
$ResultState.worktreePath = $worktreePath
$ResultState.branch = $branchName
$ResultState.baseBranch = $BaseBranch
$ResultState.requirementKey = $RequirementKey
$ResultState.role = $Role

if (Test-Path -LiteralPath $worktreePath) {
    throw "Worktree path already exists: $worktreePath"
}

if (-not (Test-Path -LiteralPath $project.RepoPath)) {
    throw "Repository path not found: $($project.RepoPath)"
}

$indexMapping = $null
if ($RequirementKey) {
    $indexMapping = Resolve-WorktreeIndexMapping -Requirement $RequirementKey -RequestedRole $Role -IndexPath $WorktreeIndexPath
    $ResultState.indexSync = [ordered]@{ status = if ($Preview) { 'planned' } else { 'pending' }; indexPath = $WorktreeIndexPath; requirementKey = $indexMapping.RequirementKey; role = $indexMapping.Role }
    [void]$ResultEffects.Add([pscustomobject]@{ type = 'worktree.index-update'; status = 'planned'; requirementKey = $indexMapping.RequirementKey; role = $indexMapping.Role })
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
    Complete-WorkflowResult -Outcome "planned" -ExitCode 0 -NextAction "Obtain human confirmation, then rerun without -Preview."
}

if (-not (Test-Path -LiteralPath $project.WorktreeParent)) {
    New-Item -ItemType Directory -Path $project.WorktreeParent | Out-Null
}

if ($BaseBranch -eq "master" -and -not $SkipBaseUpdate) {
    $ResultState.masterBaseline = Update-MasterBaseline -RepositoryPath $project.RepoPath
    $baseRef = "master"
}
else {
    git -c safe.directory=* -C $project.RepoPath fetch --all --prune 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch refs."
    }
    git -c safe.directory=* -C $project.RepoPath rev-parse --verify --quiet $BaseBranch 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $baseRef = $BaseBranch
    }
    else {
        git -c safe.directory=* -C $project.RepoPath rev-parse --verify --quiet "origin/$BaseBranch" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Base branch not found locally or on origin: $BaseBranch"
        }
        $baseRef = "origin/$BaseBranch"
    }
}

git -c safe.directory=* -C $project.RepoPath worktree add -b $branchName $worktreePath $baseRef 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to add worktree."
}
[void]$ResultEffects.Add([pscustomobject]@{ type = "worktree.created"; path = $worktreePath; branch = $branchName })

if ($indexMapping) {
    try {
        Sync-WorktreeIndex -Mapping $indexMapping -Path $worktreePath -Branch $branchName
        $ResultState.indexSync.status = 'succeeded'
        [void]$ResultEffects.Add([pscustomobject]@{ type = 'worktree.index-updated'; requirementKey = $indexMapping.RequirementKey; role = $indexMapping.Role })
    }
    catch {
        $ResultState.indexSync.status = 'failed'
        $ResultState.indexSync.error = $_.Exception.Message
        Complete-WorkflowResult -Outcome "partial" -ExitCode 3 -NextAction "Worktree was created, but synchronize WORKTREE-INDEX.md before starting execution." -ErrorMessage $_.Exception.Message
    }
}

Write-Host "Done."
Write-Host "Open this path in Codex desktop:"
Write-Host "  $worktreePath"
if (-not $indexMapping -and $OutputFormat -eq 'Human') {
    Write-Host "Remember to update brief code mapping:"
    Write-Host "  __WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md"
}
$completionNextAction = if ($indexMapping) { "Worktree and WORKTREE-INDEX.md were synchronized." } else { "Update briefs/WORKTREE-INDEX.md when this worktree is attached to a requirement." }
Complete-WorkflowResult -Outcome "succeeded" -ExitCode 0 -NextAction $completionNextAction
