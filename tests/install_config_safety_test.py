"""Exercise installer config safety in isolated, synthetic homes."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallConfigSafetyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.home = root / "home"
        self.repo = root / "repo"
        self.outside = root / "outside"
        self.home.mkdir()
        self.outside.mkdir()
        (self.repo / ".zsh").mkdir(parents=True)
        shutil.copy(ROOT / ".zsh/helpers.zsh", self.repo / ".zsh/helpers.zsh")
        for name, content in (("rclone/rclone.conf.template", "pass = {{nas_pass}}\n"),
                              ("mise/config.toml", "[tools]\n")):
            file = self.repo / ".config" / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(content)
        self.marker = root / "mise-called"
        mise = self.home / ".local/bin/mise"
        mise.parent.mkdir(parents=True)
        mise.write_text(f"#!/bin/sh\ntouch '{self.marker}'\n")
        mise.chmod(0o755)
        self.env = {**os.environ, "HOME": str(self.home)}
        self.script = (ROOT / "install").read_text().rsplit("\nrun_installation", 1)[0]
        overrides = '''
is_interactive() { return 0 }
has() { return 1 }
vault_http_get() { print -r -- '{"data":{"data":{"omen_pass":"fixture"}}}' }
VAULT_TOKEN=fixture
"$@"
'''
        self.install = self.repo / "fixture-install"
        self.install.write_text(self.script + "\n" + overrides)

    def run_step(self, step, response="y\n", *args):
        return subprocess.run(["zsh", str(self.install), step, *map(str, args)], env=self.env,
                              input=response, text=True, capture_output=True, timeout=10)

    def test_checks_each_level_of_a_single_destination(self):
        config = self.home / ".config"
        config.mkdir()
        (config / "linked").symlink_to(self.outside, target_is_directory=True)
        result = self.run_step("require_real_directory_path", "", config / "linked/deeper/target")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(str(config / "linked"), result.stderr)
        self.assertEqual(list(self.outside.iterdir()), [])

        result = self.run_step("require_real_directory_path", "", config / "new/deeper/target")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((config / "new").exists())

    def test_rejects_paths_outside_home_or_with_parent_components(self):
        for target in (self.outside / "new", str(self.home / ".config") + "/../other"):
            with self.subTest(target=target):
                result = self.run_step("require_real_directory_path", "", target)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_linked_config_ancestors_are_rejected(self):
        for step, name in (("setup_rclone", "rclone"), ("setup_mise_desktop_tools", "mise")):
            for linked in ("config", "child"):
                with self.subTest(step=step, linked=linked):
                    config = self.home / ".config"
                    if linked == "config":
                        config.symlink_to(self.outside, target_is_directory=True)
                    else:
                        config.mkdir()
                        (config / name).symlink_to(self.outside, target_is_directory=True)
                    sentinel = self.outside / ("rclone.conf" if name == "rclone" else "config.toml")
                    sentinel.write_text("keep\n")
                    try:
                        result = self.run_step(step)
                        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertIn("real directory", result.stderr)
                        self.assertEqual(sentinel.read_text(), "keep\n")
                        self.assertFalse(self.marker.exists())
                        self.assertEqual(sorted(p.name for p in self.outside.iterdir()), [sentinel.name])
                    finally:
                        if config.is_symlink():
                            config.unlink()
                        elif config.exists():
                            shutil.rmtree(config)
                        for child in self.outside.iterdir():
                            shutil.rmtree(child) if child.is_dir() and not child.is_symlink() else child.unlink()
                        self.marker.unlink(missing_ok=True)

    def test_invalid_config_child_paths_are_rejected(self):
        config = self.home / ".config"
        config.mkdir()
        for step, name in (("setup_rclone", "rclone"), ("setup_mise_desktop_tools", "mise")):
            for kind in ("file", "dangling"):
                with self.subTest(step=step, kind=kind):
                    target = config / name
                    if kind == "file":
                        target.write_text("keep\n")
                    else:
                        target.symlink_to(self.outside / "missing", target_is_directory=True)
                    try:
                        result = self.run_step(step)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn("real directory", result.stderr)
                        self.assertFalse(self.marker.exists())
                    finally:
                        target.unlink()

    def test_declined_rclone_does_not_require_config_directory(self):
        (self.home / ".config").symlink_to(self.outside, target_is_directory=True)
        result = self.run_step("setup_rclone", "n\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.outside.iterdir()), [])

    def test_rclone_writes_to_real_directory(self):
        result = self.run_step("setup_rclone")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        target = self.home / ".config/rclone/rclone.conf"
        self.assertEqual(target.read_text(), "pass = fixture\n")
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def test_full_install_preflight_rejects_linked_config_directories(self):
        overrides = '''
configure_profile() { DOTFILES_PROFILE=desktop }
init_colors() { : }
require_zsh_login_shell() { : }
configure_stow_apply() { : }
setup_private_submodule() { : }
run_installation
'''
        self.install.write_text(self.script + "\n" + overrides)
        config = self.home / ".config"
        config.mkdir()
        for name in ("rclone", "mise"):
            with self.subTest(name=name):
                link = config / name
                link.symlink_to(self.outside, target_is_directory=True)
                try:
                    result = subprocess.run(["zsh", str(self.install)], env=self.env,
                                            text=True, capture_output=True, timeout=10)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("real directory", result.stderr)
                    self.assertEqual(list(self.outside.iterdir()), [])
                finally:
                    link.unlink()

    def test_mise_checks_both_targets_before_linking(self):
        target = self.home / ".config/mise"
        target.mkdir(parents=True)
        for filename, other in (("config.local.toml", "config.toml"),
                                ("config.toml", "config.local.toml")):
            with self.subTest(filename=filename):
                conflict = target / filename
                conflict.write_text("unmanaged\n")
                result = self.run_step("setup_mise_desktop_tools")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("unmanaged mise config", result.stderr)
                self.assertEqual(conflict.read_text(), "unmanaged\n")
                self.assertFalse((target / other).is_symlink())
                self.assertFalse(self.marker.exists())
                conflict.unlink()

    def test_mise_accepts_managed_links_and_is_idempotent(self):
        for _ in range(2):
            result = self.run_step("setup_mise_desktop_tools")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for name in ("config.toml", "config.local.toml"):
                link = self.home / ".config/mise" / name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), self.repo / ".config/mise" / name)
            self.assertTrue(self.marker.exists())

    def test_mise_accepts_a_managed_link_to_missing_local_config(self):
        target = self.home / ".config/mise"
        target.mkdir(parents=True)
        (target / "config.local.toml").symlink_to(self.repo / ".config/mise/config.local.toml")
        result = self.run_step("setup_mise_desktop_tools")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.marker.exists())


if __name__ == "__main__":
    unittest.main()
