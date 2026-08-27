"""Regression tests for PostToolUse malformed-payload routing."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

GUARD_ROOT = Path(__file__).resolve().parents[1]


def run_post_hook(raw_event: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(GUARD_ROOT / "post_tool_guard.py")],
        input=raw_event,
        text=True,
        capture_output=True,
        check=False,
    )


class PostToolGuardTests(unittest.TestCase):
    def test_skips_malformed_unrelated_payload(self) -> None:
        completed = run_post_hook('{"tool_name":"Bash","tool_input":{"command":"Get-Date"}')
        self.assertEqual(0, completed.returncode, completed.stderr)

    def test_fails_closed_for_malformed_lifecycle_payload(self) -> None:
        completed = run_post_hook('{"tool_name":"Bash","command":"new-worktree.cmd"')
        self.assertEqual(1, completed.returncode)
        self.assertIn("malformed lifecycle payload", completed.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
