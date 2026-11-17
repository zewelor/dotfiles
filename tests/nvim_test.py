"""Exercise Neovim profile boundaries offline, without starting plugin managers."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
LAZY = Path.home() / ".local/share/nvim/lazy"


@unittest.skipUnless(NVIM, "Neovim is not installed")
class NeovimTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        output = subprocess.check_output([NVIM, "--version"], text=True, timeout=5)
        version = re.match(r"NVIM v(\d+)\.(\d+)\.(\d+)", output)
        if version is None:
            raise RuntimeError("Cannot determine Neovim version")
        if tuple(map(int, version.groups())) < (0, 11, 3):
            raise unittest.SkipTest("Neovim 0.11.3 or newer is required")

    def run_lua(self, code, profile=None, mise=False):
        with tempfile.TemporaryDirectory(prefix="dotfiles-nvim-") as directory:
            temp = Path(directory)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            if mise:
                executable = bin_dir / "mise"
                executable.write_text("#!/bin/sh\nexit 1\n")
                executable.chmod(0o755)
            script = temp / "test.lua"
            script.write_text(
                "package.path = " + json.dumps(str(ROOT / ".config/nvim/lua/?.lua") + ";")
                + " .. package.path\n" + code
            )
            env = dict(os.environ, HOME=directory, PATH=str(bin_dir))
            for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
                env[name] = str(temp / name.lower())
            env.pop("DOTFILES_PROFILE", None)
            if profile is not None:
                env["DOTFILES_PROFILE"] = profile
            result = subprocess.run(
                [NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(script)],
                env=env, capture_output=True, text=True, timeout=15,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unsupported_neovim_stops_before_plugin_setup(self):
        self.run_lua("""
local manager_started = false
package.preload['config.lazy'] = function() manager_started = true; return {} end
local has = vim.fn.has
vim.fn.has = function(feature)
  if feature == 'nvim-0.11.3' then return 0 end
  return has(feature)
end
local ok, err = pcall(dofile, %s)
assert(not ok, 'unsupported Neovim was accepted')
assert(tostring(err):find('Neovim 0.11.3 or newer', 1, true), tostring(err))
assert(not manager_started, 'plugin setup started before the version check')
""" % json.dumps(str(ROOT / '.config/nvim/init.lua')), "server")

    def test_child_processes_disable_implicit_mise_installation(self):
        for profile in ("desktop", "server"):
            with self.subTest(profile=profile):
                self.run_lua("""
package.loaded['config.lazy'] = {} -- Keep plugin installation outside this test.
vim.env.MISE_AUTO_INSTALL = 'true'
dofile(%s)
local child = vim.system({ %s, '-c', %s }, { text = true }):wait()
assert(child.code == 0, child.stderr)
assert(child.stdout == 'false\\n', 'child process permits implicit mise installation: ' .. child.stdout)
""" % (json.dumps(str(ROOT / '.config/nvim/init.lua')), json.dumps(sys.executable),
       json.dumps("import os; print(os.environ['MISE_AUTO_INSTALL'])")), profile)

    def test_external_changes_reload_without_agent_plugin(self):
        for profile in ("desktop", "server"):
            with self.subTest(profile=profile):
                self.run_lua("""
vim.o.autoread = false
require('config.options')
local path = vim.env.HOME .. '/external.txt'
vim.fn.writefile({ 'before' }, path)
vim.cmd.edit(vim.fn.fnameescape(path))
-- Decline prompts when a buffer cannot be reloaded automatically.
vim.api.nvim_create_autocmd('FileChangedShell', {
  callback = function() vim.v.fcs_choice = '' end,
})
vim.fn.writefile({ 'changed externally' }, path)
vim.cmd.checktime()
assert(vim.api.nvim_get_current_line() == 'changed externally', 'unmodified buffer did not reload')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local edits' })
vim.fn.writefile({ 'changed externally a second time' }, path)
vim.cmd.checktime()
assert(vim.api.nvim_get_current_line() == 'local edits', 'external changes overwrote local edits')
assert(vim.bo.modified, 'local edits lost the modified flag')
""", profile)

    def test_profiles_with_and_without_mise(self):
        for profile in (None, "server", "desktop"):
            for mise in (False, True):
                if profile is None and mise:
                    continue
                with self.subTest(profile=profile, mise=mise):
                    self.run_lua("""
local expected = vim.env.DOTFILES_PROFILE == 'desktop'
assert(require('config.profile').is_desktop() == expected, 'wrong desktop profile policy')
for _, name in ipairs({'conform'}) do
  local spec = require('plugins.' .. name)
  local active = spec.cond == nil or (type(spec.cond) == 'function' and spec.cond() or spec.cond == true)
  assert(active == expected, name .. ': wrong profile condition')
end
local lsp = require('plugins.lsp')
assert(lsp.cond() == expected, lsp[1] .. ': wrong profile condition')
vim.g.mapleader = ' '
require('config.keymaps')
for _, key in ipairs({' cf'}) do
  assert((vim.fn.maparg(key, 'n') ~= '') == expected, key .. ': wrong keymap policy')
end
assert(vim.fn.maparg(' ct', 'n') == '', 'retired Copilot toggle remains mapped')
for _, key in ipairs({'<M-]>', '<M-[>', '<M-l>', '<C-]>'}) do
  assert(vim.fn.maparg(key, 'i') == '', key .. ': retired Copilot suggestion remains mapped')
end
for _, mapping in ipairs({
  { 'n', ' oa' }, { 'x', ' oa' }, { 'n', ' ox' }, { 'x', ' ox' },
  { 'n', ' ot' }, { 't', ' ot' }, { 'n', '<S-C-u>' }, { 'n', '<S-C-d>' },
}) do
  assert(vim.fn.maparg(mapping[2], mapping[1]) == '', mapping[2] .. ': retired OpenCode key remains mapped')
end
""", profile, mise)



if __name__ == "__main__":
    unittest.main()
