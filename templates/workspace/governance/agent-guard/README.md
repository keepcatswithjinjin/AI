# Workspace Agent Guard

`pre_tool_guard.py` is a shared Codex and Claude Code `PreToolUse` command hook.
Its source of truth is `policy.json`; governance assets are protected from
agent edits by an in-code baseline. By default, a human changes protected
policy/configuration files manually outside the agent. The bounded exception is
the temporary maintenance approval described below.

## Temporary maintenance approval

For a maintenance window, a human maintainer may manually create
`maintenance-approval.json` from `maintenance-approval.example.json`. Its
entire content is exactly `{ "enabled": true }`. The guard evaluates it on
every tool call; a missing, malformed, or disabled file denies the write. The
approval file itself is permanently protected from agents, so an agent cannot
create, amend, or remove its own approval.

Remove the approval manually when the window closes. A new task is not
required: the guard reloads the switch for each call.

The guard blocks:

- agent edits to its own policy, the Claude/Codex hook registration, the
  database target configuration, and the database wrapper scripts;
- direct `mysql`/`mariadb` shell usage;
- destructive or sensitive ad-hoc SQL passed to the Col DB wrapper.

It does not replace database grants, operating-system permissions, or remote
branch protections. Database operations must continue through the workspace
`scripts\db-analysis.cmd`.
