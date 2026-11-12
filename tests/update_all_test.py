#!/usr/bin/python3
"""Offline regression checks for update-all's user command runner."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MISE = shutil.which("mise")


class UpdateAllTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "user's home"
        self.home.mkdir()
        self.caller = self.base / "caller"
        self.caller.mkdir()
        # Load only the production runner; never source shell startup or run updates.
        self.runner = re.search(
            r"^  run_for_target_user \(\) \{\n.*?^  \}",
            (ROOT / ".zshrc").read_text(), re.MULTILINE | re.DOTALL,
        ).group()
        self.update_all = re.search(
            r"^function update-all \(\) \{\n.*?^\}",
            (ROOT / ".zshrc").read_text(), re.MULTILINE | re.DOTALL,
        ).group()

    def make_update_all_fixture(self, mise_installed, target_profile=None):
        self.repository = self.base / "dotfiles"
        self.repository.mkdir()
        completion_dir = self.repository / "bin"
        completion_dir.mkdir()
        self.completion_log = self.base / "completion.log"
        self.completion_policy_log = self.base / "completion-policy.log"
        completion_script = completion_dir / "update-shell-completions"
        completion_script.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$MISE_CONFIG_DIR" >> "$TEST_COMPLETION_LOG"\n'
            'printf "%s\\n" "${MISE_GLOBAL_CONFIG_FILE-unset}" "${MISE_CEILING_PATHS-unset}" > "$TEST_COMPLETION_POLICY_LOG"\n'
        )
        completion_script.chmod(0o755)
        (self.repository / ".zshrc").touch()
        (self.home / ".zshrc").symlink_to(self.repository / ".zshrc")
        if target_profile is not None:
            profile_file = self.home / ".zshrc.d/profile.zsh"
            profile_file.parent.mkdir(parents=True)
            profile_file.write_text(f'export DOTFILES_PROFILE="{target_profile}"\n')

        self.mise_log = self.base / "mise.log"
        self.mise_policy_log = self.base / "mise-policy.log"
        self.mise_system_config_log = self.base / "mise-system-config.log"
        self.nvim_log = self.base / "nvim.log"
        tool_bin = self.home / ".local/bin"
        tool_bin.mkdir(parents=True)
        for tool in ("nvim", "npx"):
            stub = tool_bin / tool
            stub.write_text("#!/bin/sh\nexit 0\n")
            stub.chmod(0o755)
        (tool_bin / "nvim").write_text(
            '#!/bin/sh\nprintf "%s\\n" "${DOTFILES_PROFILE-unset}" >> "$TEST_NVIM_LOG"\n'
        )
        if mise_installed:
            mise_bin = tool_bin / "mise"
            mise_bin.write_text(
                '#!/bin/sh\nprintf "%s|%s\\n" "$*" "$MISE_CONFIG_DIR" >> "$TEST_MISE_LOG"\n'
                'printf "%s|%s|%s\\n" "$*" "${MISE_GLOBAL_CONFIG_FILE-unset}" "${MISE_CEILING_PATHS-unset}" >> "$TEST_MISE_POLICY_LOG"\n'
                'printf "%s\\n" "${MISE_SYSTEM_CONFIG_FILE-unset}" >> "$TEST_MISE_SYSTEM_CONFIG_LOG"\n'
                'printf "%s\\n" "${MISE_SELF_UPDATE_AUTO-unset}" >> "$TEST_MISE_AUTO_UPDATE_LOG"\n'
                'if [ "$1" = upgrade ]; then exit "${TEST_MISE_UPGRADE_EXIT:-0}"; fi\n'
            )
            mise_bin.chmod(0o755)

    def run_update_all(
        self, caller_profile, target_profile, mise_installed, config_exists=False,
        caller_config=None,
        upgrade_exit=0,
        config_link=None,
        system_config=None,
    ):
        self.make_update_all_fixture(mise_installed, target_profile)
        if config_exists:
            if target_profile == "server":
                mise_config = self.home / ".config/mise"
                mise_config.mkdir(parents=True)
            else:
                mise_config = self.repository / ".config/mise"
                mise_config.mkdir(parents=True)
                (self.home / ".config").mkdir()
                (self.home / ".config/mise").symlink_to(mise_config)
            (mise_config / "config.toml").write_text("[tools]\n")
            if config_link == "directory":
                linked_config = self.repository / "linked-config"
                mise_config.rename(linked_config)
                mise_config.symlink_to(linked_config, target_is_directory=True)
            elif config_link == "file":
                config_file = mise_config / "config.toml"
                linked_config = self.repository / "linked-config.toml"
                config_file.rename(linked_config)
                config_file.symlink_to(linked_config)
        env = dict(os.environ)
        env.pop("MISE_CONFIG_DIR", None)
        env["MISE_GLOBAL_CONFIG_FILE"] = "/caller/config.toml"
        env["MISE_CEILING_PATHS"] = "/caller"
        if system_config is not None:
            env["MISE_SYSTEM_CONFIG_FILE"] = str(system_config)
        if caller_config is not None:
            env["MISE_CONFIG_DIR"] = str(caller_config)
        setup = '''
target_user=fixture
target_home="$TEST_TARGET_HOME"
user_tool_env_path="$target_home/.local/share/mise/shims:$target_home/.local/bin:/usr/local/bin:/usr/bin:/bin"
ZINIT_SCRIPT_REL=.zinit/bin/zinit.zsh
is_desktop() { [[ "$DOTFILES_PROFILE" == desktop ]]; }
getent() { printf "fixture:x:1000:1000::%s:/bin/zsh\\n" "$TEST_TARGET_HOME"; }
has() { return 1; }
update() { return 0; }
sudo() {
  [[ "$1" == -H && "$2" == -u && "$3" == fixture ]] || return 90
  shift 3
  HOME="$TEST_TARGET_HOME" /usr/bin/env -u DOTFILES_PROFILE "$@"
}
'''
        return subprocess.run(
            ["/usr/bin/zsh", "-f", "-c", setup + self.update_all + "\nupdate-all"],
            cwd=self.caller,
            env=dict(
                env,
                TEST_TARGET_HOME=str(self.home),
                TEST_MISE_LOG=str(self.mise_log),
                TEST_MISE_POLICY_LOG=str(self.mise_policy_log),
                TEST_MISE_SYSTEM_CONFIG_LOG=str(self.mise_system_config_log),
                TEST_MISE_AUTO_UPDATE_LOG=str(self.base / "mise-auto-update.log"),
                TEST_MISE_UPGRADE_EXIT=str(upgrade_exit),
                TEST_NVIM_LOG=str(self.nvim_log),
                TEST_COMPLETION_LOG=str(self.completion_log),
                TEST_COMPLETION_POLICY_LOG=str(self.completion_policy_log),
                SUDO_USER="fixture",
                DOTFILES_PROFILE=caller_profile,
            ),
            text=True, capture_output=True,
        )

    def run_command(self, command):
        return subprocess.run(
            ["/usr/bin/zsh", "-f", "-c", '''
target_user=fixture
target_home="$TEST_TARGET_HOME"
user_tool_env_path=/usr/bin:/bin
target_mise_config_dir="$target_home/.config/mise"
typeset -a target_mise_policy=()
# Replace only the privilege boundary, preserving the caller's working directory.
sudo() {
  [[ "$1" == -H && "$2" == -u && "$3" == fixture ]] || return 90
  shift 3
  HOME="$target_home" "$@"
}
''' + self.runner + '\nrun_for_target_user "$1"', "test", command],
            cwd=self.caller,
            env=dict(os.environ, TEST_TARGET_HOME=str(self.home)),
            text=True, capture_output=True,
        )

    def test_command_runs_from_target_home_with_target_environment(self):
        result = self.run_command(
            'printf "%s\\n" "$PWD" "$HOME" "$MISE_CONFIG_DIR"'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            str(self.home), str(self.home),
            str(self.home / ".config/mise"),
        ])

    def test_missing_home_prevents_command_execution(self):
        self.home = self.base / "missing home"
        result = self.run_command('printf "command executed\\n"')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_server_without_mise_succeeds_without_a_mise_config(self):
        result = self.run_update_all(
            "desktop", None, mise_installed=False
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Skipping mise update", result.stdout)
        self.assertEqual(self.nvim_log.read_text().splitlines(), ["server"])
        self.assertEqual(
            self.completion_log.read_text().splitlines(),
            [f"{self.home}/.config/mise"],
        )

    def test_nvim_uses_target_desktop_profile_after_sudo_clears_environment(self):
        result = self.run_update_all(
            "server", "desktop", mise_installed=True, config_exists=True
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.nvim_log.read_text().splitlines(), ["desktop"])

    def test_nvim_uses_target_server_profile_after_sudo_clears_environment(self):
        result = self.run_update_all("desktop", "server", mise_installed=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.nvim_log.read_text().splitlines(), ["server"])

    def test_desktop_without_mise_fails_even_when_caller_is_server(self):
        result = self.run_update_all(
            "server", "desktop", mise_installed=False, config_exists=True
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("mise-missing", result.stderr)

    def test_desktop_missing_config_fails_before_mise_updates(self):
        result = self.run_update_all("desktop", "desktop", mise_installed=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Target config not found", result.stderr)
        self.assertFalse(self.mise_log.exists())

    def test_caller_mise_config_does_not_redirect_target_updates_or_completions(self):
        expected = self.home / ".config/mise"
        system_config = self.base / "system.toml"
        result = self.run_update_all(
            "server", "desktop", mise_installed=True, config_exists=True,
            caller_config=self.base / "caller's config",
            system_config=system_config,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.mise_log.read_text().splitlines(), [
            f"self-update -y --no-plugins|{expected}",
            f"upgrade|{expected}",
            f"prune -y|{expected}",
        ])
        self.assertEqual(self.completion_log.read_text().splitlines(), [str(expected)])
        self.assertEqual(self.completion_policy_log.read_text().splitlines(), ["unset", "unset"])
        self.assertEqual(self.mise_system_config_log.read_text().splitlines(), [str(system_config)] * 3)

    def test_caller_mise_config_does_not_redirect_server_completions(self):
        result = self.run_update_all(
            "desktop", "server", mise_installed=True,
            caller_config=Path("relative config"),
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.mise_log.exists())
        self.assertEqual(self.completion_log.read_text().splitlines(), [
            str(self.home / ".config/mise"),
        ])
        self.assertEqual(self.completion_policy_log.read_text().splitlines(), [
            str(self.home / ".config/mise/config.toml"), str(self.home),
        ])

    def test_server_upgrades_tools_from_managed_config_without_self_update_or_prune(self):
        result = self.run_update_all(
            "desktop", "server", mise_installed=True, config_exists=True,
            caller_config=Path("relative config"),
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.mise_log.read_text().splitlines(), [
            f"upgrade --global --no-prune|{self.home}/.config/mise",
        ])
        self.assertEqual(self.mise_policy_log.read_text().splitlines(), [
            f"upgrade --global --no-prune|{self.home}/.config/mise/config.toml|{self.home}",
        ])
        self.assertEqual((self.base / "mise-auto-update.log").read_text().splitlines(), ["false"])
        self.assertEqual((self.home / ".config/mise/config.toml").read_text(), "[tools]\n")

    def test_server_upgrade_failure_is_reported_and_completions_still_run(self):
        result = self.run_update_all(
            "desktop", "server", mise_installed=True, config_exists=True, upgrade_exit=42,
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("mise", result.stderr)
        self.assertIn("exit 42", result.stdout)
        self.assertIn("retry update-all", result.stdout)
        self.assertTrue(self.completion_log.exists())

    @unittest.skipUnless(MISE, "real mise executable is required")
    def test_server_policy_excludes_system_tools_with_real_mise(self):
        system_config = self.base / "system.toml"
        system_config.write_text('[tools]\nnode = "22.0.0"\n')
        result = self.run_update_all(
            "desktop", "server", mise_installed=True, config_exists=True,
            system_config=system_config,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        _, global_config, ceiling = self.mise_policy_log.read_text().strip().split("|")
        Path(global_config).write_text('[tools]\njq = "1.8.1"\n')
        env = {"HOME": str(self.home), "PATH": "/usr/bin:/bin", "MISE_OFFLINE": "1",
               "MISE_CONFIG_DIR": str(self.home / ".config/mise"),
               "MISE_GLOBAL_CONFIG_FILE": global_config, "MISE_CEILING_PATHS": ceiling,
               "MISE_SYSTEM_CONFIG_FILE": self.mise_system_config_log.read_text().strip(),
               "XDG_CONFIG_HOME": str(self.home / ".config"),
               "XDG_DATA_HOME": str(self.home / ".local/share"),
               "XDG_STATE_HOME": str(self.home / ".local/state"),
               "XDG_CACHE_HOME": str(self.home / ".cache")}
        listed = subprocess.run([MISE, "ls", "--current", "--global", "--json"],
                                cwd=self.home, env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertEqual(set(json.loads(listed.stdout)), {"jq"})
        self.assertEqual(system_config.read_text(), '[tools]\nnode = "22.0.0"\n')

    def test_server_refuses_linked_mise_directory_before_updating_tools(self):
        result = self.run_update_all(
            "desktop", "server", mise_installed=True, config_exists=True, config_link="directory",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("real directory", result.stderr)
        self.assertFalse(self.mise_log.exists())

    def test_server_refuses_linked_mise_config_before_updating_tools(self):
        result = self.run_update_all(
            "desktop", "server", mise_installed=True, config_exists=True, config_link="file",
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("regular file", result.stderr)
        self.assertFalse(self.mise_log.exists())

    def test_invalid_target_profile_fails_loudly(self):
        result = self.run_update_all(
            "desktop", "unknown", mise_installed=True
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid DOTFILES_PROFILE 'unknown'", result.stderr)

    def test_zshenv_leaves_mise_discovery_to_default_or_explicit_config(self):
        def run_zshenv(explicit_config=None):
            env = dict(os.environ, TEST_DOTFILES_ROOT=str(ROOT))
            env.pop("MISE_CONFIG_DIR", None)
            if explicit_config is not None:
                env["MISE_CONFIG_DIR"] = explicit_config
            return subprocess.run(
                [
                    "/usr/bin/zsh", "-f", "-c",
                    'source "$TEST_DOTFILES_ROOT/.zshenv"; print -r -- "${MISE_CONFIG_DIR:-__unset__}"',
                ],
                env=env, text=True, capture_output=True,
            )

        default = run_zshenv()
        self.assertEqual(default.returncode, 0, default.stderr)
        self.assertEqual(default.stdout.strip(), "__unset__")
        explicit = run_zshenv("/custom/mise/config")
        self.assertEqual(explicit.returncode, 0, explicit.stderr)
        self.assertEqual(explicit.stdout.strip(), "/custom/mise/config")


if __name__ == "__main__":
    unittest.main()
