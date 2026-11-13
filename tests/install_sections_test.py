"""Exercise installer section routing in isolated homes."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
DESKTOP = ("private", "vault", "desktop-assets", "tools", "ai", "desktop")
ALL_SECTIONS = ("profile", "base", *DESKTOP, "completions", "shell")


class InstallSectionsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = {**os.environ, "HOME": str(self.home), "ZDOTDIR": str(self.home),
                    "XDG_CONFIG_HOME": str(self.home / ".config")}
        self.env.pop("DOTFILES_PROFILE", None)

    def run_install(self, *args):
        return subprocess.run(["zsh", str(ROOT / "install"), *args], env=self.env, cwd=self.home,
                              stdin=subprocess.DEVNULL,
                              text=True, capture_output=True, timeout=10)

    def profile(self, value):
        config = self.home / ".zshrc.d"
        config.mkdir(exist_ok=True)
        (config / "profile.zsh").write_text(f'export DOTFILES_PROFILE="{value}"\n')

    def test_help_lists_sections_without_touching_home(self):
        result = self.run_install("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        for section in ALL_SECTIONS:
            self.assertIn(f"make install-{section}", result.stdout)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_invalid_arguments_and_missing_profile_fail_before_changes(self):
        for args in (("--section",), ("--section", "missing"), ("--bad",),
                     ("--section", "vault", "extra"), ("--section", "vault")):
            with self.subTest(args=args):
                result = self.run_install(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
                self.assertEqual(list(self.home.iterdir()), [])

    def test_desktop_sections_refuse_server_before_changes(self):
        self.profile("server")
        self.env["DOTFILES_PROFILE"] = "desktop"
        before = (self.home / ".zshrc.d/profile.zsh").read_text()
        for section in DESKTOP:
            with self.subTest(section=section):
                result = self.run_install("--section", section)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("desktop", result.stderr)
                self.assertEqual((self.home / ".zshrc.d/profile.zsh").read_text(), before)
                self.assertEqual(list(self.home.iterdir()), [self.home / ".zshrc.d"])

    def test_vault_noninteractive_fails_before_changes(self):
        self.profile("desktop")
        result = self.run_install("--section", "vault")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("interactive", result.stderr.lower())
        self.assertEqual(sorted(p.name for p in (self.home / ".zshrc.d").iterdir()), ["profile.zsh"])

    def test_cancelled_full_install_preserves_saved_profile(self):
        self.profile("server")
        self.env.update(DOTFILES_PROFILE="desktop", DOTFILES_ALLOW_NON_ZSH_SHELL="1",
                        DOTFILES_STOW_CONFIRM_APPLY="0")
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DOTFILES_STOW_CONFIRM_APPLY", result.stderr)
        self.assertEqual((self.home / ".zshrc.d/profile.zsh").read_text(),
                         'export DOTFILES_PROFILE="server"\n')

    def test_failed_shell_preflight_does_not_create_profile(self):
        repo = self.make_fixture('require_zsh_login_shell() { return 42 }\n')
        result = subprocess.run(["zsh", str(repo / "install")],
                                env={**self.env, "DOTFILES_PROFILE": "desktop"},
                                stdin=subprocess.DEVNULL, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertFalse((self.home / ".zshrc.d").exists())

    def test_saving_unchanged_profile_preserves_existing_file(self):
        self.profile("server")
        path = self.home / ".zshrc.d/profile.zsh"
        original = '# Local profile\nexport DOTFILES_PROFILE="server"\n'
        path.write_text(original)
        result = self.run_install("--section", "profile")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(path.read_text(), original)

    def test_make_skills_obeys_private_section_profile_and_confirmation(self):
        repo = self.make_fixture('''
setup_private_submodule() { return 0 }
setup_herdr() { return 0 }
''')
        shutil.copy(ROOT / "Makefile", repo / "Makefile")
        source = repo / "prv/.agents/skills/example/SKILL.md"
        source.parent.mkdir(parents=True)
        source.write_text("fixture\n")
        (self.home / ".config").mkdir()
        (self.home / ".var/app").mkdir(parents=True)
        for profile, confirmation in (("server", "1"), ("desktop", "0"), ("desktop", "1")):
            with self.subTest(profile=profile, confirmation=confirmation):
                self.profile(profile)
                result = subprocess.run(["make", "-s", "-C", str(repo), "skills"],
                                        env={**self.env, "DOTFILES_STOW_CONFIRM_APPLY": confirmation},
                                        stdin=subprocess.DEVNULL, text=True, capture_output=True, timeout=10)
                target = self.home / ".agents/skills/example/SKILL.md"
                if profile == "desktop" and confirmation == "1":
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(target.resolve(), source)
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertFalse(target.exists())

    def test_failed_profile_script_is_not_accepted(self):
        self.profile("desktop")
        (self.home / ".zshrc.d/profile.zsh").write_text('export DOTFILES_PROFILE=desktop\nfalse\n')
        result = self.run_install("--section", "vault")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("profile", result.stderr)

    def test_missing_section_prerequisites_fail_before_changes(self):
        self.profile("desktop")
        for section in ("private", "ai"):
            with self.subTest(section=section):
                result = self.run_install("--section", section)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("first", result.stderr)
                self.assertEqual(list(self.home.iterdir()), [self.home / ".zshrc.d"])

    def test_ai_section_requires_summarize_seed_before_any_setup(self):
        self.profile("desktop")
        repo = self.make_fixture('''
configure_stow_apply() { touch "$HOME_DIR/stow-ran" }
setup_codex() { touch "$HOME_DIR/codex-ran" }
setup_opencode() { touch "$HOME_DIR/opencode-ran" }
setup_antigravity_cli() { touch "$HOME_DIR/agy-ran" }
setup_summarize() { touch "$HOME_DIR/summarize-ran" }
''')
        for name in ("commands", "skills"):
            (self.home / ".agents" / name).mkdir(parents=True)
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "ai"],
                                env=self.env, cwd=repo, text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("private", result.stderr)
        for name in ("stow", "codex", "opencode", "agy", "summarize"):
            self.assertFalse((self.home / f"{name}-ran").exists())

    def make_fixture(self, extra):
        repo = self.home / "fixture"
        (repo / ".zsh").mkdir(parents=True, exist_ok=True)
        (repo / "bin").mkdir(exist_ok=True)
        shutil.copy(ROOT / ".zsh/helpers.zsh", repo / ".zsh/helpers.zsh")
        (repo / "bin/update-shell-completions").write_text("#!/bin/sh\nexit 0\n")
        (repo / "bin/update-shell-completions").chmod(0o755)
        script = (ROOT / "install").read_text().rsplit("\nrun_installation", 1)[0]
        (repo / "install").write_text(script + "\n" + extra + '\nrun_installation "$@"\n')
        (repo / "install").chmod(0o755)
        return repo

    def test_generated_shell_files_do_not_write_through_links(self):
        repo = self.make_fixture('''
configure_git_conflict_style() { touch "$HOME_DIR/git-ran" }
has() { [[ "$1" == nvim ]] }
nvim() { print -r -- 'NVIM v0.11.0' }
''')
        for section, filename in (("profile", "profile.zsh"), ("shell", "editor.zsh")):
            for kind in ("directory_link", "file_link", "regular", "missing"):
                with self.subTest(section=section, kind=kind), tempfile.TemporaryDirectory() as temp:
                    root = Path(temp)
                    home, outside = root / "home", root / "outside"
                    home.mkdir()
                    outside.mkdir()
                    config = home / ".zshrc.d"
                    if kind == "directory_link":
                        config.symlink_to(outside, target_is_directory=True)
                    else:
                        config.mkdir()
                    target = config / filename
                    original = 'export DOTFILES_PROFILE="server"\n' if section == "profile" else "preserve\n"
                    if section == "shell":
                        (config / "profile.zsh").write_text('export DOTFILES_PROFILE="server"\n')
                    if kind == "file_link":
                        sentinel = outside / filename
                        sentinel.write_text(original)
                        target.symlink_to(sentinel)
                    elif kind != "missing":
                        target.write_text(original)
                        sentinel = target
                    managed = config / "hermes.zsh"
                    managed.symlink_to(root / "managed.zsh")
                    env = {**self.env, "HOME": str(home), "ZDOTDIR": str(home),
                           "XDG_CONFIG_HOME": str(home / ".config")}
                    if section == "profile":
                        env["DOTFILES_PROFILE"] = "desktop"
                    result = subprocess.run(["zsh", str(repo / "install"), "--section", section],
                                            env=env, cwd=repo, stdin=subprocess.DEVNULL,
                                            text=True, capture_output=True, timeout=10)
                    self.assertTrue(managed.is_symlink())
                    if kind in ("regular", "missing"):
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        expected = 'DOTFILES_PROFILE="desktop"' if section == "profile" else "EDITOR=nvim"
                        self.assertIn(expected, target.read_text())
                    else:
                        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                        bad_path = config if kind == "directory_link" else target
                        self.assertIn(str(bad_path), result.stderr)
                        self.assertEqual(sentinel.read_text(), original)
                        if section == "shell":
                            self.assertFalse((home / "git-ran").exists())

    def test_sections_reject_linked_mise_and_rclone_directories(self):
        self.profile("desktop")
        repo = self.make_fixture('''
is_interactive() { return 0 }
add_secret_envs_from_vault() { return 0 }
setup_storagebox_media_mount() { touch "$HOME_DIR/storagebox-ran" }
vault_http_get() { print -r -- '{"data":{"data":{"omen_pass":"fixture"}}}' }
VAULT_TOKEN=fixture
''')
        template = repo / ".config/rclone/rclone.conf.template"
        template.parent.mkdir(parents=True)
        template.write_text("pass = {{nas_pass}}\n")
        mise_config = repo / ".config/mise/config.toml"
        mise_config.parent.mkdir(parents=True)
        mise_config.write_text("[tools]\n")
        mise = self.home / ".local/bin/mise"
        mise.parent.mkdir(parents=True)
        mise.write_text(f"#!/bin/sh\ntouch '{self.home / 'mise-ran'}'\n")
        mise.chmod(0o755)
        config = self.home / ".config"
        config.mkdir()
        foreign = self.home / "foreign"
        foreign.mkdir()
        sentinel = foreign / "keep"
        sentinel.write_text("preserve\n")
        for section, name in (("tools", "mise"), ("vault", "rclone")):
            with self.subTest(section=section):
                link = config / name
                link.symlink_to(foreign, target_is_directory=True)
                try:
                    result = subprocess.run(["zsh", str(repo / "install"), "--section", section],
                                            env=self.env, cwd=repo, input="y\n", text=True,
                                            capture_output=True, timeout=10)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("must be a real directory", result.stderr)
                    self.assertEqual(sentinel.read_text(), "preserve\n")
                    self.assertEqual(list(foreign.iterdir()), [sentinel])
                    self.assertFalse((self.home / "storagebox-ran").exists())
                    self.assertFalse((self.home / "mise-ran").exists())
                finally:
                    link.unlink()

    def test_private_section_prepares_flatpak_directory_after_submodule_setup(self):
        self.profile("desktop")
        repo = self.make_fixture('''
configure_stow_apply() { STOW_APPLY=true }
setup_private_submodule() { return 0 }
setup_herdr() { return 0 }
install_with_stow() { stow -n -v "$@" }
''')
        (self.home / ".config/atuin").mkdir(parents=True)
        (self.home / ".var/app").mkdir(parents=True)
        atuin = repo / "prv/.config/atuin/config.toml"
        atuin.parent.mkdir(parents=True)
        atuin.write_text("fixture\n")
        config = repo / "prv/.var/app/com.example.App/config/App/prefs.ini"
        config.parent.mkdir(parents=True)
        config.write_text("managed\n")
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                env=self.env, cwd=repo, stdin=subprocess.DEVNULL,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        app_target = self.home / ".var/app/com.example.App"
        self.assertTrue(app_target.is_dir())
        self.assertFalse(app_target.is_symlink())
        self.assertNotIn("LINK: .var/app/com.example.App =>", result.stderr)
        for target in (app_target / "config", app_target / "config/App"):
            self.assertTrue(target.is_dir())
            self.assertFalse(target.is_symlink())
        self.assertNotIn("LINK: .var/app/com.example.App/config =>", result.stderr)
        runtime = app_target / "config/App/runtime.dat"
        runtime.write_text("runtime\n")
        self.assertFalse((config.parent / "runtime.dat").exists())
        shutil.rmtree(app_target)
        foreign = self.home / "foreign"
        foreign.mkdir()
        sentinel = foreign / "keep"
        sentinel.write_text("preserve\n")
        app_target.symlink_to(foreign, target_is_directory=True)
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                env=self.env, cwd=repo, stdin=subprocess.DEVNULL,
                                text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(sentinel.read_text(), "preserve\n")
        self.assertEqual(list(foreign.iterdir()), [sentinel])
        app_target.unlink()
        app_target.mkdir()
        (app_target / "config").symlink_to(foreign, target_is_directory=True)
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                env=self.env, cwd=repo, stdin=subprocess.DEVNULL,
                                text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(sentinel.read_text(), "preserve\n")
        self.assertEqual(list(foreign.iterdir()), [sentinel])

    def test_private_section_rejects_linked_app_directory_before_submodule_update(self):
        self.profile("desktop")
        repo = self.make_fixture('''
configure_stow_apply() { return 0 }
setup_private_submodule() { touch "$HOME_DIR/submodule-updated" }
''')
        (self.home / ".config").mkdir()
        var = self.home / ".var"
        var.mkdir()
        foreign = self.home / "foreign"
        foreign.mkdir()
        (var / "app").symlink_to(foreign, target_is_directory=True)
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                env=self.env, cwd=repo, stdin=subprocess.DEVNULL,
                                text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("must be a real directory", result.stderr)
        self.assertFalse((self.home / "submodule-updated").exists())
        self.assertEqual(list(foreign.iterdir()), [])

    def test_full_install_prepares_nested_flatpak_directories(self):
        repo = self.make_fixture('''
configure_profile() { DOTFILES_PROFILE=desktop }
configure_stow_apply() { STOW_APPLY=true }
require_zsh_login_shell() { return 0 }
setup_private_submodule() { return 0 }
migrate_retired_managed_links() { return 0 }
stow_base_dotfiles() { return 0 }
add_secret_envs_from_vault() { return 0 }
setup_rclone() { return 0 }
setup_storagebox_media_mount() { return 0 }
print_flatpak_manual_instructions() { return 0 }
install_with_stow() { stow -n -v "$@" }
setup_herdr() { return 0 }
setup_desktop_assets() { return 0 }
configure_git_conflict_style() { return 0 }
setup_mise_desktop_tools() { return 0 }
setup_codex() { return 0 }
setup_opencode() { return 0 }
setup_antigravity_cli() { return 0 }
setup_summarize() { return 0 }
setup_editor() { return 0 }
setup_terminal_emulator() { return 0 }
setup_kde_terminal_shortcut() { return 0 }
setup_user_systemd_units() { return 0 }
''')
        atuin = repo / "prv/.config/atuin/config.toml"
        atuin.parent.mkdir(parents=True)
        atuin.write_text("fixture\n")
        for name in ("atuin/themes/theme.toml", "foot/foot.ini", "systemd/user/example.service"):
            source = repo / "prv/.config" / name
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text("fixture\n")
        config = repo / "prv/.var/app/com.example.App/config/App/prefs.ini"
        config.parent.mkdir(parents=True)
        config.write_text("managed\n")
        result = subprocess.run(["zsh", str(repo / "install")], env=self.env,
                                cwd=repo, stdin=subprocess.DEVNULL, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        app_target = self.home / ".var/app/com.example.App"
        for target in (app_target, app_target / "config", app_target / "config/App"):
            self.assertTrue(target.is_dir())
            self.assertFalse(target.is_symlink())
        self.assertNotIn("LINK: .var/app/com.example.App/config =>", result.stderr)
        for name in ("atuin/themes", "foot", "systemd/user"):
            target = self.home / ".config" / name
            self.assertTrue(target.is_dir(), name)
            self.assertFalse(target.is_symlink(), name)
            self.assertNotIn(f"LINK: .config/{name} =>", result.stderr)

    def test_vault_section_stops_after_rclone_failure(self):
        self.profile("desktop")
        repo = self.make_fixture('''
is_interactive() { return 0 }
add_secret_envs_from_vault() { return 0 }
setup_rclone() { return 42 }
setup_storagebox_media_mount() { touch "$HOME_DIR/storagebox-ran" }
''')
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "vault"],
                                env=self.env, cwd=repo, stdin=subprocess.DEVNULL,
                                text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / "storagebox-ran").exists())

    def test_desktop_section_rejects_linked_config_before_kde_write(self):
        self.profile("desktop")
        repo = self.make_fixture('''
setup_terminal_emulator() { return 0 }
setup_user_systemd_units() { return 0 }
has() { [[ "$1" == kwriteconfig6 || "$1" == foot ]] }
kwriteconfig6() { touch "$CONFIG_DIR/kde-write" }
''')
        foreign = self.home / "foreign"
        foreign.mkdir()
        (self.home / ".config").symlink_to(foreign, target_is_directory=True)
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "desktop"],
                                env=self.env, cwd=repo, stdin=subprocess.DEVNULL,
                                text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("must be a real directory", result.stderr)
        self.assertEqual(list(foreign.iterdir()), [])

    def test_desktop_section_requires_private_units_before_changes(self):
        self.profile("desktop")
        repo = self.make_fixture('''
setup_terminal_emulator() { touch "$HOME_DIR/terminal-ran" }
setup_kde_terminal_shortcut() { touch "$HOME_DIR/kde-ran" }
setup_user_systemd_units() { touch "$HOME_DIR/units-ran" }
''')
        (self.home / ".config").mkdir()
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "desktop"],
                                env=self.env, cwd=repo, text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("private", result.stderr)
        for name in ("terminal-ran", "kde-ran", "units-ran"):
            self.assertFalse((self.home / name).exists())

        unit_dir = self.home / ".config/systemd/user"
        unit_dir.mkdir(parents=True)
        for name in ("docker-prune.service", "docker-prune.timer", "rclone-nas.service",
                     "rclone-sleep-handler.service"):
            (unit_dir / name).write_text("fixture\n")
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "desktop"],
                                env=self.env, cwd=repo, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / "units-ran").exists())

    def test_private_section_keeps_desktop_runtime_directories_local(self):
        self.profile("desktop")
        repo = self.make_fixture('''
setup_private_submodule() { return 0 }
prepare_private_flatpak_targets() { return 0 }
setup_herdr() { return 0 }
''')
        (self.home / ".config").mkdir()
        (self.home / ".var/app").mkdir(parents=True)
        relative_files = ("atuin/config.toml", "atuin/themes/catppuccin-latte-blue.toml",
                          "foot/foot.ini", "foot/catppuccin-latte.ini",
                          "systemd/user/docker-prune.timer", "systemd/user/docker-prune.service",
                          "systemd/user/rclone-nas.service", "systemd/user/rclone-sleep-handler.service")
        for name in relative_files:
            source = repo / "prv/.config" / name
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text("fixture\n")
        env = {**self.env, "DOTFILES_STOW_CONFIRM_APPLY": "1"}

        def run_private():
            return subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                  env=env, cwd=repo, text=True, capture_output=True, timeout=10)

        result = run_private()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for directory in ("atuin", "atuin/themes", "foot", "systemd", "systemd/user"):
            target = self.home / ".config" / directory
            self.assertTrue(target.is_dir(), directory)
            self.assertFalse(target.is_symlink(), directory)
        for name in relative_files:
            target = self.home / ".config" / name
            self.assertTrue(target.is_symlink(), name)
            self.assertEqual(target.resolve(), repo / "prv/.config" / name)
        for name in ("atuin/themes/runtime.theme", "foot/runtime.ini", "systemd/user/docker.service"):
            target = self.home / ".config" / name
            target.write_text("runtime\n")
            self.assertFalse((repo / "prv/.config" / name).exists())
        repeated = run_private()
        self.assertEqual(repeated.returncode, 0, repeated.stdout + repeated.stderr)

    def test_private_section_rejects_directory_link_created_during_preparation(self):
        self.profile("desktop")
        repo = self.make_fixture('''
setup_private_submodule() { return 0 }
prepare_private_flatpak_targets() {
  ln -s "$(realpath --relative-to="$CONFIG_DIR" "$BASE_DIR/prv/.config/foot")" "$CONFIG_DIR/foot"
}
setup_herdr() { return 0 }
''')
        (self.home / ".config").mkdir()
        (self.home / ".var/app").mkdir(parents=True)
        source = repo / "prv/.config/foot/foot.ini"
        source.parent.mkdir(parents=True)
        source.write_text("fixture\n")
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                env={**self.env, "DOTFILES_STOW_CONFIRM_APPLY": "1"},
                                cwd=repo, text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / ".config/foot").is_symlink())
        self.assertFalse((source.parent / "runtime.ini").exists())

    def test_private_section_rejects_directory_link_created_during_mkdir(self):
        self.profile("desktop")
        repo = self.make_fixture('''
setup_private_submodule() { return 0 }
prepare_private_flatpak_targets() { return 0 }
setup_herdr() { return 0 }
mkdir() {
  if [[ "$1" == -p && "$2" == "$CONFIG_DIR/foot" ]]; then
    ln -s "$(realpath --relative-to="$CONFIG_DIR" "$BASE_DIR/prv/.config/foot")" "$CONFIG_DIR/foot"
  fi
  command mkdir "$@"
}
''')
        (self.home / ".config").mkdir()
        (self.home / ".var/app").mkdir(parents=True)
        source = repo / "prv/.config/foot/foot.ini"
        source.parent.mkdir(parents=True)
        source.write_text("fixture\n")
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                env={**self.env, "DOTFILES_STOW_CONFIRM_APPLY": "1"},
                                cwd=repo, text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / ".config/foot").is_symlink())
        self.assertFalse((source.parent / "runtime.ini").exists())

    def test_make_targets_route_to_installer_even_when_a_target_file_exists(self):
        repo = self.make_fixture("")
        shutil.copy(ROOT / "Makefile", repo / "Makefile")
        (repo / "install-vault").touch()
        for target, message in (("install-vault", "no saved profile"),
                                ("install-desktop-assets", "no saved profile"),
                                ("install-unknown", "unknown section"),
                                ("install-bad'$(touch pwn)", "unknown section")):
            with self.subTest(target=target):
                result = subprocess.run(["make", "-s", "-C", str(repo), target],
                                        env=self.env, cwd=repo, stdin=subprocess.DEVNULL,
                                        text=True, capture_output=True, timeout=10)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(message, result.stderr)
                self.assertFalse((repo / "pwn").exists())

    def test_private_section_creates_real_atuin_directory(self):
        self.profile("desktop")
        repo = self.make_fixture('''
setup_private_submodule() { return 0 }
prepare_private_flatpak_targets() { return 0 }
setup_herdr() { return 0 }
''')
        (self.home / ".var/app").mkdir(parents=True)
        atuin_dir = self.home / ".config/atuin"
        atuin_dir.parent.mkdir(parents=True)
        source = repo / "prv/.config/atuin/config.toml"
        source.parent.mkdir(parents=True)
        source.write_text("fixture\n")
        env = {**self.env, "DOTFILES_STOW_CONFIRM_APPLY": "1"}
        foreign = self.home / "foreign"
        foreign.mkdir()
        atuin_dir.symlink_to(foreign, target_is_directory=True)
        conflict = subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                  env=env, cwd=repo, text=True, capture_output=True, timeout=10)
        self.assertNotEqual(conflict.returncode, 0, conflict.stdout + conflict.stderr)
        self.assertEqual(list(foreign.iterdir()), [])
        atuin_dir.unlink()
        result = subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                env=env, cwd=repo, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(atuin_dir.is_dir())
        self.assertFalse(atuin_dir.is_symlink())
        self.assertEqual((atuin_dir / "config.toml").resolve(), source)
        (atuin_dir / "history.db").write_text("runtime\n")
        self.assertFalse((source.parent / "history.db").exists())

    def test_private_section_stows_atuin_without_replacing_local_config(self):
        self.profile("desktop")
        repo = self.make_fixture('''
setup_private_submodule() { return 0 }
prepare_private_flatpak_targets() { return 0 }
setup_herdr() { return 0 }
''')
        (self.home / ".var/app").mkdir(parents=True)
        target = self.home / ".config/atuin/config.toml"
        target.parent.mkdir(parents=True)
        target.write_text("local\n")
        source = repo / "prv/.config/atuin/config.toml"
        source.parent.mkdir(parents=True)
        source.write_text("managed\n")
        env = {**self.env, "DOTFILES_STOW_CONFIRM_APPLY": "1"}

        def run_private():
            return subprocess.run(["zsh", str(repo / "install"), "--section", "private"],
                                  env=env, cwd=repo, text=True, capture_output=True, timeout=10)

        conflict = run_private()
        self.assertNotEqual(conflict.returncode, 0, conflict.stdout + conflict.stderr)
        self.assertEqual(target.read_text(), "local\n")
        target.unlink()
        for _ in range(2):
            result = run_private()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), source)


if __name__ == "__main__":
    unittest.main()
