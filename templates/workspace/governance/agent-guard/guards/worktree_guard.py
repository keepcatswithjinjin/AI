"""Worktree lifecycle entrypoint checks, independent of Git syntax checks."""

from __future__ import annotations

import re
from typing import Any

from guard_utils import command_segments, is_script_invocation


def check_worktree_script_result_format(command: str, policy: dict[str, Any], cwd: str) -> str | None:
    git_policy = policy.get("git", {}) if isinstance(policy.get("git"), dict) else {}
    entrypoints = [str(item) for item in git_policy.get("json_result_entrypoints", [])]
    for segment in command_segments(command):
        if not entrypoints or not is_script_invocation(segment, entrypoints, cwd):
            continue
        has_json = re.search(r"(?i)(?<!\S)-outputformat(?:\s+|:)['\"]?json['\"]?(?=\s|$)", segment)
        if not has_json:
            return "Worktree lifecycle scripts must include -OutputFormat Json when invoked by an Agent. The workflow-result.v1 response is required for downstream verification."
    return None
