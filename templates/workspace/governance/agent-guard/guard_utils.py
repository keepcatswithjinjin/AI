"""Pure parsing and path helpers shared by guard modules."""

from __future__ import annotations

import fnmatch
import re
from pathlib import Path

PATCH_FILE_RE = re.compile(r"^\*\*\* (?:Update|Add|Delete) File: (.+)$", re.MULTILINE)
SHELL_SPLIT_RE = re.compile(r"\s*(?:&&|\|\||[;&|])\s*")


def normalize(value: str) -> str:
    return value.strip().strip("\"'").replace("\\", "/").lower()


def matches(path: str, patterns: list[str]) -> bool:
    candidate = normalize(path)
    return any(fnmatch.fnmatchcase(candidate, normalize(pattern)) for pattern in patterns)


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


def strip_quotes(value: str) -> str:
    return value.strip().strip("\"'")


def token_matches_path(token: str, path_patterns: list[str], cwd: str) -> bool:
    candidate = normalize(strip_quotes(token))
    if matches(candidate, path_patterns):
        return True
    if cwd and not re.match(r"(?i)^[a-z]:/", candidate) and not candidate.startswith("/"):
        return matches(str(Path(cwd) / strip_quotes(token)), path_patterns)
    return False


def is_script_invocation(segment: str, path_patterns: list[str], cwd: str) -> bool:
    """Recognize direct, PowerShell -File, and cmd /c script execution."""
    if is_executing_path(segment, path_patterns, cwd):
        return True
    tokens = shell_tokens(segment)
    if not tokens:
        return False
    first = normalize(Path(strip_quotes(tokens[0])).name)
    if first in {"powershell", "powershell.exe", "pwsh", "pwsh.exe"}:
        for index, token in enumerate(tokens[:-1]):
            if strip_quotes(token).lower() in {"-file", "-f"}:
                return token_matches_path(tokens[index + 1], path_patterns, cwd)
    if first in {"cmd", "cmd.exe"}:
        for index, token in enumerate(tokens[:-1]):
            if strip_quotes(token).lower() == "/c":
                return token_matches_path(tokens[index + 1], path_patterns, cwd)
    return False


def command_without_sql_payload(command: str) -> str:
    """Mask a quoted PowerShell -Sql argument before scanning shell mutations."""
    match = re.search(r"(?i)(?<!\S)-sql\s+(['\"])", command)
    if not match:
        return command
    quote = match.group(1)
    index = match.end()
    while index < len(command):
        char = command[index]
        if quote == '"' and char == "`" and index + 1 < len(command):
            index += 2
            continue
        if char == quote:
            if quote == "'" and index + 1 < len(command) and command[index + 1] == "'":
                index += 2
                continue
            return command[:match.end()] + "<SQL>" + command[index:]
        index += 1
    return command
