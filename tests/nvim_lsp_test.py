"""Start native Ruby LSP clients with controlled mise/runtime subprocesses."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import nvim_test

ROOT, NVIM = nvim_test.ROOT, nvim_test.NVIM


FIXTURE = r'''#!PYTHON
import json
import os
from pathlib import Path
import sys

base = Path(os.environ['LSP_TEST_DIR'])
args = sys.argv[1:]
root = Path.cwd()
if Path(sys.argv[0]).name == 'mise':
    if args[:1] == ['-C']:
        root = Path(args[1])
        args = args[2:]
    mode_file = root / 'mode'
    mode = mode_file.read_text() if mode_file.exists() else ''
    if len(args) == 2 and args[0] == 'which' and args[1] in ('ruby', 'ruby-lsp'):
        if mode == 'error':
            print('fixture mise resolution failed', file=sys.stderr)
            sys.exit(9)
        if mode == 'empty':
            sys.exit(0)
        if mode == 'missing':
            print(root / 'absent-ruby-lsp')
            sys.exit(0)
        if mode == 'runtime-missing' and args[1] == 'ruby':
            print(root / 'absent-ruby')
            sys.exit(0)
        print(root / args[1] if (root / args[1]).exists() else base / 'foreign' / args[1])
        sys.exit(0)
    if args[:2] == ['exec', '--']:
        assert os.environ['MISE_AUTO_INSTALL'] == 'false'
        assert Path(args[-1]).is_absolute()
        if mode == 'exit':
            print('fixture runtime startup failed', file=sys.stderr)
            sys.exit(23)
        if mode == 'signal':
            os.kill(os.getpid(), 9)
        env = dict(os.environ, TEST_RUBY=root.name, TEST_BUNDLER=root.name + '-bundler')
        os.execvpe(args[2], args[2:], env)
    sys.exit(2)

def write_log(entry):
    with open(base / 'calls.jsonl', 'a') as stream:
        stream.write(json.dumps(entry) + '\n')

if Path(sys.argv[0]).parent == base / 'bin':
    write_log({'fallback': True})
    sys.exit(31)

for line in sys.stdin.buffer:
    if not line.startswith(b'Content-Length:'):
        continue
    length = int(line.split(b':')[1])
    assert sys.stdin.buffer.readline() == b'\r\n'
    request = json.loads(sys.stdin.buffer.read(length))
    method = request.get('method')
    if method == 'initialize':
        write_log({
            'program': sys.argv[0], 'cwd': os.getcwd(),
            'ruby': os.environ.get('TEST_RUBY'), 'bundler': os.environ.get('TEST_BUNDLER'),
            'bundle_gemfile': os.environ.get('BUNDLE_GEMFILE'),
            'root': request['params']['rootUri'],
        })
        result = {'capabilities': {'textDocumentSync': 1}}
    elif method == 'exit':
        break
    else:
        result = None
    if 'id' in request:
        body = json.dumps({'jsonrpc': '2.0', 'id': request['id'], 'result': result}).encode()
        sys.stdout.buffer.write(b'Content-Length: ' + str(len(body)).encode() + b'\r\n\r\n' + body)
        sys.stdout.buffer.flush()
'''.replace('PYTHON', sys.executable)

SETUP = r'''
package.path = REPO .. '/.config/nvim/lua/?.lua;' .. package.path
-- Keep native LSP lifecycle/root discovery; seed only plugin defaults offline.
for _, name in ipairs(require('config.tools').servers) do
  vim.lsp.config(name, {cmd = {'unused'}, filetypes = {'unused'}})
end
vim.lsp.config('ruby_lsp', {
  cmd = {'ruby-lsp'}, filetypes = {'ruby'}, root_markers = {'Gemfile', '.git'},
})
local notifications = {}
vim.notify = function(message) notifications[#notifications + 1] = tostring(message) end
-- The runner may itself live under /tmp/.git; simulate a marker-free standalone path.
local fs_root = vim.fs.root
vim.fs.root = function(source, markers)
  local path = type(source) == 'number' and vim.api.nvim_buf_get_name(source) or source
  if path:find(base .. '/standalone/', 1, true) == 1 then return nil end
  return fs_root(source, markers)
end
for _, spec in ipairs(require('plugins.lsp')) do
  if spec[1] == 'neovim/nvim-lspconfig' and spec.cond() then spec.config() end
end
local function open(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.bo.filetype = 'ruby'
  return vim.api.nvim_get_current_buf()
end
local function ready(buf)
  return vim.wait(3000, function()
    for _, client in ipairs(vim.lsp.get_clients({bufnr = buf})) do
      if client.initialized then return true end
    end
    return false
  end, 10)
end
'''


@unittest.skipUnless(NVIM, 'Neovim is not installed')
class RubyLspStartupTest(unittest.TestCase):
    setUpClass = classmethod(nvim_test.NeovimTest.setUpClass.__func__)

    def run_case(self, code, *, modes=None, include_mise=True, profile='desktop'):
        with tempfile.TemporaryDirectory(prefix='dotfiles-ruby-lsp-') as directory:
            base = Path(directory)
            for name in ('bin', 'foreign', 'project a', 'worktree', 'standalone'):
                path = base / name
                path.mkdir()
                (path / 'ruby-lsp').write_text(FIXTURE)
                (path / 'ruby-lsp').chmod(0o755)
                (path / 'ruby').write_text(FIXTURE)
                (path / 'ruby').chmod(0o755)
                for filename in ('one.rb', 'two.rb'):
                    (path / filename).write_text('puts :fixture\n')
            (base / 'project a/Gemfile').touch()
            (base / 'worktree/.git').write_text('gitdir: /fixture/repository/.git/worktrees/test\n')
            for root, mode in (modes or {}).items():
                (base / root / 'mode').write_text(mode)
            if include_mise:
                (base / 'bin/mise').write_text(FIXTURE)
                (base / 'bin/mise').chmod(0o755)
            (base / 'bin/env').symlink_to(shutil.which('env'))
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith(('MISE_', 'BUNDLE_', 'RUBY', 'GEM_', 'XDG_'))}
            env.update(HOME=directory, PATH=str(base / 'bin'), LSP_TEST_DIR=directory,
                       TEST_RUBY='inherited-wrong-ruby', TEST_BUNDLER='inherited-wrong-bundler',
                       BUNDLE_GEMFILE='/foreign/Gemfile')
            env.pop('DOTFILES_PROFILE', None)
            if profile:
                env['DOTFILES_PROFILE'] = profile
            for name in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME'):
                env[name] = str(base / name.lower())
            script = base / 'test.lua'
            script.write_text('local REPO = ' + json.dumps(str(ROOT)) + '\nlocal base = '
                              + json.dumps(directory) + '\n' + SETUP + code + r'''
vim.fn.writefile({vim.json.encode(notifications)}, base .. '/notifications.json')
vim.lsp.stop_client(vim.lsp.get_clients())
vim.wait(2000, function() return #vim.lsp.get_clients() == 0 end, 10)
vim.cmd('qa!')
''')
            result = subprocess.run(
                [NVIM, '--headless', '-u', 'NONE', '-i', 'NONE', '-n', '-l', str(script)],
                cwd=base / 'foreign', env=env, capture_output=True, text=True, timeout=15)
            calls = [json.loads(line) for line in (base / 'calls.jsonl').read_text().splitlines()] \
                if (base / 'calls.jsonl').exists() else []
            notes = json.loads((base / 'notifications.json').read_text()) \
                if (base / 'notifications.json').exists() else []
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return calls, notes

    def test_two_roots_and_standalone_keep_their_runtime_and_reuse_clients(self):
        for order in (('project a', 'worktree'), ('worktree', 'project a')):
            with self.subTest(order=order):
                calls, notes = self.run_case('local order = ' + json.dumps(order).replace('[', '{').replace(']', '}') + r'''
local initial_cwd = vim.fn.getcwd()
vim.bo.filetype = 'ruby'
vim.wait(50, function() return false end, 10)
assert(#vim.lsp.get_clients() == 0, 'unnamed Ruby buffer started a client')
local initial_ruby, initial_bundler = vim.env.TEST_RUBY, vim.env.TEST_BUNDLER
local initial_gemfile = vim.env.BUNDLE_GEMFILE
local first_id
for _, name in ipairs(order) do
  local buf = open(base .. '/' .. name .. '/one.rb')
  assert(ready(buf), 'client did not initialize: ' .. name)
  local client = vim.lsp.get_clients({bufnr = buf})[1]
  assert(client.config.root_dir == base .. '/' .. name, 'wrong native client root')
  local entries = vim.fn.readfile(base .. '/calls.jsonl')
  local process = vim.json.decode(entries[#entries])
  assert(process.cwd == client.config.root_dir, 'Ruby process started outside its project')
  assert(process.ruby == name and process.bundler == name .. '-bundler', 'wrong project runtime')
  first_id = first_id or client.id
end
local again = open(base .. '/' .. order[1] .. '/two.rb')
assert(ready(again))
assert(vim.lsp.get_clients({bufnr = again})[1].id == first_id, 'same-root client was not reused')
local standalone = open(base .. '/standalone/one.rb')
assert(ready(standalone), 'standalone Ruby did not initialize: ' .. table.concat(notifications, '\n'))
assert(vim.lsp.get_clients({bufnr = standalone})[1].config.root_dir == base .. '/standalone')
assert(vim.fn.getcwd() == initial_cwd, 'global cwd changed')
assert(vim.env.TEST_RUBY == initial_ruby and vim.env.TEST_BUNDLER == initial_bundler,
  'client environment leaked into Neovim')
assert(vim.env.BUNDLE_GEMFILE == initial_gemfile, 'bundle environment changed globally')
''')
                self.assertEqual(len(calls), 3, calls)
                self.assertFalse(notes, notes)
                for call, root in zip(calls, (*order, 'standalone')):
                    self.assertTrue(call['program'].endswith('/' + root + '/ruby-lsp'), call)
                    self.assertTrue(call['cwd'].endswith('/' + root), call)
                    self.assertEqual(call['ruby'], root)
                    self.assertEqual(call['bundler'], root + '-bundler')
                    self.assertIsNone(call['bundle_gemfile'])

    def test_failures_are_visible_once_per_root_without_path_fallback(self):
        for mode in ('error', 'empty', 'missing', 'runtime-missing', 'exit', 'signal', 'no-mise'):
            with self.subTest(mode=mode):
                calls, notes = self.run_case(r'''
local buf = open(base .. '/project a/one.rb')
assert(not ready(buf), 'failed project unexpectedly started')
open(base .. '/project a/two.rb')
vim.wait(100, function() return false end, 10)
if vim.fn.executable('mise') == 1 then
  local healthy = open(base .. '/worktree/one.rb')
  assert(ready(healthy), 'failure in another root disabled this project')
end
''', modes={'project a': mode}, include_mise=mode != 'no-mise')
                self.assertEqual(len(calls), 0 if mode == 'no-mise' else 1, calls)
                for call in calls:
                    self.assertTrue(call.get('cwd', '').endswith('/worktree'), calls)
                relevant = [note for note in notes if 'project a' in note]
                self.assertEqual(len(relevant), 1, notes)
                self.assertIn('ruby', relevant[0].lower())

    def test_server_and_unset_profile_do_not_start_editor_tools(self):
        for profile in ('server', None):
            with self.subTest(profile=profile):
                calls, notes = self.run_case(r'''
local buf = open(base .. '/project a/one.rb')
vim.wait(100, function() return false end, 10)
assert(#vim.lsp.get_clients({bufnr = buf}) == 0)
''', profile=profile)
                self.assertFalse(calls)
                self.assertFalse(notes)

    def test_native_spawn_failure_is_reported_once_for_the_root(self):
        calls, notes = self.run_case(r'''
local system = vim.system
vim.system = function(cmd, opts, on_exit)
  if opts.stdin and vim.tbl_contains(cmd, base .. '/project a') then
    error('fixture native spawn denied')
  end
  return system(cmd, opts, on_exit)
end
assert(not ready(open(base .. '/project a/one.rb')))
open(base .. '/project a/two.rb')
vim.wait(100, function() return false end, 10)
''')
        self.assertFalse(calls, calls)
        self.assertEqual(len(notes), 1, notes)
        self.assertIn('project a', notes[0])
        self.assertIn('fixture native spawn denied', notes[0])


if __name__ == '__main__':
    unittest.main()
