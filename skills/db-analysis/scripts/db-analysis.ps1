param(
    [string]$Target,
    [ValidateSet("ping", "grants", "databases", "tables", "columns", "create", "query")]
    [string]$Action = "tables",
    [string]$Database,
    [string]$Table,
    [string]$Sql,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "db-targets.json"),
    [switch]$ListTargets
)

$ErrorActionPreference = "Stop"

function Load-Targets {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Config is empty: $Path"
    }

    $config = $raw | ConvertFrom-Json
    if (-not $config.targets) {
        throw "Config missing targets: $Path"
    }

    return $config
}

function Resolve-Target {
    param($Config, [string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Target is required. Use -ListTargets to inspect configured targets."
    }

    $match = @($Config.targets | Where-Object { $_.name -eq $Name })
    if ($match.Count -eq 0) {
        throw "Target not found: $Name"
    }

    $targetType = if ($match[0].type) { $match[0].type } else { "mysql" }
    if ($targetType.ToLowerInvariant() -ne "mysql") {
        throw "Unsupported target type '$targetType'. This script currently supports mysql only."
    }

    return $match[0]
}

function Quote-Identifier {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Identifier cannot be empty."
    }

    $tick = [char]96
    return ($tick + $Value.Replace($tick, "$tick$tick") + $tick)
}

function Resolve-MysqlCommand {
    $command = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command mysql -ErrorAction SilentlyContinue
    }
    if (-not $command) {
        throw "mysql client not found in PATH. Install MySQL client or add mysql.exe to PATH."
    }
    return $command.Source
}

function Build-MysqlArgs {
    param($TargetConfig, [AllowNull()][string]$DbName, [string]$QueryText)

    $connectTimeoutSeconds = 15
    if ($null -ne $TargetConfig.connectTimeoutSeconds) {
        $connectTimeoutSeconds = [int]$TargetConfig.connectTimeoutSeconds
    }
    $queryTimeoutSeconds = 60
    if ($null -ne $TargetConfig.queryTimeoutSeconds) {
        $queryTimeoutSeconds = [int]$TargetConfig.queryTimeoutSeconds
    }

    $args = @(
        "--default-character-set=utf8mb4",
        "--connect-timeout=$connectTimeoutSeconds",
        "--init-command=SET SESSION MAX_EXECUTION_TIME=$($queryTimeoutSeconds * 1000)",
        "-N",
        "-B",
        "-h", $TargetConfig.host,
        "-P", [string]$TargetConfig.port,
        "-u", $TargetConfig.user
    )

    if ($TargetConfig.password) {
        $args += "-p$($TargetConfig.password)"
    }

    if ($DbName) {
        $args += $DbName
    }

    $args += "-e"
    $args += $QueryText

    return $args
}

function Protect-ReadQuery {
    param($TargetConfig, [string]$QueryText)

    $maxRows = 1000
    if ($null -ne $TargetConfig.maxRows) {
        $maxRows = [int]$TargetConfig.maxRows
    }
    if ($maxRows -lt 1 -or $maxRows -gt 10000) {
        throw "maxRows must be between 1 and 10000."
    }

    $normalized = Remove-SqlComments -Text $QueryText
    if ($normalized -match "(?is)\b(FOR\s+UPDATE|LOCK\s+IN\s+SHARE\s+MODE|SLEEP\s*\(|BENCHMARK\s*\(|LOAD_FILE\s*\()") {
        throw "Query contains a locking, delay, or server-file function."
    }
    if ($normalized -match "(?is)\b(?:information_schema\.)?(?:processlist|innodb_[a-z_]+)\b") {
        throw "Query cannot access process or InnoDB diagnostic tables."
    }
    $sensitiveIdentifiers = @("password", "secret", "token", "private_key", "card_pan", "bank_account", "id_card", "passport")
    if ($TargetConfig.sensitiveIdentifiers) {
        $sensitiveIdentifiers += @($TargetConfig.sensitiveIdentifiers)
    }
    foreach ($identifier in ($sensitiveIdentifiers | Sort-Object -Unique)) {
        if ($normalized -match "(?i)\b$([regex]::Escape([string]$identifier))\b") {
            throw "Query references sensitive identifier '$identifier'."
        }
    }

    $limitMatch = [regex]::Match($normalized, "(?is)\bLIMIT\s+(\d+)(?:\s*,\s*(\d+)|\s+OFFSET\s+(\d+))?")
    if ($limitMatch.Success) {
        $effectiveLimit = if ($limitMatch.Groups[2].Success) { [int]$limitMatch.Groups[2].Value } else { [int]$limitMatch.Groups[1].Value }
        if ($effectiveLimit -gt $maxRows) {
            throw "Query LIMIT $effectiveLimit exceeds configured maxRows $maxRows."
        }
        return $QueryText
    }
    if ($normalized -match "(?i)\bLIMIT\b") {
        throw "Query LIMIT must be a numeric literal no greater than maxRows $maxRows."
    }
    return ($QueryText.Trim().TrimEnd(";", " ") + " LIMIT $maxRows;")
}

function Invoke-Mysql {
    param($TargetConfig, [AllowNull()][string]$DbName, [string]$QueryText)

    $mysql = Resolve-MysqlCommand
    $args = Build-MysqlArgs -TargetConfig $TargetConfig -DbName $DbName -QueryText $QueryText
    & $mysql @args
    if ($LASTEXITCODE -ne 0) {
        throw "mysql exited with code $LASTEXITCODE"
    }
}

function Get-CurrentGrants {
    param($TargetConfig)
    $result = Invoke-Mysql -TargetConfig $TargetConfig -DbName $null -QueryText "SHOW GRANTS FOR CURRENT_USER();"
    return @($result | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Assert-ReadonlyAccount {
    param($TargetConfig)

    $grants = Get-CurrentGrants -TargetConfig $TargetConfig
    if ($grants.Count -eq 0) {
        throw "Unable to inspect current account grants; refusing to continue."
    }

    $joined = ($grants -join "`n").ToUpperInvariant()
    $allowOperationalReadonlyGrants = [bool]$TargetConfig.allowOperationalReadonlyGrants
    $forbidden = @(
        "ALL PRIVILEGES", "ALTER", "CREATE", "DELETE", "DROP", "EVENT", "EXECUTE",
        "FILE", "GRANT OPTION", "INDEX", "INSERT", "REFERENCES", "RELOAD", "REPLACE",
        "SHUTDOWN", "SUPER",
        "TRIGGER", "UPDATE", "CREATE TEMPORARY TABLES", "CREATE VIEW", "CREATE ROUTINE",
        "ALTER ROUTINE", "CREATE USER", "ROLE_ADMIN", "SYSTEM_USER"
    )

    if (-not $allowOperationalReadonlyGrants) {
        $forbidden += "LOCK TABLES", "PROCESS", "REPLICATION"
    }

    $hits = @()
    foreach ($privilege in $forbidden) {
        if ($joined -match "(^|[^A-Z_])$([regex]::Escape($privilege))([^A-Z_]|$)") {
            $hits += $privilege
        }
    }

    if ($hits.Count -gt 0) {
        $uniqueHits = $hits | Sort-Object -Unique
        throw "Current database account is not readonly. Forbidden grants detected: $($uniqueHits -join ', ')"
    }

    if ($allowOperationalReadonlyGrants) {
        Write-Warning "Target '$($TargetConfig.name)' permits operational read-only grants: LOCK TABLES, PROCESS, REPLICATION."
    }

    return $grants
}

function Remove-SqlComments {
    param([string]$Text)

    $withoutBlock = [regex]::Replace($Text, "/\*.*?\*/", " ", "Singleline")
    $withoutLine = [regex]::Replace($withoutBlock, "(?m)--.*$", " ")
    return $withoutLine.Trim()
}

function Assert-ReadonlySql {
    param([string]$QueryText)

    if ([string]::IsNullOrWhiteSpace($QueryText)) {
        throw "Sql is required for -Action query."
    }

    $normalized = Remove-SqlComments -Text $QueryText
    $trimmed = $normalized.Trim()
    $withoutTrailingSemi = $trimmed.TrimEnd(";", " ")

    if ($withoutTrailingSemi -match ";") {
        throw "Multiple SQL statements are not allowed."
    }

    if ($withoutTrailingSemi -notmatch "^(?is)\s*(SELECT|SHOW|DESCRIBE|DESC|EXPLAIN|WITH)\b") {
        throw "Only read-only SQL is allowed: SELECT, SHOW, DESCRIBE, DESC, EXPLAIN, WITH."
    }

    $forbiddenPatterns = @(
        "\bINSERT\b", "\bUPDATE\b", "\bDELETE\b", "\bREPLACE\b", "\bCREATE\b",
        "\bALTER\b", "\bDROP\b", "\bTRUNCATE\b", "\bGRANT\b", "\bREVOKE\b",
        "\bCALL\b", "\bSET\b", "\bLOCK\b", "\bUNLOCK\b", "\bLOAD\b",
        "\bINTO\s+OUTFILE\b", "\bINTO\s+DUMPFILE\b", "\bANALYZE\b", "\bOPTIMIZE\b",
        "\bREPAIR\b", "\bKILL\b"
    )

    foreach ($pattern in $forbiddenPatterns) {
        if ($withoutTrailingSemi -match "(?is)$pattern") {
            throw "SQL contains forbidden operation: $pattern"
        }
    }

    return $QueryText
}

$config = Load-Targets -Path $ConfigPath

if ($ListTargets) {
    $config.targets |
        Select-Object name, type, host, port, database, user, note |
        Format-Table -AutoSize
    return
}

$targetConfig = Resolve-Target -Config $config -Name $Target
$dbName = if ($Database) { $Database } else { $targetConfig.database }
$grants = Assert-ReadonlyAccount -TargetConfig $targetConfig

switch ($Action) {
    "grants" {
        $grants
        break
    }
    "ping" {
        Invoke-Mysql -TargetConfig $targetConfig -DbName $dbName -QueryText "SELECT VERSION() AS version, DATABASE() AS current_database, CURRENT_USER() AS current_user_name, NOW() AS server_time;"
        break
    }
    "databases" {
        Invoke-Mysql -TargetConfig $targetConfig -DbName $null -QueryText "SHOW DATABASES;"
        break
    }
    "tables" {
        if (-not $dbName) { throw "Database is required for -Action tables." }
        $safeDbName = $dbName.Replace("'", "''")
        $sqlText = @"
SELECT
  table_name,
  table_rows,
  create_time,
  update_time,
  table_comment
FROM information_schema.tables
WHERE table_schema = '$safeDbName'
ORDER BY table_name;
"@
        Invoke-Mysql -TargetConfig $targetConfig -DbName $null -QueryText $sqlText
        break
    }
    "columns" {
        if (-not $dbName) { throw "Database is required for -Action columns." }
        if (-not $Table) { throw "Table is required for -Action columns." }
        $safeDbName = $dbName.Replace("'", "''")
        $safeTable = $Table.Replace("'", "''")
        $sqlText = @"
SELECT
  ordinal_position,
  column_name,
  column_type,
  is_nullable,
  column_default,
  column_key,
  extra,
  column_comment
FROM information_schema.columns
WHERE table_schema = '$safeDbName'
  AND table_name = '$safeTable'
ORDER BY ordinal_position;
"@
        Invoke-Mysql -TargetConfig $targetConfig -DbName $null -QueryText $sqlText
        break
    }
    "create" {
        if (-not $dbName) { throw "Database is required for -Action create." }
        if (-not $Table) { throw "Table is required for -Action create." }
        $quotedTable = Quote-Identifier -Value $Table
        Invoke-Mysql -TargetConfig $targetConfig -DbName $dbName -QueryText "SHOW CREATE TABLE $quotedTable;"
        break
    }
    "query" {
        $safeSql = Assert-ReadonlySql -QueryText $Sql
        $boundedSql = Protect-ReadQuery -TargetConfig $targetConfig -QueryText $safeSql
        Invoke-Mysql -TargetConfig $targetConfig -DbName $dbName -QueryText $boundedSql
        break
    }
}
