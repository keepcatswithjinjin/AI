# Configuration

Use a private JSON file based on `scripts/db-targets.example.json`.

## Rule

The skill must not own real database credentials. A caller provides a config file path with `-ConfigPath`, or a local wrapper supplies a default path.

## Recommended Locations

For a personal workstation wrapper:

```text
D:\Col\scripts\db-targets.json
```

For a reusable toolkit:

```text
D:\AI-Toolkit\private\db-targets.json
```

For a user-level config:

```text
%USERPROFILE%\.config\db-analysis\db-targets.json
```

These are conventions, not hard-coded skill requirements.

## Fields

- `name`: stable target name used by `-Target`
- `type`: `mysql` or `postgresql`; use `postgresql` with `dialect: hologres` for Hologres.
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
      "name": "oversea-test",
      "type": "mysql",
      "host": "127.0.0.1",
      "port": 3306,
      "database": "sample_db",
      "user": "readonly_user",
      "clientDefaultsFile": "D:\\private\\mysql\\readonly.cnf",
      "note": "OverSea test readonly target"
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
