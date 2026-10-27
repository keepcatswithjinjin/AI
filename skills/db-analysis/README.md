# DB Analysis Usage

This skill provides MySQL and PostgreSQL/Hologres read-only SQL exploration plus bounded test Redis key inspection.

## What Belongs Where

The skill contains reusable logic, not private environment configuration.

| Item | Location | Purpose |
|------|----------|---------|
| Skill script | `scripts/db-analysis.cmd` / `scripts/db-analysis.ps1` | Portable database inspection tool |
| Example config | `scripts/db-targets.example.json` | Template for local target config |
| Real config | `<workspace-root>\scripts\db-targets.json` | Local targets and private connection settings |
| Project profile | User-chosen project/profile path | Optional business table notes |

Do not store real credentials in the skill directory if the skill will be shared.

## Recommended Config Locations

Use the workspace-local config path; the wrapper supplies it automatically. The governance policy rejects `-ConfigPath` overrides.

For an installed workstation:

```text
<workspace-root>\scripts\db-targets.json
```

The workspace wrapper supplies this config path by default. The skill does not depend on a user-level Codex installation.

## Setup

1. Copy the workspace `scripts/db-targets.example.json` to `scripts/db-targets.json` without committing it.
2. Fill in target connection values.
3. Use read-only accounts for SQL targets. Test Redis may use a read/write account; only bounded read actions are exposed.
4. Run `ping` before exploration. SQL targets also perform account checks.

Use the workspace entrypoint:

```powershell
.\scripts\db-analysis.cmd -ListTargets
.\scripts\db-analysis.cmd -Target local-readonly -Action ping
```

Example from the workstation root:

```powershell
.\scripts\db-analysis.cmd -ListTargets
.\scripts\db-analysis.cmd -Target sample-local -Action ping
```

The wrapper defaults `-ConfigPath` to `<workspace-root>\scripts\db-targets.json`.

## Config Format

```json
{
  "targets": [
    {
      "name": "local-readonly",
      "type": "mysql",
      "host": "127.0.0.1",
      "port": 3306,
      "database": "demo_db",
      "user": "readonly_user",
      "password": "",
      "note": "Local readonly database"
    }
  ]
}
```

## Common Commands

```powershell
.\scripts\db-analysis.cmd -Target local-readonly -Action grants
.\scripts\db-analysis.cmd -Target local-readonly -Database demo_db -Action tables
.\scripts\db-analysis.cmd -Target local-readonly -Database demo_db -Action columns -Table order_subscribe
.\scripts\db-analysis.cmd -Target local-readonly -Database demo_db -Action create -Table order_subscribe
.\scripts\db-analysis.cmd -Target local-readonly -Database demo_db -Action query -Sql "SELECT COUNT(*) FROM order_subscribe"
```

## Safety

SQL targets check account permissions before querying. The Redis provider accepts only test targets and has no account permission check; it exposes explicit bounded read actions and requires a private password file. See `references/safety.md` for details.
