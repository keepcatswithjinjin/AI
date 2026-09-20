# Workspace Agent Guard

`pre_tool_guard.py` is a shared Codex and Claude Code `PreToolUse` command hook.
Its source of truth is `policy.json`; governance assets are protected from
agent edits by an in-code baseline. By default, a human changes protected
policy/configuration files manually outside the agent. The bounded exception is
the temporary maintenance approval described below.

## Code structure

`pre_tool_guard.py` contains only event parsing, tool routing, and the final
allow/deny response. Policy behavior is split by domain:

```text
pre_tool_guard.py                 # Hook input -> route -> allow/deny
policy_loader.py                  # Policy, immutable baseline, maintenance approval
guard_utils.py                    # Pure path and command parsing helpers
guards/
  path_guard.py                   # apply_patch / Edit / Write / protected shell mutations
  database_guard.py               # MySQL entrypoint, target/action, SQL restrictions
  git_guard.py                    # destructive Git commands
  worktree_guard.py               # controlled worktree scripts and JSON-result requirement
post_tool_guard.py                # PostToolUse: validates executed worktree lifecycle commands
hook-registry.json                # Single source of truth for Codex Hook matchers/commands
sync-hooks.ps1                    # Renders the registry into the workspace-local Codex config
```

To add a new governed capability, create one focused module under `guards/`
that returns either `None` or a denial reason, then register it in the relevant
tool route in `pre_tool_guard.py`. Do not add domain policy back into the entrypoint.

Do not manually maintain `[[hooks.*]]` entries in any Codex config. Update
`hook-registry.json`, then run `sync-hooks.ps1`; `__WORKSPACE_ROOT__\.codex\config.toml`
is only a generated workspace-local runtime projection. The user-level Codex
config should not bind this workspace's governance hooks.

Claude Code uses the workspace-local `__WORKSPACE_ROOT__\.claude\settings.local.json`.
Do not register this workspace guard in the user-level Claude settings.

After installing the template, add regression tests beside the guard before
introducing a new policy domain. Tests must pass synthetic Hook events and must
not execute candidate Git or database commands.

The directory name remains `agent-guard` to avoid coupling the governance
concept to one Agent runtime. The guard is shared by Codex and Claude Code when
both tools register this hook in their workspace-local configuration:

- Codex: `__WORKSPACE_ROOT__\.codex\config.toml`
- Claude Code: `__WORKSPACE_ROOT__\.claude\settings.local.json`

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

- agent edits to its own policy, the workspace-local Claude/Codex hook
  registration, the workspace database target configuration, and the database
  wrapper scripts;
- direct `mysql`/`mariadb` shell usage;
- destructive or sensitive ad-hoc SQL passed to the workspace DB wrapper.
- direct `git worktree add/remove`; worktree lifecycle must go through the workspace
  scripts so path, branch, confirmation, and workspace state are handled consistently;
- Agent invocations of the worktree create/remove scripts without `-OutputFormat Json`;
  the resulting `workflow-result.v1` is the required machine-readable evidence.
- destructive Git operations including branch deletion, `reset --hard`, forced
  clean, force/delete push, and `git init` in the `__WORKSPACE_ROOT__` root.

The guard intentionally allows non-actions and read-only references:

- reading files whose names contain guarded entrypoints, such as
  `Get-Content __WORKSPACE_ROOT__\scripts\db-analysis.cmd`;
- documentation or patch body text that mentions guarded commands;
- unsupported or malformed hook payloads that cannot be confidently mapped to a
  real tool action.
- read-only Git inspection such as `git status`, `git log`, `git diff`, and
  `git worktree list`.

For an approved database wrapper command, a quoted `-Sql` value is checked by
the SQL policy rather than interpreted as a Shell redirect. Shell mutations
outside that value remain guarded.

It does not replace database grants, operating-system permissions, or remote
branch protections. Database operations must continue through
`__WORKSPACE_ROOT__\scripts\db-analysis.cmd`.

`PostToolUse` is intentionally registered only for Bash and exits immediately for every command except non-preview `new-worktree` and `remove-worktree`. If Codex supplies a malformed PostToolUse payload, it is skipped unless its raw payload appears to contain either lifecycle script; those still fail closed. For lifecycle commands it independently verifies the filesystem and Git worktree registration.

