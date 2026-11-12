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
        self.overrides = '''
is_interactive() { return 0 }
has() { return 1 }
vault_http_get() { print -r -- '{"data":{"data":{"omen_pass":"fixture"}}}' }
VAULT_TOKEN=fixture
"$@"
'''
        self.install = self.repo / "fixture-install"
        self.install.write_text(self.script + "\n" + self.overrides)

    def run_step(self, step, response="y\n", *args):
        return subprocess.run(["zsh", str(self.install), step, *map(str, args)], env=self.env,
                              input=response, text=True, capture_output=True, timeout=10)

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
        cases = (("setup_rclone", "rclone", "file"),
                 ("setup_mise_desktop_tools", "mise", "dangling"))
        for step, name, kind in cases:
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
        template = self.repo / ".config/rclone/rclone.conf.template"
        template.write_text("[remote]\npass = {{nas_pass}}\ntype = sftp\n")
        result = self.run_step("setup_rclone")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        target = self.home / ".config/rclone/rclone.conf"
        self.assertEqual(target.read_text(), "[remote]\npass = fixture\ntype = sftp\n")
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def test_rclone_invalid_templates_preserve_existing_config(self):
        target = self.home / ".config/rclone/rclone.conf"
        target.parent.mkdir(parents=True)
        template = self.repo / ".config/rclone/rclone.conf.template"
        for content in ("no placeholder\n", "pass = {{nas_pass}}\n" * 2):
            with self.subTest(template=content):
                target.write_text("previous config\n")
                template.write_text(content)
                result = self.run_step("setup_rclone")
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("Expected exactly one", result.stderr)
                self.assertNotIn("rclone config generated", result.stdout)
                self.assertEqual(target.read_text(), "previous config\n")
                self.assertEqual(list(target.parent.iterdir()), [target])

    def test_rclone_command_failures_preserve_existing_config(self):
        target = self.home / ".config/rclone/rclone.conf"
        target.parent.mkdir(parents=True)
        fake_bin = self.home / "bin"
        fake_bin.mkdir()
        self.env["PATH"] = f"{fake_bin}{os.pathsep}{os.environ['PATH']}"
        for command in ("mktemp", "chmod", "mv"):
            with self.subTest(command=command):
                target.write_text("previous config\n")
                executable = fake_bin / command
                executable.write_text(f"#!/bin/sh\necho 'injected {command} failure' >&2\nexit 73\n")
                executable.chmod(0o755)
                try:
                    result = self.run_step("setup_rclone")
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn(f"injected {command} failure", result.stderr)
                    self.assertNotIn("rclone config generated", result.stdout)
                    self.assertEqual(target.read_text(), "previous config\n")
                    self.assertEqual(list(target.parent.iterdir()), [target])
                finally:
                    executable.unlink()

    def test_rclone_write_failure_preserves_existing_config(self):
        target = self.home / ".config/rclone/rclone.conf"
        target.parent.mkdir(parents=True)
        target.write_text("previous config\n")
        template = self.repo / ".config/rclone/rclone.conf.template"
        template.write_text("[remote]\npass = {{nas_pass}}\ntype = sftp\n")
        commands = '''
print() {
  if [[ "$#" == 3 && "$3" == 'pass = fixture' ]]; then
    echo 'injected write failure' >&2
    return 74
  fi
  builtin print "$@"
}
'''
        self.install.write_text(self.script + "\n" + commands + self.overrides)
        result = self.run_step("setup_rclone")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("injected write failure", result.stderr)
        self.assertNotIn("rclone config generated", result.stdout)
        self.assertEqual(target.read_text(), "previous config\n")
        self.assertEqual(list(target.parent.iterdir()), [target])

    def test_rclone_directory_target_is_rejected(self):
        target = self.home / ".config/rclone/rclone.conf"
        target.mkdir(parents=True)
        sentinel = target / "keep"
        sentinel.write_text("unmanaged\n")
        result = self.run_step("setup_rclone")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("rclone config generated", result.stdout)
        self.assertEqual(sentinel.read_text(), "unmanaged\n")
        self.assertEqual(list(target.iterdir()), [sentinel])
        self.assertEqual(list(target.parent.iterdir()), [target])

    def test_rclone_target_links_are_rejected(self):
        target = self.home / ".config/rclone/rclone.conf"
        target.parent.mkdir(parents=True)
        sentinel = self.outside / "config"
        sentinel.write_text("unmanaged\n")
        for source in (sentinel, self.outside, self.outside / "missing"):
            with self.subTest(source=source):
                target.symlink_to(source)
                try:
                    result = self.run_step("setup_rclone")
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertNotIn("rclone config generated", result.stdout)
                    self.assertTrue(target.is_symlink())
                    self.assertEqual(target.readlink(), source)
                    self.assertEqual(sentinel.read_text(), "unmanaged\n")
                    self.assertEqual(list(target.parent.iterdir()), [target])
                    self.assertEqual(list(self.outside.iterdir()), [sentinel])
                finally:
                    target.unlink()

    def test_rclone_directory_created_during_publication_is_rejected(self):
        target = self.home / ".config/rclone/rclone.conf"
        fake_bin = self.home / "bin"
        fake_bin.mkdir()
        executable = fake_bin / "mv"
        executable.write_text('''#!/bin/sh
mkdir "$HOME/.config/rclone/rclone.conf" || exit
printf 'unmanaged\\n' > "$HOME/.config/rclone/rclone.conf/keep" || exit
exec /usr/bin/mv "$@"
''')
        executable.chmod(0o755)
        self.env["PATH"] = f"{fake_bin}{os.pathsep}{os.environ['PATH']}"
        result = self.run_step("setup_rclone")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("rclone config generated", result.stdout)
        sentinel = target / "keep"
        self.assertEqual(sentinel.read_text(), "unmanaged\n")
        self.assertEqual(list(target.iterdir()), [sentinel])
        self.assertEqual(list(target.parent.iterdir()), [target])

    def test_full_install_preflight_rejects_linked_config_directories(self):
        overrides = '''
configure_profile() { DOTFILES_PROFILE=desktop }
init_colors() { : }
require_zsh_login_shell() { : }
configure_stow_apply() { : }
setup_private_submodule() { : }
install_with_stow() { touch "$HOME_DIR/stow-called"; return 1 }
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
                    self.assertFalse((self.home / "stow-called").exists())
                    self.assertEqual(list(self.outside.iterdir()), [])
                finally:
                    link.unlink()


    def test_mise_checks_both_targets_before_linking(self):
        target = self.home / ".config/mise"
        target.mkdir(parents=True)
        conflict = target / "config.local.toml"
        conflict.write_text("unmanaged\n")
        result = self.run_step("setup_mise_desktop_tools")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unmanaged mise config", result.stderr)
        self.assertEqual(conflict.read_text(), "unmanaged\n")
        self.assertFalse((target / "config.toml").is_symlink())
        self.assertFalse(self.marker.exists())

    def test_mise_accepts_managed_links_and_is_idempotent(self):
        for _ in range(2):
            result = self.run_step("setup_mise_desktop_tools")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for name in ("config.toml", "config.local.toml"):
                link = self.home / ".config/mise" / name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), self.repo / ".config/mise" / name)
            self.assertTrue(self.marker.exists())

if __name__ == "__main__":
    unittest.main()
