param([switch]$KeepArtifacts)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Run with PowerShell 7.' }
$toolkitRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $toolkitRoot ('local\template-smoke-' + [guid]::NewGuid().ToString('N'))
$pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
$passed = $false

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-Fixture([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Invoke-TestScript([string]$Path, [string[]]$Arguments, [int]$ExpectedExit = 0) {
    $output = @(& $pwsh -NoProfile -File $Path @Arguments 2>&1 | ForEach-Object { [string]$_ })
    $actualExit = $LASTEXITCODE
    if ($actualExit -ne $ExpectedExit) { throw "Script failed ($actualExit, expected $ExpectedExit): $Path`n$($output -join "`n")" }
    return ($output -join "`n")
}

function Invoke-TestGit([string]$Repository, [string[]]$Arguments) {
    $output = @(& git -C $Repository @Arguments 2>&1 | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) { throw "Fixture git failed: $($Arguments -join ' ')`n$($output -join "`n")" }
    return ($output -join "`n")
}

function Assert-Instance([string]$Root, [bool]$Optional) {
    $manifest = [IO.File]::ReadAllText((Join-Path $Root 'workstation-install.json')) | ConvertFrom-Json
    Assert-True ($manifest.frameworkVersion -eq ([IO.File]::ReadAllText((Join-Path $toolkitRoot 'VERSION'))).Trim()) 'Installation version mismatch.'
    Assert-True ($manifest.options.dbAnalysis -eq $Optional -and $manifest.options.yunxiao -eq $Optional) 'Installation options mismatch.'
    foreach ($relative in @('AGENTS.md','CLAUDE.md','STRUCTURE.md','.gitignore','projects/README.md','knowledge/README.md','tmp/README.md','plans/README.md','rules/execution-entry.md','rules/brief-readme-template.md','rules/verification.md','scripts/sync-workstation-state.ps1','.codex/config.toml','.claude/settings.local.json')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $Root $relative) -PathType Leaf) "Missing template: $relative"
    }
    Assert-True (!(Test-Path -LiteralPath (Join-Path $Root '.git'))) 'Installer must not initialize Git.'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $Root 'briefs/cross/example-feature'))) 'Installer created a fake requirement.'
    Assert-True ((Test-Path -LiteralPath (Join-Path $Root 'skills/db-analysis/SKILL.md')) -eq $Optional) 'Database optional boundary failed.'
    Assert-True ((Test-Path -LiteralPath (Join-Path $Root '.codex/skills/yunxiao-workstation/SKILL.md')) -eq $Optional) 'Yunxiao optional boundary failed.'
    Assert-True ([IO.File]::ReadAllText((Join-Path $Root 'CLAUDE.md')).Contains('@AGENTS.md')) 'Claude import missing.'
    foreach ($file in Get-ChildItem -LiteralPath $Root -Force -Recurse -File) {
        if ($file.Extension -notin '.md','.ps1','.cmd','.py','.json','.yaml','.toml') { continue }
        $body = [IO.File]::ReadAllText($file.FullName)
        Assert-True (!$body.Contains('__WORKSPACE_ROOT__')) "Unrendered root: $($file.FullName)"
        Assert-True ($body -notmatch 'D:[\\/]Col(?:[\\/]|\b)') "Personal root leaked: $($file.FullName)"
        Assert-True ($body -notmatch 'C:[\\/]Users[\\/]wangjian(?:[\\/]|\b)') "Personal user path leaked: $($file.FullName)"
        if ($file.Extension -eq '.json') { $null = $body | ConvertFrom-Json }
        if ($file.Extension -eq '.ps1') {
            $tokens = $null; $parseErrors = $null
            $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
            Assert-True ($parseErrors.Count -eq 0) "PowerShell syntax error: $($file.FullName) $parseErrors"
        }
        if ($file.Extension -ne '.md' -or $file.FullName.EndsWith('brief-readme-template.md')) { continue }
        $body = [regex]::Replace($body, '(?s)```.*?```', '')
        foreach ($link in [regex]::Matches($body, '\[[^\]\r\n]+\]\(([^)\r\n]+)\)')) {
            $href = ($link.Groups[1].Value -split '#')[0]
            if (!$href -or $href -match '^https?://' -or $href.Contains('<')) { continue }
            $target = [IO.Path]::GetFullPath([IO.Path]::Combine($file.DirectoryName, $href))
            Assert-True (Test-Path -LiteralPath $target -PathType Leaf) "Broken navigation: $($file.FullName) -> $href"
        }
    }
}

try {
    [void][IO.Directory]::CreateDirectory($testRoot)
    $basic = Join-Path $testRoot 'basic workspace 测试'
    $optional = Join-Path $testRoot 'optional workspace'
    $installer = Join-Path $toolkitRoot 'install.ps1'
    $null = Invoke-TestScript $installer @('-WorkspaceRoot', $basic)
    $null = Invoke-TestScript $installer @('-WorkspaceRoot', $optional, '-IncludeDbAnalysis', '-IncludeYunxiao')
    Assert-Instance $basic $false
    Assert-Instance $optional $true
    $before = (Get-FileHash -LiteralPath (Join-Path $basic 'AGENTS.md')).Hash
    $null = Invoke-TestScript $installer @('-WorkspaceRoot', $basic) 1
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $basic 'AGENTS.md')).Hash -eq $before) 'Installer changed a non-empty workspace.'
    Write-Output 'PASS: base/optional install, hidden configuration, JSON, syntax, links and overwrite refusal'

    $repo = Join-Path $basic 'projects/project-api'
    [void][IO.Directory]::CreateDirectory($repo)
    $null = Invoke-TestGit $repo @('init','--initial-branch=master')
    $null = Invoke-TestGit $repo @('config','user.name','Template Test')
    $null = Invoke-TestGit $repo @('config','user.email','template-test@example.invalid')
    Write-Fixture (Join-Path $repo 'seed.txt') "fixture`n"
    $null = Invoke-TestGit $repo @('add','seed.txt')
    $null = Invoke-TestGit $repo @('commit','-m','fixture baseline')
    $name = 'smoke-feature'
    $key = 'backend:' + $name
    $brief = Join-Path $basic ('briefs/backend/' + $name)
    $index = Join-Path $basic 'briefs/INDEX.md'
    $indexText = [IO.File]::ReadAllText($index)
    $indexText = $indexText.Replace('## backend（纯后端）', ('## backend（纯后端）' + "`n`n" + '| `' + $name + '` | `briefs/backend/' + $name + '/` |'))
    Write-Fixture $index $indexText
    $stateScript = Join-Path $basic 'scripts/sync-workstation-state.ps1'
    $register = (Invoke-TestScript $stateScript @('-Action','Register','-RequirementKey',$key)) | ConvertFrom-Json
    Assert-True ($register.state.stage -eq 'pending') 'Register failed.'
    $missing = (Invoke-TestScript $stateScript @('-Action','DesignReady','-RequirementKey',$key) 1) | ConvertFrom-Json
    Assert-True ($missing.outcome -eq 'failed') 'Missing spec should block readiness.'
    Write-Fixture (Join-Path $brief 'README.md') "# Fixture requirement`n"
    Write-Fixture (Join-Path $brief 'spec/design.md') "# Fixture design`n"
    Write-Fixture (Join-Path $brief 'spec/backend-plan.md') "# Fixture plan`n"
    $ready = (Invoke-TestScript $stateScript @('-Action','DesignReady','-RequirementKey',$key)) | ConvertFrom-Json
    Assert-True ($ready.state.stage -eq 'design_ready') 'DesignReady failed.'
    $newScript = Join-Path $basic 'scripts/new-worktree.ps1'
    $argsNew = @('-ProjectKey','project-api','-Name',$name,'-RequirementKey',$key,'-Role','backend','-OutputFormat','Json','-SkipBaseUpdate')
    $planned = (Invoke-TestScript $newScript ($argsNew + @('-Preview'))) | ConvertFrom-Json
    Assert-True ($planned.outcome -eq 'planned') 'Creation preview failed.'
    $worktree = Join-Path $basic ('worktrees/project-api-worktree/' + $name)
    Assert-True (!(Test-Path -LiteralPath $worktree)) 'Preview wrote a worktree.'
    $created = (Invoke-TestScript $newScript $argsNew) | ConvertFrom-Json
    Assert-True ($created.outcome -eq 'succeeded' -and $created.state.indexSync.status -eq 'succeeded') 'Creation/index sync failed.'
    $developing = (Invoke-TestScript $stateScript @('-Action','Developing','-RequirementKey',$key)) | ConvertFrom-Json
    Assert-True ($developing.state.stage -eq 'developing') 'Developing failed.'
    $removeScript = Join-Path $basic 'scripts/remove-worktree.ps1'
    $argsRemove = @('-WorktreePath',$worktree,'-RequirementKey',$key,'-Role','backend','-OutputFormat','Json')
    $preview = (Invoke-TestScript $removeScript ($argsRemove + @('-Preview'))) | ConvertFrom-Json
    Assert-True ($preview.outcome -eq 'planned' -and (Test-Path -LiteralPath $worktree)) 'Removal preview changed files.'
    $removed = (Invoke-TestScript $removeScript ($argsRemove + @('-Confirm'))) | ConvertFrom-Json
    Assert-True ($removed.outcome -eq 'succeeded' -and !(Test-Path -LiteralPath $worktree)) 'Removal failed.'
    Assert-True ((Invoke-TestGit $repo @('branch','--list',('feature/' + $name))).Contains($name)) 'Removal deleted branch.'
    $released = (Invoke-TestScript $stateScript @('-Action','Released','-RequirementKey',$key)) | ConvertFrom-Json
    Assert-True ($released.state.stage -eq 'released') 'Released failed.'
    $again = (Invoke-TestScript $stateScript @('-Action','Released','-RequirementKey',$key)) | ConvertFrom-Json
    Assert-True ($again.outcome -eq 'unchanged') 'State sync must be idempotent.'
    Write-Output 'PASS: state gates, JSON previews, actual disposable worktree lifecycle, index sync and preserved branch'

    # A filesystem-only bare remote exercises publishing without any business/network target.
    $origin = Join-Path $testRoot 'origin.git'
    $null = Invoke-TestGit $testRoot @('init','--bare',$origin)
    $null = Invoke-TestGit $repo @('remote','add','origin',$origin)
    $null = Invoke-TestGit $repo @('branch','integration-test')
    $null = Invoke-TestGit $repo @('push','origin','master','integration-test')
    $publishName = 'publish-smoke'
    $publishBrief = Join-Path $basic ('briefs/backend/' + $publishName)
    Write-Fixture (Join-Path $publishBrief 'README.md') "# Publish fixture`n"
    $newPublish = (Invoke-TestScript $newScript @('-ProjectKey','project-api','-Name',$publishName,'-OutputFormat','Json','-SkipBaseUpdate')) | ConvertFrom-Json
    Assert-True ($newPublish.outcome -eq 'succeeded') 'Publish fixture creation failed.'
    $publishWorktree = Join-Path $basic ('worktrees/project-api-worktree/' + $publishName)
    Write-Fixture (Join-Path $publishWorktree 'seed.txt') "source version`n"
    $publisher = Join-Path $basic 'scripts/publish-to-branch.ps1'
    $publishArgs = @('-ProjectPath',$publishWorktree,'-TargetBranch','integration-test','-Files','seed.txt','-CommitMessage','smoke 中文 commit')
    $beforeHead = Invoke-TestGit $publishWorktree @('rev-parse','HEAD')
    $null = Invoke-TestScript $publisher ($publishArgs + @('-Preview'))
    Assert-True ((Invoke-TestGit $publishWorktree @('rev-parse','HEAD')) -eq $beforeHead) 'Publish preview committed.'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $publishBrief 'runtime'))) 'Publish preview wrote artifacts.'
    $null = Invoke-TestScript $publisher $publishArgs
    Assert-True ((Invoke-TestGit $publishWorktree @('branch','--show-current')) -eq ('feature/' + $publishName)) 'Publish failed to restore source branch.'

    # Divergent edits exercise capture -> verify -> staged-tree gate -> complete.
    $null = Invoke-TestGit $repo @('switch','integration-test')
    Write-Fixture (Join-Path $repo 'seed.txt') "target divergent version`n"
    $null = Invoke-TestGit $repo @('add','seed.txt')
    $null = Invoke-TestGit $repo @('commit','-m','target divergence')
    $null = Invoke-TestGit $repo @('push','origin','integration-test')
    $null = Invoke-TestGit $repo @('switch','master')
    Write-Fixture (Join-Path $publishWorktree 'seed.txt') "source divergent version`n"
    $publishArgs = @('-ProjectPath',$publishWorktree,'-TargetBranch','integration-test','-Files','seed.txt','-CommitMessage','smoke conflict 中文')
    $null = Invoke-TestScript $publisher $publishArgs 1
    $captureRoot = Join-Path $publishBrief 'runtime/merge-verification'
    $pointers = @(Get-ChildItem -LiteralPath $captureRoot -Recurse -Filter active-merge.json)
    Assert-True ($pointers.Count -eq 1) 'Conflict capture must belong to requirement runtime.'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $basic 'artifacts/merge-verification'))) 'Conflict wrote legacy artifacts.'
    Write-Fixture (Join-Path $publishWorktree 'seed.txt') "resolved version`n"
    $null = Invoke-TestGit $publishWorktree @('add','seed.txt')
    $null = Invoke-TestScript $publisher ($publishArgs + @('-Mode','VerifyConflict'))
    Write-Fixture (Join-Path $publishWorktree 'seed.txt') "tampered after verification`n"
    $null = Invoke-TestGit $publishWorktree @('add','seed.txt')
    $null = Invoke-TestScript $publisher ($publishArgs + @('-Mode','CompleteConflict','-ConfirmConflictCompletion')) 1
    $null = Invoke-TestScript $publisher ($publishArgs + @('-Mode','VerifyConflict'))
    $null = Invoke-TestScript $publisher ($publishArgs + @('-Mode','CompleteConflict','-ConfirmConflictCompletion'))
    Assert-True ((Invoke-TestGit $publishWorktree @('branch','--show-current')) -eq ('feature/' + $publishName)) 'Conflict completion failed to restore source.'
    Assert-True (!(Test-Path -LiteralPath $pointers[0].FullName)) 'Completion left an active merge pointer.'
    Write-Output 'PASS: publish read-only preview, UTF-8 message, local push, runtime conflict capture, verification and staged-tree tamper rejection'
    # Multi-location and project baselines use only disposable local remotes.
    $multiName = 'multi-location-smoke'; $multiKey = 'cross:' + $multiName
    Write-Fixture $index (([IO.File]::ReadAllText($index)).Replace('## cross（跨端）', ('## cross（跨端）' + "`n`n" + '| `' + $multiName + '` | `briefs/cross/' + $multiName + '/` |')))
    # Some older templates label cross differently; ensure one exact fixture entry.
    if (!([IO.File]::ReadAllText($index)).Contains('| `' + $multiName + '` |')) {
        Write-Fixture $index (([IO.File]::ReadAllText($index)) + "`n" + '| `' + $multiName + '` | `briefs/cross/' + $multiName + '/` |' + "`n")
    }
    $multiBrief = Join-Path $basic ('briefs/cross/' + $multiName)
    foreach ($file in @('README.md','spec/design.md','spec/api-contract.md','spec/backend-plan.md','spec/frontend-plan.md')) { Write-Fixture (Join-Path $multiBrief $file) '# Synthetic fixture' }
    $null = Invoke-TestScript $stateScript @('-Action','Register','-RequirementKey',$multiKey)
    $null = Invoke-TestScript $stateScript @('-Action','DesignReady','-RequirementKey',$multiKey)
    $locationIndex = Join-Path $basic 'briefs/WORKTREE-INDEX.md'
    $legacyIndex = [IO.File]::ReadAllText($locationIndex)
    $registryPath = Join-Path $basic 'rules/worktree.md'
    $locations = @()
    $branches = @('main','master','develop','trunk')
    for ($i = 0; $i -lt 4; $i++) {
        $projectKey = 'fixture-' + $i
        $role = if ($i -lt 2) { 'backend' } else { 'frontend' }
        $baseline = $branches[$i]
        $fixtureRepo = Join-Path $basic ('projects/' + $projectKey)
        $fixtureRemote = Join-Path $testRoot ($projectKey + '.git')
        [void][IO.Directory]::CreateDirectory($fixtureRepo)
        $null = Invoke-TestGit $fixtureRepo @('init',('--initial-branch=' + $baseline))
        $null = Invoke-TestGit $fixtureRepo @('config','user.name','Template Test')
        $null = Invoke-TestGit $fixtureRepo @('config','user.email','template-test@example.invalid')
        Write-Fixture (Join-Path $fixtureRepo 'seed.txt') "baseline`n"
        $null = Invoke-TestGit $fixtureRepo @('add','seed.txt')
        $null = Invoke-TestGit $fixtureRepo @('commit','-m','fixture')
        $null = Invoke-TestGit $testRoot @('init','--bare',$fixtureRemote)
        $null = Invoke-TestGit $fixtureRepo @('remote','add','upstream',$fixtureRemote)
        $null = Invoke-TestGit $fixtureRepo @('push','upstream',$baseline)
        $locationParent = Join-Path $basic ('worktrees/' + $projectKey + '-worktree')
        $registryRow = '| `' + $projectKey + '` | `' + $fixtureRepo + '` | fixture | `' + $locationParent + '` | `' + $baseline + '` | `upstream` |'
        Write-Fixture $registryPath (([IO.File]::ReadAllText($registryPath)) + "`n" + $registryRow + "`n")
        $locationPath = Join-Path $locationParent $multiName
        $id = $role + '-' + $projectKey
        $creation = @('-ProjectKey',$projectKey,'-Name',$multiName,'-RequirementKey',$multiKey,'-Role',$role,'-LocationId',$id,'-LocationGroup','shared','-OutputFormat','Json')
        $beforeIndex = [IO.File]::ReadAllText($locationIndex)
        $previewMulti = (Invoke-TestScript $newScript ($creation + @('-Preview'))) | ConvertFrom-Json
        Assert-True ($previewMulti.state.baseBranch -eq $baseline -and $previewMulti.state.remote -eq 'upstream') 'Project default baseline/remote ignored.'
        Assert-True ([IO.File]::ReadAllText($locationIndex) -eq $beforeIndex -and !(Test-Path -LiteralPath $locationPath)) 'Preview mutated location state.'
        $actualMulti = (Invoke-TestScript $newScript $creation) | ConvertFrom-Json
        Assert-True ($actualMulti.outcome -eq 'succeeded') 'Multi-location creation failed.'
        Assert-True (([IO.File]::ReadAllText($locationIndex)).StartsWith($legacyIndex)) 'Legacy rows were rewritten.'
        $locations += [pscustomobject]@{ Path=$locationPath; Id=$id; Role=$role }
        if ($i -eq 0) {
            $null = Invoke-TestGit $fixtureRepo @('branch','alternate')
            $offline = (Invoke-TestScript $newScript @('-ProjectKey',$projectKey,'-Name','offline-copy','-BaseBranch','alternate','-Remote','missing','-SkipBaseUpdate','-OutputFormat','Json')) | ConvertFrom-Json
            Assert-True ($offline.outcome -eq 'succeeded' -and $offline.state.baseBranch -eq 'alternate') 'Offline explicit override ignored or unexpectedly required a remote.'
            $null = Invoke-TestScript $removeScript @('-WorktreePath',$offline.state.worktreePath,'-Confirm','-OutputFormat','Json')
            $oldRow = '| `legacy-project` | `' + $fixtureRepo + '` | old fixture | `' + $locationParent + '` |'
            Write-Fixture $registryPath (([IO.File]::ReadAllText($registryPath)) + "`n" + $oldRow + "`n")
            $null = Invoke-TestScript $newScript @('-ProjectKey','legacy-project','-Name','legacy-explicit','-SkipBaseUpdate','-Preview','-OutputFormat','Json') 1
            $oldPreview = (Invoke-TestScript $newScript @('-ProjectKey','legacy-project','-Name','legacy-explicit','-BaseBranch',$baseline,'-SkipBaseUpdate','-Preview','-OutputFormat','Json')) | ConvertFrom-Json
            Assert-True ($oldPreview.outcome -eq 'planned') 'Legacy registry explicit baseline is not compatible.'
            $badBase = (Invoke-TestScript $newScript @('-ProjectKey',$projectKey,'-Name','missing-base','-BaseBranch','missing','-SkipBaseUpdate','-OutputFormat','Json') 1) | ConvertFrom-Json
            Assert-True ($badBase.outcome -eq 'failed') 'Missing baseline silently fell back.'
            Write-Fixture (Join-Path $fixtureRepo 'dirty.txt') 'must remain'
            $blocked = (Invoke-TestScript $newScript @('-ProjectKey',$projectKey,'-Name','dirty-root','-OutputFormat','Json') 1) | ConvertFrom-Json
            Assert-True ($blocked.outcome -eq 'failed' -and (Test-Path -LiteralPath (Join-Path $fixtureRepo 'dirty.txt'))) 'Dirty root was not preserved.'
        }
    }
    # Deliberately ambiguous basename: only the v2 row identifies the right brief.
    Write-Fixture (Join-Path $basic ('briefs/backend/' + $multiName + '/README.md')) '# Decoy fixture'
    $previewFile = Join-Path $locations[1].Path 'seed.txt'
    $previewOriginal = [IO.File]::ReadAllBytes($previewFile)
    Write-Fixture (Join-Path $locations[1].Path 'seed.txt') "changed for preview`n"
    $null = Invoke-TestScript $publisher @('-ProjectPath',$locations[1].Path,'-TargetBranch','integration-test','-Files','seed.txt','-CommitMessage','multi preview','-Preview')
    [IO.File]::WriteAllBytes($previewFile, $previewOriginal)
    $null = Invoke-TestScript $stateScript @('-Action','Developing','-RequirementKey',$multiKey)
    $wrongCleanup = (Invoke-TestScript $removeScript @('-WorktreePath',$locations[0].Path,'-RequirementKey',$multiKey,'-Role','backend','-LocationId','wrong-id','-Preview','-OutputFormat','Json') 1) | ConvertFrom-Json
    Assert-True ($wrongCleanup.outcome -eq 'failed' -and (Test-Path -LiteralPath $locations[0].Path)) 'Cleanup accepted wrong location.'
    for ($i = 0; $i -lt $locations.Count; $i++) {
        $location = $locations[$i]
        $null = Invoke-TestScript $removeScript @('-WorktreePath',$location.Path,'-RequirementKey',$multiKey,'-Role',$location.Role,'-LocationId',$location.Id,'-Confirm','-OutputFormat','Json')
        if ($i -lt 3) {
            $notReleased = (Invoke-TestScript $stateScript @('-Action','Released','-RequirementKey',$multiKey)) | ConvertFrom-Json
            Assert-True ($notReleased.outcome -eq 'unchanged' -and $notReleased.state.stage -eq 'developing') 'Released while other locations exist.'
        }
    }
    $allReleased = (Invoke-TestScript $stateScript @('-Action','Released','-RequirementKey',$multiKey)) | ConvertFrom-Json
    Assert-True ($allReleased.state.stage -eq 'released') 'All-location cleanup did not unlock Released.'
    Assert-True (([IO.File]::ReadAllText($locationIndex)).StartsWith($legacyIndex)) 'Cleanup rewrote legacy rows.'
    $mixedLegacy = (Invoke-TestScript $newScript @('-ProjectKey','project-api','-Name',$multiName,'-BaseBranch','master','-SkipBaseUpdate','-OutputFormat','Json')) | ConvertFrom-Json
    $oldCrossRow = '| `' + $multiName + '` | `briefs/cross/' + $multiName + '/` | `' + $mixedLegacy.state.worktreePath + '` | `feature/' + $multiName + '` | — | — | legacy fixture |'
    $crossSeparator = '|------|-------|--------------|----------|--------------|----------|------|'
    Write-Fixture $locationIndex (([IO.File]::ReadAllText($locationIndex)).Replace($crossSeparator, ($crossSeparator + "`n" + $oldCrossRow)))
    $mixedRemoved = (Invoke-TestScript $removeScript @('-WorktreePath',$mixedLegacy.state.worktreePath,'-RequirementKey',$multiKey,'-Role','backend','-Confirm','-OutputFormat','Json')) | ConvertFrom-Json
    Assert-True ($mixedRemoved.outcome -eq 'succeeded') 'Legacy cleanup broke when v2 records exist for the same requirement.'
    Write-Output 'PASS: four locations, project baselines/remotes, offline override, dirty-root preservation, exact cleanup, legacy compatibility and release gate'
    $passed = $true
}
finally {
    if ($passed -and !$KeepArtifacts) {
        $expectedParent = [IO.Path]::GetFullPath((Join-Path $toolkitRoot 'local')).TrimEnd('\') + '\'
        $resolved = [IO.Path]::GetFullPath($testRoot)
        if (!$resolved.StartsWith($expectedParent, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^template-smoke-[a-f0-9]{32}$') { throw 'Cleanup path rejected.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    else { Write-Output "Disposable fixtures retained: $testRoot" }
}
