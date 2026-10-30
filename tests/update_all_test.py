#!/usr/bin/python3
"""Offline regression checks for update-all's user command runner."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class UpdateAllTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "user's home"
        self.home.mkdir()
        self.caller = self.base / "caller"
        self.caller.mkdir()
        # Load only the production runner; never source shell startup or run updates.
        self.runner = re.search(
            r"^  run_for_target_user \(\) \{\n.*?^  \}",
            (ROOT / ".zshrc").read_text(), re.MULTILINE | re.DOTALL,
        ).group()

    def run_command(self, command):
        return subprocess.run(
            ["/usr/bin/zsh", "-f", "-c", '''
target_user=fixture
target_home="$TEST_TARGET_HOME"
user_tool_env_path=/usr/bin:/bin
target_mise_config_dir="$target_home/dotfiles/.config/mise"
# Replace only the privilege boundary, preserving the caller's working directory.
sudo() {
  [[ "$1" == -H && "$2" == -u && "$3" == fixture ]] || return 90
  shift 3
  HOME="$target_home" "$@"
}
''' + self.runner + '\nrun_for_target_user "$1"', "test", command],
            cwd=self.caller,
            env=dict(os.environ, TEST_TARGET_HOME=str(self.home)),
            text=True, capture_output=True,
        )

    def test_command_runs_from_target_home_with_target_environment(self):
        result = self.run_command(
            'printf "%s\\n" "$PWD" "$HOME" "$MISE_CONFIG_DIR"'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            str(self.home), str(self.home),
            str(self.home / "dotfiles/.config/mise"),
        ])

    def test_missing_home_prevents_command_execution(self):
        self.home = self.base / "missing home"
        result = self.run_command('printf "command executed\\n"')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_command_failure_is_preserved(self):
        result = self.run_command("exit 23")
        self.assertEqual(result.returncode, 23, result.stderr)


if __name__ == "__main__":
    unittest.main()
