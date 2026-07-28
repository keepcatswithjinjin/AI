param(
    [Parameter(Mandatory = $true)]
    [string]$WorktreePath,

    [switch]$Preview,
    [switch]$Force,
    [switch]$SkipSerenaCleanup,
    [switch]$StopSerenaProcesses,

    [string]$StatePath = "__WORKSPACE_ROOT__\scripts\workspace-state.json",
    [string]$SerenaConfigPath = "$env:USERPROFILE\.serena\serena_config.yml",
    [string]$WorkspaceWorktreesRoot = "__WORKSPACE_ROOT__\worktrees",
    [string]$WorktreeRulesPath = "__WORKSPACE_ROOT__\rules\worktree.md"
)

$ErrorActionPreference = "Stop"

function Normalize-PathString {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Get-WorkspaceStateMatches {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$StateFile
    )
    if (-not (Test-Path -LiteralPath $StateFile)) {
        return @()
    }
    $state = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    $name = Split-Path -Leaf $ProjectPath
    $matches = @()
    foreach ($session in $state.sessions) {
        $sessionPath = if ($session.path) { Normalize-PathString $session.path } else { "" }
        $sessionName = [string]$session.sessionName
        if ($sessionPath.Equals($ProjectPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $matches += [pscustomobject]@{ Session = $session; Reason = "path" }
        }
        elseif ($sessionName.Equals($name, [System.StringComparison]::OrdinalIgnoreCase)) {
            $matches += [pscustomobject]@{ Session = $session; Reason = "name" }
        }
        elseif (($sessionPath -like "*$name*") -or ($sessionName -like "*$name*")) {
            $matches += [pscustomobject]@{ Session = $session; Reason = "contains" }
        }
    }
    return $matches
}

function Update-WorkspaceStateAfterWorktreeDelete {
    param(
        [Parameter(Mandatory = $true)][object[]]$Matches,
        [Parameter(Mandatory = $true)][string]$StateFile
    )
    if ($Matches.Count -eq 0) {
        return
    }
    $state = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    $names = @($Matches | ForEach-Object { $_.Session.sessionName })
    $state.sessions = @($state.sessions | Where-Object { $names -notcontains $_.sessionName })
    $state.updatedAt = (Get-Date -Format "yyyy-MM-dd")
    $state | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StateFile -Encoding UTF8
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

function Get-Md5Hex {
    param([Parameter(Mandatory = $true)][string]$Text)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $md5.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $md5.Dispose()
    }
}

function Get-DirectorySizeText {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return "0 B"
    }
    $sum = (Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) {
        $sum = 0
    }
    if ($sum -ge 1GB) {
        return "{0:N2} GB" -f ($sum / 1GB)
    }
    if ($sum -ge 1MB) {
        return "{0:N2} MB" -f ($sum / 1MB)
    }
    if ($sum -ge 1KB) {
        return "{0:N2} KB" -f ($sum / 1KB)
    }
    return "$sum B"
}

function Test-SerenaEnabled {
    param([Parameter(Mandatory = $true)][string]$Path)
    $codexConfig = Join-Path $Path ".codex\config.toml"
    $serenaDir = Join-Path $Path ".serena"
    if (Test-Path -LiteralPath $serenaDir) {
        return $true
    }
    if (Test-Path -LiteralPath $codexConfig) {
        $content = Get-Content -LiteralPath $codexConfig -Raw
        return $content -match "(?im)^\s*\[mcp_servers\.serena\]" -or $content -match "serena"
    }
    return $false
}

function Get-YamlScalar {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Key
    )
    $pattern = "^\s*$([regex]::Escape($Key))\s*:\s*[""']?(.*?)[""']?\s*$"
    foreach ($line in $Lines) {
        if ($line -match $pattern) {
            return $Matches[1]
        }
    }
    return $null
}

function Get-SerenaJdtlsWorkspaceDirs {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$ConfigPath
    )

    $candidates = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $workspaceBase = Join-Path $env:USERPROFILE ".serena\language_servers\static\EclipseJDTLS\workspaces"

    if (-not (Test-Path -LiteralPath $workspaceBase)) {
        return @()
    }

    [void]$candidates.Add((Get-Md5Hex $ProjectPath))

    if (Test-Path -LiteralPath $ConfigPath) {
        $lines = Get-Content -LiteralPath $ConfigPath
        $jdtlsPath = Get-YamlScalar -Lines $lines -Key "jdtls_path"
        $javaHome = Get-YamlScalar -Lines $lines -Key "java_home"
        if ($jdtlsPath -and $javaHome) {
            $pluginDir = Join-Path $jdtlsPath "plugins"
            $launcher = Get-ChildItem -LiteralPath $pluginDir -Filter "org.eclipse.equinox.launcher_*.jar" -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($launcher) {
                $escapedJavaHome = $javaHome.Replace("\", "\\").Replace('"', '\"')
                $settingsJson = "{""java_home"":""$escapedJavaHome""}"
                [void]$candidates.Add((Get-Md5Hex ($ProjectPath + "|" + $launcher.FullName + "|" + $settingsJson)))
            }
        }
    }

    $logRoot = Join-Path $env:USERPROFILE ".serena\logs"
    if (Test-Path -LiteralPath $logRoot) {
        $escapedProject = [regex]::Escape($ProjectPath)
        Get-ChildItem -LiteralPath $logRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 20MB } |
            ForEach-Object {
                $text = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
                if ($text -and $text -match $escapedProject) {
                    [regex]::Matches($text, "EclipseJDTLS[\\/]+workspaces[\\/]+([0-9a-fA-F]{32})") |
                        ForEach-Object { [void]$candidates.Add($_.Groups[1].Value.ToLowerInvariant()) }
                }
            }
    }

    $results = @()
    foreach ($hash in $candidates) {
        $dir = Join-Path $workspaceBase $hash
        if (Test-Path -LiteralPath $dir) {
            $results += [pscustomobject]@{
                Hash = $hash
                Path = (Normalize-PathString $dir)
                Size = (Get-DirectorySizeText $dir)
            }
        }
    }
    return $results
}

function Remove-SerenaProjectRegistration {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][bool]$DoWrite
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return $false
    }

    $lines = Get-Content -LiteralPath $ConfigPath
    $target = (Normalize-PathString $ProjectPath)
    $inProjects = $false
    $changed = $false
    $newLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match "^\S.*:\s*$") {
            $inProjects = $line -match "^projects:\s*$"
        }

        if ($inProjects -and $line -match "^\s*-\s*(.+?)\s*$") {
            $entry = (Normalize-PathString $Matches[1])
            if ($entry.Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) {
                $changed = $true
                continue
            }
        }

        $newLines.Add($line)
    }

    if ($changed -and $DoWrite) {
        Set-Content -LiteralPath $ConfigPath -Value $newLines -Encoding UTF8
    }

    return $changed
}

function Test-SerenaProjectRegistered {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$ConfigPath
    )
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return $false
    }
    $target = Normalize-PathString $ProjectPath
    $inProjects = $false
    foreach ($line in Get-Content -LiteralPath $ConfigPath) {
        if ($line -match "^\S.*:\s*$") {
            $inProjects = $line -match "^projects:\s*$"
        }
        if (-not $inProjects) {
            continue
        }
        if ($line -match "^\s*-\s*(.+?)\s*$") {
            try {
                $entry = Normalize-PathString $Matches[1]
            }
            catch {
                continue
            }
            if ($entry.Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }
    return $false
}

function Get-SerenaProcessMatches {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][object[]]$WorkspaceDirs
    )
    $patterns = @([regex]::Escape($ProjectPath))
    foreach ($item in $WorkspaceDirs) {
        $patterns += [regex]::Escape([string]$item.Hash)
        $patterns += [regex]::Escape([string]$item.Path)
    }
    $regex = ($patterns | Where-Object { $_ }) -join "|"
    if (-not $regex) {
        return @()
    }
    try {
        return @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $regex } | Select-Object ProcessId,Name,CommandLine)
    }
    catch {
        Write-Host "Unable to inspect process command lines. Use an elevated run if cleanup is blocked."
        return @()
    }
}

function Get-StoppableSerenaProcesses {
    param([AllowNull()][object[]]$Processes)
    if (-not $Processes) {
        return @()
    }
    $currentPid = $PID
    $stoppableNames = @("java.exe", "cmd.exe", "serena.exe", "python.exe", "python3.exe", "uv.exe")
    $results = @()
    foreach ($process in $Processes) {
        $name = ([string]$process.Name).ToLowerInvariant()
        $cmd = [string]$process.CommandLine
        if ([int]$process.ProcessId -eq $currentPid) {
            continue
        }
        if ($cmd -match "remove-worktree\.(cmd|ps1)") {
            continue
        }
        if ($stoppableNames -notcontains $name) {
            continue
        }
        if ($cmd -match "EclipseJDTLS\\workspaces\\|serena-agent|start-mcp-server") {
            $results += $process
        }
    }
    return $results
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

$stateMatches = @(Get-WorkspaceStateMatches -ProjectPath $resolvedWorktreePath -StateFile $StatePath)
$serenaWorkspaces = @()
$serenaRegistered = (-not $SkipSerenaCleanup) -and (Test-SerenaProjectRegistered -ProjectPath $resolvedWorktreePath -ConfigPath $SerenaConfigPath)
$localSerenaEnabled = (-not $SkipSerenaCleanup) -and (Test-SerenaEnabled -Path $resolvedWorktreePath)
if (-not $SkipSerenaCleanup) {
    $serenaWorkspaces = @(Get-SerenaJdtlsWorkspaceDirs -ProjectPath $resolvedWorktreePath -ConfigPath $SerenaConfigPath)
}
$serenaEnabled = (-not $SkipSerenaCleanup) -and ($localSerenaEnabled -or $serenaRegistered -or $serenaWorkspaces.Count -gt 0)
$willUpdateSerenaProjects = $false
if ($serenaEnabled) {
    $willUpdateSerenaProjects = Remove-SerenaProjectRegistration -ProjectPath $resolvedWorktreePath -ConfigPath $SerenaConfigPath -DoWrite:$false
}
$serenaProcesses = if ($serenaEnabled) { @(Get-SerenaProcessMatches -ProjectPath $resolvedWorktreePath -WorkspaceDirs $serenaWorkspaces) } else { @() }
$stoppableSerenaProcesses = if ($serenaEnabled) { @(Get-StoppableSerenaProcesses -Processes $serenaProcesses) } else { @() }

Write-Host "Worktree removal plan"
Write-Host "  worktree: $resolvedWorktreePath"
Write-Host "  main repo: $mainRepo"
Write-Host "  state matches: $($stateMatches.Count)"
foreach ($match in $stateMatches) {
    Write-Host "    - $($match.Session.sessionName) [$($match.Reason)] $($match.Session.path)"
}
Write-Host "  serena enabled: $serenaEnabled"
if ($serenaEnabled) {
    Write-Host "  serena project registration update: $willUpdateSerenaProjects"
    Write-Host "  serena JDTLS workspaces: $($serenaWorkspaces.Count)"
    foreach ($item in $serenaWorkspaces) {
        Write-Host "    - $($item.Path) ($($item.Size))"
    }
    Write-Host "  serena matching processes: $($serenaProcesses.Count)"
    foreach ($process in $serenaProcesses) {
        Write-Host "    - $($process.ProcessId) $($process.Name)"
    }
    Write-Host "  serena stoppable processes: $($stoppableSerenaProcesses.Count)"
    foreach ($process in $stoppableSerenaProcesses) {
        Write-Host "    - $($process.ProcessId) $($process.Name)"
    }
    Write-Host "  serena sharedIndex: keep"
    Write-Host "  serena logs: keep"
}

if ($Preview) {
    exit 0
}

if (-not $Force) {
    $answer = Read-Host "Type YES to remove this worktree and owned Serena indexes"
    if ($answer -ne "YES") {
        Write-Host "Cancelled."
        exit 1
    }
}

if ($stoppableSerenaProcesses.Count -gt 0) {
    if (-not $StopSerenaProcesses) {
        Write-Host "Serena/JDTLS processes still reference this worktree or index. Re-run with -StopSerenaProcesses after human approval."
        exit 3
    }
    foreach ($process in $stoppableSerenaProcesses) {
        Stop-Process -Id $process.ProcessId -Force
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

if ($stateMatches.Count -gt 0) {
    Update-WorkspaceStateAfterWorktreeDelete -Matches $stateMatches -StateFile $StatePath
}

if ($serenaEnabled) {
    [void](Remove-SerenaProjectRegistration -ProjectPath $resolvedWorktreePath -ConfigPath $SerenaConfigPath -DoWrite:$true)
    foreach ($item in $serenaWorkspaces) {
        $workspaceBase = Normalize-PathString (Join-Path $env:USERPROFILE ".serena\language_servers\static\EclipseJDTLS\workspaces")
        if (Test-IsUnderPath -Child $item.Path -Parent $workspaceBase) {
            Remove-Item -LiteralPath $item.Path -Recurse -Force
        }
    }
}

Write-Host "Done."
