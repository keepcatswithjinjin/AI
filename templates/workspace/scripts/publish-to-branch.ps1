param(
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory = $true)]
    [string]$TargetBranch,

    [Parameter(Mandatory = $true)]
    [string]$Files,

    [Parameter(Mandatory = $true)]
    [string]$CommitMessage,

    [ValidateSet('Publish', 'VerifyConflict', 'CompleteConflict')]
    [string]$Mode = 'Publish',

    [string]$CompileModules,
    [string]$MavenSettings,
    [string]$ManualAcceptanceFile,
    [switch]$ConfirmConflictCompletion,
    [switch]$UseHumanCompletionApproval,
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'
$script:LastGitExitCode = 0
$script:resolvedProjectPath = $null
$script:approvedLocalGitHookBypass = $false
$artifactRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\\merge-verification'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$localGitHookBypassApprovalPath = Join-Path $workspaceRoot 'governance\\agent-guard\\local-git-hook-bypass-approval.json'
$localGitHookBypassHooksPath = Join-Path $workspaceRoot 'governance\\agent-guard\\empty-git-hooks'

function Normalize-PathString {
    param([Parameter(Mandatory = $true)][string]$Path)
    [System.IO.Path]::GetFullPath($Path).TrimEnd('\\')
}

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Arguments, [switch]$AllowFailure)

    # Git progress is normally written to stderr. PowerShell 7.3+ must decide
    # failure from the native exit code, not from that progress stream.
    $oldEap = $ErrorActionPreference
    $hasNativePreference = Test-Path variable:\PSNativeCommandUseErrorActionPreference
    if ($hasNativePreference) { $oldNativePreference = $PSNativeCommandUseErrorActionPreference; $PSNativeCommandUseErrorActionPreference = $false }
    try {
        $ErrorActionPreference = 'Continue'
        $gitConfig = @('-c', 'safe.directory=*')
        if ($script:approvedLocalGitHookBypass -and $Arguments.Count -gt 0 -and $Arguments[0] -in @('commit', 'push')) {
            $gitConfig += @('-c', "core.hooksPath=$localGitHookBypassHooksPath")
        }
        $rawOutput = & git @gitConfig -C $script:resolvedProjectPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldEap
        if ($hasNativePreference) { $PSNativeCommandUseErrorActionPreference = $oldNativePreference }
    }
    $script:LastGitExitCode = $exitCode
    $output = @($rawOutput | ForEach-Object { [string]$_ })
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "git $($Arguments -join ' ') failed.$([Environment]::NewLine)$(($output | Out-String).Trim())"
    }
    @($output)
}

function Test-ApprovedLocalGitHookBypass {
    if (-not $UseHumanCompletionApproval) { return $false }
    if ($Mode -ne 'CompleteConflict') { throw '-UseHumanCompletionApproval is allowed only with -Mode CompleteConflict.' }
    if (-not (Test-Path -LiteralPath $localGitHookBypassApprovalPath)) { throw "Local Git hook bypass requires a human-created approval file: $localGitHookBypassApprovalPath" }
    try { $approval = Get-Content -LiteralPath $localGitHookBypassApprovalPath -Raw | ConvertFrom-Json }
    catch { throw "Local Git hook bypass approval is not valid JSON: $localGitHookBypassApprovalPath" }
    $properties = @($approval.PSObject.Properties.Name | Sort-Object)
    $expected = @('enabled', 'scope')
    if ($properties.Count -ne $expected.Count -or @($properties | Where-Object { $_ -notin $expected }).Count -gt 0 -or $approval.enabled -ne $true -or $approval.scope -ne 'publish-to-branch.complete-conflict') {
        throw "Local Git hook bypass approval must contain exactly enabled=true and scope=publish-to-branch.complete-conflict: $localGitHookBypassApprovalPath"
    }
    if (-not (Test-Path -LiteralPath $localGitHookBypassHooksPath)) { throw "Approved empty Git hooks directory is missing: $localGitHookBypassHooksPath" }
    return $true
}

function Get-CurrentBranch {
    $branch = ((Invoke-Git @('branch', '--show-current')) -join '').Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) { throw 'Detached HEAD is not supported.' }
    $branch
}

function Get-GitDirPath {
    $gitDir = ((Invoke-Git @('rev-parse', '--git-dir')) -join '').Trim()
    if ([System.IO.Path]::IsPathRooted($gitDir)) { return (Normalize-PathString $gitDir) }
    Normalize-PathString (Join-Path $script:resolvedProjectPath $gitDir)
}

function Test-MergeInProgress {
    Test-Path -LiteralPath (Join-Path (Get-GitDirPath) 'MERGE_HEAD')
}

function Normalize-RepoRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or [System.IO.Path]::IsPathRooted($Path)) { throw "-Files must use repository-relative paths: $Path" }
    $normalized = $Path.Replace('\\', '/').TrimStart('./')
    if ($normalized -eq '' -or $normalized -match '(^|/)\.\.(/|$)') { throw "-Files contains an unsafe repository-relative path: $Path" }
    $normalized
}

function Get-ChangedPaths {
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($lineObject in (Invoke-Git @('status', '--porcelain=v1', '--untracked-files=all'))) {
        $line = [string]$lineObject
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Length -lt 4) { throw "Unable to safely parse git status output: $line" }
        $path = $line.Substring(3).Replace('\\', '/')
        if ($path -match ' -> ') { throw "Renamed files require manual handling: $line" }
        $paths.Add($path)
    }
    @($paths | Sort-Object -Unique)
}

function Assert-ExactChangedFiles {
    param([Parameter(Mandatory = $true)][string[]]$ExpectedFiles)
    $actual = @(Get-ChangedPaths)
    $unexpected = @($actual | Where-Object { $_ -notin $ExpectedFiles })
    $missing = @($ExpectedFiles | Where-Object { $_ -notin $actual })
    if ($unexpected.Count -or $missing.Count) {
        $detail = @()
        if ($unexpected.Count) { $detail += "Unexpected changed files: $($unexpected -join ', ')" }
        if ($missing.Count) { $detail += "Expected files without changes: $($missing -join ', ')" }
        throw "File scope check failed. $($detail -join ' | ')"
    }
}

function Get-WorktreeBranchLocations {
    $items = @(); $path = $null
    foreach ($lineObject in (Invoke-Git @('worktree', 'list', '--porcelain'))) {
        $line = [string]$lineObject
        if ($line -match '^worktree\s+(.+)$') { $path = Normalize-PathString $Matches[1]; continue }
        if ($line -match '^branch\s+refs/heads/(.+)$' -and $path) { $items += [pscustomobject]@{ Path = $path; Branch = $Matches[1] } }
    }
    $items
}

function Assert-TargetNotCheckedOutElsewhere {
    param([Parameter(Mandatory = $true)][string]$Branch)
    $matches = @(Get-WorktreeBranchLocations | Where-Object {
        $_.Branch -eq $Branch -and -not $_.Path.Equals($script:resolvedProjectPath, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($matches.Count) { throw "Target branch '$Branch' is checked out by another worktree: $(($matches.Path -join ', ')). Stop and ask the user." }
}

function Test-RefExists {
    param([Parameter(Mandatory = $true)][string]$Ref)
    Invoke-Git @('show-ref', '--verify', '--quiet', $Ref) -AllowFailure | Out-Null
    $script:LastGitExitCode -eq 0
}

function Test-HeadMatchesCommitMessage {
    param([Parameter(Mandatory = $true)][string]$ExpectedMessage)
    (((Invoke-Git @('log', '-1', '--pretty=%B')) -join [Environment]::NewLine).Trim() -eq $ExpectedMessage.Trim())
}

function Get-ActiveMergePointerPath {
    Join-Path (Get-MergeArtifactRepositoryPath) 'active-merge.json'
}

function Get-MergeArtifactRepositoryPath {
    $repoName = Split-Path -Leaf $script:resolvedProjectPath
    $commonDir = ((Invoke-Git @('rev-parse', '--git-common-dir')) -join '').Trim()
    if (-not [System.IO.Path]::IsPathRooted($commonDir)) { $commonDir = Join-Path $script:resolvedProjectPath $commonDir }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes((Normalize-PathString $commonDir).ToLowerInvariant())
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha256.ComputeHash($bytes) }
    finally { $sha256.Dispose() }
    $suffix = ([System.BitConverter]::ToString($hash) -replace '-', '').Substring(0, 12).ToLowerInvariant()
    Join-Path $artifactRoot "$(Get-SafeArtifactName $repoName)-$suffix"
}

function Write-JsonFile {
    param([Parameter(Mandatory = $true)]$Value, [Parameter(Mandatory = $true)][string]$Path)
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Merge verification state not found: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-SafeArtifactName {
    param([Parameter(Mandatory = $true)][string]$Value)
    ($Value -replace '[^A-Za-z0-9._-]', '_')
}

function Save-GitStageContent {
    param([Parameter(Mandatory = $true)][int]$Stage, [Parameter(Mandatory = $true)][string]$RepoPath, [Parameter(Mandatory = $true)][string]$OutputPath)
    # Stage 1 can be absent for add/add conflicts. An empty file is the explicit
    # representation of that absent side, preserving the comparison contract.
    $content = Invoke-Git @('show', ":$Stage`:$RepoPath") -AllowFailure
    if ($script:LastGitExitCode -ne 0) { $content = @() }
    $text = ($content -join [Environment]::NewLine)
    [System.IO.File]::WriteAllText($OutputPath, $text, [System.Text.UTF8Encoding]::new($false))
}

function Get-ConflictFiles {
    @(Invoke-Git @('diff', '--name-only', '--diff-filter=U') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-LineMultiset {
    param([Parameter(Mandatory = $true)][string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($map.ContainsKey($line)) { $map[$line]++ } else { $map[$line] = 1 }
    }
    $map
}

function Get-MultisetDifference {
    param([hashtable]$From, [hashtable]$To)
    $result = @{}
    foreach ($key in @($From.Keys + $To.Keys | Sort-Object -Unique)) {
        $fromCount = if ($From.ContainsKey($key)) { [int]$From[$key] } else { 0 }
        $toCount = if ($To.ContainsKey($key)) { [int]$To[$key] } else { 0 }
        if ($toCount -gt $fromCount) { $result[$key] = $toCount - $fromCount }
    }
    $result
}

function Compare-Multiset {
    param([hashtable]$Actual, [hashtable]$Expected)
    $differences = @()
    foreach ($key in @($Actual.Keys + $Expected.Keys | Sort-Object -Unique)) {
        $actualCount = if ($Actual.ContainsKey($key)) { [int]$Actual[$key] } else { 0 }
        $expectedCount = if ($Expected.ContainsKey($key)) { [int]$Expected[$key] } else { 0 }
        if ($actualCount -ne $expectedCount) {
            $display = if ($key -eq '') { '[empty line]' } else { $key }
            $differences += "expected=$expectedCount actual=$actualCount | $display"
        }
    }
    @($differences)
}

function Get-ConflictClassification {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$OursPath,
        [Parameter(Mandatory = $true)][string]$TheirsPath
    )
    # A is deliberately conservative. It is allowed only when neither side
    # removes/replaces any line from the common base: both changes are pure
    # additions relative to the common input. This also handles zdiff3 blocks
    # whose base section contains unchanged surrounding context.
    $base = Get-LineMultiset $BasePath
    $ours = Get-LineMultiset $OursPath
    $theirs = Get-LineMultiset $TheirsPath
    foreach ($line in $base.Keys) {
        if (([int]$ours[$line] -lt [int]$base[$line]) -or ([int]$theirs[$line] -lt [int]$base[$line])) { return 'B' }
    }
    'A'
}

function Test-JavaOrPomPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $Path.EndsWith('.java', [System.StringComparison]::OrdinalIgnoreCase) -or
    ([System.IO.Path]::GetFileName($Path).Equals('pom.xml', [System.StringComparison]::OrdinalIgnoreCase))
}

function New-MergeCapture {
    param([Parameter(Mandatory = $true)][string]$SourceBranch, [Parameter(Mandatory = $true)][string]$TargetBranch)
    $conflicts = @(Get-ConflictFiles)
    if ($conflicts.Count -eq 0) { throw 'Git merge failed but did not leave conflict entries; no merge verification state was created.' }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $artifactPath = Join-Path (Get-MergeArtifactRepositoryPath) "$stamp-$(Get-SafeArtifactName $TargetBranch)-$(Get-SafeArtifactName $SourceBranch)"
    $inputPath = Join-Path $artifactPath 'inputs'
    New-Item -ItemType Directory -Force -Path $inputPath | Out-Null
    $files = @()
    foreach ($path in $conflicts) {
        $name = Get-SafeArtifactName $path
        $base = Join-Path $inputPath "$name.base"
        $ours = Join-Path $inputPath "$name.ours"
        $theirs = Join-Path $inputPath "$name.theirs"
        $conflicted = Join-Path $inputPath "$name.conflicted"
        Save-GitStageContent -Stage 1 -RepoPath $path -OutputPath $base
        Save-GitStageContent -Stage 2 -RepoPath $path -OutputPath $ours
        Save-GitStageContent -Stage 3 -RepoPath $path -OutputPath $theirs
        Copy-Item -LiteralPath (Join-Path $script:resolvedProjectPath $path) -Destination $conflicted -Force
        $files += [pscustomobject]@{ path = $path; base = $base; ours = $ours; theirs = $theirs; conflicted = $conflicted; classification = (Get-ConflictClassification -BasePath $base -OursPath $ours -TheirsPath $theirs); javaOrPom = (Test-JavaOrPomPath $path) }
    }
    $state = [pscustomobject]@{
        schemaVersion = 'merge-verification.v1'; projectPath = $script:resolvedProjectPath; sourceBranch = $SourceBranch; targetBranch = $TargetBranch
        sourceCommit = ((Invoke-Git @('rev-parse', $SourceBranch)) -join '').Trim(); targetCommitBeforeMerge = ((Invoke-Git @('rev-parse', 'HEAD')) -join '').Trim()
        mergeHead = ((Invoke-Git @('rev-parse', 'MERGE_HEAD')) -join '').Trim(); createdAt = (Get-Date).ToString('o'); artifactPath = $artifactPath
        files = $files; verification = [pscustomobject]@{ status = 'pending'; checkedAt = $null; compileStatus = 'not-started'; reportPath = $null }
    }
    $statePath = Join-Path $artifactPath 'state.json'
    Write-JsonFile -Value $state -Path $statePath
    Write-JsonFile -Value ([pscustomobject]@{ schemaVersion = 'merge-verification-pointer.v1'; statePath = $statePath }) -Path (Get-ActiveMergePointerPath)
    $state
}

function Get-ActiveMergeState {
    $pointer = Read-JsonFile (Get-ActiveMergePointerPath)
    $state = Read-JsonFile $pointer.statePath
    if (-not $state.projectPath.Equals($script:resolvedProjectPath, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Active merge verification belongs to a different worktree.' }
    if ($state.targetBranch -ne $TargetBranch) { throw "Active merge verification targets '$($state.targetBranch)', not '$TargetBranch'." }
    $state
}

function Save-MergeState {
    param([Parameter(Mandatory = $true)]$State)
    Write-JsonFile -Value $State -Path (Join-Path $State.artifactPath 'state.json')
}

function Invoke-CompileVerification {
    param([Parameter(Mandatory = $true)][string[]]$Modules, [string]$Settings)
    $arguments = @()
    if (-not [string]::IsNullOrWhiteSpace($Settings)) { $arguments += @('-s', $Settings) }
    $arguments += @('-pl', ($Modules -join ','), '-am', 'compile')
    $oldEap = $ErrorActionPreference
    $hasNativePreference = Test-Path variable:\PSNativeCommandUseErrorActionPreference
    if ($hasNativePreference) { $oldNativePreference = $PSNativeCommandUseErrorActionPreference; $PSNativeCommandUseErrorActionPreference = $false }
    try {
        $ErrorActionPreference = 'Continue'
        $output = & mvn @arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldEap
        if ($hasNativePreference) { $PSNativeCommandUseErrorActionPreference = $oldNativePreference }
    }
    [pscustomobject]@{ exitCode = $exitCode; output = @($output | ForEach-Object { [string]$_ }) }
}

function New-ManualAcceptanceTemplate {
    param([Parameter(Mandatory = $true)]$State)
    $templatePath = Join-Path $State.artifactPath 'manual-acceptance.md'
    if (Test-Path -LiteralPath $templatePath) { return $templatePath }
    $lines = @('# Manual acceptance for B-class merge conflicts', '', '> Fill every REQUIRED item. This document records a human decision; it does not replace targeted validation.', '')
    foreach ($file in @($State.files | Where-Object { $_.classification -eq 'B' })) {
        $lines += @("## $($file.path)", '', '### Target-side behavior retained', '<!-- REQUIRED: describe -->', '', '### Source-side behavior retained', '<!-- REQUIRED: describe -->', '', '### Resolution and intentional trade-off', '<!-- REQUIRED: describe -->', '', '### Impacted callers', '<!-- REQUIRED: describe -->', '', '### Targeted validation', '<!-- REQUIRED: test class, build, or environment scenario -->', '')
    }
    $lines | Set-Content -LiteralPath $templatePath -Encoding utf8
    $templatePath
}

function Test-ManualAcceptance {
    param([Parameter(Mandatory = $true)]$State, [Parameter(Mandatory = $true)][string]$Path)
    $resolvedPath = Normalize-PathString $Path
    $artifactPrefix = (Normalize-PathString $State.artifactPath) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedPath.StartsWith($artifactPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Manual acceptance file must be stored under this merge artifact: $($State.artifactPath)"
    }
    if (-not (Test-Path -LiteralPath $resolvedPath)) { throw "Manual acceptance file not found: $resolvedPath" }
    $text = Get-Content -LiteralPath $resolvedPath -Raw
    if ($text -match '<!-- REQUIRED:') { throw "Manual acceptance file still has required placeholders: $Path" }
    foreach ($file in @($State.files | Where-Object { $_.classification -eq 'B' })) {
        if ($text -notmatch [regex]::Escape("## $($file.path)")) { throw "Manual acceptance file has no decision section for B conflict: $($file.path)" }
    }
    $true
}

function Invoke-ConflictVerification {
    $state = Get-ActiveMergeState
    if (-not (Test-MergeInProgress)) { throw 'No merge is in progress. VerifyConflict only runs after Publish stopped on a captured conflict.' }
    if ((Get-CurrentBranch) -ne $state.targetBranch) { throw "Current branch must remain '$($state.targetBranch)' while verifying the conflict." }
    if (@(Get-ConflictFiles).Count -gt 0) { throw 'Unresolved conflict entries remain. Resolve and git add every conflict file before verification.' }

    Invoke-Git @('diff', '--check') | Out-Null
    Invoke-Git @('grep', '-n', '-E', '^(<<<<<<<|=======|>>>>>>>|\|\|\|\|\|\|\|)', '--') -AllowFailure | Out-Null
    if ($script:LastGitExitCode -eq 0) { throw 'Conflict marker text remains in the worktree. Remove it before verification.' }

    $report = New-Object System.Collections.Generic.List[string]
    $report.Add('# Merge conflict verification')
    $report.Add('')
    $report.Add("- Source branch: $($state.sourceBranch)")
    $report.Add("- Target branch: $($state.targetBranch)")
    $report.Add("- Captured at: $($state.createdAt)")
    $allAPassed = $true; $hasB = $false
    foreach ($file in $state.files) {
        $report.Add('')
        $report.Add("## $($file.path) ($($file.classification))")
        if ($file.classification -eq 'B') {
            $hasB = $true
            $report.Add('Manual acceptance required: both sides changed shared base content, or the recorded conflict could not be safely classified as A.')
            $report.Add("- base: $($file.base)")
            $report.Add("- ours: $($file.ours)")
            $report.Add("- theirs: $($file.theirs)")
            $report.Add("- conflict input: $($file.conflicted)")
            $report.Add('- Record which side behavior is retained, which is intentionally changed, affected callers, and targeted verification before completion.')
            continue
        }
        $mergedPath = Join-Path $state.artifactPath ('resolved-' + (Get-SafeArtifactName $file.path))
        Copy-Item -LiteralPath (Join-Path $script:resolvedProjectPath $file.path) -Destination $mergedPath -Force
        $base = Get-LineMultiset $file.base; $ours = Get-LineMultiset $file.ours; $theirs = Get-LineMultiset $file.theirs; $merged = Get-LineMultiset $mergedPath
        $checks = @(
            [pscustomobject]@{ name = 'add(theirs→merged) = add(base→ours)'; actual = (Get-MultisetDifference $theirs $merged); expected = (Get-MultisetDifference $base $ours) },
            [pscustomobject]@{ name = 'del(theirs→merged) = del(base→ours)'; actual = (Get-MultisetDifference $merged $theirs); expected = (Get-MultisetDifference $ours $base) },
            [pscustomobject]@{ name = 'add(ours→merged) = add(base→theirs)'; actual = (Get-MultisetDifference $ours $merged); expected = (Get-MultisetDifference $base $theirs) },
            [pscustomobject]@{ name = 'del(ours→merged) = del(base→theirs)'; actual = (Get-MultisetDifference $merged $ours); expected = (Get-MultisetDifference $theirs $base) }
        )
        foreach ($check in $checks) {
            $differences = @(Compare-Multiset $check.actual $check.expected)
            if ($differences.Count) { $allAPassed = $false; $report.Add("- FAIL $($check.name)"); foreach ($difference in $differences) { $report.Add("  - $difference") } }
            else { $report.Add("- PASS $($check.name)") }
        }
    }

    # Recompute from frozen state before the conclusion so report wording and
    # completion eligibility cannot depend on loop-local state.
    $hasB = @($state.files | Where-Object { $_.classification -eq 'B' }).Count -gt 0
    $manualAcceptancePath = $null
    $manualAccepted = $false
    if ($hasB) {
        $templatePath = New-ManualAcceptanceTemplate $state
        $report.Add('')
        $report.Add('## Manual acceptance')
        if ([string]::IsNullOrWhiteSpace($ManualAcceptanceFile)) {
            $report.Add("PENDING: fill the generated template and rerun with -ManualAcceptanceFile $templatePath")
        }
        else {
            $manualAcceptancePath = Normalize-PathString $ManualAcceptanceFile
            $manualAccepted = Test-ManualAcceptance -State $state -Path $manualAcceptancePath
            $report.Add("Human acceptance record supplied: $manualAcceptancePath")
        }
    }

    $javaOrPom = @($state.files | Where-Object { $_.javaOrPom })
    $compileStatus = 'not-required'
    if ($javaOrPom.Count) {
        $modules = @($CompileModules -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($modules.Count -eq 0) {
            $compileStatus = 'required-but-not-run'
            $report.Add('')
            $report.Add('## Compile verification')
            $report.Add('PENDING: Java/POM conflict files require `-CompileModules <module[,module]>`; final completion is blocked.')
        }
        else {
            $compile = Invoke-CompileVerification -Modules $modules -Settings $MavenSettings
            $compileLog = Join-Path $state.artifactPath 'compile.log'
            $compile.output | Set-Content -LiteralPath $compileLog -Encoding utf8
            $compileStatus = if ($compile.exitCode -eq 0) { 'passed' } else { 'failed' }
            $report.Add('')
            $report.Add('## Compile verification')
            $report.Add("- Modules: $($modules -join ', ')")
            $report.Add("- Exit code: $($compile.exitCode)")
            $report.Add("- Log: $compileLog")
        }
    }
    $status = if (-not $allAPassed) { 'failed' } elseif ($hasB -and -not $manualAccepted) { 'manual-acceptance-required' } elseif ($compileStatus -eq 'required-but-not-run') { 'compile-required' } elseif ($compileStatus -eq 'failed') { 'failed' } else { 'passed' }
    $report.Add('')
    $report.Add("## Result: $status")
    if ($status -eq 'passed' -and $hasB) { $report.Add('A-class multiset checks passed; B-class decisions have a completed human acceptance record; required compilation passed.') }
    elseif ($status -eq 'passed') { $report.Add('All captured conflicts are conservative A cases, four-way multiset checks passed, and required compilation passed.') }
    else { $report.Add('Do not commit this merge through CompleteConflict until the blocking condition is resolved and verification is rerun.') }
    $reportPath = Join-Path $state.artifactPath 'report.md'
    $report | Set-Content -LiteralPath $reportPath -Encoding utf8
    $state.verification = [pscustomobject]@{ status = $status; checkedAt = (Get-Date).ToString('o'); compileStatus = $compileStatus; reportPath = $reportPath; manualAcceptancePath = $manualAcceptancePath }
    Save-MergeState $state
    Write-Host "Merge verification result: $status"
    Write-Host "Report: $reportPath"
    if ($status -ne 'passed') { throw "Merge verification is $status. Resolve the report findings or complete required human acceptance before committing." }
}

function Complete-VerifiedConflict {
    if (-not $ConfirmConflictCompletion) { throw 'CompleteConflict requires -ConfirmConflictCompletion after a human has reviewed the verification report.' }
    $state = Get-ActiveMergeState
    if (-not (Test-MergeInProgress)) { throw 'No captured merge is in progress.' }
    if ($state.verification.status -ne 'passed') { throw "Merge verification status is '$($state.verification.status)'; completion is blocked." }
    if (@(Get-ConflictFiles).Count) { throw 'Unresolved conflict entries remain.' }
    Invoke-Git @('diff', '--check') | Out-Null
    $script:approvedLocalGitHookBypass = Test-ApprovedLocalGitHookBypass
    if ($script:approvedLocalGitHookBypass) {
        Add-Content -LiteralPath $state.verification.reportPath -Value "`n## Local Git hook bypass`n- Human approval: $localGitHookBypassApprovalPath`n- Scope: commit and push in CompleteConflict only`n- Remote CI and script verification: not bypassed" -Encoding utf8
        $state.localGitHookBypass = [pscustomobject]@{ approved = $true; approvalPath = $localGitHookBypassApprovalPath; scope = 'publish-to-branch.complete-conflict'; usedAt = (Get-Date).ToString('o') }
        Save-MergeState $state
    }
    try {
        Invoke-Git @('commit', '--no-edit') | Out-Null
        Invoke-Git @('push', 'origin', $state.targetBranch) | Out-Null
    }
    catch { throw "Merged locally but target push failed. Stay on '$($state.targetBranch)' and request human direction.$([Environment]::NewLine)$($_.Exception.Message)" }
    finally { $script:approvedLocalGitHookBypass = $false }
    $targetCommit = ((Invoke-Git @('rev-parse', 'HEAD')) -join '').Trim()
    Invoke-Git @('switch', $state.sourceBranch) | Out-Null
    Remove-Item -LiteralPath (Get-ActiveMergePointerPath) -Force -ErrorAction SilentlyContinue
    Write-Host 'Done.'
    Write-Host "  restored source branch: $($state.sourceBranch)"
    Write-Host "  pushed target branch: $($state.targetBranch)"
    Write-Host "  target merge commit: $targetCommit"
    Write-Host "  verification report: $($state.verification.reportPath)"
}

$script:resolvedProjectPath = Normalize-PathString $ProjectPath
if (-not (Test-Path -LiteralPath $script:resolvedProjectPath)) { throw "Project path not found: $script:resolvedProjectPath" }
$inside = ((Invoke-Git @('rev-parse', '--is-inside-work-tree')) -join '').Trim()
if ($inside -ne 'true') { throw "Project path is not a Git worktree: $script:resolvedProjectPath" }
if ($UseHumanCompletionApproval -and $Mode -ne 'CompleteConflict') { throw '-UseHumanCompletionApproval is allowed only with -Mode CompleteConflict.' }
Invoke-Git @('check-ref-format', '--branch', $TargetBranch) -AllowFailure | Out-Null
if ($script:LastGitExitCode -ne 0) { throw "Invalid target branch name: $TargetBranch" }

if ($Mode -eq 'VerifyConflict') { if ($Preview) { Write-Host 'Preview is not supported for VerifyConflict.'; exit 0 }; Invoke-ConflictVerification; exit 0 }
if ($Mode -eq 'CompleteConflict') { if ($Preview) { Write-Host 'Preview is not supported for CompleteConflict.'; exit 0 }; Complete-VerifiedConflict; exit 0 }
if (Test-MergeInProgress) { throw 'Git merge already in progress. Run VerifyConflict after resolving/staging conflicts, or abort manually. Do not rerun Publish.' }

$sourceBranch = Get-CurrentBranch
if ($sourceBranch -eq $TargetBranch) { throw "Source and target branch are both '$sourceBranch'." }
$expectedFiles = @($Files -split ',' | ForEach-Object { Normalize-RepoRelativePath $_.Trim() } | Sort-Object -Unique)
if ($expectedFiles.Count -eq 0) { throw 'At least one repository-relative file must be supplied with -Files.' }
$changedFiles = @(Get-ChangedPaths)
$resumeFromExistingSourceCommit = $false
if ($changedFiles.Count -eq 0) { $resumeFromExistingSourceCommit = Test-HeadMatchesCommitMessage $CommitMessage; if (-not $resumeFromExistingSourceCommit) { Assert-ExactChangedFiles $expectedFiles } }
else { Assert-ExactChangedFiles $expectedFiles }
Assert-TargetNotCheckedOutElsewhere $TargetBranch
$localTargetExists = Test-RefExists "refs/heads/$TargetBranch"; $remoteTargetExists = Test-RefExists "refs/remotes/origin/$TargetBranch"

Write-Host 'Publish-to-branch plan'
Write-Host "  project: $script:resolvedProjectPath"
Write-Host "  source branch: $sourceBranch"
Write-Host "  target branch: $TargetBranch"
Write-Host "  source commit already exists: $resumeFromExistingSourceCommit"
Write-Host '  conflict behavior: capture Git stages to artifacts, stop for manual resolution, verify, then explicitly complete'
if ($Preview) { exit 0 }

if (-not $remoteTargetExists) { Invoke-Git @('fetch', 'origin', $TargetBranch); $remoteTargetExists = Test-RefExists "refs/remotes/origin/$TargetBranch" }
if (-not $remoteTargetExists) { throw "Target branch '$TargetBranch' does not exist on origin. It will not be created automatically." }
if (-not $resumeFromExistingSourceCommit) { Assert-ExactChangedFiles $expectedFiles }
if ($resumeFromExistingSourceCommit) { $sourceCommit = ((Invoke-Git @('rev-parse', 'HEAD')) -join '').Trim() }
else { Invoke-Git (@('add', '--') + $expectedFiles) | Out-Null; Invoke-Git @('commit', '-m', $CommitMessage) | Out-Null; $sourceCommit = ((Invoke-Git @('rev-parse', 'HEAD')) -join '').Trim() }
Invoke-Git @('push', '-u', 'origin', $sourceBranch) | Out-Null
Invoke-Git @('fetch', 'origin', $TargetBranch) | Out-Null
Assert-TargetNotCheckedOutElsewhere $TargetBranch
if (-not (Test-RefExists "refs/heads/$TargetBranch")) { Invoke-Git @('switch', '--track', '-c', $TargetBranch, "origin/$TargetBranch") | Out-Null }
else { Invoke-Git @('switch', $TargetBranch) | Out-Null }
Invoke-Git @('pull', '--ff-only', 'origin', $TargetBranch) | Out-Null

Invoke-Git @('-c', 'merge.conflictStyle=zdiff3', 'merge', '--no-ff', '--no-commit', $sourceBranch) -AllowFailure | Out-Null
if ($script:LastGitExitCode -ne 0) {
    if (Test-MergeInProgress) {
        $state = New-MergeCapture -SourceBranch $sourceBranch -TargetBranch $TargetBranch
        throw "Merge stopped on '$TargetBranch'. Git inputs were captured at '$($state.artifactPath)'. Resolve conflicts manually, stage them, run -Mode VerifyConflict, then run -Mode CompleteConflict -ConfirmConflictCompletion. The script will not switch branches automatically."
    }
    throw 'Git merge failed without a conflict state. Stay on the target branch and request human direction.'
}
Invoke-Git @('diff', '--check') | Out-Null
Invoke-Git @('commit', '--no-edit') | Out-Null
try { Invoke-Git @('push', 'origin', $TargetBranch) | Out-Null }
catch { throw "Target branch '$TargetBranch' was merged locally but was not pushed. Stay on this branch and ask the user whether to retry, inspect, or roll back.$([Environment]::NewLine)$($_.Exception.Message)" }
$targetCommit = ((Invoke-Git @('rev-parse', 'HEAD')) -join '').Trim()
Invoke-Git @('switch', $sourceBranch) | Out-Null
Write-Host 'Done.'
Write-Host "  restored source branch: $sourceBranch"
Write-Host "  source commit: $sourceCommit"
Write-Host "  pushed target branch: $TargetBranch"
Write-Host "  target merge commit: $targetCommit"
