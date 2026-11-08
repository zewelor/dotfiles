"""Exercise Atuin setup with isolated repository and home directories."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AtuinSetupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-atuin-")
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.repo = root / "repo"
        self.home = root / "home"
        (self.repo / ".zsh").mkdir(parents=True)
        shutil.copy(ROOT / ".zsh/helpers.zsh", self.repo / ".zsh/helpers.zsh")
        self.seed = self.repo / ".config/atuin/config.toml"
        self.seed.parent.mkdir(parents=True)
        self.seed.write_text("managed\n")
        self.target = self.home / ".config/atuin/config.toml"
        script = (ROOT / "install").read_text().rsplit("\nrun_installation", 1)[0]
        (self.repo / "install").write_text(script + "\nsetup_atuin\n")

    def run_setup(self):
        return subprocess.run(
            ["zsh", str(self.repo / "install")],
            env={**os.environ, "HOME": str(self.home)},
            capture_output=True, text=True, timeout=10,
        )

    def test_creates_managed_link_and_is_idempotent(self):
        for _ in range(2):
            result = self.run_setup()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(self.target.is_symlink())
            self.assertEqual(self.target.resolve(), self.seed)

    def test_preserves_existing_local_config(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_text("local settings\n")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.target.is_symlink())
        self.assertEqual(self.target.read_text(), "local settings\n")

    def test_rejects_linked_runtime_directory(self):
        foreign = self.repo.parent / "foreign"
        foreign.mkdir()
        (foreign / "config.toml").write_text("local settings\n")
        self.target.parent.parent.mkdir(parents=True)
        self.target.parent.symlink_to(foreign, target_is_directory=True)
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.target.parent.is_symlink())
        self.assertEqual((foreign / "config.toml").read_text(), "local settings\n")

    def test_rejects_dangling_config_link(self):
        self.target.parent.mkdir(parents=True)
        self.target.symlink_to(self.home / "missing")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.target.is_symlink())
        self.assertEqual(os.readlink(self.target), str(self.home / "missing"))

    def test_missing_repo_config_fails_before_creating_target(self):
        self.seed.unlink()
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.target.parent.exists())


if __name__ == "__main__":
    unittest.main()
