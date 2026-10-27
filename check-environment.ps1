param([switch]$Json)

$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
$checks.Add([pscustomobject]@{ name = 'Windows'; required = $true; available = ($env:OS -eq 'Windows_NT'); detail = [Environment]::OSVersion.VersionString })
$checks.Add([pscustomobject]@{ name = 'PowerShell'; required = $true; available = ($PSVersionTable.PSVersion.Major -ge 7); detail = $PSVersionTable.PSVersion.ToString() })
foreach ($name in @('git', 'python')) {
    $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $available = $false
    $detail = 'Not found on PATH'
    if ($command) {
        try {
            if ($name -eq 'python') {
                $output = @(& $command.Source -c 'import sys; print(sys.version.split()[0]); sys.exit(0 if sys.version_info.major == 3 else 1)' 2>&1)
            } else { $output = @(& $command.Source --version 2>&1) }
            $available = $LASTEXITCODE -eq 0
            $detail = if ($available) { ($output -join ' ').Trim() } else { 'Command found but version check failed' }
        } catch { $detail = 'Command found but could not execute' }
    }
    $checks.Add([pscustomobject]@{ name = $name; required = $true; available = $available; detail = $detail })
}
$ready = @($checks | Where-Object { $_.required -and !$_.available }).Count -eq 0
$result = [pscustomobject]@{ ready = $ready; checks = @($checks.ToArray()); scope = 'Framework only; Agent login, project toolchains and optional services are not validated.' }
if ($Json) { $result | ConvertTo-Json -Depth 5 }
else { $checks | Format-Table name, available, detail -AutoSize; Write-Output $result.scope }
if (!$ready) { exit 1 }
exit 0
