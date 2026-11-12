"""Exercise the base installer with real Stow and isolated home directories."""

import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class StowTargetsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-stow-targets-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.home = self.root / "home"
        self.env = {**os.environ, "HOME": str(self.home), "ZDOTDIR": str(self.home),
                    "XDG_CONFIG_HOME": str(self.home / ".config"),
                    "BTOP_TEST_VERSION": "1.2.13"}
        (self.repo / ".zsh").mkdir(parents=True)
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        fake_btop = fake_bin / "btop"
        fake_btop.write_text('#!/bin/sh\nprintf "btop version: \\033[1m%s\\033[0m\\n" "$BTOP_TEST_VERSION"\n')
        fake_btop.chmod(0o755)
        self.env["PATH"] = f"{fake_bin}{os.pathsep}{os.environ['PATH']}"
        shutil.copy(ROOT / ".zsh/helpers.zsh", self.repo / ".zsh/helpers.zsh")
        shutil.copy(ROOT / ".stow-local-ignore", self.repo / ".stow-local-ignore")
        for name in ("btop/btop.conf", "btop/themes/catppuccin_latte.theme", "mise/config.toml"):
            target = self.repo / ".config" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / ".config" / name, target)
        self.seed = self.repo / ".config/btop/btop.conf"
        self.config = self.home / ".config"
        sample = self.repo / ".config/example/nested/managed.conf"
        sample.parent.mkdir(parents=True)
        sample.write_text("managed\n")
        hidden = self.repo / ".config/example/.hidden/managed.conf"
        hidden.parent.mkdir()
        hidden.write_text("managed\n")
        script = (ROOT / "install").read_text()
        main = script[script.index("run_installation() {"):]
        # Run the production base stage, excluding tool installs and user services.
        start = main.index('  print_banner "Stowing base dotfiles')
        end = main.index("  # Interactive prompts first", start)
        stage = main[start:end]
        script = script.rsplit("\nrun_installation", 1)[0]
        script += '\nHOME_DIR="$BASE_DIR/../home"\nCONFIG_DIR="$HOME_DIR/.config"\nSTOW_APPLY=true\nprepare_stow_targets\n'
        (self.repo / "install").write_text(script + stage)

    def run_install(self, profile="server", version="1.2.13"):
        return subprocess.run(
            ["zsh", str(self.repo / "install")],
            env={**self.env, "DOTFILES_PROFILE": profile, "BTOP_TEST_VERSION": version}, cwd=self.repo,
            capture_output=True, text=True, timeout=20,
        )

    def check_runtime_files(self, profile):
        units = self.config / "systemd/user"
        units.mkdir(parents=True)
        (units / "docker.service").write_text("[Service]\n")
        wants = units / "default.target.wants"
        wants.mkdir()
        (wants / "docker.service").symlink_to(units / "docker.service")
        result = self.run_install(profile)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for relative in ("systemd/user", "btop", "example/nested"):
            self.assertFalse((self.config / relative).is_symlink(), relative)
        self.assertFalse((self.config / "mise").exists())
        self.assertFalse((units / "rclone-nas.service").exists())
        local = self.config / "btop/btop.conf"
        self.assertFalse(local.is_symlink())
        expected = self.seed.read_text().replace('cpu_graph_upper = "Auto"', 'cpu_graph_upper = "total"')
        expected = expected.replace('cpu_graph_lower = "Auto"', 'cpu_graph_lower = "total"')
        self.assertEqual(local.read_text(), expected)
        self.assertEqual(stat.S_IMODE(local.stat().st_mode), 0o600)
        local.write_text('cpu_graph_upper = "total"\ncpu_graph_lower = "total"\n')
        self.seed.write_text("new defaults\n")
        (self.config / "btop/btop.log").write_text("runtime log\n")
        (self.config / "example/nested/runtime.json").write_text("{}\n")
        repeated = self.run_install(profile)
        self.assertEqual(repeated.returncode, 0, repeated.stdout + repeated.stderr)
        self.assertIn('cpu_graph_upper = "total"', local.read_text())
        for relative in ("systemd/user/docker.service", "systemd/user/default.target.wants",
                         "btop/btop.log", "example/nested/runtime.json"):
            self.assertFalse((self.repo / ".config" / relative).exists(), relative)
        self.assertTrue((wants / "docker.service").is_file())

    def test_server_runtime_files_stay_outside_checkout(self):
        self.check_runtime_files("server")

    def test_desktop_runtime_files_stay_outside_checkout(self):
        self.check_runtime_files("desktop")

    def test_server_base_does_not_link_desktop_files(self):
        files = ("atuin/themes/catppuccin-latte-blue.toml", "foot/foot.ini",
                 "foot/catppuccin-latte.ini", "systemd/user/docker-prune.service",
                 "systemd/user/docker-prune.timer", "systemd/user/rclone-nas.service",
                 "systemd/user/rclone-sleep-handler.service")
        for name in files:
            public_source = ROOT / ".config" / name
            if public_source.is_file():
                target = self.repo / ".config" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(public_source, target)
            private_fixture = self.repo / "prv/.config" / name
            private_fixture.parent.mkdir(parents=True, exist_ok=True)
            private_fixture.write_text("fixture\n")
        result = self.run_install("server")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in files:
            self.assertFalse((self.config / name).exists(), name)
        self.assertFalse((self.config / "atuin").exists())

    def test_legacy_directory_links_fail_before_writing(self):
        foreign = self.root / "foreign"
        foreign.mkdir()
        for relative in (".", "mise", "example/nested", "example/.hidden"):
            with self.subTest(relative=relative):
                if self.home.exists():
                    shutil.rmtree(self.home)
                path = self.config if relative == "." else self.config / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.symlink_to(foreign, target_is_directory=True)
                try:
                    result = self.run_install()
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("must be a real directory", result.stderr)
                    self.assertEqual(list(foreign.iterdir()), [])
                    self.assertTrue(path.is_symlink())
                finally:
                    path.unlink()

    def test_existing_btop_settings_are_preserved(self):
        local = self.config / "btop/btop.conf"
        local.parent.mkdir(parents=True)
        local.write_text('cpu_graph_upper = "total"\n')
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(local.read_text(), 'cpu_graph_upper = "total"\n')

    def test_old_btop_rejects_directory_created_during_publication(self):
        local = self.config / "btop/btop.conf"
        foreign = self.root / "foreign"
        foreign.mkdir()
        fake_sed = self.root / "bin/sed"
        fake_sed.write_text('''#!/bin/sh
/usr/bin/sed "$@" || exit
if [ "$1" = -E ]; then
  if [ "$BTOP_TEST_CONFLICT" = directory ]; then
    mkdir "$HOME/.config/btop/btop.conf"
  else
    ln -s "$BTOP_TEST_FOREIGN" "$HOME/.config/btop/btop.conf"
  fi
fi
''')
        fake_sed.chmod(0o755)
        self.env["BTOP_TEST_FOREIGN"] = str(foreign)
        for kind in ("directory", "symlink"):
            with self.subTest(kind=kind):
                if self.home.exists():
                    shutil.rmtree(self.home)
                self.env["BTOP_TEST_CONFLICT"] = kind
                result = self.run_install(version="1.4.5")
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("btop.conf", result.stderr)
                self.assertTrue(local.is_dir())
                self.assertEqual(local.is_symlink(), kind == "symlink")
                self.assertEqual(list(local.iterdir()), [])
                self.assertEqual(list(foreign.iterdir()), [])
                self.assertEqual(list(local.parent.glob('.btop.conf.*')), [])
                self.assertFalse((self.config / "example/nested/managed.conf").exists())

    def test_btop_config_link_is_rejected_without_changing_target(self):
        local = self.config / "btop/btop.conf"
        local.parent.mkdir(parents=True)
        for source in (self.seed, self.root / "missing-foreign-config"):
            with self.subTest(source=source):
                original = self.seed.read_bytes()
                local.symlink_to(source)
                try:
                    result = self.run_install()
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertTrue(local.is_symlink())
                    self.assertEqual(self.seed.read_bytes(), original)
                    self.assertFalse((self.config / "example/nested/managed.conf").exists())
                finally:
                    local.unlink()

    def test_modern_btop_links_config_and_refuses_an_unmanaged_file(self):
        local = self.config / "btop/btop.conf"
        local.parent.mkdir(parents=True)
        local.write_text('local settings\n')
        conflict = self.run_install(version="1.4.6")
        self.assertNotEqual(conflict.returncode, 0, conflict.stdout + conflict.stderr)
        self.assertEqual(local.read_text(), 'local settings\n')
        local.unlink()
        local.mkdir()
        conflict = self.run_install(version="1.4.6")
        self.assertNotEqual(conflict.returncode, 0, conflict.stdout + conflict.stderr)
        self.assertEqual(list(local.iterdir()), [])
        local.rmdir()
        local.parent.rmdir()
        for _ in range(2):
            result = self.run_install(version="1.4.6")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(local.is_symlink())
            self.assertEqual(local.resolve(), self.seed)

    def test_old_btop_keeps_local_copy_after_update_and_rejects_downgraded_link(self):
        local = self.config / "btop/btop.conf"
        first = self.run_install(version="1.4.5")
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        self.assertFalse(local.is_symlink())
        self.assertEqual(local.read_text(), self.seed.read_text())
        local.write_text('custom settings\n')
        upgraded = self.run_install(version="1.4.6")
        self.assertNotEqual(upgraded.returncode, 0, upgraded.stdout + upgraded.stderr)
        self.assertEqual(local.read_text(), 'custom settings\n')
        local.unlink()
        local.symlink_to(self.seed)
        downgraded = self.run_install(version="1.4.5")
        self.assertNotEqual(downgraded.returncode, 0, downgraded.stdout + downgraded.stderr)
        self.assertTrue(local.is_symlink())

    def test_modern_btop_refuses_seed_with_autosave_enabled(self):
        self.seed.write_text('save_config_on_exit = true\n')
        result = self.run_install(version="1.4.6")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.config / "btop/btop.conf").exists())

    def test_unknown_btop_version_fails_without_installing_config(self):
        for version in ("unknown", "1.4.6-rc1"):
            with self.subTest(version=version):
                result = self.run_install(version=version)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse((self.config / "btop/btop.conf").exists())

    def test_legacy_graph_compatibility_handles_inline_comments(self):
        self.seed.write_text('cpu_graph_upper = "Auto" # upper\ncpu_graph_lower = Auto\n')
        result = self.run_install(version="1.2.13")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        local = self.config / "btop/btop.conf"
        self.assertEqual(local.read_text(), 'cpu_graph_upper = "total" # upper\ncpu_graph_lower = "total"\n')

    def test_btop_1_3_keeps_auto_graphs_in_local_copy(self):
        result = self.run_install(version="1.3.0")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        local = self.config / "btop/btop.conf"
        self.assertFalse(local.is_symlink())
        self.assertEqual(local.read_text(), self.seed.read_text())


if __name__ == "__main__":
    unittest.main()
