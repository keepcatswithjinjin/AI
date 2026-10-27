---
name: db-analysis
description: Use this skill to configure database targets, verify connectivity, inspect MySQL or PostgreSQL schemas, run bounded read-only SQL, or inspect test Redis keys through a bounded command interface. Project business knowledge should live in separate project profiles.
---

# DB Analysis

Use this skill for safe, repeatable database exploration. It provides a Windows PowerShell entrypoint for MySQL, PostgreSQL-compatible databases (including Hologres), and test Redis diagnostics.

## Core Rules

- From the workspace root, use `scripts/db-analysis.cmd`; its implementation lives beside this skill in `skills/db-analysis/scripts/`.
- Do not put real credentials in the skill folder.
- Keep real target config in the workspace's `scripts/db-targets.json`, outside this skill, using `scripts/db-targets.example.json` as an example.
- Before SQL target operations, the script checks the account's read-only state. MySQL uses `SHOW GRANTS FOR CURRENT_USER()`; PostgreSQL-compatible targets reject superuser, database/schema CREATE, and approved-schema DML capability. Redis test targets may use a read/write account; the Redis provider only exposes bounded read operations.
- Treat `allowedDatabases` as the only database authority. `-Action databases` returns that configured allowlist, not the server's full database list. PostgreSQL-compatible targets additionally require `allowedSchemas`; use `-Action schemas` to view it, pass `-Schema <approved-schema>`, and use `schema.table` in every query.
- For custom SQL, only read-only statements are allowed: `SELECT`, `SHOW`, `DESCRIBE`, `DESC`, `EXPLAIN`, and read-only `WITH` queries.
- Do not run DDL, DML, stored procedures, exports, locks, privilege changes, or multi-statement SQL through this skill.
- Redis uses `redis-cli` with a password read from a private local file. Never call `redis-cli` directly in the governed workspace. Do not use `KEYS`, `MONITOR`, `FLUSH*`, `EVAL`, or arbitrary Redis commands. `scan` requires a literal prefix and processes one cursor page per call.

## Quick Start

List configured targets:

```powershell
.\scripts\db-analysis.cmd -ListTargets
```

Check connectivity and SQL account status:

```powershell
.\scripts\db-analysis.cmd -Target example-readonly -Action ping
.\scripts\db-analysis.cmd -Target example-readonly -Action grants
```

List and select an approved schema:

```powershell
.\scripts\db-analysis.cmd -Target example-readonly -Action databases
.\scripts\db-analysis.cmd -Target example-readonly -Database actual_schema -Action tables
```

For PostgreSQL/Hologres:

```powershell
.\scripts\db-analysis.cmd -Target holo-prod-ro -Database prod_ads -Action schemas
.\scripts\db-analysis.cmd -Target holo-prod-ro -Database prod_ads -Schema common -Action tables
```

For a configured test Redis target:

```powershell
.\scripts\db-analysis.cmd -Target redis-test -Action ping
.\scripts\db-analysis.cmd -Target redis-test -Action scan -Pattern "order:*" -Cursor 0 -Count 50
.\scripts\db-analysis.cmd -Target redis-test -Action key-info -Key "order:123"
.\scripts\db-analysis.cmd -Target redis-test -Action get -Key "order:123"
.\scripts\db-analysis.cmd -Target redis-test -Action hget -Key "order:123" -Field "status"
```

Explore schema:

```powershell
.\scripts\db-analysis.cmd -Target example-readonly -Action tables
.\scripts\db-analysis.cmd -Target example-readonly -Action columns -Table example_table
.\scripts\db-analysis.cmd -Target example-readonly -Action create -Table example_table
```

Run read-only SQL:

```powershell
.\scripts\db-analysis.cmd -Target example-readonly -Action query -Sql "SELECT COUNT(*) FROM example_table"
```

## Workflow

1. Read `references/config.md` when setting up or changing database targets. Always execute through the workspace wrapper, which selects the local target config.
2. Read `references/safety.md` before changing the script or attempting custom SQL.
3. Run `-ListTargets` to choose a target.
4. Run `-Action ping` to verify connection. SQL targets also enforce the account checks; Redis test targets rely on the provider's bounded command list.
5. Run `databases` to view the target's configured `allowedDatabases`; never guess or discover additional schemas from the server.
6. For MySQL, explore the selected approved database: `tables` -> `columns` -> `create` with `-Database <approved-schema>`.
7. For PostgreSQL/Hologres, explore the selected approved database and schema: `schemas` -> `tables` -> `columns` with `-Database <approved-database> -Schema <approved-schema>`. `create` stays unavailable until its DDL extraction method is verified for that target.
8. Run custom `query` only after the relevant tables and columns are known; use fully qualified `schema.table` names for PostgreSQL/Hologres.
9. For Redis, select an explicit test target, inspect a key's type/TTL/length first, and use one-page `scan` only with a known prefix. Reuse the returned `nextCursor` when another page is needed.

## Project Knowledge

This skill does not contain business schema knowledge. For project-specific table maps, maintain a separate profile outside the skill, for example:

```text
<workspace-root>\knowledge\db-profiles\<project>.md
```

Load project profiles only when the user asks business-specific database questions.
