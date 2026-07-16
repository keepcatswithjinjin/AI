# Col Agent Guard

`pre_tool_guard.py` is a shared Codex and Claude Code `PreToolUse` command hook.
Its source of truth is `policy.json`; both files are protected from agent edits
by an in-code baseline. A human changes protected policy/configuration files
manually outside the agent, then starts a new task so the updated configuration
is loaded.

The guard blocks:

- agent edits to its own policy, the Claude/Codex hook registration, the Col
  database target configuration, and the database wrapper scripts;
- direct `mysql`/`mariadb` shell usage;
- destructive or sensitive ad-hoc SQL passed to the Col DB wrapper.

It does not replace database grants, operating-system permissions, or remote
branch protections. Database operations must continue through
`__WORKSPACE_ROOT__\scripts\db-analysis.cmd`.
