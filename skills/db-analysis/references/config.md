# Configuration

Use a private JSON file based on `scripts/db-targets.example.json`.

## Rule

The skill must not own real database credentials. In a governed workstation, the root `scripts/db-analysis.cmd` wrapper always supplies `scripts/db-targets.json`; agents must not override it with `-ConfigPath`.

## Recommended Locations

For a workspace wrapper:

```text
<workspace-root>\scripts\db-targets.json
```

The workspace wrapper resolves this path from its own location. Real credentials remain in private files under the workspace and are never packaged with the skill.

## Fields

- `name`: stable target name used by `-Target`
- `type`: `mysql`, `postgresql`, or `redis`; use `postgresql` with `dialect: hologres` for Hologres.
- `host`: database host
- `port`: database port
- `database`: optional default database/schema. Keep it empty for a multi-schema target; schema operations still require an explicit `-Database`.
- `allowedDatabases`: required non-empty list of schemas that this target may expose to an agent. `-Action databases` returns only this list; an unlisted schema is rejected before a query is sent.
- `user`: database user
- `clientDefaultsFile`: optional absolute path to a private MySQL option file. When set, the script passes it as `--defaults-extra-file` and reads credentials from `[client]`; this is preferred for password-authenticated targets.
- `password`: legacy optional field. It is used only when `clientDefaultsFile` is absent; migrate it to a private option file instead.
- `allowedSchemas`: required non-empty list for PostgreSQL-compatible targets. It is the only schema authority for table discovery and queries.
- `pgPassFile`: required absolute path for PostgreSQL-compatible targets. It points to a private libpq passfile, never a shared skill file.
- `psqlPath`: optional absolute path to `psql.exe`; use it when the client is intentionally kept outside the system PATH.
- `sslMode`: optional libpq SSL mode. Prefer `verify-full` with `sslRootCert` for remote Hologres targets.
- `sslRootCert`: optional absolute CA certificate path used by `verify-ca` or `verify-full`.
- Redis test targets use `environment: test`, `redisDb` (numeric logical database, default 0), optional `user`, optional `redisCliPath`, `redisAuthFile` (private password file), optional `tls`/`caCertPath`, optional `allowedKeyPrefixes`, and `maxValueBytes` (default 65536, maximum 1048576). A read/write Redis account is permitted; the script never sends write commands.
- `allowOperationalReadonlyGrants`: optional; keep `false` by default. When `true`, allows `LOCK TABLES`, `PROCESS`, and replication-related grants, but direct write and administrative grants remain prohibited.
- `environment`: optional target classification. Set to `test` only for a test target.
- `allowPrivilegedTestAccount`: optional; keep `false` by default. When `true`, skips the account-grant rejection only when `environment` is `test`; SQL remains read-only and callers must still pass the Hook policy.
- `connectTimeoutSeconds`: optional connection timeout; defaults to 15 seconds.
- `queryTimeoutSeconds`: optional server-side read-query timeout; defaults to 60 seconds.
- `maxRows`: optional maximum rows for an ad-hoc query; defaults to 1000 and cannot exceed 10000.
- `sensitiveIdentifiers`: optional extra column or field names that ad-hoc queries must not reference.
- `note`: human-readable description

## Example

```json
{
  "targets": [
    {
      "name": "example-readonly",
      "type": "mysql",
      "host": "127.0.0.1",
      "port": 3306,
      "database": "sample_db",
      "user": "readonly_user",
      "clientDefaultsFile": "D:\\private\\mysql\\readonly.cnf",
      "note": "Example test readonly target"
    }
  ]
}
```

PostgreSQL/Hologres example:

```json
{
  "name": "holo-prod-ro",
  "type": "postgresql",
  "dialect": "hologres",
  "host": "<endpoint>",
  "port": 80,
  "database": "prod_ads",
  "allowedDatabases": ["prod_ads"],
  "allowedSchemas": ["common"],
  "user": "<readonly-user>",
  "psqlPath": "D:\\Tools\\pgsql\\bin\\psql.exe",
  "pgPassFile": "D:\\private\\postgres\\hologres.pgpass",
  "sslMode": "verify-full"
}
```

Do not store real credentials in the skill directory when sharing the skill.

Redis test example:

```json
{
  "name": "redis-test",
  "type": "redis",
  "environment": "test",
  "host": "redis.example.internal",
  "port": 6379,
  "redisDb": 0,
  "user": "",
  "redisCliPath": "",
  "redisAuthFile": "D:\\private\\redis\\test.password",
  "tls": false,
  "allowedKeyPrefixes": [],
  "maxValueBytes": 65536
}
```
