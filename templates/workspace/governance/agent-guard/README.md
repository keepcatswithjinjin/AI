# Agent Guard

`pre_tool_guard.py` is a shared Codex and Claude Code `PreToolUse` command hook.
Its source of truth is `policy.json`; governance assets are protected from
agent edits by an in-code baseline. By default, a human changes protected
policy/configuration files manually outside the agent. The bounded exception is
the temporary maintenance approval described below.

The directory is named `agent-guard` because the same guard can be registered by
Codex and Claude Code. The hook path is installed under the generated workspace,
not under this framework repository.

## Temporary maintenance approval

For a maintenance window, a human maintainer may manually create
`maintenance-approval.json` from `maintenance-approval.example.json`. Its entire
content is exactly `{ "enabled": true }`. The guard evaluates it on every tool
call; a missing, malformed, or disabled file denies protected writes. The
approval file itself is permanently protected from agents, so an agent cannot
create, amend, or remove its own approval.

Remove the approval manually when the window closes. A new task is not required:
the guard reloads the switch for each call.

The guard blocks:

- agent edits to its own policy, hook registration-sensitive files, database target configuration, and database wrapper scripts;
- direct `mysql`/`mariadb` shell usage;
- destructive or sensitive ad-hoc SQL passed to the workspace DB wrapper;
- direct `git worktree add/remove`; worktree lifecycle must go through the workspace scripts so Serena and workspace state are handled consistently;
- destructive Git operations including branch deletion, `reset --hard`, forced clean, force/delete push, and `git init` in the workspace root.

The guard intentionally allows non-actions and read-only references:

- reading files whose names contain guarded entrypoints, such as `Get-Content <workspace>\scripts\db-analysis.cmd`;
- documentation or patch body text that mentions guarded commands;
- unsupported or malformed hook payloads that cannot be confidently mapped to a real tool action;
- read-only Git inspection such as `git status`, `git log`, `git diff`, and `git worktree list`.

For an approved database wrapper command, a quoted `-Sql` value is checked by
the SQL policy rather than interpreted as a shell redirect. Shell mutations
outside that value remain guarded.

It does not replace database grants, operating-system permissions, or remote
branch protections. Database operations must continue through the installed
workspace `scripts\db-analysis.cmd` entrypoint.