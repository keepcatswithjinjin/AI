param(
    [string]$Target,
    [ValidateSet("ping", "grants", "databases", "schemas", "tables", "columns", "create", "query")]
    [string]$Action = "tables",
    [string]$Database,
    [string]$Schema,
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
    if ($targetType.ToLowerInvariant() -notin @("mysql", "postgresql", "postgres")) {
        throw "Unsupported target type '$targetType'. Supported types: mysql, postgresql."
    }

    return $match[0]
}

function Get-TargetType {
    param($TargetConfig)
    if ($TargetConfig.type) { return ([string]$TargetConfig.type).Trim().ToLowerInvariant() }
    return "mysql"
}

function Get-AllowedSchemas {
    param($TargetConfig)

    $allowed = @($TargetConfig.allowedSchemas | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    if ($allowed.Count -eq 0) {
        throw "PostgreSQL target '$($TargetConfig.name)' has no allowedSchemas configured; refusing schema access."
    }
    return $allowed
}

function Resolve-ApprovedSchema {
    param($TargetConfig, [AllowNull()][string]$SchemaName, [string]$ActionName)

    if ([string]::IsNullOrWhiteSpace($SchemaName)) {
        throw "Schema is required for PostgreSQL -Action $ActionName. Use -Action schemas to view the configured allowlist, then pass -Schema <approved-schema>."
    }
    $matches = @(Get-AllowedSchemas -TargetConfig $TargetConfig | Where-Object { $_.Equals($SchemaName.Trim(), [System.StringComparison]::OrdinalIgnoreCase) })
    if ($matches.Count -eq 0) {
        throw "Schema '$SchemaName' is not in the allowedSchemas allowlist for target '$($TargetConfig.name)'."
    }
    return $matches[0]
}

function Get-AllowedDatabases {
    param($TargetConfig)

    $allowed = @($TargetConfig.allowedDatabases | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    if ($allowed.Count -eq 0) {
        throw "Target '$($TargetConfig.name)' has no allowedDatabases configured; refusing schema access."
    }
    return $allowed
}

function Resolve-ApprovedDatabase {
    param($TargetConfig, [AllowNull()][string]$DatabaseName, [string]$ActionName)

    if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
        throw "Database is required for -Action $ActionName. Use -Action databases to view the configured allowlist, then pass -Database <approved-schema>."
    }
    $matches = @(Get-AllowedDatabases -TargetConfig $TargetConfig | Where-Object { $_.Equals($DatabaseName.Trim(), [System.StringComparison]::OrdinalIgnoreCase) })
    if ($matches.Count -eq 0) {
        throw "Database '$DatabaseName' is not in the allowedDatabases allowlist for target '$($TargetConfig.name)'."
    }
    return $matches[0]
}

function Quote-Identifier {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Identifier cannot be empty."
    }

    $tick = [string][char]96
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

    $args = @()
    $defaultsExtraFile = ([string]$TargetConfig.clientDefaultsFile).Trim()
    if ($defaultsExtraFile) {
        if (-not (Test-Path -LiteralPath $defaultsExtraFile -PathType Leaf)) {
            throw "clientDefaultsFile does not exist for target '$($TargetConfig.name)': $defaultsExtraFile"
        }
        # MySQL requires this option before every other option so it is read
        # before normal client defaults. The file holds credentials only.
        $args += "--defaults-extra-file=$defaultsExtraFile"
    }

    $args += @(
        "--default-character-set=utf8mb4",
        "--connect-timeout=$connectTimeoutSeconds",
        "--init-command=SET SESSION MAX_EXECUTION_TIME=$($queryTimeoutSeconds * 1000)",
        "-N",
        "-B",
        "-h", $TargetConfig.host,
        "-P", [string]$TargetConfig.port,
        "-u", $TargetConfig.user
    )

    if (-not $defaultsExtraFile -and $TargetConfig.password) {
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

function Resolve-PsqlCommand {
    param($TargetConfig)

    $configuredPath = ([string]$TargetConfig.psqlPath).Trim()
    if ($configuredPath) {
        if (-not (Test-Path -LiteralPath $configuredPath -PathType Leaf)) {
            throw "psqlPath does not exist for target '$($TargetConfig.name)': $configuredPath"
        }
        return $configuredPath
    }
    $command = Get-Command psql.exe -ErrorAction SilentlyContinue
    if (-not $command) { $command = Get-Command psql -ErrorAction SilentlyContinue }
    if (-not $command) {
        throw "psql client not found in PATH. Install PostgreSQL 11+ client and add its bin directory to PATH."
    }
    return $command.Source
}

function Build-PostgresqlArgs {
    param($TargetConfig, [string]$DbName, [string]$QueryText)

    $args = @("-X", "-v", "ON_ERROR_STOP=1", "-A", "-t", "-F", "`t", "-h", $TargetConfig.host, "-p", [string]$TargetConfig.port, "-U", $TargetConfig.user, "-d", $DbName, "-c", $QueryText)
    return $args
}

function Invoke-Postgresql {
    param($TargetConfig, [string]$DbName, [string]$QueryText)

    $psql = Resolve-PsqlCommand -TargetConfig $TargetConfig
    $passFile = ([string]$TargetConfig.pgPassFile).Trim()
    if (-not $passFile -or -not (Test-Path -LiteralPath $passFile -PathType Leaf)) {
        throw "pgPassFile does not exist for target '$($TargetConfig.name)': $passFile"
    }

    $saved = @{}
    foreach ($name in @("PGPASSFILE", "PGSSLMODE", "PGSSLROOTCERT", "PGOPTIONS", "PGCONNECT_TIMEOUT")) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    }
    try {
        [Environment]::SetEnvironmentVariable("PGPASSFILE", $passFile, "Process")
        $sslMode = ([string]$TargetConfig.sslMode).Trim()
        if ($sslMode) { [Environment]::SetEnvironmentVariable("PGSSLMODE", $sslMode, "Process") }
        $sslRootCert = ([string]$TargetConfig.sslRootCert).Trim()
        if ($sslRootCert) {
            if (-not (Test-Path -LiteralPath $sslRootCert -PathType Leaf)) { throw "sslRootCert does not exist for target '$($TargetConfig.name)': $sslRootCert" }
            [Environment]::SetEnvironmentVariable("PGSSLROOTCERT", $sslRootCert, "Process")
        }
        $connectTimeout = if ($null -ne $TargetConfig.connectTimeoutSeconds) { [int]$TargetConfig.connectTimeoutSeconds } else { 15 }
        if ($connectTimeout -lt 1 -or $connectTimeout -gt 60) { throw "connectTimeoutSeconds must be between 1 and 60 for PostgreSQL targets." }
        [Environment]::SetEnvironmentVariable("PGCONNECT_TIMEOUT", [string]$connectTimeout, "Process")
        $timeout = if ($null -ne $TargetConfig.queryTimeoutSeconds) { [int]$TargetConfig.queryTimeoutSeconds } else { 60 }
        if ($timeout -lt 1 -or $timeout -gt 600) { throw "queryTimeoutSeconds must be between 1 and 600 for PostgreSQL targets." }
        [Environment]::SetEnvironmentVariable("PGOPTIONS", "-c statement_timeout=$($timeout * 1000) -c default_transaction_read_only=on", "Process")
        & $psql @(Build-PostgresqlArgs -TargetConfig $TargetConfig -DbName $DbName -QueryText $QueryText)
        if ($LASTEXITCODE -ne 0) { throw "psql exited with code $LASTEXITCODE" }
    }
    finally {
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], "Process") }
    }
}

function Assert-PostgresqlReadonlyAccount {
    param($TargetConfig, [string]$DbName)

    $schemas = Get-AllowedSchemas -TargetConfig $TargetConfig
    $schemaValues = (($schemas | ForEach-Object { "'$($_.Replace("'", "''"))'" }) -join ", ")
    $sqlText = @"
SELECT
  current_user,
  COALESCE((SELECT rolsuper::text FROM pg_roles WHERE rolname = current_user), 'unknown'),
  has_database_privilege(current_user, current_database(), 'CREATE')::text,
  COALESCE((SELECT bool_or(has_schema_privilege(current_user, nspname, 'CREATE')) FROM pg_namespace WHERE nspname IN ($schemaValues)), false)::text,
  COALESCE((SELECT bool_or(has_table_privilege(current_user, format('%I.%I', table_schema, table_name), 'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')) FROM information_schema.tables WHERE table_schema IN ($schemaValues) AND table_type = 'BASE TABLE'), false)::text;
"@
    $result = @((Invoke-Postgresql -TargetConfig $TargetConfig -DbName $DbName -QueryText $sqlText) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($result.Count -ne 1) { throw "Unable to inspect PostgreSQL readonly account state; refusing to continue." }
    $parts = $result[0] -split "`t", 5
    if ($parts.Count -ne 5) { throw "Unable to parse PostgreSQL readonly account state; refusing to continue." }
    if ($parts[1].Trim().ToLowerInvariant() -ne 'false' -or $parts[2].Trim().ToLowerInvariant() -ne 'false' -or $parts[3].Trim().ToLowerInvariant() -ne 'false' -or $parts[4].Trim().ToLowerInvariant() -ne 'false') {
        throw "Current PostgreSQL account is not readonly for the approved database/schema scope. Superuser/create/DML capability detected."
    }
    return $result
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
    $allowPrivilegedTestAccount = [bool]$TargetConfig.allowPrivilegedTestAccount
    $environment = ([string]$TargetConfig.environment).Trim().ToLowerInvariant()
    if ($allowPrivilegedTestAccount -and $environment -ne "test") {
        throw "allowPrivilegedTestAccount is permitted only for a target with environment 'test'."
    }
    if ($allowPrivilegedTestAccount) {
        Write-Warning "Target '$($TargetConfig.name)' uses a privileged test account. Only the read-only action and SQL checks remain permitted."
        return $grants
    }
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

function Assert-QuerySchemasAllowed {
    param($TargetConfig, [string]$QueryText)

    $allowed = Get-AllowedDatabases -TargetConfig $TargetConfig
    $normalized = Remove-SqlComments -Text $QueryText
    $qualifiedSources = [regex]::Matches($normalized, "(?is)\b(?:FROM|JOIN|TABLE)\s+`?([A-Za-z0-9_$]+)`?\s*\.")
    foreach ($source in $qualifiedSources) {
        $schema = $source.Groups[1].Value
        if (-not (@($allowed | Where-Object { $_.Equals($schema, [System.StringComparison]::OrdinalIgnoreCase) }).Count)) {
            throw "Query references schema '$schema', which is not in the allowedDatabases allowlist for target '$($TargetConfig.name)'."
        }
    }
}

function Quote-PostgresqlIdentifier {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { throw "Identifier cannot be empty." }
    return '"' + $Value.Replace('"', '""') + '"'
}

function Assert-PostgresqlReadonlySql {
    param([string]$QueryText)

    $safeSql = Assert-ReadonlySql -QueryText $QueryText
    $normalized = Remove-SqlComments -Text $safeSql
    $forbiddenPatterns = @(
        '\bSELECT\s+.+?\s+INTO\s+', '\bCOPY\b', '\bDO\b', '\bCALL\b',
        '\bVACUUM\b', '\bREINDEX\b', '\bCLUSTER\b', '\bREFRESH\s+MATERIALIZED\b',
        '\bFOR\s+(?:UPDATE|NO\s+KEY\s+UPDATE|SHARE|KEY\s+SHARE)\b', '\bLOCK\b',
        '\bPG_(?:TERMINATE_BACKEND|CANCEL_BACKEND|READ_FILE|WRITE_FILE|LOGDIR_LS)\s*\('
    )
    foreach ($pattern in $forbiddenPatterns) {
        if ($normalized -match "(?is)$pattern") { throw "PostgreSQL query contains forbidden operation: $pattern" }
    }
    return $safeSql
}

function Protect-PostgresqlReadQuery {
    param($TargetConfig, [string]$QueryText)

    $maxRows = if ($null -ne $TargetConfig.maxRows) { [int]$TargetConfig.maxRows } else { 1000 }
    if ($maxRows -lt 1 -or $maxRows -gt 10000) { throw "maxRows must be between 1 and 10000." }
    $normalized = Remove-SqlComments -Text $QueryText
    $limitMatch = [regex]::Match($normalized, '(?is)\bLIMIT\s+(\d+)(?:\s+OFFSET\s+(\d+))?')
    if ($limitMatch.Success) {
        if ([int]$limitMatch.Groups[1].Value -gt $maxRows) { throw "Query LIMIT $($limitMatch.Groups[1].Value) exceeds configured maxRows $maxRows." }
        return $QueryText
    }
    if ($normalized -match '(?i)\bLIMIT\b') { throw "PostgreSQL LIMIT must be a numeric literal no greater than maxRows $maxRows." }
    return ($QueryText.Trim().TrimEnd(";", " ") + " LIMIT $maxRows;")
}

function Assert-PostgresqlQuerySchemasAllowed {
    param($TargetConfig, [string]$QueryText)

    $allowed = Get-AllowedSchemas -TargetConfig $TargetConfig
    $normalized = Remove-SqlComments -Text $QueryText
    $sources = [regex]::Matches($normalized, '(?is)\b(?:FROM|JOIN)\s+"?([A-Za-z0-9_$]+)"?\s*\.\s*"?([A-Za-z0-9_$]+)"?')
    if ($sources.Count -eq 0) { throw "PostgreSQL queries must use explicit schema.table sources from the configured allowedSchemas list." }
    foreach ($source in $sources) {
        $schemaName = $source.Groups[1].Value
        if (-not (@($allowed | Where-Object { $_.Equals($schemaName, [System.StringComparison]::OrdinalIgnoreCase) }).Count)) {
            throw "Query references schema '$schemaName', which is not in the allowedSchemas allowlist for target '$($TargetConfig.name)'."
        }
    }
    if ($normalized -match '(?is)\b(?:FROM|JOIN)\s+(?!"?[A-Za-z0-9_$]+"?\s*\.)[A-Za-z_][A-Za-z0-9_$]*') {
        throw "PostgreSQL queries cannot use unqualified table sources. Use schema.table."
    }
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
$targetType = Get-TargetType -TargetConfig $targetConfig
$dbName = if ($Action -in @('tables', 'columns', 'create', 'query', 'schemas')) { Resolve-ApprovedDatabase -TargetConfig $targetConfig -DatabaseName $dbName -ActionName $Action } else { $dbName }
if ($targetType -eq 'mysql') {
    $grants = Assert-ReadonlyAccount -TargetConfig $targetConfig
}
else {
    if ([string]::IsNullOrWhiteSpace($dbName)) { throw "Database is required for PostgreSQL target '$($targetConfig.name)'." }
    $grants = Assert-PostgresqlReadonlyAccount -TargetConfig $targetConfig -DbName $dbName
}

switch ($Action) {
    "grants" {
        $grants
        break
    }
    "ping" {
        if ($targetType -eq 'mysql') {
            Invoke-Mysql -TargetConfig $targetConfig -DbName $dbName -QueryText "SELECT VERSION() AS version, DATABASE() AS current_database, CURRENT_USER() AS current_user_name, NOW() AS server_time;"
        }
        else {
            Invoke-Postgresql -TargetConfig $targetConfig -DbName $dbName -QueryText "SELECT version(), current_database(), current_user, now();"
        }
        break
    }
    "databases" {
        Get-AllowedDatabases -TargetConfig $targetConfig
        break
    }
    "schemas" {
        if ($targetType -eq 'mysql') { throw "-Action schemas is supported only for PostgreSQL targets." }
        Get-AllowedSchemas -TargetConfig $targetConfig
        break
    }
    "tables" {
        if ($targetType -ne 'mysql') {
            $schemaName = Resolve-ApprovedSchema -TargetConfig $targetConfig -SchemaName $Schema -ActionName $Action
            $safeSchema = $schemaName.Replace("'", "''")
            Invoke-Postgresql -TargetConfig $targetConfig -DbName $dbName -QueryText "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = '$safeSchema' ORDER BY table_name;"
            break
        }
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
        if (-not $Table) { throw "Table is required for -Action columns." }
        if ($targetType -ne 'mysql') {
            $schemaName = Resolve-ApprovedSchema -TargetConfig $targetConfig -SchemaName $Schema -ActionName $Action
            $safeSchema = $schemaName.Replace("'", "''"); $safeTable = $Table.Replace("'", "''")
            Invoke-Postgresql -TargetConfig $targetConfig -DbName $dbName -QueryText "SELECT ordinal_position, column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = '$safeSchema' AND table_name = '$safeTable' ORDER BY ordinal_position;"
            break
        }
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
        if ($targetType -ne 'mysql') { throw "-Action create is not enabled for PostgreSQL/Hologres until its DDL extraction method is verified for this instance." }
        if (-not $Table) { throw "Table is required for -Action create." }
        $quotedTable = Quote-Identifier -Value $Table
        Invoke-Mysql -TargetConfig $targetConfig -DbName $dbName -QueryText "SHOW CREATE TABLE $quotedTable;"
        break
    }
    "query" {
        if ($targetType -ne 'mysql') {
            Resolve-ApprovedSchema -TargetConfig $targetConfig -SchemaName $Schema -ActionName $Action | Out-Null
            $safeSql = Assert-PostgresqlReadonlySql -QueryText $Sql
            Assert-PostgresqlQuerySchemasAllowed -TargetConfig $targetConfig -QueryText $safeSql
            $boundedSql = Protect-PostgresqlReadQuery -TargetConfig $targetConfig -QueryText $safeSql
            Invoke-Postgresql -TargetConfig $targetConfig -DbName $dbName -QueryText $boundedSql
            break
        }
        $safeSql = Assert-ReadonlySql -QueryText $Sql
        Assert-QuerySchemasAllowed -TargetConfig $targetConfig -QueryText $safeSql
        $boundedSql = Protect-ReadQuery -TargetConfig $targetConfig -QueryText $safeSql
        Invoke-Mysql -TargetConfig $targetConfig -DbName $dbName -QueryText $boundedSql
        break
    }
}
