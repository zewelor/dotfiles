"""Run the installer's public/private Stow steps against a temporary home."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def extract_function(source, name):
    start = source.index(f"\n{name}() {{") + 1
    end = source.index("\n}\n", start) + 3
    return source[start:end]


class StowIntegrationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-stow-integration-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.home = self.root / "home"
        self.private = self.repo / "prv"
        self.env = {**os.environ, "HOME": str(self.home)}

        self.private.mkdir(parents=True)
        shutil.copy2(ROOT / ".stow-local-ignore", self.repo / ".stow-local-ignore")
        # This synthetic package must also work in public/server checkouts without prv.
        (self.private / ".stow-local-ignore").write_text("")
        public_file = self.repo / ".config/health-check-fixture/public.toml"
        public_file.parent.mkdir(parents=True)
        public_file.write_text("public defaults\n")
        self.private_file = self.private / ".config/health-check-fixture/private.toml"
        self.private_file.parent.mkdir(parents=True)
        self.private_file.write_text("private override\n")

        install_source = (ROOT / "install").read_text()
        functions = [
            "require_real_directory_path",
            "install_with_stow",
            "prepare_private_flatpak_targets",
            "prepare_private_stow_targets",
            "prepare_stow_targets",
            "stow_base_dotfiles",
        ]
        function_source = "\n".join(extract_function(install_source, name) for name in functions)
        harness = f'''#!/bin/zsh
set -euo pipefail
BASE_DIR={shlex.quote(str(self.repo))}
HOME_DIR={shlex.quote(str(self.home))}
CONFIG_DIR="$HOME_DIR/.config"
STOW_APPLY=true
DOTFILES_PROFILE=desktop
is_desktop() {{ return 0; }}
print_banner() {{ :; }}
setup_btop() {{ :; }}

{function_source}

prepare_stow_targets
stow_base_dotfiles
install_with_stow -d "$BASE_DIR/prv" -t "$HOME_DIR" "."
'''
        self.harness = self.root / "stow-fixture.zsh"
        self.harness.write_text(harness)

    def run_stow_install(self):
        return subprocess.run(
            ["zsh", str(self.harness)], env=self.env, capture_output=True,
            text=True, timeout=20,
        )

    def test_public_and_private_stow_install_is_repeatable(self):
        for attempt in (1, 2):
            with self.subTest(attempt=attempt):
                result = self.run_stow_install()
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

                public_target = self.home / ".config/health-check-fixture/public.toml"
                private_target = self.home / ".config/health-check-fixture/private.toml"
                self.assertTrue(public_target.is_symlink())
                self.assertTrue(private_target.is_symlink())
                self.assertEqual(public_target.resolve(),
                                 (self.repo / ".config/health-check-fixture/public.toml").resolve())
                self.assertEqual(private_target.resolve(), self.private_file.resolve())

    def test_local_private_conflict_is_preserved(self):
        conflict = self.home / ".config/health-check-fixture/private.toml"
        conflict.parent.mkdir(parents=True)
        conflict.write_text("operator-owned local setting\n")

        result = self.run_stow_install()

        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("conflict", (result.stdout + result.stderr).lower())
        self.assertFalse(conflict.is_symlink())
        self.assertEqual(conflict.read_text(), "operator-owned local setting\n")
        self.assertTrue((self.home / ".config/health-check-fixture/public.toml").is_symlink())


if __name__ == "__main__":
    unittest.main()
