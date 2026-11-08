"""Exercise private Flatpak Stow targets in isolated home directories."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class FlatpakTargetsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-flatpak-")
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.repo = root / "repo"
        self.home = root / "home"
        (self.repo / ".zsh").mkdir(parents=True)
        shutil.copy(ROOT / ".zsh/helpers.zsh", self.repo / ".zsh/helpers.zsh")
        self.source = self.repo / "prv/.var/app/com.example.App/config/App"
        self.source.mkdir(parents=True)
        (self.source / "prefs.ini").write_text("managed\n")
        self.target = self.home / ".var/app/com.example.App/config/App"
        script = (ROOT / "install").read_text().rsplit("\nrun_installation", 1)[0]
        (self.repo / "install").write_text(script + "\nprepare_stow_targets\n")

    def run_prepare(self, profile="desktop"):
        return subprocess.run(
            ["zsh", str(self.repo / "install")],
            env={**os.environ, "HOME": str(self.home), "DOTFILES_PROFILE": profile},
            capture_output=True, text=True, timeout=10,
        )

    def test_private_stow_keeps_runtime_files_outside_checkout(self):
        for attempt in range(2):
            result = self.run_prepare()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run(
                ["stow", "-d", str(self.repo / "prv"), "-t", str(self.home), "."],
                capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for directory in (self.target, self.target.parent, self.target.parent.parent):
                self.assertTrue(directory.is_dir())
                self.assertFalse(directory.is_symlink())
            self.assertTrue((self.target / "prefs.ini").is_symlink())
            self.assertEqual((self.target / "prefs.ini").resolve(), self.source / "prefs.ini")
            runtime = self.target / "runtime.json"
            if attempt == 0:
                runtime.write_text("local runtime\n")
            self.assertEqual(runtime.read_text(), "local runtime\n")
            self.assertFalse((self.source / "runtime.json").exists())

    def test_rejects_linked_parent_and_nested_directories(self):
        for relative in (".var", ".var/app/com.example.App/config"):
            with self.subTest(relative=relative):
                if self.home.exists():
                    shutil.rmtree(self.home)
                foreign = self.repo.parent / "foreign"
                foreign.mkdir(exist_ok=True)
                sentinel = foreign / "keep"
                sentinel.write_text("preserve\n")
                target = self.home / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(foreign, target_is_directory=True)
                result = self.run_prepare()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(target.is_symlink())
                self.assertEqual(sentinel.read_text(), "preserve\n")
                self.assertEqual(list(foreign.iterdir()), [sentinel])

    def test_server_does_not_create_flatpak_directories(self):
        result = self.run_prepare("server")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / ".var").exists())


if __name__ == "__main__":
    unittest.main()
