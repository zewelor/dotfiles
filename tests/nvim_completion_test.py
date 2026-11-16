"""Exercise completion keys in real Neovim using an offline Blink source."""

import json
from itertools import product
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
BLINK = Path.home() / ".local/share/nvim/lazy/blink.cmp"


@unittest.skipUnless(NVIM and BLINK.is_dir(), "Neovim and prepared Blink are required")
class CompletionKeysTest(unittest.TestCase):
    def test_enter_requires_selection_and_tab_keeps_indenting(self):
        for profile, scenario in product(("desktop", "server"), ("newline", "accept", "tab")):
            with self.subTest(profile=profile, scenario=scenario), tempfile.TemporaryDirectory(prefix="nvim-completion-") as directory:
                home = Path(directory)
                script = home / "check.lua"
                script.write_text(
                    "vim.opt.rtp:append(" + json.dumps(str(BLINK)) + ")\n"
                    + "local opts = dofile(" + json.dumps(str(ROOT / ".config/nvim/lua/plugins/blink.lua")) + ").opts\n"
                    + "local scenario = " + json.dumps(scenario) + "\n"
                    + r'''
-- Keep this fixture independent of native-library downloads and language servers.
opts.fuzzy = { implementation = 'lua', frecency = { enabled = false } }
opts.sources = { default = { 'fixture' }, providers = {
  fixture = { name = 'Fixture', module = 'completion_fixture' },
} }
opts.completion.menu.auto_show_delay_ms = 0
-- Isolate acceptance from Blink's asynchronous insertion previews.
opts.completion.list = opts.completion.list or {}
opts.completion.list.selection = opts.completion.list.selection or {}
opts.completion.list.selection.auto_insert = false
-- Show each menu explicitly so delayed automatic triggers cannot reset a selection.
opts.completion.trigger = { show_on_keyword = false, show_on_trigger_character = false }
package.preload.completion_fixture = function()
  return { new = function()
    return { get_completions = function(_, _, callback)
      callback({ items = { { label = 'print', kind = 1 } },
        is_incomplete_forward = false, is_incomplete_backward = false })
    end }
  end }
end
local cmp = require('blink.cmp')
cmp.setup(opts)
vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.softtabstop = -1

local function input(keys)
  vim.api.nvim_input(vim.api.nvim_replace_termcodes(keys, true, false, true))
end
local function wait_until(condition, message)
  local deadline = vim.uv.now() + 3000
  while not condition() do
    assert(vim.uv.now() < deadline, message)
    coroutine.yield()
  end
end
local function open_menu()
  local typed = false
  vim.api.nvim_create_autocmd('TextChangedI', { callback = function()
    if vim.api.nvim_get_current_line() == 'pri' then
      typed = true
      return true
    end
  end })
  input('pri')
  wait_until(function() return typed end, 'typing did not finish processing')
  local shown = false
  cmp.show({ callback = function() shown = true end })
  wait_until(function() return shown and cmp.is_menu_visible() end, 'completion menu did not open')
end
local task = coroutine.create(function()
  wait_until(function() return vim.fn.mode() == 'i' end, 'Insert mode did not start')
  open_menu()
  assert(cmp.get_selected_item() == nil, 'completion was preselected')
  if scenario == 'newline' then
    input('<CR>')
    wait_until(function() return vim.api.nvim_buf_line_count(0) == 2 end, 'Enter did not insert a newline')
    assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == 'pri', 'Enter accepted an unselected completion')
  elseif scenario == 'accept' then
    input('<C-n>')
    wait_until(function() return cmp.get_selected_item() ~= nil end, 'completion selection failed')
    input('<CR>')
    wait_until(function() return not cmp.is_menu_visible() end, 'Enter did not accept the selected completion')
    assert(vim.api.nvim_get_current_line() == 'print', 'selected completion was not inserted')
    assert(vim.api.nvim_buf_line_count(0) == 1, 'accepting also inserted a newline')
  else
    input('<Tab>')
    wait_until(function() return vim.api.nvim_get_current_line() ~= 'pri' end, 'Tab did not indent')
    assert(vim.api.nvim_get_current_line() == 'pri ', 'Tab accepted a completion instead of indenting')
  end
  assert(vim.v.errmsg == '', vim.v.errmsg)
end)
local function step()
  local ok, err = coroutine.resume(task)
  if not ok then
    print(debug.traceback(task, err))
    vim.cmd('cquit!')
  elseif coroutine.status(task) == 'dead' then
    print('Completion keys accepted')
    vim.cmd('qa!')
  else
    vim.defer_fn(step, 10)
  end
end
vim.cmd('startinsert')
vim.defer_fn(step, 10)
'''
                )
                env = dict(os.environ, HOME=directory, PATH="/usr/bin:/bin", DOTFILES_PROFILE=profile)
                for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
                    env[name] = str(home / name.lower())
                result = subprocess.run(
                    [NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-c", "luafile " + str(script)],
                    cwd=directory, env=env, text=True, capture_output=True, timeout=15,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
