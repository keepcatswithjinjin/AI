param(
    [Parameter(Mandatory = $true)][ValidateSet('Register', 'DesignReady', 'Developing', 'Released')][string]$Action,
    [Parameter(Mandatory = $true)][ValidatePattern('^(cross|backend|frontend):[a-z0-9]+(?:-[a-z0-9]+)*$')][string]$RequirementKey,
    [string]$WorkstationRoot = '__WORKSPACE_ROOT__'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'worktree-locations.ps1')

function Complete-Result {
    param([string]$Outcome, [string]$Message, [object]$State = $null, [int]$ExitCode = 0)
    [pscustomobject]@{ schemaVersion = 'workstation-state.v1'; outcome = $Outcome; message = $Message; state = $State } | ConvertTo-Json -Compress -Depth 6
    exit $ExitCode
}

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Write-StateFile([string]$Path, [object]$Value) {
    $temporary = "$Path.tmp"
    $json = $Value | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($temporary, $json + "`n", [System.Text.UTF8Encoding]::new($true))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Has-IndexEntry([string]$IndexPath, [string]$Type, [string]$Name) {
    if (-not (Test-Path -LiteralPath $IndexPath)) { return $false }
    $expected = '| `' + $Name + '` | `briefs/' + $Type + '/' + $Name + '/` |'
    return @(
        Get-Content -LiteralPath $IndexPath -Encoding UTF8 |
            Where-Object { $_.Trim() -eq $expected }
    ).Count -gt 0
}

function Get-RequiredFiles([string]$Type, [string]$BriefPath) {
    $names = if ($Type -eq 'backend') { @('design.md', 'backend-plan.md') } elseif ($Type -eq 'frontend') { @('design.md', 'frontend-plan.md') } else { @('design.md', 'api-contract.md', 'backend-plan.md', 'frontend-plan.md') }
    return @($names | Where-Object { -not (Test-Path -LiteralPath (Join-Path (Join-Path $BriefPath 'spec') $_)) })
}

function Has-ActiveWorktree([string]$WorktreeIndexPath, [string]$Type, [string]$Name) {
    if (-not (Test-Path -LiteralPath $WorktreeIndexPath)) { return $false }
    foreach ($row in (Read-MultiLocationIndex $WorktreeIndexPath).Rows) {
        if ($row.Cells[0] -eq "${Type}:$Name" -and $row.Cells[4] -notin @('', '—') -and (Test-Path -LiteralPath $row.Cells[4])) { return $true }
    }
    $section = ''
    foreach ($line in Get-Content -LiteralPath $WorktreeIndexPath -Encoding UTF8) {
        if ($line -match '^##\s+(cross|backend|frontend)\s*$') { $section = $Matches[1]; continue }
        if ($line -match '^##\s+') { $section = ''; continue }
        if ($section -ne $Type -or $line -notmatch '^\|') { continue }
        $cells = @($line.Trim() -split '\|' | Select-Object -Skip 1 | Select-Object -SkipLast 1 | ForEach-Object { $_.Trim().Trim('`') })
        if ($cells.Count -lt 3 -or $cells[0] -ne $Name) { continue }
        $paths = if ($Type -eq 'cross') { @($cells[2], $cells[4]) } else { @($cells[2]) }
        return @($paths | Where-Object { $_ -and $_ -ne '—' -and (Test-Path -LiteralPath $_) }).Count -gt 0
    }
    return $false
}

try {
    $parts = $RequirementKey -split ':', 2
    $type = $parts[0]; $name = $parts[1]
    $briefPath = Join-Path $WorkstationRoot "briefs\$type\$name"
    $briefIndex = Join-Path $WorkstationRoot 'briefs\INDEX.md'
    $worktreeIndex = Join-Path $WorkstationRoot 'briefs\WORKTREE-INDEX.md'
    $statePath = Join-Path $WorkstationRoot 'briefs\WORKSTATION-STATE.json'
    if (-not (Has-IndexEntry $briefIndex $type $name)) { Complete-Result 'failed' '需求未登记在 briefs/INDEX.md。' $null 1 }

    $document = Read-JsonFile $statePath
    if ($null -eq $document) { $document = [pscustomobject]@{ schemaVersion = 'workstation-state.v1'; requirements = [pscustomobject]@{} } }
    if ($null -eq $document.requirements) { $document | Add-Member -NotePropertyName requirements -NotePropertyValue ([pscustomobject]@{}) }
    $current = $document.requirements.PSObject.Properties[$RequirementKey].Value
    $now = (Get-Date).ToUniversalTime().ToString('o')

    if ($Action -eq 'Register') {
        if ($current) { Complete-Result 'unchanged' '需求已登记状态。' $current }
        $current = [pscustomobject]@{ stage = 'pending'; createdAt = $now; designConfirmedAt = $null; developingStartedAt = $null; releasedAt = $null; updatedAt = $now }
        $document.requirements | Add-Member -NotePropertyName $RequirementKey -NotePropertyValue $current
        Write-StateFile $statePath $document
        Complete-Result 'updated' '已登记为待处理。' $current
    }

    if (-not $current) { Complete-Result 'failed' '需求尚未纳入工作站状态机；请先登记需求索引并调用 Register。' $null 1 }
    if ($Action -eq 'DesignReady') {
        if ($current.stage -eq 'design_ready') { Complete-Result 'unchanged' '方案状态已同步。' $current }
        if ($current.stage -ne 'pending') { Complete-Result 'failed' "当前状态为 $($current.stage)，不能再次同步方案状态。" $current 1 }
        $missing = Get-RequiredFiles $type $briefPath
        if ($missing.Count) { Complete-Result 'failed' ("brief 尚缺少：" + ($missing -join '、')) $current 1 }
        $current.stage = 'design_ready'; $current.designConfirmedAt = $now; $current.updatedAt = $now
        Write-StateFile $statePath $document
        Complete-Result 'updated' '方案已制定，等待开发。' $current
    }

    if ($Action -eq 'Developing') {
        if ($current.stage -eq 'developing') { Complete-Result 'unchanged' '已处于开发中。' $current }
        if ($current.stage -ne 'design_ready') { Complete-Result 'failed' '仅“方案已制定，待开发”可以进入开发中。' $current 1 }
        if (-not (Has-ActiveWorktree $worktreeIndex $type $name)) { Complete-Result 'failed' '尚无有效 worktree，不能进入开发中。' $current 1 }
        $current.stage = 'developing'; $current.developingStartedAt = $now; $current.updatedAt = $now
        Write-StateFile $statePath $document
        Complete-Result 'updated' '已同步为开发中。' $current
    }

    if ($current.stage -eq 'released') { Complete-Result 'unchanged' '已处于已上线。' $current }
    if ($current.stage -ne 'developing') { Complete-Result 'failed' '仅“开发中”可以在清理最后一个 worktree 后标记已上线。' $current 1 }
    if (Has-ActiveWorktree $worktreeIndex $type $name) { Complete-Result 'unchanged' '仍存在有效 worktree，保留开发中。' $current }
    $current.stage = 'released'; $current.releasedAt = $now; $current.updatedAt = $now
    Write-StateFile $statePath $document
    Complete-Result 'updated' '已上线。' $current
}
catch { Complete-Result 'failed' $_.Exception.Message $null 1 }
