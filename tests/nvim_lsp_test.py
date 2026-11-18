"""Exercise the native LSP setup with a local JSON-RPC server and isolated files."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import nvim_test

ROOT, NVIM = nvim_test.ROOT, nvim_test.NVIM
LSPCONFIG = nvim_test.LAZY / "nvim-lspconfig"


@unittest.skipUnless(NVIM, "Neovim is not installed")
@unittest.skipUnless(LSPCONFIG.is_dir(), "nvim-lspconfig is not installed")
class NativeLspIntegrationTest(unittest.TestCase):
    setUpClass = classmethod(nvim_test.NeovimTest.setUpClass.__func__)

    def test_native_lsp_uses_available_ruff_for_each_project_and_leaves_ruby_unmanaged(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-lsp-") as directory:
            temp = Path(directory)
            projects = [temp / "project a", temp / "project b"]
            for project in projects:
                project.mkdir()
                (project / "pyproject.toml").write_text("[project]\nname = 'example'\n")
                (project / "example.py").write_text("print('hello')\n")
            first_project = projects[0]
            (first_project / "no_ruff.py").write_text("print('hello')\n")
            (first_project / "example.rb").write_text("puts 'hello'\n")
            (first_project / "Gemfile").write_text('gem "rubocop"\n')
            (first_project / ".rubocop.yml").write_text("AllCops: {}\n")
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            log = temp / "commands.jsonl"
            log.touch()
            fixture = temp / "lsp-fixture"
            fixture.write_text(f"#!{sys.executable}\n" + '''import json, os, sys

def record(value):
    with open(os.environ['LSP_TEST_LOG'], 'a') as output:
        output.write(json.dumps(value) + '\\n')

record({'program': os.path.basename(sys.argv[0]), 'args': sys.argv[1:],
        'cwd': os.getcwd(), 'mise_auto_install': os.environ.get('MISE_AUTO_INSTALL')})
if os.path.basename(sys.argv[0]) != 'ruff':
    sys.exit(1)
while True:
    headers = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            sys.exit(0)
        if line in (b'\\r\\n', b'\\n'):
            break
        key, value = line.decode().split(':', 1)
        headers[key.lower()] = value.strip()
    message = json.loads(sys.stdin.buffer.read(int(headers['content-length'])))
    if message.get('method') == 'initialize':
        record({'root_uri': message['params']['rootUri']})
        response = json.dumps({'jsonrpc': '2.0', 'id': message['id'],
                               'result': {'capabilities': {}}}).encode()
        sys.stdout.buffer.write(b'Content-Length: %d\\r\\n\\r\\n' % len(response) + response)
        sys.stdout.buffer.flush()
''')
            fixture.chmod(0o755)
            for command in ("ruby", "ruby-lsp", "bundle", "rubocop", "docker", "mise"):
                (bin_dir / command).symlink_to(fixture)
            wrappers = first_project / ".dev/bin"
            wrappers.mkdir(parents=True)
            for command in ("ruby", "ruby-lsp", "bundle", "rubocop"):
                (wrappers / command).symlink_to(fixture)
            script = temp / "test.lua"
            script.write_text('''
vim.opt.runtimepath:prepend(%s)
package.path = %s .. ";" .. package.path
vim.cmd.runtime('plugin/lspconfig.lua')
package.loaded['config.lazy'] = {} -- Exercise init without plugin installation.
dofile(%s)
vim.cmd('filetype plugin indent on')
local spec = require('plugins.lsp')
assert(spec.cond(), 'desktop LSP was disabled')
local function lsp_info()
  return vim.api.nvim_get_commands({ builtin = false }).LspInfo
end
local upstream_info = lsp_info()
if upstream_info then
  spec.config()
  assert(vim.deep_equal(lsp_info(), upstream_info), 'LspInfo from upstream was replaced')
  vim.api.nvim_del_user_command('LspInfo')
end
vim.g.lspconfig = nil -- Let the upstream entry point run again.
local exists = vim.fn.exists
local checked_native = false
-- Simulate the native lowercase command on Neovim 0.11.
vim.fn.exists = function(name)
  if name == ':lsp' then
    checked_native = true
    return 2
  end
  return exists(name)
end
vim.cmd.runtime('plugin/lspconfig.lua')
vim.fn.exists = exists
assert(checked_native and not lsp_info(), 'upstream did not defer LspInfo with native :lsp')
spec.config()
for _, name in ipairs({ 'helm_ls', 'ruff', 'taplo', 'marksman', 'gopls' }) do
  assert(vim.lsp.is_enabled(name), name .. ': native server not enabled')
end
for _, name in ipairs({ 'ruby_lsp', 'lua_ls' }) do
  assert(not vim.lsp.is_enabled(name), name .. ': retired server enabled')
end
assert(vim.deep_equal(vim.lsp.config.helm_ls.filetypes, { 'helm' }), 'Helm filetypes changed')
assert(vim.fn.exists(':LspInfo') == 2, 'LspInfo command missing')
vim.cmd.edit(%s)
assert(not vim.wait(500, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end, 20),
  'Python started an LSP client without Ruff')
assert(#vim.fn.readfile(vim.env.LSP_TEST_LOG) == 0, 'missing Ruff invoked a fallback command')
local bin_path = vim.env.PATH
vim.env.PATH = %s .. ':' .. bin_path
vim.cmd.edit(%s)
assert(not vim.wait(500, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end, 20),
  'Ruby started an LSP client')
assert(#vim.fn.readfile(vim.env.LSP_TEST_LOG) == 0, 'Ruby invoked a project or runtime wrapper')
vim.env.PATH = bin_path
assert(vim.uv.fs_symlink(%s, bin_path .. '/ruff'))
for _, project in ipairs({ %s, %s }) do
  vim.cmd.edit(project .. '/example.py')
  assert(vim.wait(5000, function()
    local clients = vim.lsp.get_clients({ bufnr = 0, name = 'ruff' })
    return #clients == 1 and clients[1].initialized
  end, 20), 'Ruff did not initialize for ' .. project)
  local client = vim.lsp.get_clients({ bufnr = 0, name = 'ruff' })[1]
  assert(client.config.root_dir == project, 'unexpected LSP root for ' .. project)
end
for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end
''' % tuple(json.dumps(str(value)) for value in (
                LSPCONFIG,
                ROOT / ".config/nvim/lua/?.lua",
                ROOT / ".config/nvim/init.lua",
                first_project / "no_ruff.py", wrappers, first_project / "example.rb", fixture, *projects,
            )))
            env = dict(os.environ, HOME=str(temp), PATH=str(bin_dir),
                       DOTFILES_PROFILE="desktop", LSP_TEST_LOG=str(log),
                       MISE_AUTO_INSTALL="true")
            for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
                env[name] = str(temp / name.lower())
            result = subprocess.run(
                [NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(script)],
                env=env, cwd=temp, capture_output=True, text=True, timeout=15,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            events = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(events, [
                event
                for project in projects
                for event in (
                    {"program": "ruff", "args": ["server"], "cwd": str(temp), "mise_auto_install": "false"},
                    {"root_uri": project.as_uri()},
                )
            ])


if __name__ == "__main__":
    unittest.main()
