#!/usr/bin/env python3
"""PreToolUse guard for a multi-project workspace.

The policy file is deliberately protected from agent edits. A human may change
it outside the agent; the next tool call reloads the policy. Invalid or missing
policy fails closed for the guard's own assets and database configuration.
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
BASELINE_PROTECTED = [
    "__WORKSPACE_ROOT__/governance/agent-guard/**",
    "__WORKSPACE_ROOT__/scripts/db-targets.json",
    "__WORKSPACE_ROOT__/scripts/db-analysis.cmd",
    "__WORKSPACE_ROOT__/scripts/db-analysis.ps1",
]
PATCH_FILE_RE = re.compile(r"^\*\*\* (?:Update|Add|Delete) File: (.+)$", re.MULTILINE)
MUTATING_SHELL_RE = re.compile(
    r"(?i)\b(set-content|add-content|out-file|copy-item|move-item|remove-item|"
    r"rename-item|new-item|apply_patch|git\s+(?:restore|checkout|clean))\b|(?:^|\s)>{1,2}(?:\s|$)"
)
DIRECT_DB_CLIENT_RE = re.compile(r"(?i)(?:^|[\s;&|])(?:[\w./:\\-]*\\)?(?:mysql|mariadb)(?:\.exe)?(?:\s|$)")


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


def matches(path: str, patterns: list[str]) -> bool:
    candidate = normalize(path)
    return any(fnmatch.fnmatchcase(candidate, normalize(pattern)) for pattern in patterns)


def deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))
    raise SystemExit(0)


def patch_paths(command: str) -> list[str]:
    return [match.group(1).strip() for match in PATCH_FILE_RE.finditer(command)]


def contains_blocked_sql(command: str, database: dict[str, Any]) -> str | None:
    if not re.search(r"(?i)(?:-action\s+query|-sql\s+)", command):
        return None
    for word in database.get("blocked_sql_keywords", []):
        if re.search(rf"(?i)\b{re.escape(str(word))}\b", command):
            return f"SQL keyword '{word}' is blocked by the Col governance policy."
    for name in database.get("sensitive_identifiers", []):
        if re.search(rf"(?i)\b{re.escape(str(name))}\b", command):
            return f"Sensitive identifier '{name}' is blocked from ad-hoc database queries."
    return None


def guard_apply_patch(command: str, policy: dict[str, Any]) -> None:
    protected = list(BASELINE_PROTECTED) + list(policy.get("protected_paths", []))
    high_risk = list(policy.get("high_risk_paths", []))
    for path in patch_paths(command):
        if matches(path, protected):
            deny("Protected governance/configuration path. Edit the policy or configuration manually outside Codex, then start a new task.")
        if matches(path, high_risk):
            deny("High-risk project path. This global guard requires a manual policy change before an agent may edit it.")


def uses_approved_entrypoint(command: str, database: dict[str, Any], cwd: str) -> bool:
    approved = [normalize(str(item)) for item in database.get("approved_entrypoints", [])]
    if not approved:
        return False
    normalized_command = normalize(command)
    for entrypoint in approved:
        if entrypoint in normalized_command:
            return True
        if cwd:
            try:
                relative = normalize(os.path.relpath(entrypoint, cwd))
            except ValueError:
                continue
            if relative and relative in normalized_command:
                return True
    return False


def guard_bash(command: str, policy: dict[str, Any], cwd: str) -> None:
    protected = list(BASELINE_PROTECTED) + list(policy.get("protected_paths", []))
    high_risk = list(policy.get("high_risk_paths", []))
    normalized = normalize(command)
    if MUTATING_SHELL_RE.search(command):
        for pattern in protected + high_risk:
            stem = normalize(pattern).replace("/**", "")
            if stem and stem in normalized:
                deny("Shell mutation targets a protected or high-risk path. Change the governing policy manually outside Codex first.")

    database = policy.get("database", {}) if isinstance(policy.get("database"), dict) else {}
    if database.get("deny_direct_clients", True) and DIRECT_DB_CLIENT_RE.search(command):
        deny("Direct mysql/mariadb invocation is blocked. Use D:\\Col\\scripts\\db-analysis.cmd so read-only checks are enforced.")
    if re.search(r"(?i)db-analysis\.(?:cmd|ps1)\b", command):
        if not uses_approved_entrypoint(command, database, cwd):
            deny("Database invocation must use a Col-approved db-analysis entrypoint.")
        if database.get("deny_config_path_override", True) and re.search(r"(?i)(?<!\S)-configpath\b", command):
            deny("Overriding the database target configuration is blocked.")
        target_match = re.search(r"(?i)(?<!\S)-target\s+['\"]?([^\s'\"]+)", command)
        allowed_targets = {str(item).lower() for item in database.get("allowed_targets", [])}
        if not target_match or target_match.group(1).lower() not in allowed_targets:
            deny("Database invocation must use an explicitly allowed target.")
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
        deny("Protected governance/configuration path. Edit the policy or configuration manually outside Codex, then start a new task.")
    if matches(file_path, high_risk):
            deny("High-risk project path. This global guard requires a manual policy change before an agent may edit it.")


def main() -> None:
    try:
        event = json.load(sys.stdin)
    except Exception:
        deny("Malformed PreToolUse payload; failing closed.")
    tool_name = str(event.get("tool_name", ""))
    tool_input = event.get("tool_input") or {}
    cwd = str(event.get("cwd", ""))
    if not isinstance(tool_input, dict):
        deny("Unsupported tool input shape; failing closed.")
    policy = load_policy()

    if tool_name == "apply_patch":
        command = tool_input.get("command", "")
        if not isinstance(command, str):
            deny("Unsupported tool input shape; failing closed.")
        guard_apply_patch(command, policy)
    elif tool_name == "Bash":
        command = tool_input.get("command", "")
        if not isinstance(command, str):
            deny("Unsupported tool input shape; failing closed.")
        guard_bash(command, policy, cwd)
    elif tool_name in ("Edit", "Write"):
        guard_edit_or_write(tool_input, policy)


if __name__ == "__main__":
    main()
