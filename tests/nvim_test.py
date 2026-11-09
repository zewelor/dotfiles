"""Exercise Neovim profile boundaries offline, without starting plugin managers."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
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
        version = re.match(r"NVIM v(\d+)\.(\d+)", output)
        if version is None:
            raise RuntimeError("Cannot determine Neovim version")
        if tuple(map(int, version.groups())) < (0, 11):
            raise unittest.SkipTest("Neovim 0.11 or newer is required")

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

    def test_copilot_excludes_env_files(self):
        self.run_lua("""
local should_attach = require('plugins.copilot').opts.should_attach
local cases = {
  { '/project/.env', false },
  { '/project/config/.env.local', false },
  { '/project/.envrc', true },
  { '/project/environment.sh', true },
}
for _, case in ipairs(cases) do
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, case[1])
  local allowed = should_attach(buf, vim.api.nvim_buf_get_name(buf))
  assert(allowed == case[2], case[1] .. ': unexpected Copilot attachment decision')
  vim.api.nvim_buf_delete(buf, { force = true })
end
""", "desktop")

    def test_profiles_with_and_without_mise(self):
        for profile in (None, "server", "desktop"):
            for mise in (False, True):
                if profile is None and mise:
                    continue
                with self.subTest(profile=profile, mise=mise):
                    self.run_lua("""
local expected = vim.env.DOTFILES_PROFILE == 'desktop'
assert(require('config.profile').is_desktop() == expected, 'wrong desktop profile policy')
for _, name in ipairs({'conform', 'mason-tool-installer', 'copilot', 'opencode'}) do
  local spec = require('plugins.' .. name)
  local active = spec.cond == nil or (type(spec.cond) == 'function' and spec.cond() or spec.cond == true)
  assert(active == expected, name .. ': wrong profile condition')
end
for _, spec in ipairs(require('plugins.lsp')) do
  assert(spec.cond() == expected, spec[1] .. ': wrong profile condition')
end
vim.g.mapleader = ' '
require('config.keymaps')
for _, key in ipairs({' cf', ' oa', ' ct'}) do
  assert((vim.fn.maparg(key, 'n') ~= '') == expected, key .. ': wrong keymap policy')
end
""", profile, mise)

    @unittest.skipUnless((LAZY / "mason-lspconfig.nvim").is_dir()
                         and (LAZY / "mason.nvim").is_dir(), "Mason plugins are not installed")
    def test_installed_extra_lsp_is_not_enabled(self):
        # Run the installed Mason enablement code against an isolated registry:
        # an old manually installed server must not expand our active server set.
        self.run_lua("""
vim.opt.rtp:append(%s)
vim.opt.rtp:append(%s)
local specs = require('plugins.lsp')
local opts = specs[2].opts
local mapping = {}
local installed = {'legacy-unwanted-server'}
for _, name in ipairs(opts.ensure_installed) do
  mapping[name] = name
  table.insert(installed, name)
end
mapping['legacy-unwanted-server'] = 'unwanted_ls'
package.loaded['mason-lspconfig.mappings'] = {
  get_mason_map = function() return {package_to_lspconfig = mapping} end,
}
package.loaded['mason-registry'] = {
  get_installed_package_names = function() return installed end,
  off = function() end,
  on = function() end,
}
require('mason-lspconfig.settings').set(opts)
local enabled = {}
vim.lsp.enable = function(name) enabled[name] = true end
require('mason-lspconfig.features.automatic_enable').init()
assert(not enabled.unwanted_ls, 'an undeclared installed LSP was enabled')
for _, name in ipairs(opts.ensure_installed) do
  assert(enabled[name], name .. ': declared LSP was not enabled')
end
""" % (json.dumps(str(LAZY / "mason.nvim")),
       json.dumps(str(LAZY / "mason-lspconfig.nvim"))), "desktop")

    def test_desktop_without_mise_does_not_start_ruby_lsp(self):
        self.run_lua("""
local configured = {}
vim.lsp.config = function(name, opts) configured[name] = opts end
vim.lsp.enable = function() error('Ruby LSP must not start without mise') end
require('plugins.lsp')[3].config()
assert(not configured.ruby_lsp)
assert(configured.lua_ls, 'desktop LSP configuration was skipped')
""", "desktop")


if __name__ == "__main__":
    unittest.main()
