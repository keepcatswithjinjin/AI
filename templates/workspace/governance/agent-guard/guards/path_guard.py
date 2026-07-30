"""Protected/high-risk path checks for patch, edit, write, and shell mutation."""

from __future__ import annotations

import re
from typing import Any

from guard_utils import command_without_sql_payload, normalize, patch_paths, matches
from policy_loader import BASELINE_PROTECTED, maintenance_approval_is_active

MUTATING_SHELL_RE = re.compile(
    r"(?i)\b(set-content|add-content|out-file|copy-item|move-item|remove-item|"
    r"rename-item|new-item|apply_patch|git\s+(?:restore|checkout|clean))\b|(?:^|\s)>{1,2}(?:\s|$)"
)


def protected_patterns(policy: dict[str, Any]) -> list[str]:
    return list(BASELINE_PROTECTED) + list(policy.get("protected_paths", []))


def check_path(path: str, policy: dict[str, Any]) -> str | None:
    if matches(path, protected_patterns(policy)) and not maintenance_approval_is_active(path):
        return "Protected governance/configuration path. A valid human-issued maintenance approval is required."
    if matches(path, list(policy.get("high_risk_paths", []))) and not maintenance_approval_is_active(path):
        return "High-risk project path. A valid human-issued maintenance approval is required."
    return None


def check_apply_patch(tool_input: dict[str, Any], policy: dict[str, Any]) -> str | None:
    for key in ("command", "patch", "input", "content"):
        value = tool_input.get(key)
        if isinstance(value, str):
            for path in patch_paths(value):
                reason = check_path(path, policy)
                if reason:
                    return reason
            return None
    return None


def check_edit_or_write(tool_input: dict[str, Any], policy: dict[str, Any]) -> str | None:
    file_path = str(tool_input.get("file_path", ""))
    return check_path(file_path, policy) if file_path else None


def check_shell_path_mutation(command: str, policy: dict[str, Any], database_invocation: bool) -> str | None:
    shell_scan_command = command_without_sql_payload(command) if database_invocation else command
    if not MUTATING_SHELL_RE.search(shell_scan_command):
        return None
    normalized = normalize(command)
    for pattern in protected_patterns(policy) + list(policy.get("high_risk_paths", [])):
        stem = normalize(pattern).replace("/**", "")
        if stem and stem in normalized and not maintenance_approval_is_active(stem):
            return "Shell mutation targets a protected or high-risk path. A valid human-issued maintenance approval is required."
    return None
