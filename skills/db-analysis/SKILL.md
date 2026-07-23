---
name: db-analysis
description: Use this skill when the user needs to configure database targets, verify database connectivity, inspect database schemas, list tables, inspect columns, view CREATE TABLE output, or run safe read-only SQL through a local MySQL client. This skill is database- and project-neutral; project business knowledge should live in separate project profiles.
---

# DB Analysis

Use this skill for safe, repeatable database exploration. It provides a portable Windows PowerShell script for MySQL schema inspection and read-only SQL.

## Core Rules

- Use bundled script `scripts/db-analysis.cmd` or `scripts/db-analysis.ps1` for database operations.
- Do not put real credentials in the skill folder.
- Keep real target config in a local file outside the skill, copied from `scripts/db-targets.example.json`.
- Before any target operation, the script checks `SHOW GRANTS FOR CURRENT_USER()` and refuses accounts with write or admin privileges.
- Treat `allowedDatabases` as the only schema authority. `-Action databases` returns that configured allowlist, not the server's full schema list. For schema operations and custom SQL, always pass `-Database <approved-schema>` and use `schema.table`; never infer a schema from a target name, project name, or example.
- For custom SQL, only read-only statements are allowed: `SELECT`, `SHOW`, `DESCRIBE`, `DESC`, `EXPLAIN`, and read-only `WITH` queries.
- Do not run DDL, DML, stored procedures, exports, locks, privilege changes, or multi-statement SQL through this skill.

## Quick Start

List configured targets:

```powershell
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -ListTargets
```

Check connectivity and readonly status:

```powershell
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -Target example-readonly -Action ping
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -Target example-readonly -Action grants
```

List and select an approved schema:

```powershell
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -Target example-readonly -Action databases
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -Target example-readonly -Database actual_schema -Action tables
```

Explore schema:

```powershell
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -Target example-readonly -Action tables
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -Target example-readonly -Action columns -Table example_table
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -Target example-readonly -Action create -Table example_table
```

Run read-only SQL:

```powershell
.\scripts\db-analysis.cmd -ConfigPath "D:\path\db-targets.json" -Target example-readonly -Action query -Sql "SELECT COUNT(*) FROM example_table"
```

## Workflow

1. Read `references/config.md` when setting up or changing database targets.
2. Read `references/safety.md` before changing the script or attempting custom SQL.
3. Run `-ListTargets` to choose a target.
4. Run `-Action ping` to verify connection and read-only enforcement.
5. Run `databases` to view the target's configured `allowedDatabases`; never guess or discover additional schemas from the server.
6. Explore the selected approved schema explicitly: `tables` -> `columns` -> `create` with `-Database <approved-schema>`.
7. Run custom `query` only after the relevant tables and columns are known; use fully qualified `schema.table` names.

## Project Knowledge

This skill does not contain business schema knowledge. For project-specific table maps, maintain a separate profile outside the skill, for example:

```text
D:\AI-Toolkit\db-profiles\<project>.md
```

Load project profiles only when the user asks business-specific database questions.
