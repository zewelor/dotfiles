"""Exercise setup_user_systemd_units in isolated environments."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallUserUnitsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.home = root / "home"
        self.repo = root / "repo"
        self.home.mkdir()
        self.config = self.home / ".config"
        self.config.mkdir()
        (self.repo / ".zsh").mkdir(parents=True)
        shutil.copy(ROOT / ".zsh/helpers.zsh", self.repo / ".zsh/helpers.zsh")
        self.calls = root / "calls"
        self.env = {**os.environ, "HOME": str(self.home), "CALLS": str(self.calls)}
        self.script = (ROOT / "install").read_text().rsplit("\nrun_installation", 1)[0]

    def make_runner(self, has_docker=True):
        docker_ret = "0" if has_docker else "1"
        overrides = f'''
has() {{
  if [[ "$1" == "systemctl" ]]; then return 0; fi
  if [[ "$1" == "/usr/bin/docker" ]]; then return {docker_ret}; fi
  return 1
}}
systemctl() {{
  echo "systemctl $*" >> "$CALLS"
  if [[ "$*" == *"--user show-environment"* ]]; then return 0; fi
  return 0
}}
print_banner() {{ :; }}
"$@"
'''
        runner = self.repo / "test-install"
        runner.write_text(self.script + "\n" + overrides)
        return runner

    def run_units(self, has_docker=True):
        runner = self.make_runner(has_docker)
        return subprocess.run(["zsh", str(runner), "setup_user_systemd_units"],
                              env=self.env, text=True, capture_output=True, timeout=10)

    def test_docker_prune_timer_enabled_when_present_and_docker_available(self):
        unit_dir = self.config / "systemd/user"
        unit_dir.mkdir(parents=True)
        (unit_dir / "docker-prune.timer").write_text("[Timer]\n")
        result = self.run_units(has_docker=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls.read_text().splitlines()
        self.assertIn("systemctl --user enable --now docker-prune.timer", calls)

    def test_docker_prune_timer_skipped_when_docker_missing(self):
        unit_dir = self.config / "systemd/user"
        unit_dir.mkdir(parents=True)
        (unit_dir / "docker-prune.timer").write_text("[Timer]\n")
        result = self.run_units(has_docker=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        if self.calls.exists():
            calls = self.calls.read_text().splitlines()
            self.assertNotIn("systemctl --user enable --now docker-prune.timer", calls)

    def test_docker_prune_timer_skipped_when_unit_missing(self):
        result = self.run_units(has_docker=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        if self.calls.exists():
            calls = self.calls.read_text().splitlines()
            self.assertNotIn("systemctl --user enable --now docker-prune.timer", calls)


if __name__ == "__main__":
    unittest.main()
