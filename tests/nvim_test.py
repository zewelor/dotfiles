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
for _, name in ipairs({'conform', 'copilot', 'opencode'}) do
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

    def test_desktop_enables_only_declared_native_lsp_servers(self):
        self.run_lua("""
local declared = require('config.tools').servers
local defaults = {
  lua_ls = { 'lua-language-server' },
  helm_ls = { 'helm_ls', 'serve' },
  ruff = { 'ruff', 'server' },
  taplo = { 'taplo', 'lsp', 'stdio' },
  marksman = { 'marksman', 'server' },
  gopls = { 'gopls' },
}
local configured, enabled = {}, {}
vim.lsp.config = setmetatable({}, {
  __index = function(_, name)
    return defaults[name] and { cmd = defaults[name] } or nil
  end,
  __call = function(_, name, opts)
    configured[name] = opts
  end,
})
vim.lsp.enable = function(name) enabled[name] = true end
vim.fn.executable = function() return 0 end
local specs = require('plugins.lsp')
local mason
for _, spec in ipairs(specs) do
  assert(spec[1] ~= 'williamboman/mason-lspconfig.nvim', 'mason-lspconfig must not activate LSP servers')
  if spec[1] == 'williamboman/mason.nvim' then mason = spec end
end
assert(mason and mason.opts.PATH == 'skip', 'manual Mason extras must not enter PATH')
local lsp
for _, spec in ipairs(specs) do
  if spec[1] == 'neovim/nvim-lspconfig' then lsp = spec end
end
assert(lsp, 'native nvim-lspconfig plugin spec is missing')
lsp.config()
assert(not configured.lua_ls and not enabled.lua_ls, 'retired LuaLS must not be activated')
for _, name in ipairs(declared) do
  assert(configured[name] and enabled[name], name .. ': declared native server was not configured and enabled')
end
assert(configured.ruby_lsp and enabled.ruby_lsp and type(configured.ruby_lsp.cmd) == 'function',
  'Ruby LSP must defer mise resolution until a project client starts')
for name in pairs(enabled) do
  local found = name == 'ruby_lsp'
  for _, declared_name in ipairs(declared) do
    found = found or name == declared_name
  end
  assert(found, name .. ': an undeclared LSP was activated')
end
""", "desktop")

    def test_native_lsp_commands_resolve_each_server_at_its_project_root(self):
        self.run_lua("""
local declared = require('config.tools').servers
local defaults = {
  lua_ls = { 'lua-language-server' },
  helm_ls = { 'helm_ls', 'serve' },
  ruff = { 'ruff', 'server' },
  taplo = { 'taplo', 'lsp', 'stdio' },
  marksman = { 'marksman', 'server' },
  gopls = { 'gopls' },
}
local configured, starts = {}, {}
vim.lsp.config = setmetatable({}, {
  __index = function(_, name)
    return defaults[name] and { cmd = defaults[name] } or nil
  end,
  __call = function(_, name, opts)
    configured[name] = opts
  end,
})
vim.lsp.enable = function() end
vim.fn.executable = function() return 0 end
vim.lsp.rpc.start = function(command, dispatchers, opts)
  starts[#starts + 1] = { command = command, dispatchers = dispatchers, opts = opts }
  return {}
end
local resolved = {}
require('config.tools').resolve = function(binary, root)
  resolved[#resolved + 1] = { binary = binary, root = root }
  return '/mise/bin/' .. binary
end
local lsp
for _, spec in ipairs(require('plugins.lsp')) do
  if spec[1] == 'neovim/nvim-lspconfig' then lsp = spec end
end
assert(lsp, 'native nvim-lspconfig plugin spec is missing')
lsp.config()
for _, name in ipairs(declared) do
  local root = '/projects/' .. name
  local dispatchers = { server = name }
  local config = configured[name]
  assert(type(config.cmd) == 'function', name .. ': expected a native command factory')
  config.cmd(dispatchers, { root_dir = root })
  local call = starts[#starts]
  local resolution = resolved[#resolved]
  assert(resolution.binary == defaults[name][1] and resolution.root == root,
    name .. ': resolver did not receive this server command and project root')
  local expected = vim.deepcopy(defaults[name])
  expected[1] = '/mise/bin/' .. expected[1]
  assert(#call.command == #expected, name .. ': default server argument count changed')
  for index, value in ipairs(expected) do
    assert(call.command[index] == value, name .. ': default server arguments were not preserved')
  end
  assert(call.dispatchers == dispatchers and call.opts.cwd == root,
    name .. ': RPC process did not retain dispatchers and project cwd')
end
""", "desktop")

    def test_desktop_without_mise_reports_ruby_client_start_failure(self):
        self.run_lua("""
local defaults = {
  lua_ls = { 'lua-language-server' }, helm_ls = { 'helm_ls', 'serve' },
  ruff = { 'ruff', 'server' }, taplo = { 'taplo', 'lsp', 'stdio' },
  marksman = { 'marksman', 'server' }, gopls = { 'gopls' },
}
local configured, enabled = {}, {}
vim.lsp.config = setmetatable({}, {
  __index = function(_, name) return defaults[name] and { cmd = defaults[name] } or nil end,
  __call = function(_, name, opts) configured[name] = opts end,
})
vim.lsp.enable = function(name) enabled[name] = true end
local lsp
for _, spec in ipairs(require('plugins.lsp')) do
  if spec[1] == 'neovim/nvim-lspconfig' then lsp = spec end
end
assert(lsp, 'native nvim-lspconfig plugin spec is missing')
lsp.config()
for _, name in ipairs(require('config.tools').servers) do
  assert(configured[name] and enabled[name], name .. ': declared server was skipped without Ruby mise')
end
assert(configured.ruby_lsp and enabled.ruby_lsp, 'Ruby LSP configuration must remain lazy')
local ok, err = pcall(configured.ruby_lsp.cmd, {}, { root_dir = '/projects/ruby' })
assert(not ok, 'Ruby LSP must not start without mise')
assert(err:find('mise', 1, true) and err:find('/projects/ruby', 1, true),
  'missing-mise diagnostic must name the project and cause')
""", "desktop")

    @unittest.skipUnless((LAZY / "nvim-treesitter").is_dir(), "Tree-sitter plugin is not installed")
    def test_treesitter_build_waits_for_parser_failure(self):
        self.run_lua("""
vim.opt.rtp:append(%s)
local async = require('nvim-treesitter.async')
local finished = false
package.loaded['nvim-treesitter.install'] = {
  update = async.async(function()
    async.await(1, function(callback) vim.defer_fn(callback, 10) end)
    finished = true
    return false
  end),
}
dofile(%s)
local build = require('plugins.treesitter').build
local ok = pcall(function()
  if type(build) == 'string' then vim.cmd(build:sub(2)) else build() end
end)
assert(finished, 'the build returned before its parser update finished')
assert(not ok, 'the parser update failure was reported as a successful build')
""" % (json.dumps(str(LAZY / "nvim-treesitter")),
       json.dumps(str(LAZY / "nvim-treesitter/plugin/nvim-treesitter.lua"))), "desktop")


if __name__ == "__main__":
    unittest.main()
