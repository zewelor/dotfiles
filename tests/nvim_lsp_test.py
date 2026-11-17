"""Exercise native LSP PATH startup and the absence of Ruby integration offline."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import nvim_test

ROOT, NVIM = nvim_test.ROOT, nvim_test.NVIM


@unittest.skipUnless(NVIM, 'Neovim is not installed')
@unittest.skipUnless((nvim_test.LAZY / 'nvim-lspconfig').is_dir(), 'installed nvim-lspconfig source is required')
class NativeLspPathTest(unittest.TestCase):
    setUpClass = classmethod(nvim_test.NeovimTest.setUpClass.__func__)

    def run_native_case(self, *, available, filetype="python", native_lsp_command=False):
        with tempfile.TemporaryDirectory(prefix='dotfiles-native-lsp-') as directory:
            temp = Path(directory)
            projects = [temp / 'project a', temp / 'project b']
            for project in projects:
                project.mkdir()
                (project / 'pyproject.toml').write_text('[project]\nname = "fixture"\n')
                (project / 'example.py').write_text('print("hello")\n')
                (project / 'example.rb').write_text('puts :hello\n')
                (project / 'Gemfile').write_text('gem "rubocop"\n')
                (project / '.rubocop.yml').write_text('AllCops: {}\n')
            bin_dir = temp / 'bin'
            bin_dir.mkdir()
            log = temp / 'commands.jsonl'
            log.touch()
            fixture = bin_dir / 'server-fixture'
            fixture.write_text(f'#!{sys.executable}\n' + r'''import json, os, sys

def record(value):
    with open(os.environ['LSP_PATH_LOG'], 'a') as output:
        output.write(json.dumps(value) + '\n')

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
        if line in (b'\r\n', b'\n'):
            break
        key, value = line.decode().split(':', 1)
        headers[key.lower()] = value.strip()
    message = json.loads(sys.stdin.buffer.read(int(headers['content-length'])))
    if message.get('method') == 'initialize':
        record({'root_uri': message['params']['rootUri']})
        response = json.dumps({'jsonrpc': '2.0', 'id': message['id'],
                               'result': {'capabilities': {}}}).encode()
        sys.stdout.buffer.write(b'Content-Length: %d\r\n\r\n' % len(response) + response)
        sys.stdout.buffer.flush()
''')
            fixture.chmod(0o755)
            for name in ('mise', 'ruby', 'bundle', 'ruby-lsp', 'rubocop', 'docker'):
                (bin_dir / name).symlink_to(fixture)
            for project in projects:
                wrappers = project / '.dev/bin'
                wrappers.mkdir(parents=True)
                for name in ('ruby-lsp', 'ruby', 'bundle', 'rubocop'):
                    (wrappers / name).symlink_to(fixture)
            if available:
                (bin_dir / 'ruff').symlink_to(fixture)
            script = temp / 'test.lua'
            script.write_text('''
vim.opt.runtimepath:prepend(%s)
local exists = vim.fn.exists
if vim.env.LSP_TEST_NATIVE_COMMAND == '1' then
  -- Neovim 0.11 cannot define a lowercase user command; simulate the newer builtin.
  vim.fn.exists = function(name) return name == ':lsp' and 2 or exists(name) end
end
vim.cmd.runtime('plugin/lspconfig.lua')
vim.fn.exists = exists
package.path = %s .. ';' .. package.path
package.loaded['config.lazy'] = {} -- Exercise init without plugin installation.
dofile(%s)
vim.cmd('filetype plugin indent on')
local notes = {}
vim.notify = function(message) notes[#notes + 1] = tostring(message) end
local spec = require('plugins.lsp')
if spec.cond() then spec.config() end
for _, name in ipairs({ 'helm_ls', 'ruff', 'taplo', 'marksman', 'gopls' }) do
  assert(vim.lsp.is_enabled(name), name .. ': native server not enabled')
end
for _, name in ipairs({ 'ruby_lsp', 'lua_ls' }) do
  assert(not vim.lsp.is_enabled(name), name .. ': retired server enabled')
end
assert(vim.deep_equal(vim.lsp.config.helm_ls.filetypes, { 'helm' }), 'Helm filetypes changed')
assert(vim.fn.exists(':LspInfo') == 2, 'LspInfo command missing')
local available = %s
for _, project in ipairs(%s) do
  vim.env.PATH = project .. '/.dev/bin:' .. vim.env.LSP_PATH_BIN
  vim.cmd.edit(vim.fn.fnameescape(project .. '/example.' .. vim.env.LSP_PATH_EXTENSION))
  if available then
    assert(vim.wait(3000, function()
      local clients = vim.lsp.get_clients({ bufnr = 0, name = 'ruff' })
      return #clients == 1 and clients[1].initialized
    end, 10), 'PATH Ruff did not initialize: ' .. vim.inspect(notes))
    assert(vim.lsp.get_clients({ bufnr = 0, name = 'ruff' })[1].config.root_dir == project,
      'opening another project lost its LSP root')
  else
    vim.wait(200, function() return false end)
    assert(#vim.lsp.get_clients({ bufnr = 0 }) == 0,
      'excluded or missing server unexpectedly started a client')
  end
end
for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end
''' % (
                json.dumps(str(nvim_test.LAZY / 'nvim-lspconfig')),
                json.dumps(str(ROOT / '.config/nvim/lua/?.lua')),
                json.dumps(str(ROOT / '.config/nvim/init.lua')),
                'true' if available else 'false',
                '{' + ','.join(json.dumps(str(project)) for project in projects) + '}',
            ))
            env = dict(os.environ, HOME=str(temp), PATH=str(bin_dir),
                       DOTFILES_PROFILE='desktop', LSP_PATH_LOG=str(log), MISE_AUTO_INSTALL='true',
                       LSP_PATH_BIN=str(bin_dir), LSP_PATH_EXTENSION='rb' if filetype == 'ruby' else 'py',
                       LSP_TEST_NATIVE_COMMAND='1' if native_lsp_command else '0')
            for name in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME'):
                env[name] = str(temp / name.lower())
            result = subprocess.run(
                [NVIM, '--headless', '-u', 'NONE', '-i', 'NONE', '-n', '-l', str(script)],
                env=env, cwd=temp, capture_output=True, text=True, timeout=15,
            )
            events = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr + '\n' + repr(events))
            return events, str(temp), [project.as_uri() for project in projects]

    def test_path_command_preserves_arguments_and_each_project_root(self):
        events, cwd, roots = self.run_native_case(available=True)
        self.assertEqual([event for event in events if 'program' in event], [
            {'program': 'ruff', 'args': ['server'], 'cwd': cwd, 'mise_auto_install': 'false'},
            {'program': 'ruff', 'args': ['server'], 'cwd': cwd, 'mise_auto_install': 'false'},
        ])
        self.assertEqual(sorted(event['root_uri'] for event in events if 'root_uri' in event), sorted(roots))

    def test_missing_path_command_does_not_query_mise_or_start_a_client(self):
        events, _cwd, _roots = self.run_native_case(available=False)
        self.assertEqual(events, [])


    def test_ruby_projects_do_not_start_clients_or_invoke_available_wrappers(self):
        events, _cwd, _roots = self.run_native_case(available=False, filetype='ruby')
        self.assertEqual(events, [], 'Ruby LSP or a project/runtime wrapper was invoked')

    def test_lsp_info_survives_upstream_native_command_shortcut(self):
        events, _cwd, _roots = self.run_native_case(available=False, native_lsp_command=True)
        self.assertEqual(events, [])


if __name__ == '__main__':
    unittest.main()
