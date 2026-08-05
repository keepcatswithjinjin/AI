#!/usr/bin/env python3
"""Thin PreToolUse entrypoint: parse the event, route it, emit allow/deny."""

from __future__ import annotations

import json
import sys

# The Hook runs for every tool call; never leave runtime bytecode in governance.
sys.dont_write_bytecode = True

from guards.database_guard import check_database_command, is_database_invocation
from guards.git_guard import check_git_command
from guards.path_guard import check_apply_patch, check_edit_or_write, check_shell_path_mutation
from guards.worktree_guard import check_worktree_script_result_format
from policy_loader import load_policy


def deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))
    raise SystemExit(0)


def allow() -> None:
    raise SystemExit(0)


def deny_if(reason: str | None) -> None:
    if reason:
        deny(reason)


def route_bash(command: str, policy: dict, cwd: str) -> None:
    """Run independent command guards in fail-fast policy order."""
    deny_if(check_worktree_script_result_format(command, policy, cwd))
    deny_if(check_git_command(command, policy, cwd))

    database_reason = check_database_command(command, policy, cwd)
    deny_if(database_reason)
    deny_if(check_shell_path_mutation(
        command,
        policy,
        database_invocation=is_database_invocation(command, policy, cwd),
    ))


def main() -> None:
    try:
        event = json.load(sys.stdin)
    except Exception:
        allow()

    tool_name = str(event.get("tool_name", ""))
    tool_input = event.get("tool_input") or {}
    cwd = str(event.get("cwd", ""))
    if not isinstance(tool_input, dict):
        allow()
    policy = load_policy()

    if tool_name == "apply_patch":
        deny_if(check_apply_patch(tool_input, policy))
    elif tool_name == "Bash":
        command = tool_input.get("command", "")
        if isinstance(command, str):
            route_bash(command, policy, cwd)
    elif tool_name in ("Edit", "Write", "MultiEdit"):
        deny_if(check_edit_or_write(tool_input, policy))


if __name__ == "__main__":
    main()
