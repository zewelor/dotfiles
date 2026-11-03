#!/usr/bin/python3
"""Offline regression checks for the temporary Codex workspace."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CodexTmpTests(unittest.TestCase):
    def test_workspace_remains_current_and_preserves_files_and_exit_code(self):
        for exit_code in (0, 23):
            with self.subTest(exit_code=exit_code), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                workspace_root = base / "temporary workspaces"
                workspace_root.mkdir()
                result = subprocess.run(
                    ["/usr/bin/zsh", "-f", "-c", '''
is_desktop() { return 0; }
zpcompdef() { :; }
source "$1/.zsh/shell_llm.zsh"
codex() {
  print -r -- "$PWD" > "$TEST_RECORD"
  printf '%s\\n' "$@" >> "$TEST_RECORD"
  print -r -- 'session output' > artifact.txt
  return "$TEST_EXIT_CODE"
}
cdxtmp 'prompt with spaces' --model fixture
result=$?
printf '%s\\n' "$PWD" "$result"
''', "test", str(ROOT)],
                    cwd=base,
                    env=dict(os.environ, TMPDIR=str(workspace_root),
                             TEST_RECORD=str(base / "record"),
                             TEST_EXIT_CODE=str(exit_code)),
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                cwd, actual_exit_code = result.stdout.splitlines()
                workspace = Path(cwd)
                self.assertEqual(workspace.parent, workspace_root)
                self.assertEqual(actual_exit_code, str(exit_code))
                self.assertEqual((base / "record").read_text().splitlines(), [
                    cwd, 'prompt with spaces', '--model', 'fixture',
                ])
                self.assertEqual((workspace / "artifact.txt").read_text(),
                                 'session output\n')


if __name__ == "__main__":
    unittest.main()
