# Configuration

Use a private JSON file based on `scripts/db-targets.example.json`.

## Rule

The skill must not own real database credentials. A caller provides a config file path with `-ConfigPath`, or a local wrapper supplies a default path.

## Recommended Locations

For a personal workstation wrapper:

```text
__WORKSPACE_ROOT__\scripts\db-targets.json
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
- `type`: currently only `mysql`
- `host`: database host
- `port`: database port
- `database`: optional default database/schema. Keep it empty for a multi-schema target; schema operations still require an explicit `-Database`.
- `allowedDatabases`: required non-empty list of schemas that this target may expose to an agent. `-Action databases` returns only this list; an unlisted schema is rejected before a query is sent.
- `user`: database user
- `clientDefaultsFile`: optional absolute path to a private MySQL option file. When set, the script passes it as `--defaults-extra-file` and reads credentials from `[client]`; this is preferred for password-authenticated targets.
- `password`: legacy optional field. It is used only when `clientDefaultsFile` is absent; migrate it to a private option file instead.
- `allowOperationalReadonlyGrants`: optional; keep `false` by default. When `true`, allows `LOCK TABLES`, `PROCESS`, and replication-related grants, but direct write and administrative grants remain prohibited.
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
      "database": "example_database",
      "user": "readonly_user",
      "clientDefaultsFile": "D:\\private\\mysql\\readonly.cnf",
      "note": "Example read-only target"
    }
  ]
}
```

Do not store real credentials in the skill directory when sharing the skill.
