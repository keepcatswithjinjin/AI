"""Database entrypoint, read-action, and SQL deny-list checks."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from guard_utils import executable_tokens, is_executing_path, normalize


def is_direct_db_client_invocation(command: str) -> bool:
    for token in executable_tokens(command):
        if normalize(Path(token).name) in {"mysql", "mysql.exe", "mariadb", "mariadb.exe", "psql", "psql.exe"}:
            return True
    return False


def is_database_invocation(command: str, policy: dict[str, Any], cwd: str) -> bool:
    database = policy.get("database", {}) if isinstance(policy.get("database"), dict) else {}
    entrypoints = [str(item) for item in database.get("approved_entrypoints", [])]
    return is_executing_path(command, entrypoints, cwd)


def check_sql(command: str, database: dict[str, Any]) -> str | None:
    if not re.search(r"(?i)(?:-action\s+query|-sql\s+)", command):
        return None
    for word in database.get("blocked_sql_keywords", []):
        if re.search(rf"(?i)\b{re.escape(str(word))}\b", command):
            return f"SQL keyword '{word}' is blocked by the workspace governance policy."
    for name in database.get("sensitive_identifiers", []):
        if re.search(rf"(?i)\b{re.escape(str(name))}\b", command):
            return f"Sensitive identifier '{name}' is blocked from ad-hoc database queries."
    return None


def check_database_command(command: str, policy: dict[str, Any], cwd: str) -> str | None:
    database = policy.get("database", {}) if isinstance(policy.get("database"), dict) else {}
    if database.get("deny_direct_clients", True) and is_direct_db_client_invocation(command):
        return "Direct database-client invocation is blocked. Use the workspace db-analysis.cmd so read-only checks are enforced."
    if is_database_invocation(command, policy, cwd):
        if database.get("deny_config_path_override", True) and re.search(r"(?i)(?<!\S)-configpath\b", command):
            return "Overriding the database target configuration is blocked."
        if not re.search(r"(?i)(?<!\S)-listtargets\b", command):
            target_match = re.search(r"(?i)(?<!\S)-target\s+['\"]?([^\s'\"]+)", command)
            allowed_targets = {str(item).lower() for item in database.get("allowed_targets", [])}
            if not target_match or target_match.group(1).lower() not in allowed_targets:
                return "Database invocation must use an explicitly allowed target."
            action_match = re.search(r"(?i)(?<!\S)-action\s+['\"]?([^\s'\"]+)", command)
            allowed_actions = {str(item).lower() for item in database.get("allowed_read_actions", [])}
            if not action_match or action_match.group(1).lower() not in allowed_actions:
                return "Database invocation must use an explicitly allowed read-only action."
    return check_sql(command, database)
