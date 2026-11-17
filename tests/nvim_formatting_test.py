"""Manual Conform formatting with isolated PATH tools and real buffer writes.

Uses installed Conform sources without loading Lazy or touching user state.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
CONFORM = Path.home() / ".local/share/nvim/lazy/conform.nvim"

TOOL = r'''#!PYTHON
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
with open(os.environ['CALL_LOG'], 'a') as out:
    out.write(json.dumps({'name':name, 'args':sys.argv[1:], 'cwd':os.getcwd()})+'\n')
if name in ('mise', 'docker', 'ruby', 'ruby-lsp', 'rubocop', 'bundle'):
    sys.exit('unexpected runtime routing')
if name == 'dprint':
    config = next((p / 'dprint.json' for p in [pathlib.Path.cwd(), *pathlib.Path.cwd().parents]
                   if (p / 'dprint.json').exists()), pathlib.Path.home() / '.config/dprint/dprint.jsonc')
    if not config.exists() or config.read_text() == 'BROKEN':
        sys.exit('invalid or missing dprint configuration')
sys.stdout.write(sys.stdin.read().replace('value=1', 'value = 1'))
'''.replace('PYTHON', sys.executable)

@unittest.skipUnless(NVIM and CONFORM.is_dir(), "Neovim and installed Conform are required")
class ManualFormattingTest(unittest.TestCase):
    def run_case(self, body, *, config=None, global_config='{}', tools=None):
        with tempfile.TemporaryDirectory(prefix="nvim-manual-format-") as td:
            temp = Path(td)
            project = temp / "project with spaces"
            project.mkdir()
            (project / "nested").mkdir()
            if config is not None:
                (project / "dprint.json").write_text(config)
            if global_config is not None:
                global_path = temp / '.config/dprint/dprint.jsonc'
                global_path.parent.mkdir(parents=True)
                global_path.write_text(global_config)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            names = tools if tools is not None else ["dprint", "stylua"]
            for name in names + ["mise", "docker", "ruby", "ruby-lsp", "rubocop", "bundle"]:
                p = bin_dir / name
                p.write_text(TOOL)
                p.chmod(0o755)
            script = temp / "test.lua"
            script.write_text(
                'vim.opt.rtp:append(' + json.dumps(str(CONFORM)) + ')\n'
                + 'package.path = ' + json.dumps(str(ROOT / '.config/nvim/lua/?.lua') + ';') + '..package.path\n'
                + '''local conform = require('conform')
conform.setup(require('plugins.conform').opts)
local messages = {}
vim.notify = function(message) messages[#messages+1] = tostring(message) end
local function open(name, ft)
  vim.cmd.edit(vim.fn.fnameescape(vim.env.PROJECT .. '/' .. name))
  vim.bo.filetype = ft
  vim.api.nvim_buf_set_lines(0,0,-1,false,{'value=1'})
end
local function format()
  conform.format({async=false})
  vim.wait(50, function() return false end)
end
''' + body)
            env = dict(os.environ, HOME=td, PATH=str(bin_dir), PROJECT=str(project),
                       CALL_LOG=str(temp / "calls.jsonl"), DOTFILES_PROFILE="desktop")
            for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
                env[name] = str(temp / name)
            result = subprocess.run([NVIM, '--headless', '-u', 'NONE', '-i', 'NONE', '-n', '-l', str(script)],
                                    env=env, cwd=temp, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            log = temp / 'calls.jsonl'
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return calls

    def test_save_does_not_format_manual_action_does(self):
        calls = self.run_case('''
open('sample.lua', 'lua')
vim.cmd.write()
assert(vim.fn.readfile(vim.api.nvim_buf_get_name(0))[1] == 'value=1')
assert(vim.fn.filereadable(vim.env.CALL_LOG) == 0, 'save invoked a tool')
format()
assert(vim.api.nvim_get_current_line() == 'value = 1', 'manual formatting did not edit buffer')
assert(vim.fn.readfile(vim.api.nvim_buf_get_name(0))[1] == 'value=1', 'format silently saved buffer')
vim.cmd.write()
assert(vim.fn.readfile(vim.api.nvim_buf_get_name(0))[1] == 'value = 1')
''')
        self.assertEqual([c['name'] for c in calls], ['stylua'])

    def test_project_dprint_discovers_repo_config_from_file_directory(self):
        calls = self.run_case('''
open('nested/example.yaml', 'yaml')
format()
assert(vim.api.nvim_get_current_line() == 'value = 1')
''', config='{}')
        self.assertEqual([c['name'] for c in calls], ['dprint'])
        call = calls[0]
        self.assertEqual(call['args'][:2], ['fmt', '--stdin'])
        self.assertEqual(Path(call['args'][2]).parent, Path(call['cwd']))

    def test_missing_or_broken_project_formatter_has_no_fallback(self):
        for config, tools in [('BROKEN', ['dprint', 'oxfmt']), ('{}', ['oxfmt'])]:
            with self.subTest(config=config, tools=tools):
                calls = self.run_case('''
open('example.yaml', 'yaml')
format()
assert(vim.api.nvim_get_current_line() == 'value=1', 'failed formatter changed buffer')
assert(#messages > 0, 'failure was not visible')
''', config=config, tools=tools)
                self.assertTrue(all(c['name'] == 'dprint' for c in calls), calls)

    def test_files_without_project_config_use_dprint_stdin_without_saving(self):
        calls = self.run_case("""
for _, ft in ipairs({'yaml', 'yaml.docker-compose', 'yaml.tmuxinator',
  'javascript', 'javascriptreact', 'typescript', 'typescriptreact',
  'json', 'jsonc', 'json5', 'css', 'graphql', 'markdown'}) do
  open('nested/example.' .. ft, ft)
  vim.cmd.write()
  format()
  assert(vim.api.nvim_get_current_line() == 'value = 1', ft .. ' was not formatted')
  assert(vim.fn.readfile(vim.api.nvim_buf_get_name(0))[1] == 'value=1', ft .. ' was saved by formatter')
  assert(vim.bo.modified, ft .. ' lost unsaved changes')
  vim.bo.modified = false
end
""")
        self.assertEqual(len(calls), 13)
        self.assertTrue(all(c['name'] == 'dprint' for c in calls), calls)
        self.assertTrue(all(c['args'][:2] == ['fmt', '--stdin'] for c in calls), calls)
        self.assertTrue(all(Path(c['args'][2]).parent == Path(c['cwd']) for c in calls), calls)

    def test_missing_or_broken_global_dprint_keeps_buffer_and_reports_error(self):
        for config, tools in [(None, ['dprint']), ('BROKEN', ['dprint']), ('{}', ['stylua'])]:
            with self.subTest(config=config, tools=tools):
                calls = self.run_case('''
open('example.js', 'javascript')
vim.lsp.buf.format = function() error('unexpected LSP formatting') end
format()
assert(vim.api.nvim_get_current_line() == 'value=1', 'failed formatter changed buffer')
assert(#messages > 0, 'formatter failure was not visible')
''', tools=tools, global_config=config)
                self.assertTrue(all(c['name'] == 'dprint' for c in calls), calls)

    def test_ruby_and_erb_are_not_formatted_even_with_lsp_available(self):
        calls = self.run_case('''
vim.lsp.buf.format = function() error('unexpected LSP formatting') end
for _, ft in ipairs({'ruby', 'eruby.yaml.tmuxinator'}) do
  open('example.' .. ft, ft)
  format()
  assert(vim.api.nvim_get_current_line() == 'value=1')
end
''', config='{}')
        self.assertEqual(calls, [])

if __name__ == '__main__':
    unittest.main()
