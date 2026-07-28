#!/usr/bin/env python3
"""Shared PreToolUse guard for a multi-project workspace.

Governance assets are protected by default. A human may temporarily authorize
maintenance using ``maintenance-approval.json``. The approval is read-only to
agents and fails closed when missing or malformed.
"""

from __future__ import annotations

import fnmatch
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(r"__WORKSPACE_ROOT__")
POLICY_PATH = ROOT / "governance" / "agent-guard" / "policy.json"
MAINTENANCE_APPROVAL_PATH = ROOT / "governance" / "agent-guard" / "maintenance-approval.json"
BASELINE_PROTECTED = [
    "__WORKSPACE_ROOT__/governance/agent-guard/**",
    "__WORKSPACE_ROOT__/scripts/db-targets.json",
    "__WORKSPACE_ROOT__/scripts/db-analysis.cmd",
    "__WORKSPACE_ROOT__/scripts/db-analysis.ps1",
    "__WORKSPACE_ROOT__/governance/agent-guard/maintenance-approval.json",
]
PATCH_FILE_RE = re.compile(r"^\*\*\* (?:Update|Add|Delete) File: (.+)$", re.MULTILINE)
MUTATING_SHELL_RE = re.compile(
    r"(?i)\b(set-content|add-content|out-file|copy-item|move-item|remove-item|"
    r"rename-item|new-item|apply_patch|git\s+(?:restore|checkout|clean))\b|(?:^|\s)>{1,2}(?:\s|$)"
)
DIRECT_DB_CLIENT_RE = re.compile(r"(?i)(?:^|[\s;&|])(?:[\w./:\\-]*\\)?(?:mysql|mariadb)(?:\.exe)?(?:\s|$)")
SHELL_SPLIT_RE = re.compile(r"\s*(?:&&|\|\||[;&|])\s*")


def normalize(value: str) -> str:
    return value.strip().strip('"\'').replace("\\", "/").lower()


def load_policy() -> dict[str, Any]:
    try:
        data = json.loads(POLICY_PATH.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("policy root must be an object")
        return data
    except Exception:
        return {"protected_paths": BASELINE_PROTECTED, "high_risk_paths": [], "database": {}}


def load_maintenance_approval() -> bool:
    """Load the single human-controlled maintenance switch, failing closed."""
    try:
        data = json.loads(MAINTENANCE_APPROVAL_PATH.read_text(encoding="utf-8"))
        return isinstance(data, dict) and set(data) == {"enabled"} and data["enabled"] is True
    except (OSError, json.JSONDecodeError):
        return False


def matches(path: str, patterns: list[str]) -> bool:
    candidate = normalize(path)
    return any(fnmatch.fnmatchcase(candidate, normalize(pattern)) for pattern in patterns)


def maintenance_approval_is_active(path: str) -> bool:
    """The approval file itself remains immutable even while maintenance is on."""
    if matches(path, [str(MAINTENANCE_APPROVAL_PATH)]):
        return False
    return load_maintenance_approval()


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


def patch_paths(command: str) -> list[str]:
    return [match.group(1).strip() for match in PATCH_FILE_RE.finditer(command)]


def first_command_token(segment: str) -> str:
    text = segment.strip()
    if not text:
        return ""
    if text.startswith("&"):
        text = text[1:].strip()
    if text.startswith(("'", '"')):
        quote = text[0]
        end = text.find(quote, 1)
        if end != -1:
            return text[1:end]
    return text.split()[0] if text.split() else ""


def shell_tokens(segment: str) -> list[str]:
    return re.findall(r'"[^"]*"|\'[^\']*\'|\S+', segment.strip())


def command_segments(command: str) -> list[str]:
    return [part for part in SHELL_SPLIT_RE.split(command) if part.strip()]


def executable_tokens(command: str) -> list[str]:
    return [first_command_token(segment) for segment in command_segments(command)]


def is_executing_path(command: str, path_patterns: list[str], cwd: str = "") -> bool:
    for token in executable_tokens(command):
        normalized = normalize(token)
        if matches(normalized, path_patterns):
            return True
        if cwd and not re.match(r"(?i)^[a-z]:/", normalized) and not normalized.startswith("/"):
            candidate = normalize(str(Path(cwd) / token.strip("\"'")))
            if matches(candidate, path_patterns):
                return True
    return False


def is_direct_db_client_invocation(command: str) -> bool:
    for token in executable_tokens(command):
        name = normalize(Path(token).name)
        if name in {"mysql", "mysql.exe", "mariadb", "mariadb.exe"}:
            return True
    return False


def is_git_token(token: str) -> bool:
    name = normalize(Path(token.strip("\"'")).name)
    return name in {"git", "git.exe"}


def git_invocations(command: str) -> list[tuple[list[str], str]]:
    invocations: list[tuple[list[str], str]] = []
    for segment in command_segments(command):
        tokens = shell_tokens(segment)
        if tokens and is_git_token(tokens[0]):
            invocations.append((tokens[1:], segment))
    return invocations


def strip_quotes(value: str) -> str:
    return value.strip().strip("\"'")


def git_command_parts(args: list[str]) -> tuple[str, list[str], str]:
    index = 0
    git_cwd = ""
    while index < len(args):
        token = strip_quotes(args[index])
        lower = token.lower()
        if token == "-c" and index + 1 < len(args):
            index += 2
            continue
        if token == "-C" and index + 1 < len(args):
            git_cwd = strip_quotes(args[index + 1])
            index += 2
            continue
        if lower in {"--git-dir", "--work-tree", "--namespace"} and index + 1 < len(args):
            index += 2
            continue
        if lower.startswith("--git-dir=") or lower.startswith("--work-tree="):
            index += 1
            continue
        if lower in {"--no-pager", "--bare"}:
            index += 1
            continue
        break
    if index >= len(args):
        return "", [], git_cwd
    return strip_quotes(args[index]).lower(), [strip_quotes(item) for item in args[index + 1:]], git_cwd


def contains_blocked_sql(command: str, database: dict[str, Any]) -> str | None:
    if not re.search(r"(?i)(?:-action\s+query|-sql\s+)", command):
        return None
    for word in database.get("blocked_sql_keywords", []):
        if re.search(rf"(?i)\b{re.escape(str(word))}\b", command):
            return f"SQL keyword '{word}' is blocked by the workspace governance policy."
    for name in database.get("sensitive_identifiers", []):
        if re.search(rf"(?i)\b{re.escape(str(name))}\b", command):
            return f"Sensitive identifier '{name}' is blocked from ad-hoc database queries."
    return None


def guard_git(command: str, policy: dict[str, Any], cwd: str) -> None:
    git_policy = policy.get("git", {}) if isinstance(policy.get("git"), dict) else {}
    if not git_policy:
        return
    for args, _segment in git_invocations(command):
        subcommand, rest, git_cwd = git_command_parts(args)
        effective_cwd = normalize(git_cwd or cwd)
        lowered = [item.lower() for item in rest]
        if subcommand == "worktree" and rest:
            action = rest[0].lower()
            if action == "add" and git_policy.get("deny_direct_worktree_add", True):
                deny("Direct git worktree add is blocked. Use the workspace new-worktree.cmd so path, branch, and Serena rules are enforced.")
            if action == "remove" and git_policy.get("deny_direct_worktree_remove", True):
                deny("Direct git worktree remove is blocked. Use the workspace remove-worktree.cmd so workspace-state and Serena indexes are cleaned safely.")
        if subcommand == "branch" and git_policy.get("deny_branch_delete", True):
            if any(flag in {"-d", "-D".lower(), "--delete"} for flag in lowered):
                deny("Direct git branch deletion is blocked. Confirm branch cleanup separately.")
        if subcommand == "reset" and git_policy.get("deny_reset_hard", True):
            if "--hard" in lowered:
                deny("git reset --hard is blocked by workspace git governance.")
        if subcommand == "clean" and git_policy.get("deny_clean_force", True):
            if any(flag.startswith("-") and "f" in flag.lower() for flag in rest) or "--force" in lowered:
                deny("git clean with force is blocked by workspace git governance.")
        if subcommand == "push" and git_policy.get("deny_force_or_delete_push", True):
            if any(flag in {"-f", "--force", "--force-with-lease", "--delete"} or flag.startswith("--force-with-lease=") for flag in lowered):
                deny("Force or delete git push is blocked by workspace git governance.")
        if subcommand == "init" and git_policy.get("deny_workspace_root_init", True):
            if effective_cwd == normalize(str(ROOT)):
                deny("git init in the workspace root is blocked. The workspace root is a container, not a git repository.")


def guard_apply_patch(command: str, policy: dict[str, Any]) -> None:
    protected = list(BASELINE_PROTECTED) + list(policy.get("protected_paths", []))
    high_risk = list(policy.get("high_risk_paths", []))
    for path in patch_paths(command):
        if matches(path, protected):
            if not maintenance_approval_is_active(path):
                deny("Protected governance/configuration path. A valid human-issued maintenance approval is required.")
        if matches(path, high_risk):
            if not maintenance_approval_is_active(path):
                deny("High-risk project path. A valid human-issued maintenance approval is required.")


def uses_approved_entrypoint(command: str, database: dict[str, Any], cwd: str) -> bool:
    approved = [str(item) for item in database.get("approved_entrypoints", [])]
    if not approved:
        return False
    return is_executing_path(command, approved, cwd)


def command_without_sql_payload(command: str) -> str:
    """Mask a quoted PowerShell -Sql value before checking shell mutations.

    The SQL is validated separately. Keeping its comparison operators out of
    the shell scan avoids treating SQL `> 0` as PowerShell redirection.
    """
    match = re.search(r"(?i)(?<!\S)-sql\s+(['\"])", command)
    if not match:
        return command
    quote = match.group(1)
    index = match.end()
    while index < len(command):
        char = command[index]
        if quote == '"' and char == '`' and index + 1 < len(command):
            index += 2
            continue
        if char == quote:
            if quote == "'" and index + 1 < len(command) and command[index + 1] == "'":
                index += 2
                continue
            return command[:match.end()] + "<SQL>" + command[index:]
        index += 1
    return command


def guard_bash(command: str, policy: dict[str, Any], cwd: str) -> None:
    protected = list(BASELINE_PROTECTED) + list(policy.get("protected_paths", []))
    high_risk = list(policy.get("high_risk_paths", []))
    normalized = normalize(command)

    guard_git(command, policy, cwd)

    database = policy.get("database", {}) if isinstance(policy.get("database"), dict) else {}
    if database.get("deny_direct_clients", True) and is_direct_db_client_invocation(command):
        deny("Direct mysql/mariadb invocation is blocked. Use D:\\Col\\scripts\\db-analysis.cmd so read-only checks are enforced.")
    approved_entrypoints = [str(item) for item in database.get("approved_entrypoints", [])]
    is_database_invocation = is_executing_path(command, approved_entrypoints, cwd)
    if is_database_invocation:
        if not uses_approved_entrypoint(command, database, cwd):
            deny("Database invocation must use a workspace-approved db-analysis entrypoint.")
        if database.get("deny_config_path_override", True) and re.search(r"(?i)(?<!\S)-configpath\b", command):
            deny("Overriding the database target configuration is blocked.")
        if not re.search(r"(?i)(?<!\S)-listtargets\b", command):
            target_match = re.search(r"(?i)(?<!\S)-target\s+['\"]?([^\s'\"]+)", command)
            allowed_targets = {str(item).lower() for item in database.get("allowed_targets", [])}
            if not target_match or target_match.group(1).lower() not in allowed_targets:
                deny("Database invocation must use an explicitly allowed target.")
            action_match = re.search(r"(?i)(?<!\S)-action\s+['\"]?([^\s'\"]+)", command)
            allowed_actions = {str(item).lower() for item in database.get("allowed_read_actions", [])}
            if not action_match or action_match.group(1).lower() not in allowed_actions:
                deny("Database invocation must use an explicitly allowed read-only action.")
    shell_scan_command = command_without_sql_payload(command) if is_database_invocation else command
    if MUTATING_SHELL_RE.search(shell_scan_command):
        for pattern in protected + high_risk:
            stem = normalize(pattern).replace("/**", "")
            if stem and stem in normalized and not maintenance_approval_is_active(stem):
                deny("Shell mutation targets a protected or high-risk path. A valid human-issued maintenance approval is required.")
    sql_reason = contains_blocked_sql(command, database)
    if sql_reason:
        deny(sql_reason)


def guard_edit_or_write(tool_input: dict, policy: dict[str, Any]) -> None:
    """Guard Edit/Write tools by checking the target file_path."""
    file_path = str(tool_input.get("file_path", "") if isinstance(tool_input, dict) else "")
    if not file_path:
        return
    protected = list(BASELINE_PROTECTED) + list(policy.get("protected_paths", []))
    high_risk = list(policy.get("high_risk_paths", []))
    if matches(file_path, protected):
        if not maintenance_approval_is_active(file_path):
            deny("Protected governance/configuration path. A valid human-issued maintenance approval is required.")
    if matches(file_path, high_risk):
        if not maintenance_approval_is_active(file_path):
            deny("High-risk project path. A valid human-issued maintenance approval is required.")


def extract_patch_text(tool_input: dict) -> str:
    for key in ("command", "patch", "input", "content"):
        value = tool_input.get(key)
        if isinstance(value, str):
            return value
    return ""


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
        command = extract_patch_text(tool_input)
        if not command:
            allow()
        guard_apply_patch(command, policy)
    elif tool_name == "Bash":
        command = tool_input.get("command", "")
        if not isinstance(command, str):
            allow()
        guard_bash(command, policy, cwd)
    elif tool_name in ("Edit", "Write"):
        guard_edit_or_write(tool_input, policy)


if __name__ == "__main__":
    main()
