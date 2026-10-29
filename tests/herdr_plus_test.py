"""Exercise Herdr project linking in an isolated installer fixture."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class HerdrPlusTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-herdr-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / ".zsh").mkdir()
        shutil.copy(REPO / ".zsh/helpers.zsh", self.root / ".zsh/helpers.zsh")
        script = (REPO / "install").read_text()
        # Load the real installer functions without running the full installation.
        script = script.rsplit("\nrun_installation", 1)[0]
        script += '\nHOME_DIR="$BASE_DIR/home"\nCONFIG_DIR="$HOME_DIR/.config"\nSTOW_APPLY=true\nsetup_herdr\n'
        (self.root / "install").write_text(script)
        self.source = self.root / "prv/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/gitops.toml"
        self.source.parent.mkdir(parents=True)
        self.source.write_text('name = "Gitops"\n')
        self.config = self.root / "home/.config/herdr/plugins/config/cloudmanic.herdr-plus"
        self.target = self.config / "projects/gitops.toml"

    def run_install(self, profile="desktop"):
        return subprocess.run(
            ["zsh", str(self.root / "install")],
            env={**os.environ, "DOTFILES_PROFILE": profile},
            text=True, capture_output=True,
        )

    def test_fresh_install_and_repeat(self):
        for _ in range(2):
            result = self.run_install()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(self.target.is_symlink())
            self.assertEqual(self.target.resolve(), self.source)
            self.assertTrue((self.config / "quick-actions").is_dir())
            generated = self.config / "cloudmanic-state.json"
            generated.write_text("{}")
            self.assertFalse((self.source.parents[2] / generated.name).exists())
        self.assertFalse(self.config.is_symlink())

    def test_server_does_not_link_private_config(self):
        self.source.unlink()
        result = self.run_install("server")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.config.exists())

    def test_missing_source_fails(self):
        shutil.rmtree(self.root / "prv/.config/herdr/plugins/config")
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertFalse(self.target.is_symlink())

    def test_existing_file_or_foreign_link_is_preserved(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_text("local config")
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertEqual(self.target.read_text(), "local config")
        self.target.unlink()
        self.target.symlink_to("/missing-foreign-config")
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertEqual(os.readlink(self.target), "/missing-foreign-config")

    def test_symlinked_runtime_parent_is_rejected(self):
        foreign = self.root / "foreign"
        foreign.mkdir()
        parent = self.root / "home/.config/herdr"
        parent.mkdir(parents=True)
        (parent / "plugins").symlink_to(foreign, target_is_directory=True)
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertEqual(list(foreign.iterdir()), [])

    def test_symlinked_quick_actions_is_rejected(self):
        foreign = self.root / "foreign-actions"
        foreign.mkdir()
        self.config.mkdir(parents=True)
        (self.config / "quick-actions").symlink_to(foreign, target_is_directory=True)
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertEqual(list(foreign.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
