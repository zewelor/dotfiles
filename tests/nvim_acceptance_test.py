"""Opt-in full-config acceptance using prepared plugins and real formatters.

DOTFILES_TEST_DPRINT=/absolute/dprint \
DOTFILES_TEST_DPRINT_CACHE=/prepared/dprint-cache \
DOTFILES_TEST_MARKSMAN=/absolute/marksman \
DOTFILES_TEST_RUFF=/absolute/ruff python3 -m unittest tests.nvim_acceptance_test

Copies installed plugins/cache into temporary HOME. Never installs or updates.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOST = Path.home()
NVIM = shutil.which('nvim')
TOOLS = {name: os.environ.get('DOTFILES_TEST_' + name.upper()) for name in ('dprint', 'ruff', 'marksman')}

@unittest.skipUnless(NVIM and all(TOOLS.values()), 'explicit real formatter and LSP paths required')
class PreparedEditorAcceptance(unittest.TestCase):
    def test_desktop_and_server_with_prepared_tools(self):
        for name, executable in TOOLS.items():
            self.assertTrue(Path(executable).is_file() and os.access(executable, os.X_OK),
                            f'{name} must point to a prepared executable: {executable}')
        with tempfile.TemporaryDirectory(prefix='nvim-prepared-acceptance-') as td:
            home = Path(td)
            config = home / '.config/nvim'
            shutil.copytree(ROOT / '.config/nvim', config)
            plugins = home / '.local/share/nvim/lazy'
            plugins.mkdir(parents=True)
            shutil.copytree(HOST / '.local/share/nvim/site', home / '.local/share/nvim/site')
            for source in (HOST / '.local/share/nvim/lazy').iterdir():
                if source.is_dir() and source.name not in ('copilot.lua', 'opencode.nvim', 'mason.nvim', 'editorconfig-vim'):
                    shutil.copytree(source, plugins / source.name, ignore=shutil.ignore_patterns('.git'))
            cache = home / '.cache/dprint'
            shutil.copytree(HOST / '.cache/dprint', cache)
            if os.environ.get('DOTFILES_TEST_DPRINT_CACHE'):
                shutil.copytree(os.environ['DOTFILES_TEST_DPRINT_CACHE'], cache, dirs_exist_ok=True)
            global_config = home / '.config/dprint/dprint.jsonc'
            global_config.parent.mkdir()
            shutil.copyfile(ROOT / '.config/dprint/dprint.jsonc', global_config)
            bin_dir = home / 'bin'
            bin_dir.mkdir()
            for name, executable in TOOLS.items():
                (bin_dir / name).symlink_to(Path(executable).resolve())
            for name in ('curl', 'wget', 'make', 'cc', 'docker', 'ruby', 'ruby-lsp', 'mise', 'npm', 'yamlfmt', 'oxfmt'):
                path = bin_dir / name
                path.write_text('#!/bin/sh\necho ' + name + ' >> "$HOME/unexpected-commands"\nexit 91\n')
                path.chmod(0o755)
            git = bin_dir / 'git'
            git.write_text('#!/bin/sh\ncase "$1" in clone|fetch|pull) echo git >> "$HOME/unexpected-commands"; exit 91;; esac\nexec /usr/bin/git "$@"\n')
            git.chmod(0o755)
            project = home / 'project with spaces'
            project.mkdir()
            (project / '.editorconfig').write_text('root = true\n[*]\nindent_style = space\nindent_size = 2\n')
            (project / 'dprint.json').write_text(json.dumps({
                'includes': ['**/*.yaml'], 'excludes': ['excluded.yaml'], 'yaml': {'indentWidth': 4},
                'plugins': ['https://plugins.dprint.dev/g-plane/pretty_yaml-v0.6.0.wasm']}))
            (project / 'example.yaml').write_text('parent:\n  child: 1\n')
            (project / 'excluded.yaml').write_text('parent:\n  child: 1\n')
            (project / 'example.rb').write_text('puts "hello"\n')
            (project / 'pyproject.toml').write_text('[project]\nname = "probe"\nversion = "0.1.0"\n')
            (project / 'example.py').write_text('x=1\n')
            (project / 'unhandled.js').write_text('const value={answer:42};\n')
            plain = home / 'plain project'
            plain.mkdir()
            (plain / 'example.js').write_text('const value={answer:42};\n')
            (plain / 'example.yaml').write_text('parent: {child: 1, other: [1,2,3]}\n')
            global_samples = {
                'example.ts': 'const value={answer:42};\n',
                'example.json': '{"answer":42}\n',
                'example.jsonc': '// comment\n{"answer":42}\n',
                'example.json5': '{answer:42}\n',
                'example.css': 'a{color:red}\n',
                'example.graphql': 'query Test{user{id}}\n',
                'example.md': '#   Heading\n\n-   item\n',
            }
            for name, text in global_samples.items():
                (plain / name).write_text(text)
            (plain / 'package-lock.json').write_text('{"answer":42}\n')
            script = home / 'accept.lua'
            script.write_text('''
local function open(path) vim.cmd.edit(vim.fn.fnameescape(path)) end
local desktop = vim.env.DOTFILES_PROFILE == 'desktop'
local config = require('lazy.core.config')
for _, name in ipairs({'copilot.lua','opencode.nvim','mason.nvim','editorconfig-vim'}) do
  assert(not config.plugins[name], name .. ' remains enabled')
end
assert(vim.env.MISE_AUTO_INSTALL == 'false')
assert(vim.fn.maparg(' ff','n') ~= '' and vim.fn.maparg(' ghs','n') ~= '')
open(vim.env.PROJECT .. '/example.rb')
vim.wait(200)
assert(#vim.lsp.get_clients({bufnr=0}) == 0, 'Ruby started an LSP')
assert((vim.fn.maparg(' cf','n') ~= '') == desktop)
if desktop then
  open(vim.env.PROJECT .. '/example.yaml')
  assert(vim.bo.shiftwidth == 2, 'builtin EditorConfig did not apply')
  vim.cmd.write()
  assert(vim.fn.readfile(vim.api.nvim_buf_get_name(0))[2] == '  child: 1', 'save formatted YAML')
  vim.fn.maparg(' cf','n',false,true).callback()
  assert(vim.api.nvim_buf_get_lines(0,1,2,false)[1] == '    child: 1', 'repo dprint rules not used')
  assert(vim.fn.readfile(vim.api.nvim_buf_get_name(0))[2] == '  child: 1', 'manual format saved file')
  vim.bo.modified = false
  open(vim.env.PROJECT .. '/excluded.yaml')
  vim.fn.maparg(' cf','n',false,true).callback()
  assert(vim.api.nvim_buf_get_lines(0,1,2,false)[1] == '  child: 1', 'dprint exclusion ignored')
  for _, name in ipairs({'dprint.json', 'dprint.jsonc'}) do
    local config_dir = vim.env.PROJECT .. '/.config'
    vim.fn.mkdir(config_dir, 'p')
    assert(vim.uv.fs_rename(vim.env.PROJECT .. '/dprint.json', config_dir .. '/' .. name))
    open(vim.env.PROJECT .. '/example.yaml')
    vim.cmd('edit!')
    assert(vim.api.nvim_buf_get_lines(0,1,2,false)[1] == '  child: 1', 'fixture already formatted')
    vim.fn.maparg(' cf','n',false,true).callback()
    assert(vim.api.nvim_buf_get_lines(0,1,2,false)[1] == '    child: 1', '.config/' .. name .. ' not used')
    vim.bo.modified = false
    assert(vim.uv.fs_rename(config_dir .. '/' .. name, vim.env.PROJECT .. '/dprint.json'))
  end
  open(vim.env.PROJECT .. '/unhandled.js')
  vim.fn.maparg(' cf','n',false,true).callback()
  assert(vim.api.nvim_get_current_line() == 'const value={answer:42};', 'global plugin overrode the project plugin set')
  vim.bo.modified = false
  open(vim.env.PLAIN .. '/example.js')
  vim.cmd.write()
  assert(vim.api.nvim_get_current_line() == 'const value={answer:42};', 'save formatted JavaScript')
  vim.fn.maparg(' cf','n',false,true).callback()
  assert(vim.api.nvim_get_current_line() == 'const value = { answer: 42 };', 'global dprint did not format JavaScript')
  assert(vim.fn.readfile(vim.api.nvim_buf_get_name(0))[1] == 'const value={answer:42};', 'dprint saved JavaScript')
  local formatted = vim.api.nvim_get_current_line()
  vim.fn.maparg(' cf','n',false,true).callback()
  assert(vim.api.nvim_get_current_line() == formatted, 'global dprint JavaScript is not idempotent')
  vim.bo.modified = false
  open(vim.env.PLAIN .. '/example.yaml')
  vim.fn.maparg(' cf','n',false,true).callback()
  assert(vim.api.nvim_get_current_line() == 'parent: { child: 1, other: [1, 2, 3] }', 'global dprint did not format YAML')
  assert(vim.fn.readfile(vim.api.nvim_buf_get_name(0))[1] == 'parent: {child: 1, other: [1,2,3]}', 'dprint saved YAML')
  formatted = vim.api.nvim_get_current_line()
  vim.fn.maparg(' cf','n',false,true).callback()
  assert(vim.api.nvim_get_current_line() == formatted, 'global dprint YAML is not idempotent')
  vim.bo.modified = false
  for _, extension in ipairs({'ts', 'json', 'jsonc', 'json5', 'css', 'graphql', 'md'}) do
    open(vim.env.PLAIN .. '/example.' .. extension)
    local path = vim.api.nvim_buf_get_name(0)
    local original = table.concat(vim.fn.readfile(path), '\\n')
    vim.fn.maparg(' cf','n',false,true).callback()
    local result = table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false), '\\n')
    assert(result ~= original, extension .. ' was not formatted by the global plugin')
    assert(table.concat(vim.fn.readfile(path), '\\n') == original, extension .. ' was saved by formatting')
    vim.fn.maparg(' cf','n',false,true).callback()
    assert(table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false), '\\n') == result, extension .. ' is not idempotent')
    vim.bo.modified = false
  end
  open(vim.env.PLAIN .. '/package-lock.json')
  vim.fn.maparg(' cf','n',false,true).callback()
  assert(vim.api.nvim_get_current_line() == '{"answer":42}', 'global exclusion was ignored')
  assert(#vim.fn.glob(vim.env.PLAIN .. '/.conform.*', false, true) == 0, 'dprint left temporary files')
  vim.bo.modified = false
  open(vim.env.PROJECT .. '/example.py')
  assert(vim.wait(5000, function()
    for _, client in ipairs(vim.lsp.get_clients({bufnr=0, name='ruff'})) do
      if client.initialized then return true end
    end
  end, 25), 'real Ruff did not initialize')
  for _, client in ipairs(vim.lsp.get_clients()) do client:stop() end
  assert(vim.wait(3000, function() return #vim.lsp.get_clients() == 0 end, 25), 'LSP did not shut down')
else
  assert(not config.plugins['nvim-treesitter'], 'server loads Tree-sitter')
end
assert(vim.fn.filereadable(vim.env.HOME .. '/unexpected-commands') == 0, 'unexpected install/runtime command')
print('ACCEPTED ' .. vim.env.DOTFILES_PROFILE)
vim.cmd('qa!')
''')
            for profile in ('desktop', 'server'):
                env = dict(os.environ, HOME=td, DOTFILES_PROFILE=profile,
                           PATH=str(bin_dir) + ':/usr/bin:/bin', PROJECT=str(project), PLAIN=str(plain),
                           MISE_AUTO_INSTALL='true', DPRINT_CACHE_DIR=str(cache / "cache"),
                           DPRINT_CONFIG_DIR=str(global_config.parent),
                           HTTP_PROXY='http://127.0.0.1:1', HTTPS_PROXY='http://127.0.0.1:1',
                           http_proxy='http://127.0.0.1:1', https_proxy='http://127.0.0.1:1',
                           NVIM_APPNAME='nvim', NVIM_LOG_FILE=str(home / 'nvim.log'))
                env.pop('DPRINT_CONFIG_DISCOVERY', None)
                for key, value in {'XDG_CONFIG_HOME':'.config','XDG_DATA_HOME':'.local/share',
                                   'XDG_STATE_HOME':'.local/state','XDG_CACHE_HOME':'.cache'}.items():
                    env[key] = str(home / value)
                result = subprocess.run([NVIM, '--headless', '-i', 'NONE', '-n', '-c', 'luafile ' + str(script), '-c', 'qa!'],
                                        env=env, cwd=home, capture_output=True, text=True, timeout=25)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                logs = '\n'.join(p.read_text(errors='replace') for p in (home / '.local/state/nvim').glob('*.log'))
                self.assertIn('ACCEPTED ' + profile, result.stdout + result.stderr + '\n' + logs)
                self.assertNotIn('Error detected', result.stdout + result.stderr)
                self.assertFalse((home / 'unexpected-commands').exists(), result.stdout + result.stderr)

if __name__ == '__main__':
    unittest.main()
