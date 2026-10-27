function Resolve-RedisCli {
    param($TargetConfig)
    $configured = ([string]$TargetConfig.redisCliPath).Trim()
    if ($configured) {
        if (-not (Test-Path -LiteralPath $configured -PathType Leaf)) { throw "redisCliPath does not exist for target '$($TargetConfig.name)'." }
        return $configured
    }
    $command = Get-Command redis-cli.exe -ErrorAction SilentlyContinue
    if (-not $command) { $command = Get-Command redis-cli -ErrorAction SilentlyContinue }
    if (-not $command) { throw 'redis-cli not found. Set redisCliPath to the installed redis-cli executable.' }
    return $command.Source
}

function Assert-RedisTestTarget {
    param($TargetConfig)
    if (([string]$TargetConfig.environment).Trim().ToLowerInvariant() -ne 'test') {
        throw 'Redis provider currently accepts only environment: test targets.'
    }
    if (-not $TargetConfig.host -or -not $TargetConfig.port) { throw 'Redis target host and port are required.' }
    $db = [int]$TargetConfig.redisDb
    if ($db -lt 0 -or $db -gt 255) { throw 'redisDb must be between 0 and 255.' }
    $authFile = ([string]$TargetConfig.redisAuthFile).Trim()
    if (-not $authFile -or -not (Test-Path -LiteralPath $authFile -PathType Leaf)) { throw 'redisAuthFile must point to a local private password file.' }
    return $db
}

function Invoke-RedisCli {
    param($TargetConfig, [int]$Db, [string[]]$CommandArgs)
    $redisCli = Resolve-RedisCli -TargetConfig $TargetConfig
    $authFile = ([string]$TargetConfig.redisAuthFile).Trim()
    $password = [System.IO.File]::ReadAllText($authFile, [System.Text.Encoding]::UTF8).TrimEnd("`r", "`n")
    if (-not $password) { throw 'redisAuthFile is empty.' }
    $saved = [Environment]::GetEnvironmentVariable('REDISCLI_AUTH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('REDISCLI_AUTH', $password, 'Process')
        $arguments = @('--raw', '-h', [string]$TargetConfig.host, '-p', [string]$TargetConfig.port, '-n', [string]$Db, '-t', '10')
        if ($TargetConfig.user) { $arguments += @('--user', [string]$TargetConfig.user) }
        if ($TargetConfig.tls -eq $true) {
            $arguments += '--tls'
            if ($TargetConfig.caCertPath) {
                if (-not (Test-Path -LiteralPath $TargetConfig.caCertPath -PathType Leaf)) { throw 'Redis CA certificate file not found.' }
                $arguments += @('--cacert', [string]$TargetConfig.caCertPath)
            }
        }
        $output = @(& $redisCli @arguments @CommandArgs)
        if ($LASTEXITCODE -ne 0) { throw "redis-cli exited with code $LASTEXITCODE." }
        if ($output.Count -gt 0 -and [string]$output[0] -match '^(?:ERR|NOAUTH|WRONGPASS|NOPERM|MOVED|ASK)\b') { throw "Redis rejected the request: $($output[0])" }
        return $output
    }
    finally {
        [Environment]::SetEnvironmentVariable('REDISCLI_AUTH', $saved, 'Process')
        $password = $null
    }
}

function Assert-RedisKey {
    param($TargetConfig, [string]$KeyName)
    if ([string]::IsNullOrWhiteSpace($KeyName)) { throw 'An exact -Key is required.' }
    $prefixes = @($TargetConfig.allowedKeyPrefixes | ForEach-Object { [string]$_ } | Where-Object { $_ })
    if ($prefixes.Count -and -not @($prefixes | Where-Object { $KeyName.StartsWith($_, [System.StringComparison]::Ordinal) }).Count) {
        throw 'Key is outside allowedKeyPrefixes.'
    }
}

function Assert-RedisScanPattern {
    param($TargetConfig, [string]$ScanPattern)
    if ($ScanPattern -notmatch '^[A-Za-z0-9:_./-]{3,}\*$') {
        throw 'SCAN requires a literal prefix of at least 3 characters followed by one trailing *.'
    }
    $prefixes = @($TargetConfig.allowedKeyPrefixes | ForEach-Object { [string]$_ } | Where-Object { $_ })
    $literalPrefix = $ScanPattern.Substring(0, $ScanPattern.Length - 1)
    if ($prefixes.Count -and -not @($prefixes | Where-Object { $literalPrefix.StartsWith($_, [System.StringComparison]::Ordinal) }).Count) {
        throw 'SCAN pattern is outside allowedKeyPrefixes.'
    }
}

function Invoke-RedisAction {
    param($TargetConfig, [string]$ActionName, [string]$KeyName, [string]$FieldName, [string]$ScanPattern, [string]$ScanCursor, [int]$ScanCount)
    $db = Assert-RedisTestTarget -TargetConfig $TargetConfig
    $maxBytes = if ($TargetConfig.maxValueBytes) { [int]$TargetConfig.maxValueBytes } else { 65536 }
    if ($maxBytes -lt 1 -or $maxBytes -gt 1048576) { throw 'maxValueBytes must be between 1 and 1048576.' }
    switch ($ActionName) {
        'ping' { Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @('PING'); return }
        'databases' { [string]$db; return }
        'key-info' {
            Assert-RedisKey -TargetConfig $TargetConfig -KeyName $KeyName
            $type = [string](Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @('TYPE', $KeyName) | Select-Object -First 1)
            $ttl = [string](Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @('TTL', $KeyName) | Select-Object -First 1)
            $lengthCommand = @{ string='STRLEN'; hash='HLEN'; list='LLEN'; set='SCARD'; zset='ZCARD'; stream='XLEN' }[$type]
            $length = if ($lengthCommand) { [string](Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @($lengthCommand, $KeyName) | Select-Object -First 1) } else { '' }
            [pscustomobject]@{ key=$KeyName; type=$type; ttlSeconds=$ttl; length=$length }
            return
        }
        'get' {
            Assert-RedisKey -TargetConfig $TargetConfig -KeyName $KeyName
            $size = [int](Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @('STRLEN', $KeyName) | Select-Object -First 1)
            if ($size -gt $maxBytes) { throw "Value is $size bytes; maxValueBytes is $maxBytes." }
            Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @('GET', $KeyName)
            return
        }
        'hget' {
            Assert-RedisKey -TargetConfig $TargetConfig -KeyName $KeyName
            if ([string]::IsNullOrEmpty($FieldName)) { throw '-Field is required for hget.' }
            $size = [int](Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @('HSTRLEN', $KeyName, $FieldName) | Select-Object -First 1)
            if ($size -gt $maxBytes) { throw "Field is $size bytes; maxValueBytes is $maxBytes." }
            Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @('HGET', $KeyName, $FieldName)
            return
        }
        'scan' {
            Assert-RedisScanPattern -TargetConfig $TargetConfig -ScanPattern $ScanPattern
            if ($ScanCursor -notmatch '^\d+$') { throw 'SCAN cursor must be an unsigned integer returned by the preceding call.' }
            if ($ScanCount -lt 1 -or $ScanCount -gt 100) { throw 'SCAN count must be between 1 and 100.' }
            $result = @(Invoke-RedisCli -TargetConfig $TargetConfig -Db $db -CommandArgs @('SCAN', $ScanCursor, 'MATCH', $ScanPattern, 'COUNT', [string]$ScanCount))
            if (-not $result.Count -or [string]$result[0] -notmatch '^\d+$') { throw 'Could not parse SCAN cursor.' }
            [pscustomobject]@{ nextCursor=[string]$result[0]; keys=@($result | Select-Object -Skip 1 -First 100); returnedKeyCount=[Math]::Max(0, $result.Count - 1); truncated=($result.Count -gt 101) }
            return
        }
        default { throw "Redis target does not support -Action $ActionName. Use ping, databases, key-info, get, hget, or scan." }
    }
}
