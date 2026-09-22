"""Destructive Git command checks; worktree-script format lives separately."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from guard_utils import command_segments, normalize, shell_tokens, strip_quotes
from policy_loader import ROOT


def is_git_token(token: str) -> bool:
    return normalize(Path(token.strip("\"'")).name) in {"git", "git.exe"}


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


def check_git_command(command: str, policy: dict[str, Any], cwd: str) -> str | None:
    git_policy = policy.get("git", {}) if isinstance(policy.get("git"), dict) else {}
    segments = command_segments(command)
    has_git_command = False
    for segment in segments:
        tokens = shell_tokens(segment)
        if not tokens or not is_git_token(tokens[0]):
            continue
        has_git_command = True
        lowered_segment = segment.lower()
        if "--no-verify" in lowered_segment or "core.hookspath" in lowered_segment:
            return f"Direct local Git hook bypass is blocked. After human approval, use {ROOT / 'scripts' / 'publish-to-branch.cmd'} with -Mode CompleteConflict -ConfirmConflictCompletion -UseHumanCompletionApproval."
        subcommand, rest, git_cwd = git_command_parts(tokens[1:])
        effective_cwd = normalize(git_cwd or cwd)
        lowered = [item.lower() for item in rest]
        if subcommand == "worktree" and rest:
            action = rest[0].lower()
            if action == "add" and git_policy.get("deny_direct_worktree_add", True):
                return f"Direct git worktree add is blocked. Use {ROOT / 'scripts' / 'new-worktree.cmd'} so path and branch rules are enforced."
            if action == "remove" and git_policy.get("deny_direct_worktree_remove", True):
                return f"Direct git worktree remove is blocked. Use {ROOT / 'scripts' / 'remove-worktree.cmd'} so workspace state is cleaned safely."
        if subcommand == "branch" and git_policy.get("deny_branch_delete", True):
            if any(flag in {"-d", "--delete"} for flag in lowered):
                return "Direct git branch deletion is blocked. Confirm branch cleanup separately."
        if subcommand == "reset" and git_policy.get("deny_reset_hard", True) and "--hard" in lowered:
            return "git reset --hard is blocked by workspace git governance."
        if subcommand == "clean" and git_policy.get("deny_clean_force", True):
            if any(flag.startswith("-") and "f" in flag.lower() for flag in rest) or "--force" in lowered:
                return "git clean with force is blocked by workspace git governance."
        if subcommand == "push" and git_policy.get("deny_force_or_delete_push", True):
            if any(flag in {"-f", "--force", "--force-with-lease", "--delete"} or flag.startswith("--force-with-lease=") for flag in lowered):
                return "Force or delete git push is blocked by workspace git governance."
        if subcommand == "init" and git_policy.get("deny_workspace_root_init", True):
            if effective_cwd == normalize(str(ROOT)):
                return "git init in the workspace root is blocked. The workspace root is a container, not a git repository."
    if has_git_command and "git_config_key_" in command.lower():
        return f"Direct local Git hook bypass is blocked. After human approval, use {ROOT / 'scripts' / 'publish-to-branch.cmd'} with -Mode CompleteConflict -ConfirmConflictCompletion -UseHumanCompletionApproval."
    return None
