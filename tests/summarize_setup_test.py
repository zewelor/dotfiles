"""Exercise Summarize's desktop seed installation in an isolated home."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SummarizeSetupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.home = self.root / "home"
        self.home.mkdir()
        (self.root / ".zsh").mkdir()
        shutil.copy(ROOT / ".zsh/helpers.zsh", self.root / ".zsh/helpers.zsh")
        self.seed = self.repo / "prv/.summarize/config.json"
        self.seed.parent.mkdir(parents=True)
        self.seed.write_text('{"model":"cli/codex/gpt-6-luna"}\n')
        self.config = self.home / ".summarize/config.json"
        script = (ROOT / "install").read_text().rsplit("\nrun_installation", 1)[0]
        self.script = self.root / "setup.zsh"
        self.script.write_text(script + '\nBASE_DIR="$TEST_REPO"\nHOME_DIR="$HOME"\nsetup_summarize\n')
        self.env = {**os.environ, "HOME": str(self.home), "ZDOTDIR": str(self.home),
                    "TEST_REPO": str(self.repo)}

    def run_setup(self):
        return subprocess.run(["zsh", str(self.script)], env=self.env, text=True,
                              capture_output=True, timeout=10)

    def test_new_seed_is_copied_and_existing_config_is_preserved(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.config.is_symlink())
        self.assertEqual(self.config.read_text(), self.seed.read_text())
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        self.config.write_text('{"model":"local-choice"}\n')
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.config.read_text(), '{"model":"local-choice"}\n')

    def test_legacy_public_seed_link_is_rejected(self):
        self.config.parent.mkdir()
        self.config.symlink_to(self.repo / ".summarize/config.json")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.config.is_symlink())

    def test_link_to_private_seed_is_rejected(self):
        self.config.parent.mkdir()
        self.config.symlink_to(self.seed)
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.config.is_symlink())

    def test_file_created_during_seed_is_not_overwritten(self):
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        fake_install = bin_dir / "install"
        fake_install.write_text('''#!/bin/sh
/usr/bin/install "$@"
printf 'unmanaged' > "$HOME/.summarize/config.json"
''')
        fake_install.chmod(0o755)
        self.env["PATH"] = f"{bin_dir}:{self.env['PATH']}"
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.config.read_text(), "unmanaged")
        self.assertEqual(sorted(p.name for p in self.config.parent.iterdir()), ["config.json"])

    def test_directory_created_during_seed_is_not_used_as_target(self):
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        fake_install = bin_dir / "install"
        fake_install.write_text('''#!/bin/sh
/usr/bin/install "$@"
mkdir "$HOME/.summarize/config.json"
printf 'unmanaged' > "$HOME/.summarize/config.json/keep"
''')
        fake_install.chmod(0o755)
        self.env["PATH"] = f"{bin_dir}:{self.env['PATH']}"
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.config / "keep").read_text(), "unmanaged")
        self.assertEqual(sorted(p.name for p in self.config.iterdir()), ["keep"])

    def test_existing_config_with_wrong_mode_is_rejected_without_changes(self):
        self.config.parent.mkdir()
        self.config.write_text("existing")
        self.config.chmod(0o644)
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("chmod 600", result.stderr)
        self.assertEqual(self.config.read_text(), "existing")
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o644)

    def test_existing_config_works_with_older_chmod(self):
        self.config.parent.mkdir()
        self.config.write_text("existing")
        self.config.chmod(0o600)
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        fake_chmod = bin_dir / "chmod"
        fake_chmod.write_text('''#!/bin/sh
if [ "$1" = -h ]; then
  echo "chmod: invalid option -- 'h'" >&2
  exit 1
fi
exec /usr/bin/chmod "$@"
''')
        fake_chmod.chmod(0o755)
        self.env["PATH"] = f"{bin_dir}:{self.env['PATH']}"
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.config.read_text(), "existing")
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_replacement_during_inspection_is_rejected_without_changing_it(self):
        for kind in ("directory", "symlink"):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                home = root / "home"
                config = home / ".summarize/config.json"
                config.parent.mkdir(parents=True)
                config.write_text("existing")
                config.chmod(0o600)
                other = root / "foreign.json"
                other.write_text("foreign")
                other.chmod(0o644)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                fake_stat = bin_dir / "stat"
                fake_stat.write_text('''#!/bin/sh
rm "$HOME/.summarize/config.json"
if [ "$TEST_KIND" = directory ]; then
  mkdir -m 755 "$HOME/.summarize/config.json"
  printf keep > "$HOME/.summarize/config.json/keep"
else
  ln -s "$TEST_FOREIGN" "$HOME/.summarize/config.json"
fi
exec /usr/bin/stat "$@"
''')
                fake_stat.chmod(0o755)
                env = {**self.env, "HOME": str(home), "ZDOTDIR": str(home),
                       "TEST_KIND": kind, "TEST_FOREIGN": str(other),
                       "PATH": f"{bin_dir}:{self.env['PATH']}"}
                result = subprocess.run(["zsh", str(self.script)], env=env, text=True,
                                        capture_output=True, timeout=10)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                if kind == "directory":
                    self.assertEqual(config.stat().st_mode & 0o777, 0o755)
                    self.assertEqual((config / "keep").read_text(), "keep")
                else:
                    self.assertTrue(config.is_symlink())
                    self.assertEqual(other.read_text(), "foreign")
                    self.assertEqual(other.stat().st_mode & 0o777, 0o644)

    def test_foreign_link_is_rejected(self):
        self.config.parent.mkdir()
        other = self.root / "foreign.json"
        other.write_text("foreign\n")
        self.config.symlink_to(other)
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.config.is_symlink())
        self.assertEqual(other.read_text(), "foreign\n")


if __name__ == "__main__":
    unittest.main()
