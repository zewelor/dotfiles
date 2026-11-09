"""Exercise the base installer with real Stow and isolated home directories."""

import os
from pathlib import Path
import shutil
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
                    "XDG_CONFIG_HOME": str(self.home / ".config")}
        (self.repo / ".zsh").mkdir(parents=True)
        shutil.copy(ROOT / ".zsh/helpers.zsh", self.repo / ".zsh/helpers.zsh")
        shutil.copy(ROOT / ".stow-local-ignore", self.repo / ".stow-local-ignore")
        for name in ("systemd/user/rclone-nas.service", "btop/btop.conf",
                     "btop/themes/catppuccin_latte.theme", "mise/config.toml"):
            target = self.repo / ".config" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / ".config" / name, target)
        self.units = self.repo / ".config/systemd/user"
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

    def run_install(self, profile="server"):
        return subprocess.run(
            ["zsh", str(self.repo / "install")],
            env={**self.env, "DOTFILES_PROFILE": profile}, cwd=self.repo,
            capture_output=True, text=True, timeout=20,
        )

    def check_runtime_files(self, profile):
        result = self.run_install(profile)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for relative in ("systemd/user", "btop", "example/nested"):
            self.assertFalse((self.config / relative).is_symlink(), relative)
        self.assertFalse((self.config / "mise").exists())
        service = self.config / "systemd/user/rclone-nas.service"
        self.assertEqual(service.resolve(), self.units / service.name)
        self.assertTrue((self.config / "btop/btop.conf").is_symlink())
        units = self.config / "systemd/user"
        (units / "docker.service").write_text("[Service]\n")
        wants = units / "default.target.wants"
        wants.mkdir()
        (wants / "docker.service").symlink_to(units / "docker.service")
        (self.config / "btop/btop.log").write_text("runtime log\n")
        (self.config / "example/nested/runtime.json").write_text("{}\n")
        repeated = self.run_install(profile)
        self.assertEqual(repeated.returncode, 0, repeated.stdout + repeated.stderr)
        for relative in ("systemd/user/docker.service", "systemd/user/default.target.wants",
                         "btop/btop.log", "example/nested/runtime.json"):
            self.assertFalse((self.repo / ".config" / relative).exists(), relative)
        self.assertTrue((wants / "docker.service").is_file())

    def test_server_runtime_files_stay_outside_checkout(self):
        self.check_runtime_files("server")

    def test_desktop_runtime_files_stay_outside_checkout(self):
        self.check_runtime_files("desktop")

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



if __name__ == "__main__":
    unittest.main()
