# Shared Markdown index adapter. Legacy sections stay untouched.
function Read-MultiLocationIndex([string]$IndexPath) {
    $text = [IO.File]::ReadAllText($IndexPath)
    $bytes = [IO.File]::ReadAllBytes($IndexPath)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
    $lines = @($text -split '\r?\n')
    $rows = @(); $inside = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+') { $inside = $lines[$i] -match '^##\s+locations-v2\s*$'; continue }
        if (!$inside -or $lines[$i] -notmatch '^\s*\|') { continue }
        $cells = @($lines[$i].Trim().Split('|') | Select-Object -Skip 1 | Select-Object -SkipLast 1 | ForEach-Object { $_.Trim().Trim([char]96) })
        if ($cells.Count -ge 8 -and $cells[0] -match '^(backend|frontend|cross):[a-z0-9]+(?:-[a-z0-9]+)*$') { $rows += [pscustomobject]@{ RowIndex = $i; Cells = $cells } }
    }
    [pscustomobject]@{ Text = $text; Lines = $lines; Rows = @($rows); Newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }; Encoding = [Text.UTF8Encoding]::new($bom) }
}

function Resolve-MultiLocationMapping {
    param([string]$IndexPath, [string]$Requirement, [string]$LocationId, [string]$Role, [string]$ProjectKey, [string]$ExpectedPath, [string]$Group = '', [switch]$Cleanup)
    if ($Requirement -notmatch '^(backend|frontend|cross):([a-z0-9]+(?:-[a-z0-9]+)*)$') { throw 'Invalid RequirementKey.' }
    $type = $Matches[1]
    if ($LocationId -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $Role -notin @('backend','frontend')) { throw 'LocationId and Role are required for multi-location mappings.' }
    if ($type -ne 'cross' -and $type -ne $Role) { throw 'Location role does not match requirement type.' }
    if ($Group -and $Group -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'LocationGroup must be kebab-case.' }
    $document = Read-MultiLocationIndex $IndexPath
    $matched = @($document.Rows | Where-Object { $_.Cells[0] -eq $Requirement -and $_.Cells[1] -eq $LocationId })
    if ($matched.Count -gt 1) { throw 'Duplicate location identity in index.' }
    $row = if ($matched.Count) { $matched[0] } else { $null }
    if ($Cleanup) {
        if (!$row -or $row.Cells[2] -ne $Role -or $row.Cells[4] -in @('',([string][char]0x2014))) { throw 'No active exact location mapping.' }
        if (![IO.Path]::GetFullPath($row.Cells[4]).TrimEnd('\').Equals([IO.Path]::GetFullPath($ExpectedPath).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Location path does not match cleanup request.' }
    } else {
        if ($ProjectKey -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'ProjectKey is required for new locations.' }
        if ($row -and ($row.Cells[2] -ne $Role -or $row.Cells[3] -ne $ProjectKey)) { throw 'LocationId already belongs to another role/project.' }
        if ($row -and $row.Cells[4] -notin @('',([string][char]0x2014))) { throw 'Location already has an active mapping.' }
        foreach ($line in $document.Lines) {
            if ($line -notmatch '^\s*\|') { continue }
            foreach ($cell in ($line.Split('|') | ForEach-Object { $_.Trim().Trim([char]96) })) {
                if ($cell -and $cell.TrimEnd('\','/').Equals($ExpectedPath.TrimEnd('\','/'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Worktree path already registered; reuse it instead of duplicating.' }
            }
        }
    }
    [pscustomobject]@{ Format = 'locations-v2'; IndexPath = $IndexPath; Document = $document; Row = $row; RequirementKey = $Requirement; Role = $Role; LocationId = $LocationId; ProjectKey = $ProjectKey; Group = $Group; Branch = if ($row) { $row.Cells[5] } else { '' } }
}

function Sync-MultiLocationIndex {
    param($Mapping, [string]$Path = '', [string]$Branch = '', [switch]$Cleanup)
    if ([IO.File]::ReadAllText($Mapping.IndexPath) -ne $Mapping.Document.Text) { throw 'Index changed after preflight; retry from a fresh preview.' }
    $lines = @($Mapping.Document.Lines)
    $date = Get-Date -Format 'yyyy-MM-dd'
    if ($Cleanup) {
        $cells = @($Mapping.Row.Cells)
        $cells[4] = ([string][char]0x2014); $cells[5] = ([string][char]0x2014)
        $cells[7] = "Cleaned $date; branch retained: $($Mapping.Branch)"
    } else {
        $cells = @($Mapping.RequirementKey, $Mapping.LocationId, $Mapping.Role, $Mapping.ProjectKey, $Path, $Branch, $(if ($Mapping.Group) { $Mapping.Group } else { ([string][char]0x2014) }), "Created $date")
    }
    $rowText = '| ' + (($cells | ForEach-Object { if ($_ -match '[|\r\n]') { throw 'Unsafe Markdown cell.' }; $_ }) -join ' | ') + ' |'
    if ($Mapping.Row) { $lines[$Mapping.Row.RowIndex] = $rowText }
    else {
        $section = -1; $end = $lines.Count
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^##\s+locations-v2\s*$') { $section = $i; continue }
            if ($section -ge 0 -and $lines[$i] -match '^##\s+') { $end = $i; break }
        }
        if ($section -lt 0) { $lines += @('', '## locations-v2', '', '| RequirementKey | LocationId | Role | ProjectKey | Path | Branch | Group | Note |', '| --- | --- | --- | --- | --- | --- | --- | --- |', $rowText) }
        else { $lines = @($lines | Select-Object -First $end) + @($rowText) + @($lines | Select-Object -Skip $end) }
    }
    $temporary = "$($Mapping.IndexPath).tmp"
    [IO.File]::WriteAllText($temporary, ($lines -join $Mapping.Document.Newline), $Mapping.Document.Encoding)
    Move-Item -LiteralPath $temporary -Destination $Mapping.IndexPath -Force
}
