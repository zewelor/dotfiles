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
        self.dprint_log = self.home / "dprint.log"
        self.env = dict(os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
                        DOTFILES_PROFILE="server", MISE_CONFIG_DIR=str(self.caller),
                        XDG_CONFIG_HOME=str(self.caller), XDG_DATA_HOME=str(self.caller),
                        NVIM_APPNAME="foreign", TEST_NVIM_LOG=str(self.log),
                        TEST_MISE_LOG=str(self.mise_log))
        self.env.update(DPRINT_CONFIG_DIR=str(self.caller), DPRINT_CACHE_DIR=str(self.caller),
                        TEST_DPRINT_LOG=str(self.dprint_log))
        self.write_tool("nvim", '''
if [ "$1" = --version ]; then printf 'NVIM v%s\\n' "${TEST_NVIM_VERSION:-0.11.6}"; exit 0; fi
printf '%s\\n' "$PWD" "$HOME" "$DOTFILES_PROFILE" "$MISE_CONFIG_DIR" \\
  "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$NVIM_APPNAME" "$*" > "$TEST_NVIM_LOG"
exit "${TEST_NVIM_EXIT:-0}"
''')
        self.write_tool("mise", 'printf "%s\\n" "$*" >> "$TEST_MISE_LOG"\nexit 0\n')
        self.write_tool("make", 'exit 0\n')
        self.write_tool("cc", 'exit 0\n')
        self.write_tool("tree-sitter", 'echo "tree-sitter 0.26.1"\n')
        self.write_tool("dprint", '''
printf '%s|%s|%s|%s\\n' "$*" "$DPRINT_CONFIG_DIR" "$DPRINT_CACHE_DIR" "$PWD" >> "$TEST_DPRINT_LOG"
if [ "$1 $2" = 'config update' ]; then
  [ "${TEST_DPRINT_UPDATE_EXIT:-0}" = 0 ] || exit "$TEST_DPRINT_UPDATE_EXIT"
  config="$DPRINT_CONFIG_DIR/dprint.jsonc"
  updated=$(sed 's/oxc@[^"]*/oxc@0.99.0/' "$config")
  printf '%s\\n' "$updated" > "$config"
fi
exit "${TEST_DPRINT_EXIT:-0}"
''')
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
        self.repo_config = self.base / "dotfiles/.config/dprint/dprint.jsonc"
        self.repo_config.parent.mkdir(parents=True)
        self.repo_config.write_bytes((ROOT / ".config/dprint/dprint.jsonc").read_bytes())
        dprint = self.home / ".config/dprint"
        dprint.mkdir()
        (dprint / "dprint.jsonc").symlink_to(self.repo_config)

    def run_helper(self, stage="plugins", mode="install"):
        return subprocess.run(["/usr/bin/zsh", str(ROOT / "bin/maintain-neovim"), stage, mode],
                              env=self.env, cwd=self.caller, text=True, capture_output=True, timeout=10)

    def test_preflight_checks_requirements_without_running_maintenance(self):
        self.profile("desktop")
        self.base_config()
        result = self.run_helper(mode="check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.log.exists())
        self.assertFalse(self.mise_log.exists())
        self.assertFalse(self.dprint_log.exists())
        self.env["TEST_NVIM_VERSION"] = "0.11.2"
        result = self.run_helper(mode="check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("0.11.3", result.stderr)
        self.env["TEST_NVIM_VERSION"] = "0.11.6"
        (self.home / ".config/nvim/init.lua").unlink()
        result = self.run_helper(mode="check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("install-base", result.stderr)
        self.assertFalse(self.log.exists())
        self.assertFalse(self.mise_log.exists())

    def test_server_installs_and_updates_plugins_without_desktop_tools(self):
        self.profile("server")
        self.base_config()
        self.env["DOTFILES_PROFILE"] = "desktop"
        for tool in ("mise", "make", "cc", "tree-sitter", "dprint"):
            self.write_tool(tool, 'printf called >> "$HOME/' + tool + '.log"\nexit 42\n')
        for mode in ("check", "install", "update"):
            with self.subTest(mode=mode):
                self.log.unlink(missing_ok=True)
                result = self.run_helper("plugins", mode)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if mode == "check":
                    self.assertFalse(self.log.exists())
                else:
                    lines = self.log.read_text().splitlines()
                    self.assertEqual(lines[2], "server")
                    self.assertTrue(lines[7].endswith(f"maintain.lua plugins {mode}"), lines[7])
                for tool in ("mise", "make", "cc", "tree-sitter", "dprint", "node", "npm", "python3", "go"):
                    self.assertFalse((self.home / (tool + ".log")).exists(), tool)

    def test_exact_minimum_neovim_runs_maintenance(self):
        self.profile("server")
        self.base_config()
        self.env["TEST_NVIM_VERSION"] = "0.11.3"
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.log.exists())

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

    def test_global_formatter_install_preserves_config_and_update_changes_repo_pin(self):
        self.profile("desktop")
        self.base_config()
        directory = self.home / ".config/dprint"
        config = directory / "dprint.jsonc"
        original = self.repo_config.read_bytes()
        for mode in ("check", "install", "install", "update"):
            result = self.run_helper(mode=mode)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(config.is_symlink())
            if mode == "update":
                self.assertIn(b"npm:@dprint/oxc@0.99.0", self.repo_config.read_bytes())
                self.assertNotEqual(self.repo_config.read_bytes(), original)
            else:
                self.assertEqual(self.repo_config.read_bytes(), original)
        commands = [line.split("|")[0] for line in self.dprint_log.read_text().splitlines()]
        self.assertEqual(commands, ["install --global", "install --global",
                                    "config update --global", "install --global"])
        for line in self.dprint_log.read_text().splitlines():
            self.assertEqual(line.split("|")[1:], [str(directory),
                str(self.home / ".cache/dprint/cache"), str(self.home)])


    def test_global_formatter_update_failure_stops_before_cache_and_neovim(self):
        self.profile("desktop")
        self.base_config()
        original = self.repo_config.read_bytes()
        self.env["TEST_DPRINT_UPDATE_EXIT"] = "42"
        result = self.run_helper(mode="update")
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertFalse(self.log.exists())
        self.assertEqual(self.repo_config.read_bytes(), original)
        commands = [line.split("|")[0] for line in self.dprint_log.read_text().splitlines()]
        self.assertEqual(commands, ["config update --global"])


    def test_global_formatter_missing_config_fails_without_creating_a_copy(self):
        self.profile("desktop")
        self.base_config()
        directory = self.home / ".config/dprint"
        (directory / "dprint.jsonc").unlink()
        directory.rmdir()
        for mode in ("install", "update"):
            result = self.run_helper(mode=mode)
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("install-base", result.stderr)
            self.assertFalse(directory.exists())
            self.assertFalse(self.dprint_log.exists())
            self.assertFalse(self.log.exists())


    def test_global_formatter_failure_stops_before_neovim(self):
        self.profile("desktop")
        self.base_config()
        self.env["TEST_DPRINT_EXIT"] = "42"
        for mode in ("install", "update"):
            result = self.run_helper(mode=mode)
            self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
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
        for version in ("0.10.4", "0.11.0", "0.11.2"):
            with self.subTest(version=version):
                self.env["TEST_NVIM_VERSION"] = version
                result = self.run_helper()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("0.11.3", result.stderr)
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

    def test_desktop_requires_prepared_compatible_tree_sitter_before_plugins(self):
        self.profile("desktop")
        self.base_config()
        for body in ('exit 127\n', 'echo "tree-sitter 0.25.10"\n',
                     'echo "unknown"\n', 'echo "tree-sitter 0.26"\n'):
            with self.subTest(body=body):
                self.write_tool("tree-sitter", body)
                result = self.run_helper()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("tree-sitter", result.stderr)
                self.assertFalse(self.log.exists(), "plugin maintenance ran before CLI preparation")
                self.assertFalse(self.mise_log.exists(), "helper implicitly installed missing CLI")

    def test_preflight_does_not_require_cli_or_mutate_tools_and_plugins(self):
        self.profile("desktop")
        self.base_config()
        self.write_tool("tree-sitter", 'echo called > "$HOME/cli-called"; exit 127\n')
        result = self.run_helper(mode="check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / "cli-called").exists())
        self.assertFalse(self.log.exists())
        self.assertFalse(self.mise_log.exists())




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

    def local_manager_source(self):
        # Installed Lazy may be a partial clone; make a complete local Git fixture.
        source = self.home / "manager-source"
        shutil.copytree(LAZY, source, ignore=shutil.ignore_patterns(".git"))
        for args in (("init", "--initial-branch=stable"), ("add", "."),
                     ("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                      "commit", "-m", "Prepared manager source")):
            subprocess.run(["git", "-C", str(source), *args], env=self.env,
                           check=True, capture_output=True, timeout=10)
        subprocess.run(["git", "config", "--file", str(self.home / ".gitconfig"),
                        "--unset-all", "url." + LAZY.as_uri() + ".insteadOf"],
                       env=self.env, check=True, capture_output=True, timeout=10)
        subprocess.run(["git", "config", "--file", str(self.home / ".gitconfig"),
                        "url." + source.as_uri() + ".insteadOf", "https://github.com/folke/lazy.nvim.git"],
                       env=self.env, check=True, capture_output=True, timeout=10)

    def run_config(self, before="", after=""):
        script = "vim.opt.loadplugins = true; vim.opt.rtp:prepend(vim.fn.stdpath('config')); require('config.lazy')"
        command = "local ok, err = xpcall(function() " + before + "; " + script + "; " + after + " end, debug.traceback); if not ok then io.stderr:write(tostring(err)); vim.cmd('cquit 1') end"
        return subprocess.run([NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n",
                               "-c", "lua " + command, "-c", "qa!"],
                              env=self.env, cwd=self.home, text=True, capture_output=True, timeout=30)

    def test_fresh_server_full_install_prepares_first_editor_start(self):
        # Use real maintenance + Lazy bootstrap with local Git sources. Stub only
        # unrelated system/Stow operations of the full installer.
        shutil.rmtree(self.home / ".local/share/nvim/lazy/lazy.nvim")
        self.env["GIT_ALLOW_PROTOCOL"] = "file"
        self.local_manager_source()
        (self.home / ".zshrc.d").mkdir()
        (self.home / ".zshrc.d/profile.zsh").write_text('export DOTFILES_PROFILE=server\n')
        config = self.home / ".config/nvim"
        (config / "init.lua").symlink_to(ROOT / ".config/nvim/init.lua")
        for source in (ROOT / ".config/nvim/lua/config").glob("*.lua"):
            if source.name != "lazy.lua":
                (config / "lua/config" / source.name).symlink_to(source)
        repo = self.home / "installer"
        (repo / "bin").mkdir(parents=True)
        (repo / ".zsh").mkdir()
        shutil.copy(ROOT / ".zsh/helpers.zsh", repo / ".zsh/helpers.zsh")
        (repo / "bin/maintain-neovim").symlink_to(ROOT / "bin/maintain-neovim")
        completions = repo / "bin/update-shell-completions"
        completions.write_text("#!/bin/sh\nexit 0\n")
        completions.chmod(0o755)
        script = (ROOT / "install").read_text().rsplit("\nrun_installation", 1)[0]
        script += "\nconfigure_profile() { DOTFILES_PROFILE=server }\n"
        for function in ("require_zsh_login_shell", "configure_stow_apply", "setup_private_submodule",
                         "prepare_stow_targets", "migrate_retired_managed_links", "stow_base_dotfiles",
                         "configure_git_conflict_style"):
            script += function + "() { return 0 }\n"
        (repo / "install").write_text(script + '\nrun_installation "$@"\n')
        result = subprocess.run(["zsh", str(repo / "install")],
                                env={**self.env, "TEST_BUILD_FAILURE": "1"}, cwd=self.home,
                                capture_output=True, text=True, timeout=45)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("controlled build failure", result.stdout + result.stderr)
        self.assertFalse((self.home / ".zshrc.d/editor.zsh").exists(),
                         "installer selected nvim after plugin preparation failed")
        result = subprocess.run(["zsh", str(repo / "install")], env=self.env, cwd=self.home,
                                capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("export EDITOR=nvim", (self.home / ".zshrc.d/editor.zsh").read_text())
        self.assertTrue((self.home / ".local/share/nvim/lazy/lazy.nvim").is_dir())
        self.assertTrue((self.home / ".local/share/nvim/lazy/managed/plugin/fixture.lua").is_file())
        self.assertEqual((self.home / "build.log").read_text().splitlines(), ["built"])
        probe = self.home / "first-start.lua"
        probe.write_text("assert(vim.o.mouse == '')\n"
                         "assert(vim.fn.maparg(' ff', 'n') ~= '')\n"
                         "vim.cmd('qa!')\n")
        result = subprocess.run([NVIM, "--headless", "-u", str(config / "init.lua"), "-i", "NONE", "-n", "-l", str(probe)],
                                env=self.env, cwd=self.home, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("Error", result.stdout + result.stderr)


    def test_startup_installs_missing_plugins_without_updating_existing(self):
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        installed = self.home / ".local/share/nvim/lazy/managed"
        self.assertTrue((installed / "plugin/fixture.lua").is_file())
        original = subprocess.check_output(["git", "-C", str(installed), "rev-parse", "HEAD"],
                                           env=self.env, text=True, timeout=10).strip()
        (self.remote / "plugin/fixture.lua").write_text("vim.g.fixture_loaded = 'new'\n")
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "-m", "New upstream version")
        upstream = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertNotEqual(original, upstream)
        added_remote = self.home / "added-remote"
        subprocess.run(["git", "clone", "--no-hardlinks", self.remote.as_uri(), str(added_remote)],
                       env=self.env, check=True, capture_output=True, timeout=10)
        spec = self.home / ".config/nvim/lua/plugins/fixture.lua"
        spec.write_text(spec.read_text().replace(
            "\n}\n", '\n  { "fixture/added", url = ' + json.dumps(added_remote.as_uri())
            + ', lazy = true },\n}\n'))
        added = self.home / ".local/share/nvim/lazy/added"
        for attempt in range(2):
            with self.subTest(attempt=attempt):
                result = self.run_config()
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(subprocess.check_output(
                    ["git", "-C", str(installed), "rev-parse", "HEAD"], env=self.env,
                    text=True, timeout=10).strip(), original)
                self.assertTrue((added / "plugin/fixture.lua").is_file())
                self.assertEqual(subprocess.check_output(
                    ["git", "-C", str(added), "rev-parse", "HEAD"], env=self.env,
                    text=True, timeout=10).strip(), upstream)
                self.assertEqual((self.home / "build.log").read_text().splitlines(), ["built"])

    def test_startup_bootstraps_missing_manager_and_plugins(self):
        self.local_manager_source()
        manager = self.home / ".local/share/nvim/lazy/lazy.nvim"
        shutil.rmtree(manager)
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((manager / "lua/lazy/init.lua").is_file())
        self.assertTrue((self.home / ".local/share/nvim/lazy/managed/plugin/fixture.lua").is_file())
        self.assertEqual((self.home / "build.log").read_text().splitlines(), ["built"])

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

    def test_real_lazy_retries_failed_build_without_updating_or_rebuilding_healthy_plugins(self):
        for retry_mode in ("install", "update"):
            with self.subTest(retry_mode=retry_mode):
                self.env["TEST_BUILD_FAILURE"] = "1"
                result = self.run_stage()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("controlled build failure", result.stdout + result.stderr)
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

    def test_startup_installs_missing_parsers_retries_failures_and_skips_server(self):
        self.env["DOTFILES_PROFILE"] = "desktop"
        tree_remote = self.home / "startup-tree-remote"
        subprocess.run(["git", "clone", str(self.remote), str(tree_remote)],
                       check=True, capture_output=True, timeout=10)
        self.remote = tree_remote
        module = tree_remote / "lua/nvim-treesitter"
        module.mkdir(parents=True)
        (module / "init.lua").write_text("""
return {
  setup = function() end,
  update = function() error('startup must not update existing parsers') end,
  uninstall = function(languages)
    return { await = function(_, callback)
      for _, lang in ipairs(languages) do
        local site = vim.env.HOME .. '/.local/share/nvim/site'
        vim.fn.delete(site .. '/parser/' .. lang .. '.so')
        vim.fn.delete(site .. '/queries/' .. lang, 'rf')
      end
      callback(nil)
    end }
  end,
  install = function(languages, options)
    vim.fn.writefile(languages, vim.env.HOME .. '/parser-install.log')
    languages = vim.deepcopy(languages)
    if vim.tbl_contains(languages, 'markdown') and not vim.tbl_contains(languages, 'markdown_inline') then
      languages[#languages + 1] = 'markdown_inline'
    end
    return { await = function(_, callback)
      vim.defer_fn(function()
        if vim.env.TEST_PARSER_FAILURE == '1' then
          callback('controlled compiler failure')
          return
        end
        for _, lang in ipairs(languages) do
          local site = vim.env.HOME .. '/.local/share/nvim/site'
          vim.fn.mkdir(site .. '/parser', 'p')
          vim.fn.mkdir(site .. '/queries/' .. lang, 'p')
          if (options and options.force) or vim.fn.filereadable(site .. '/parser/' .. lang .. '.so') == 0 then
            vim.fn.writefile({}, site .. '/parser/' .. lang .. '.so')
            vim.fn.writefile({}, site .. '/queries/' .. lang .. '/highlights.scm')
          end
        end
        callback(nil, true)
        vim.fn.writefile({'done'}, vim.env.HOME .. '/install-finished')
      end, 10)
    end }
  end,
}
""")
        (module / "config.lua").write_text("return { get_install_dir = function(kind) return vim.env.HOME .. '/.local/share/nvim/site/' .. kind end }\n")
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "-m", "Asynchronous parser installer fixture")
        revision = self.git("rev-parse", "HEAD").stdout.strip()
        spec = self.home / ".config/nvim/lua/plugins/treesitter.lua"
        spec.write_text("local spec = dofile(" + json.dumps(str(ROOT / '.config/nvim/lua/plugins/treesitter.lua')) + ")\n"
                        "spec.url = " + json.dumps(tree_remote.as_uri()) + "\n"
                        "spec.commit = " + json.dumps(revision) + "\nreturn spec\n")
        site = self.home / ".local/share/nvim/site"
        parser = site / "parser/lua.so"
        parser.parent.mkdir(parents=True)
        parser.write_bytes(b"retained parser fixture")
        queries = site / "queries/lua"
        queries.mkdir(parents=True)
        (queries / "highlights.scm").write_text("retained queries")
        log = self.home / "parser-install.log"
        done = self.home / "install-finished"
        errors = self.home / "startup-errors"
        before = "vim.notify = function(msg, level) if level == vim.log.levels.ERROR then vim.fn.writefile({msg}, vim.env.HOME .. '/startup-errors', 'a') end end"
        wait = "assert(vim.wait(3000, function() return vim.fn.filereadable(vim.env.HOME .. '/install-finished') == 1 end), 'parser installation did not complete')"
        result = self.run_config(before=before, after=wait)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(errors.exists(), errors.read_text() if errors.exists() else "")
        self.assertTrue((self.home / '.local/share/nvim/lazy/nvim-treesitter/lua/nvim-treesitter/init.lua').is_file())
        self.assertEqual(len(log.read_text().splitlines()), 16)
        self.assertNotIn("lua", log.read_text().splitlines())
        self.assertEqual(parser.read_bytes(), b"retained parser fixture")
        log.unlink()
        result = self.run_config(before=before)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(log.exists(), "repeat startup reinstalled healthy parsers")
        (site / 'parser/json.so').unlink()
        done.unlink()
        self.env['TEST_PARSER_FAILURE'] = '1'
        result = self.run_config(before=before, after="assert(vim.wait(3000, function() return vim.fn.filereadable(vim.env.HOME .. '/startup-errors') == 1 end), 'compiler failure was hidden')")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('controlled compiler failure', errors.read_text())
        self.assertFalse((site / 'parser/json.so').exists())
        self.env.pop('TEST_PARSER_FAILURE')
        errors.unlink()
        result = self.run_config(before=before, after=wait)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(log.read_text().splitlines(), ['json'])
        self.assertFalse(errors.exists())
        inline = site / 'parser/markdown_inline.so'
        inline.write_bytes(b'healthy dependency')
        (site / 'parser/markdown.so').unlink()
        done.unlink()
        result = self.run_config(before=before, after=wait)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(log.read_text().splitlines(), ['markdown'])
        self.assertEqual(inline.read_bytes(), b'healthy dependency',
                         'installing Markdown rebuilt its healthy inline dependency')
        for profile in ('server', None):
            with self.subTest(profile=profile):
                log.unlink(missing_ok=True)
                (site / 'parser/json.so').unlink(missing_ok=True)
                if profile is None:
                    self.env.pop('DOTFILES_PROFILE', None)
                else:
                    self.env['DOTFILES_PROFILE'] = profile
                result = self.run_config(before=before)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(log.exists(), 'server/unset profile started parser installation')
                self.assertFalse((site / 'parser/json.so').exists())

    def test_parser_maintenance_installs_retries_and_skips_server(self):
        self.env["DOTFILES_PROFILE"] = "desktop"
        plugin = self.home / "local-treesitter"
        plugin.mkdir()
        spec = self.home / ".config/nvim/lua/plugins/treesitter.lua"
        spec.write_text("""
local spec = dofile(%s)
spec.dir = %s
package.preload['nvim-treesitter.config'] = function()
  return { get_installed = function() return {} end,
    get_install_dir = function(kind) return vim.env.HOME .. '/site/' .. kind end }
end
package.preload['nvim-treesitter'] = function()
  return {
    setup = function() end,
    uninstall = function() return { wait = function() end } end,
    update = function()
      vim.fn.writefile({ 'updated' }, vim.env.HOME .. '/parser-update.log')
      return { wait = function() return vim.env.TEST_PARSER_UPDATE_FAILURE ~= '1' end }
    end,
    install = function(languages)
      vim.fn.writefile(languages, vim.env.HOME .. '/parsers.log')
      if vim.env.TEST_PARSER_FAILURE ~= '1' then
        for _, lang in ipairs(languages) do
          vim.fn.mkdir(vim.env.HOME .. '/site/parser', 'p')
          vim.fn.mkdir(vim.env.HOME .. '/site/queries/' .. lang, 'p')
          vim.fn.writefile({}, vim.env.HOME .. '/site/parser/' .. lang .. '.so')
          vim.fn.writefile({}, vim.env.HOME .. '/site/queries/' .. lang .. '/highlights.scm')
        end
      end
      return { wait = function() return vim.env.TEST_PARSER_FAILURE ~= '1' end }
    end,
  }
end
return spec
""" % (json.dumps(str(ROOT / ".config/nvim/lua/plugins/treesitter.lua")), json.dumps(str(plugin))))
        self.env["TEST_PARSER_FAILURE"] = "1"
        result = self.run_stage()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Tree-sitter parser installation failed", result.stdout + result.stderr)
        self.env.pop("TEST_PARSER_FAILURE")
        result = self.run_stage()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.home / "parsers.log").read_text().splitlines(),
                         ["lua", "vim", "vimdoc", "query", "bash", "python", "json", "yaml", "toml",
                          "markdown", "markdown_inline", "dockerfile", "git_config", "gitcommit", "diff", "helm", "go"])
        self.assertTrue((self.home / "parser-update.log").exists())
        self.env["TEST_PARSER_UPDATE_FAILURE"] = "1"
        result = self.run_stage("update")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Tree-sitter parser update failed", result.stdout + result.stderr)
        self.env.pop("TEST_PARSER_UPDATE_FAILURE")
        result = self.run_stage("update")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / "parser-update.log").exists())
        (self.home / "parser-update.log").unlink()
        (self.home / "parsers.log").unlink()
        self.env["DOTFILES_PROFILE"] = "server"
        result = self.run_stage()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / "parsers.log").exists())

    def test_install_and_update_repair_incompatible_checkout_before_loading_it(self):
        self.env['DOTFILES_PROFILE'] = 'desktop'
        tree_remote = self.home / 'tree-remote'
        subprocess.run(['git', 'clone', str(self.remote), str(tree_remote)],
                       check=True, capture_output=True, timeout=10)
        self.remote = tree_remote
        module = self.remote / 'lua/nvim-treesitter'
        module.mkdir(parents=True)
        (module / 'init.lua').write_text("""
return {
  setup = function() end,
    uninstall = function() return { wait = function() end } end,
  install = function(languages)
    for _, lang in ipairs(languages) do
      vim.fn.mkdir(vim.env.HOME .. '/site/parser', 'p')
      vim.fn.mkdir(vim.env.HOME .. '/site/queries/' .. lang, 'p')
      vim.fn.writefile({}, vim.env.HOME .. '/site/parser/' .. lang .. '.so')
      vim.fn.writefile({}, vim.env.HOME .. '/site/queries/' .. lang .. '/highlights.scm')
    end
    vim.fn.writefile({'installed'}, vim.env.HOME .. '/parser-installed', 'a')
    return {wait = function() return true end}
  end,
  update = function()
    vim.fn.writefile({'updated'}, vim.env.HOME .. '/parser-updated', 'a')
    return {wait = function() return true end}
  end,
}
""")
        (module / 'config.lua').write_text("return {get_install_dir = function(kind) return vim.env.HOME .. '/site/' .. kind end}\n")
        (module / 'install.lua').write_text("return require('nvim-treesitter')\n")
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-m', 'Compatible parser API')
        compatible = self.git('rev-parse', 'HEAD').stdout.strip()
        (module / 'init.lua').write_text("error('incompatible parser API loaded before checkout')\n")
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-m', 'Incompatible parser API')
        (self.home / '.config/nvim/lua/plugins/treesitter.lua').write_text(
            'local spec = dofile(' + json.dumps(str(ROOT / '.config/nvim/lua/plugins/treesitter.lua')) + ')\n'
            'spec.url = ' + json.dumps(self.remote.as_uri()) + '\n'
            'spec.commit = ' + json.dumps(compatible) + '\nreturn spec\n')
        installed = self.home / '.local/share/nvim/lazy/nvim-treesitter'
        for mode in ('install', 'update'):
            with self.subTest(mode=mode):
                if installed.exists():
                    shutil.rmtree(installed)
                subprocess.run(['git', 'clone', str(self.remote), str(installed)], env=self.env,
                               check=True, capture_output=True, timeout=10)
                result = self.run_stage(mode)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn('incompatible parser API', result.stdout + result.stderr)
                head = subprocess.check_output(['git', '-C', str(installed), 'rev-parse', 'HEAD'], text=True)
                self.assertEqual(head.strip(), compatible)
                self.assertTrue((self.home / 'parser-installed').exists())
                before = (self.home / 'parser-installed').read_text()
                result = self.run_stage('install')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.home / 'parser-installed').read_text(), before,
                                 'healthy parsers were reinstalled on repeat install')




if __name__ == "__main__":
    unittest.main()
