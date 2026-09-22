# DB Analysis Usage

This skill provides a portable MySQL schema and read-only SQL helper.

## What Belongs Where

The skill contains reusable logic, not private environment configuration.

| Item | Location | Purpose |
|------|----------|---------|
| Skill script | `scripts/db-analysis.cmd` / `scripts/db-analysis.ps1` | Portable database inspection tool |
| Example config | `scripts/db-targets.example.json` | Template for local target config |
| Real config | User-chosen private path | Host, port, database, user, password |
| Project profile | User-chosen project/profile path | Optional business table notes |

Do not store real credentials in the skill directory if the skill will be shared.

## Recommended Config Locations

Choose one private config path and pass it with `-ConfigPath`.

For this user's Col workstation:

```text
D:\Col\scripts\db-targets.json
```

For a reusable toolkit or another machine:

```text
D:\AI-Toolkit\private\db-targets.json
%USERPROFILE%\.config\db-analysis\db-targets.json
```

The skill does not hard-code these paths. They are examples. The caller must pass the config path explicitly unless a local wrapper provides a default.

## Setup

1. Copy `scripts/db-targets.example.json` to a private local path.
2. Fill in target connection values.
3. Use a database account that only has read permissions.
4. Run `grants` or `ping` before schema exploration.

Example using the skill script directly:

```powershell
.\scripts\db-analysis.cmd -ConfigPath "D:\AI-Toolkit\private\db-targets.json" -ListTargets
.\scripts\db-analysis.cmd -ConfigPath "D:\AI-Toolkit\private\db-targets.json" -Target local-readonly -Action ping
```

Example from the Col workstation wrapper:

```powershell
D:\Col\scripts\db-analysis.cmd -ListTargets
D:\Col\scripts\db-analysis.cmd -Target sample-local -Action ping
```

The Col wrapper defaults `-ConfigPath` to `D:\Col\scripts\db-targets.json`.

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
.\scripts\db-analysis.cmd -ConfigPath "D:\AI-Toolkit\private\db-targets.json" -Target local-readonly -Action grants
.\scripts\db-analysis.cmd -ConfigPath "D:\AI-Toolkit\private\db-targets.json" -Target local-readonly -Action tables
.\scripts\db-analysis.cmd -ConfigPath "D:\AI-Toolkit\private\db-targets.json" -Target local-readonly -Action columns -Table order_subscribe
.\scripts\db-analysis.cmd -ConfigPath "D:\AI-Toolkit\private\db-targets.json" -Target local-readonly -Action create -Table order_subscribe
.\scripts\db-analysis.cmd -ConfigPath "D:\AI-Toolkit\private\db-targets.json" -Target local-readonly -Action query -Sql "SELECT COUNT(*) FROM order_subscribe"
```

## Safety

The script refuses to continue when `SHOW GRANTS FOR CURRENT_USER()` indicates write or admin privileges. This is a guardrail, not a substitute for provisioning a true read-only account at the database level.
