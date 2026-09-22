"""Load immutable-baseline governance policy and human maintenance approval."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from guard_utils import matches

ROOT = Path(r"__WORKSPACE_ROOT__")
POLICY_PATH = ROOT / "governance" / "agent-guard" / "policy.json"
MAINTENANCE_APPROVAL_PATH = ROOT / "governance" / "agent-guard" / "maintenance-approval.json"
LOCAL_GIT_HOOK_BYPASS_APPROVAL_PATH = ROOT / "governance" / "agent-guard" / "local-git-hook-bypass-approval.json"


def root_pattern(*parts: str) -> str:
    return ROOT.joinpath(*parts).as_posix().lower()


BASELINE_PROTECTED = [
    root_pattern("governance", "agent-guard", "**"),
    root_pattern("scripts", "db-targets.json"),
    root_pattern("scripts", "db-analysis.cmd"),
    root_pattern("scripts", "db-analysis.ps1"),
    root_pattern("scripts", "publish-to-branch.cmd"),
    root_pattern("scripts", "publish-to-branch.ps1"),
    root_pattern(".codex", "config.toml"),
    root_pattern(".claude", "settings.local.json"),
    root_pattern("governance", "agent-guard", "maintenance-approval.json"),
    root_pattern("governance", "agent-guard", "local-git-hook-bypass-approval.json"),
]


def load_policy() -> dict[str, Any]:
    """Fail closed to the in-code baseline if policy cannot be read."""
    try:
        data = json.loads(POLICY_PATH.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("policy root must be an object")
        return data
    except Exception:
        return {"protected_paths": BASELINE_PROTECTED, "high_risk_paths": [], "database": {}}


def load_maintenance_approval() -> bool:
    """Accept only the exact, human-controlled {"enabled": true} switch."""
    try:
        data = json.loads(MAINTENANCE_APPROVAL_PATH.read_text(encoding="utf-8"))
        return isinstance(data, dict) and set(data) == {"enabled"} and data["enabled"] is True
    except (OSError, json.JSONDecodeError):
        return False


def maintenance_approval_is_active(path: str) -> bool:
    """The approval file itself remains immutable during a maintenance window."""
    if matches(path, [str(MAINTENANCE_APPROVAL_PATH), str(LOCAL_GIT_HOOK_BYPASS_APPROVAL_PATH)]):
        return False
    return load_maintenance_approval()

