param(
    [string]$StatePath = "__WORKSPACE_ROOT__\scripts\workspace-state.json",
    [switch]$WhatIf,
    [switch]$All,
    [bool]$EnabledOnly = $true
)

$ErrorActionPreference = "Stop"

if ($All) {
    $EnabledOnly = $false
}

function Normalize-PathValue {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $PathValue
    }
    try {
        return (Resolve-Path -LiteralPath $PathValue).Path
    } catch {
        return $PathValue.Replace("/", "\")
    }
}

function Quote-ForPowerShell {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return "''"
    }
    return "'" + ($Value -replace "'", "''") + "'"
}

function Resolve-ToolPath {
    param([Parameter(Mandatory = $true)][string]$Tool)

    $command = Get-Command "$Tool.cmd" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $command = Get-Command $Tool -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Unable to resolve executable for tool '$Tool'."
}

function Get-ResumeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Tool,
        [AllowNull()][string]$Resume
    )

    $toolPath = Resolve-ToolPath -Tool $Tool

    switch ($Tool.ToLowerInvariant()) {
        "codex" {
            if ([string]::IsNullOrWhiteSpace($Resume)) {
                return "& $(Quote-ForPowerShell $toolPath) resume --last"
            }
            return "& $(Quote-ForPowerShell $toolPath) resume $(Quote-ForPowerShell $Resume)"
        }
        "claude" {
            if ([string]::IsNullOrWhiteSpace($Resume)) {
                return "& $(Quote-ForPowerShell $toolPath) --continue"
            }
            return "& $(Quote-ForPowerShell $toolPath) --resume $(Quote-ForPowerShell $Resume)"
        }
        "powershell" {
            return ""
        }
        default {
            throw "Unsupported tool '$Tool'. Use codex, claude, or powershell."
        }
    }
}

function Build-SessionPlan {
    param(
        [Parameter(Mandatory = $true)]$Session
    )

    $errors = New-Object System.Collections.ArrayList
    $sessionName = if ($Session.PSObject.Properties.Name -contains "sessionName") {
        $Session.sessionName
    } else {
        $Session.name
    }
    $sessionId = if ($Session.PSObject.Properties.Name -contains "sessionId") {
        $Session.sessionId
    } else {
        ""
    }

    if ([string]::IsNullOrWhiteSpace($sessionName)) {
        [void]$errors.Add("missing sessionName")
        $sessionName = "<missing>"
    }
    if ([string]::IsNullOrWhiteSpace($Session.path)) {
        [void]$errors.Add("missing path")
    }
    $sessionPath = if ([string]::IsNullOrWhiteSpace($Session.path)) {
        ""
    } else {
        Normalize-PathValue $Session.path
    }
    if ([string]::IsNullOrWhiteSpace($Session.tool)) {
        [void]$errors.Add("missing tool")
    }
    if (-not [string]::IsNullOrWhiteSpace($sessionPath) -and -not (Test-Path -LiteralPath $sessionPath)) {
        [void]$errors.Add("path not found: $sessionPath")
    }

    $resumeCommand = ""
    $displayCommand = "PowerShell"
    if (-not [string]::IsNullOrWhiteSpace($Session.tool)) {
        try {
            $resumeCommand = Get-ResumeCommand -Tool $Session.tool -Resume $sessionName
            if (-not [string]::IsNullOrWhiteSpace($resumeCommand)) {
                $displayCommand = $resumeCommand
            }
        } catch {
            [void]$errors.Add($_.Exception.Message)
        }
    }

    return [PSCustomObject]@{
        SessionName = $sessionName
        SessionId = $sessionId
        Tool = $Session.tool
        Path = $sessionPath
        Command = $displayCommand
        ResumeCommand = $resumeCommand
        Errors = @($errors)
        Status = if ($errors.Count -eq 0) { "OK" } else { "ERROR" }
    }
}

function Open-SessionPlan {
    param(
        [Parameter(Mandatory = $true)]$Plan
    )

    $title = $Plan.SessionName
    $proxyBlock = ""
    if ($Plan.Tool -eq "codex") {
        $proxyBlock = '$env:HTTP_PROXY = "http://127.0.0.1:7890"; $env:HTTPS_PROXY = "http://127.0.0.1:7890"; $env:ALL_PROXY = "socks5://127.0.0.1:7891"; '
    }

    $shellCommand = if ([string]::IsNullOrWhiteSpace($Plan.ResumeCommand)) {
        "Set-Location -LiteralPath $(Quote-ForPowerShell $Plan.Path)"
    } else {
        "Set-Location -LiteralPath $(Quote-ForPowerShell $Plan.Path); ${proxyBlock}$($Plan.ResumeCommand)"
    }

    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($shellCommand))

    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($wt) {
        $args = @(
            "new-tab",
            "--title", $title,
            "-d", $Plan.Path,
            "powershell",
            "-NoExit",
            "-EncodedCommand", $encodedCommand
        )
        Start-Process -FilePath $wt.Source -ArgumentList $args | Out-Null
    } else {
        Start-Process -FilePath "powershell" -ArgumentList @("-NoExit", "-EncodedCommand", $encodedCommand) | Out-Null
    }

    return $Plan
}

if (-not (Test-Path -LiteralPath $StatePath)) {
    throw "Workspace state file not found: $StatePath"
}

$state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
$sessions = @($state.sessions)
if ($EnabledOnly) {
    $sessions = @($sessions | Where-Object { $_.enabled -eq $true })
}

if ($sessions.Count -eq 0) {
    Write-Host "No sessions to open."
    return
}

$plans = foreach ($session in $sessions) {
    Build-SessionPlan -Session $session
}

$rows = foreach ($plan in $plans) {
    [PSCustomObject]@{
        Status = $plan.Status
        SessionName = $plan.SessionName
        SessionId = $plan.SessionId
        Tool = $plan.Tool
        Path = $plan.Path
        Command = $plan.Command
        Error = ($plan.Errors -join "; ")
    }
}

if ($WhatIf) {
    $rows | Format-Table Status, SessionName, SessionId, Tool, Path, Command, Error -AutoSize
    return
}

$invalidPlans = @($plans | Where-Object { $_.Status -ne "OK" })
if ($invalidPlans.Count -gt 0) {
    $rows | Format-Table Status, SessionName, SessionId, Tool, Path, Command, Error -AutoSize
    throw "Workspace restore aborted. Fix invalid sessions and retry."
}

$opened = foreach ($plan in $plans) {
    Open-SessionPlan -Plan $plan
}

$rows | Format-Table Status, SessionName, SessionId, Tool, Path, Command -AutoSize
