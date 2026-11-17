"""Exercise native LSP PATH startup and Ruby runtime routing in isolation."""

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

documents = {}
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
        result = {'capabilities': {'textDocumentSync': 1, 'documentFormattingProvider': True}}
    elif method == 'textDocument/didOpen':
        doc = request['params']['textDocument']
        documents[doc['uri']] = doc['text']
        continue
    elif method == 'textDocument/didChange':
        documents[request['params']['textDocument']['uri']] = request['params']['contentChanges'][0]['text']
        continue
    elif method == 'textDocument/formatting':
        uri = request['params']['textDocument']['uri']
        write_log({'format': True, 'uri': uri, 'text': documents.get(uri), 'cwd': os.getcwd()})
        result = [{'range': {'start': {'line': 0, 'character': 0}, 'end': {'line': 0, 'character': 100}},
                   'newText': 'formatted by project LSP'}]
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
local function activate(name)
  vim.env.PATH = base .. '/' .. name .. '/.dev/bin:' .. base .. '/bin'
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

    def run_case(self, code, *, modes=None, include_mise=True, profile='desktop', project_roots=()):
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
            for name in project_roots:
                project = base / name
                (project / 'Gemfile').touch()
                runner = project / '.dev/bin/ruby-lsp'
                runner.parent.mkdir(parents=True)
                runner.write_text('#!' + sys.executable + '\n' + r'''
import json, os
from pathlib import Path
import sys
root = Path(__file__).parents[2]
assert sys.argv[1:] == []
assert Path.cwd() == root
assert os.environ['PWD'] == str(root)
with open(Path(os.environ['LSP_TEST_DIR']) / 'calls.jsonl', 'a') as stream:
    stream.write(json.dumps({'transport': 'project_path', 'cwd': str(root)}) + '\n')
if (root / 'mode').exists() and (root / 'mode').read_text() == 'exit':
    print('fixture Docker image is missing; run setup', file=sys.stderr)
    sys.exit(23)
env = dict(os.environ, TEST_RUBY='project-' + root.name, TEST_BUNDLER='project-bundler-' + root.name,
           BUNDLE_GEMFILE=str(root / 'Gemfile'))
os.execve(str(root / 'ruby-lsp'), [str(root / 'ruby-lsp')], env)
''')
                runner.chmod(0o755)
            for root, mode in (modes or {}).items():
                (base / root / 'mode').write_text(mode)
            if include_mise:
                (base / 'bin/mise').write_text(FIXTURE)
                (base / 'bin/mise').chmod(0o755)
            (base / 'bin/bundle').write_text(FIXTURE)
            (base / 'bin/bundle').chmod(0o755)
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

    def test_project_roots_start_without_mise_and_reuse_their_clients(self):
        calls, notes = self.run_case(r'''
local cwd = vim.fn.getcwd()
activate('project a')
local a = open(base .. '/project a/one.rb')
assert(ready(a), 'Docker LSP for first root did not start')
local first = vim.lsp.get_clients({bufnr = a})[1]
activate('worktree')
local b = open(base .. '/worktree/one.rb')
assert(ready(b), 'Docker LSP for second root did not start')
assert(vim.lsp.get_clients({bufnr = b})[1].id ~= first.id)
activate('project a')
local another = open(base .. '/project a/two.rb')
assert(ready(another))
assert(vim.lsp.get_clients({bufnr = another})[1].id == first.id)
assert(vim.fn.getcwd() == cwd)
''', project_roots=('project a', 'worktree'), include_mise=False)
        starts = [call for call in calls if 'program' in call]
        self.assertEqual(len(starts), 2)
        self.assertTrue(all(call['ruby'].startswith('project-') for call in starts))
        self.assertTrue(all(call['bundle_gemfile'] == str(Path(call['cwd']) / 'Gemfile') for call in starts))
        self.assertFalse(notes)

    def test_failed_project_wrapper_never_uses_mise_or_retries_other_buffers(self):
        calls, notes = self.run_case(r'''
activate('project a')
local a = open(base .. '/project a/one.rb')
assert(vim.wait(3000, function() return #notifications > 0 end, 10))
open(base .. '/project a/two.rb')
vim.wait(100)
activate('worktree')
local b = open(base .. '/worktree/one.rb')
assert(ready(b))
''', project_roots=('project a', 'worktree'), modes={'project a': 'exit'})
        attempts = [call for call in calls if call.get('transport') == 'project_path']
        self.assertEqual(len(attempts), 2)
        root_notes = [note for note in notes if 'project a' in note]
        self.assertEqual(len(root_notes), 1, notes)
        self.assertFalse(any(call.get('fallback') for call in calls))

    def test_activated_project_formatting_uses_the_ready_project_client_for_unsaved_text(self):
        conform = Path.home() / '.local/share/nvim/lazy/conform.nvim'
        if not conform.is_dir():
            self.skipTest('installed Conform source required')
        calls, notes = self.run_case('vim.opt.rtp:append(' + json.dumps(str(conform)) + ')' + r'''
vim.fn.writefile({'AllCops: {}'}, base .. '/project a/.rubocop.yml')
local spec = require('plugins.conform')
require('conform').setup(spec.opts)
activate('project a')
local buf = open(base .. '/project a/one.rb')
assert(ready(buf))
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"puts 'unsaved buffer'"})
local plan = require('config.formatting').format(buf, 'manual')
assert(plan and plan.kind == 'ruby_lsp', 'container LSP must own formatting')
assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'formatted by project LSP')
''', project_roots=('project a',))
        formatted = [call for call in calls if call.get('format')]
        self.assertEqual(len(formatted), 1)
        self.assertIn('unsaved buffer', formatted[0]['text'])
        self.assertFalse(any(call.get('fallback') for call in calls), calls)
        self.assertFalse(notes)

    def test_activated_project_formatting_reports_missing_lsp_and_skips_unconfigured_projects(self):
        conform = Path.home() / '.local/share/nvim/lazy/conform.nvim'
        if not conform.is_dir():
            self.skipTest('installed Conform source required')
        calls, notes = self.run_case('vim.opt.rtp:append(' + json.dumps(str(conform)) + ')' + r'''
require('conform').setup(require('plugins.conform').opts)
activate('project a')
local buf = open(base .. '/project a/one.rb')
assert(ready(buf))
local formatting = require('config.formatting')
assert(formatting.format(buf, 'save').kind == 'skip', 'no project formatter must stay unformatted')
vim.fn.writefile({'AllCops: {}'}, base .. '/project a/.rubocop.yml')
local get_clients = vim.lsp.get_clients
vim.lsp.get_clients = function() return {} end
assert(formatting.format(buf, 'manual') == nil)
vim.lsp.get_clients = get_clients
assert(#notifications == 1 and notifications[1]:find('no ready client', 1, true))
''', project_roots=('project a',))
        self.assertFalse(any(call.get('format') or call.get('fallback') for call in calls), calls)
        self.assertEqual(len(notes), 1)

    def test_project_gem_sources_are_readonly_and_start_no_new_client(self):
        calls, notes = self.run_case(r'''
for _, root in ipairs({'project a', 'worktree', 'relocated project'}) do
  local gem_root = base .. '/' .. root .. '/.bundle/gems/ruby/4.0.0/gems/example'
  local path = gem_root .. '/lib/example.rb'
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({'class Example; end'}, path)
  vim.fn.writefile({'source "https://rubygems.org"'}, gem_root .. '/Gemfile')
  local gem = open(path)
  vim.wait(80)
  assert(vim.bo[gem].readonly and not vim.bo[gem].modifiable, 'project gem source must be readonly')
  assert(#vim.lsp.get_clients({bufnr = gem}) == 0, 'gem must not start a host LSP')
  assert(require('config.formatting').format(gem, 'save').kind == 'skip')
end
''')
        self.assertFalse(calls)
        self.assertFalse(notes)

    def test_bundle_sibling_sources_stay_editable_and_use_project_lsp(self):
        calls, notes = self.run_case(r'''
activate('project a')
for _, suffix in ipairs({'/.bundle/gems-other/example.rb', '/lib/example.rb'}) do
  local path = base .. '/project a' .. suffix
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({'puts :editable'}, path)
  local buf = open(path)
  assert(not vim.bo[buf].readonly and vim.bo[buf].modifiable, 'ordinary source was made readonly')
  assert(ready(buf), 'ordinary source did not receive project LSP')
end
''', project_roots=('project a',))
        self.assertEqual(len([call for call in calls if 'program' in call]), 1)
        self.assertFalse(notes)

    def test_inactive_project_wrappers_and_another_roots_path_keep_mise(self):
        calls, notes = self.run_case(r'''
local a = open(base .. '/project a/one.rb')
assert(ready(a))
activate('project a')
local b = open(base .. '/worktree/one.rb')
assert(ready(b))
''', project_roots=('project a', 'worktree'))
        starts = [call for call in calls if 'program' in call]
        self.assertEqual(len(starts), 2)
        self.assertFalse(any(call.get('transport') for call in calls), calls)
        self.assertEqual({call['ruby'] for call in starts}, {'project a', 'worktree'})
        self.assertFalse(notes)

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


@unittest.skipUnless(NVIM, 'Neovim is not installed')
@unittest.skipUnless((nvim_test.LAZY / 'nvim-lspconfig').is_dir(), 'installed nvim-lspconfig source is required')
class NativeLspPathTest(unittest.TestCase):
    setUpClass = classmethod(nvim_test.NeovimTest.setUpClass.__func__)

    def run_native_case(self, *, available):
        with tempfile.TemporaryDirectory(prefix='dotfiles-native-lsp-') as directory:
            temp = Path(directory)
            projects = [temp / 'project a', temp / 'project b']
            for project in projects:
                project.mkdir()
                (project / 'pyproject.toml').write_text('[project]\nname = "fixture"\n')
                (project / 'example.py').write_text('print("hello")\n')
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
            (bin_dir / 'mise').symlink_to(fixture)
            if available:
                (bin_dir / 'ruff').symlink_to(fixture)
            script = temp / 'test.lua'
            script.write_text('''
vim.opt.runtimepath:prepend(%s)
package.path = %s .. ';' .. package.path
package.loaded['config.lazy'] = {} -- Exercise init without plugin installation.
dofile(%s)
vim.cmd('filetype plugin indent on')
local notes = {}
vim.notify = function(message) notes[#notes + 1] = tostring(message) end
for _, spec in ipairs(require('plugins.lsp')) do
  if spec.cond() then spec.config() end
end
local available = %s
for _, project in ipairs(%s) do
  vim.cmd.edit(vim.fn.fnameescape(project .. '/example.py'))
  if available then
    assert(vim.wait(3000, function()
      local clients = vim.lsp.get_clients({ bufnr = 0, name = 'ruff' })
      return #clients == 1 and clients[1].initialized
    end, 10), 'PATH Ruff did not initialize: ' .. vim.inspect(notes))
    assert(vim.lsp.get_clients({ bufnr = 0, name = 'ruff' })[1].config.root_dir == project,
      'opening another project lost its LSP root')
  else
    vim.wait(200, function() return false end)
    assert(#vim.lsp.get_clients({ bufnr = 0, name = 'ruff' }) == 0,
      'missing PATH executable unexpectedly started a client')
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
                       DOTFILES_PROFILE='desktop', LSP_PATH_LOG=str(log), MISE_AUTO_INSTALL='true')
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


if __name__ == '__main__':
    unittest.main()
