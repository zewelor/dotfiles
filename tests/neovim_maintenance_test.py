"""Check the plugin-maintenance command boundary with isolated homes and fake tools."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
LAZY = Path.home() / ".local/share/nvim/lazy/lazy.nvim"


class NeovimMaintenanceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-maintenance-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "target home"
        self.caller = self.base / "foreign-project"
        self.home.mkdir()
        self.caller.mkdir()
        (self.caller / "mise.toml").write_text('[tools]\nnode = "caller"\n')
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        self.log = self.home / "nvim.log"
        self.mise_log = self.home / "mise.log"
        self.env = dict(os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
                        DOTFILES_PROFILE="server", MISE_CONFIG_DIR=str(self.caller),
                        XDG_CONFIG_HOME=str(self.caller), XDG_DATA_HOME=str(self.caller),
                        NVIM_APPNAME="foreign", TEST_NVIM_LOG=str(self.log),
                        TEST_MISE_LOG=str(self.mise_log))
        self.write_tool("nvim", '''
if [ "$1" = --version ]; then printf 'NVIM v%s\\n' "${TEST_NVIM_VERSION:-0.11.6}"; exit 0; fi
printf '%s\\n' "$PWD" "$HOME" "$DOTFILES_PROFILE" "$MISE_CONFIG_DIR" \\
  "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$NVIM_APPNAME" "$*" > "$TEST_NVIM_LOG"
exit "${TEST_NVIM_EXIT:-0}"
''')
        self.write_tool("mise", 'printf "%s\\n" "$*" >> "$TEST_MISE_LOG"\nexit 0\n')
        self.write_tool("make", 'exit 0\n')
        self.write_tool("cc", 'exit 0\n')
        # These deliberately fail if maintenance tries to invoke runtimes that are
        # not prerequisites for Neovim plugin maintenance.
        for tool in ("node", "npm", "python3", "go"):
            self.write_tool(tool, f'printf "%s\\n" called >> "$HOME/{tool}.log"\nexit 42\n')

    def write_tool(self, name, body):
        tool = self.bin / name
        tool.write_text("#!/bin/sh\n" + body)
        tool.chmod(0o755)

    def profile(self, value):
        path = self.home / ".zshrc.d/profile.zsh"
        path.parent.mkdir(exist_ok=True)
        path.write_text(f'export DOTFILES_PROFILE={value}\n')

    def base_config(self):
        config = self.home / ".config/nvim"
        config.mkdir(parents=True)
        (config / "init.lua").symlink_to(ROOT / ".config/nvim/init.lua")
        (config / "lua").symlink_to(ROOT / ".config/nvim/lua", target_is_directory=True)
        mise = self.home / ".config/mise"
        mise.mkdir()
        (mise / "config.toml").write_text("[tools]\n")

    def run_helper(self, stage="plugins", mode="install"):
        return subprocess.run(["/usr/bin/zsh", str(ROOT / "bin/maintain-neovim"), stage, mode],
                              env=self.env, cwd=self.caller, text=True, capture_output=True, timeout=10)

    def test_desktop_plugins_use_target_home_and_need_no_language_runtimes(self):
        self.profile("desktop")
        self.base_config()
        result = self.run_helper("plugins", "install")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        lines = self.log.read_text().splitlines()
        self.assertEqual(lines[:7], [str(self.home), str(self.home), "desktop",
                                    str(self.home / ".config/mise"), str(self.home / ".config"),
                                    str(self.home / ".local/share"), "nvim"])
        self.assertTrue(lines[7].endswith("maintain.lua plugins install"), lines[7])
        self.assertFalse(self.mise_log.exists(), "plugin maintenance must not install or update mise tools")
        for tool in ("node", "npm", "python3", "go"):
            self.assertFalse((self.home / f"{tool}.log").exists(),
                             f"plugin maintenance invoked the {tool} runtime")
        self.assertEqual(list(self.caller.iterdir()), [self.caller / "mise.toml"])

    def test_helper_rejects_the_removed_tools_stage_before_running_neovim(self):
        self.profile("desktop")
        self.base_config()
        result = self.run_helper("tools", "install")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Usage: maintain-neovim plugins install|update", result.stderr)
        self.assertFalse(self.log.exists())
        self.assertFalse(self.mise_log.exists())

    def test_server_updates_plugins_but_cannot_install_them(self):
        self.profile("server")
        self.base_config()
        self.env["DOTFILES_PROFILE"] = "desktop"
        result = self.run_helper("plugins", "update")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.log.read_text().splitlines()[2], "server")
        self.log.unlink()

        result = self.run_helper("plugins", "install")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("desktop profile", result.stderr)
        self.assertFalse(self.log.exists())

    def test_unknown_profile_and_missing_base_fail_before_neovim(self):
        self.profile("unknown")
        self.base_config()
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("invalid saved Neovim profile", result.stderr)
        self.assertFalse(self.log.exists())

        self.profile("desktop")
        (self.home / ".config/nvim/init.lua").unlink()
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("install-base", result.stderr)
        self.assertFalse(self.log.exists())

    def test_old_neovim_fails_before_maintenance(self):
        self.profile("desktop")
        self.base_config()
        self.env["TEST_NVIM_VERSION"] = "0.10.4"
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("0.11", result.stderr)
        self.assertFalse(self.log.exists())

    def test_desktop_requires_mise(self):
        self.profile("desktop")
        self.base_config()
        (self.bin / "mise").unlink()
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("mise", result.stderr)
        self.assertFalse(self.log.exists())

    def test_process_failure_propagates(self):
        self.profile("desktop")
        self.base_config()
        self.env["TEST_NVIM_EXIT"] = "42"
        result = self.run_helper("plugins", "update")
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)


@unittest.skipUnless(NVIM and LAZY.is_dir(), "installed Neovim and lazy.nvim sources are required")
class NeovimPluginMaintenanceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-lazy-maintenance-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home), DOTFILES_PROFILE="server",
                        XDG_CONFIG_HOME=str(self.home / ".config"),
                        XDG_DATA_HOME=str(self.home / ".local/share"),
                        XDG_STATE_HOME=str(self.home / ".local/state"),
                        XDG_CACHE_HOME=str(self.home / ".cache"), NVIM_APPNAME="nvim",
                        GIT_CONFIG_GLOBAL=str(self.home / ".gitconfig"), GIT_CONFIG_SYSTEM="/dev/null")
        # Copy manager state too: the test may update refs or build local fixtures.
        shutil.copytree(LAZY, self.home / ".local/share/nvim/lazy/lazy.nvim")
        subprocess.run(["git", "-C", str(self.home / ".local/share/nvim/lazy/lazy.nvim"),
                        "remote", "set-url", "origin", "https://github.com/folke/lazy.nvim.git"], env=self.env,
                       check=True, capture_output=True, timeout=10)
        subprocess.run(["git", "config", "--file", str(self.home / ".gitconfig"),
                        "url." + LAZY.as_uri() + ".insteadOf", "https://github.com/folke/lazy.nvim.git"], env=self.env,
                       check=True, capture_output=True, timeout=10)
        self.remote = self.home / "remote"
        self.remote.mkdir()
        self.git("init", "--initial-branch=main")
        (self.remote / "plugin").mkdir()
        (self.remote / "plugin/fixture.lua").write_text("vim.g.fixture_loaded = true\n")
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "-m", "Fixture plugin")
        lua = self.home / ".config/nvim/lua"
        (lua / "config").mkdir(parents=True)
        (lua / "config/lazy.lua").symlink_to(ROOT / ".config/nvim/lua/config/lazy.lua")
        (lua / "plugins").mkdir()
        (lua / "plugins/fixture.lua").write_text('''
return {
  { "folke/lazy.nvim", pin = true },
  {
    "fixture/managed", url = %s, lazy = true,
    build = function()
      assert(vim.env.TEST_BUILD_FAILURE ~= "1", "controlled build failure")
      vim.fn.writefile({ "built" }, vim.env.HOME .. "/build.log", "a")
    end,
  },
}
''' % json.dumps(self.remote.as_uri()))

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.remote), *args], env=self.env,
                              check=True, text=True, capture_output=True, timeout=10)

    def run_stage(self, mode="install"):
        return subprocess.run([NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n",
                               "-l", str(ROOT / ".config/nvim/maintain.lua"), "plugins", mode],
                              env=self.env, cwd=self.home, text=True, capture_output=True, timeout=30)

    def test_real_lazy_installs_missing_plugin_without_updating_it_on_repeat(self):
        result = self.run_stage()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        plugin = self.home / ".local/share/nvim/lazy/managed/plugin/fixture.lua"
        self.assertTrue(plugin.is_file())
        (self.remote / "plugin/fixture.lua").write_text("vim.g.fixture_loaded = 'new'\n")
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "-m", "New upstream version")
        result = self.run_stage()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("= true", plugin.read_text())
        self.assertEqual((self.home / "build.log").read_text().splitlines(), ["built"])
        result = self.run_stage("update")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("= 'new'", plugin.read_text())

    def test_real_lazy_build_failure_reaches_process_exit(self):
        self.env["TEST_BUILD_FAILURE"] = "1"
        result = self.run_stage()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("controlled build failure", result.stdout + result.stderr)

    def test_real_lazy_retries_failed_build_without_updating_or_rebuilding_healthy_plugins(self):
        for retry_mode in ("install", "update"):
            with self.subTest(retry_mode=retry_mode):
                self.env["TEST_BUILD_FAILURE"] = "1"
                result = self.run_stage()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse((self.home / "build.log").exists())
                plugin_file = self.home / ".local/share/nvim/lazy/managed/plugin/fixture.lua"
                checkout = plugin_file.read_text()
                if retry_mode == "install":
                    (self.remote / "plugin/fixture.lua").write_text("vim.g.fixture_loaded = 'upstream changed'\n")
                    self.git("add", ".")
                    self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                             "commit", "-m", "Unrelated upstream change")
                result = self.run_stage(retry_mode)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.env.pop("TEST_BUILD_FAILURE")
                result = self.run_stage(retry_mode)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if retry_mode == "install":
                    self.assertEqual(plugin_file.read_text(), checkout, "retry install upgraded the checkout")
                builds = (self.home / "build.log").read_text().splitlines()
                self.assertTrue(builds and all(line == "built" for line in builds))
                result = self.run_stage("install")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.home / "build.log").read_text().splitlines(), builds)
                shutil.rmtree(self.home / ".local/share/nvim/lazy/managed")
                (self.home / "build.log").unlink()

    def test_real_lazy_fetch_failure_errors_with_existing_plugin(self):
        result = self.run_stage()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.remote.rename(self.home / "offline-remote")
        result = self.run_stage("update")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / ".local/share/nvim/lazy/managed").is_dir())


if __name__ == "__main__":
    unittest.main()
