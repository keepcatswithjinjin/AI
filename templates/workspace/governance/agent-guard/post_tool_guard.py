#!/usr/bin/env python3
"""Fast PostToolUse verifier for completed worktree lifecycle commands only."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from guard_utils import command_segments, is_script_invocation, normalize
from policy_loader import ROOT

ENTRYPOINTS = [
    str(ROOT / "scripts" / "new-worktree.cmd"), str(ROOT / "scripts" / "new-worktree.ps1"),
    str(ROOT / "scripts" / "remove-worktree.cmd"), str(ROOT / "scripts" / "remove-worktree.ps1"),
]
LIFECYCLE_SCRIPT_MARKERS = ("new-worktree.", "remove-worktree.")


def payload_may_contain_lifecycle_script(raw_event: str) -> bool:
    """Fail closed only when an unreadable payload may be a governed action.

    PostToolUse is registered for every Bash command because its matcher cannot
    filter by command arguments. A malformed event for an unrelated command
    must not make this narrow worktree verifier a global failure source.
    """
    lowered = raw_event.lower()
    return any(marker in lowered for marker in LIFECYCLE_SCRIPT_MARKERS)


def value(command: str, name: str) -> str:
    match = re.search(rf"(?i)(?<!\S)-{re.escape(name)}\s+['\"]?([^\s'\"]+)", command)
    return match.group(1) if match else ""


def registry() -> list[tuple[str, str, str]]:
    rows = []
    for line in (ROOT / "rules" / "worktree.md").read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|.*\|\s*`([^`]+)`\s*\|", line)
        if match:
            rows.append((match.group(1), match.group(2), match.group(3)))
    return rows


def worktrees(repo: str) -> str:
    return subprocess.run(["git", "-C", repo, "worktree", "list", "--porcelain"], text=True, capture_output=True, check=False).stdout


def verify_create(command: str) -> str | None:
    key, name = value(command, "ProjectKey"), value(command, "Name")
    kind = value(command, "Type") or "feature"
    item = next((row for row in registry() if row[0] == key), None)
    if not item or not name:
        return "Post-worktree verification could not parse the registered project or worktree name."
    _, repo, parent = item
    path = str(Path(parent) / name)
    branch = f"refs/heads/{kind}/{name}"
    listing = worktrees(repo)
    if not Path(path).is_dir() or f"worktree {path}" not in listing or f"branch {branch}" not in listing:
        return f"Worktree creation post-check failed: expected path/branch is absent ({path}, {branch})."
    return None


def verify_remove(command: str) -> str | None:
    path = value(command, "WorktreePath")
    if not path:
        return "Post-worktree verification could not parse -WorktreePath."
    item = next((row for row in registry() if normalize(path).startswith(normalize(row[2]) + "/")), None)
    if not item:
        return f"Post-worktree verification could not resolve the registered parent for {path}."
    if Path(path).exists() or f"worktree {path}" in worktrees(item[1]):
        return f"Worktree removal post-check failed: path or Git registration remains ({path})."
    return None


def verify(command: str, cwd: str) -> str | None:
    if re.search(r"(?i)(?<!\S)-preview\b", command):
        return None
    for segment in command_segments(command):
        if not is_script_invocation(segment, ENTRYPOINTS, cwd):
            continue
        if re.search(r"(?i)new-worktree\.(?:cmd|ps1)", segment):
            return verify_create(segment)
        if re.search(r"(?i)remove-worktree\.(?:cmd|ps1)", segment):
            return verify_remove(segment)
    return None


def main() -> int:
    raw_event = sys.stdin.read()
    try:
        event = json.loads(raw_event)
    except json.JSONDecodeError as exc:
        if payload_may_contain_lifecycle_script(raw_event):
            print(f"Post-worktree verifier failed closed: malformed lifecycle payload ({exc})", file=sys.stderr)
            return 1
        return 0

    if not isinstance(event, dict):
        return 0
    tool_input = event.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return 0

    try:
        command = str(tool_input.get("command") or "")
        reason = verify(command, str(event.get("cwd") or ""))
    except Exception as exc:
        print(f"Post-worktree verifier failed closed: {exc}", file=sys.stderr)
        return 1
    if reason:
        print(reason, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

