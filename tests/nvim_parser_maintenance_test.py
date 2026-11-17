"""Opt-in real parser maintenance and startup on supported Neovim, in a disposable HOME.

DOTFILES_TEST_TREESITTER_SOURCE=/path/to/upstream/git/checkout \
DOTFILES_TEST_TREE_SITTER=/absolute/tree-sitter \
python3 -m unittest tests.nvim_parser_maintenance_test

Uses the revision selected by the actual plugin spec (upstream main if unpinned),
real Lazy, the real parser installer and C compiler. Downloads parser sources;
never changes installed plugins, toolchains or the user's HOME.
"""
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
LAZY = Path.home() / ".local/share/nvim/lazy/lazy.nvim"
SOURCE = os.environ.get("DOTFILES_TEST_TREESITTER_SOURCE")
CLI = os.environ.get("DOTFILES_TEST_TREE_SITTER")


@unittest.skipUnless(NVIM and LAZY.is_dir() and SOURCE and CLI,
                     "explicit upstream checkout and prepared Tree-sitter CLI required")
class RealParserMaintenanceTest(unittest.TestCase):
    def test_install_update_and_load_all_required_parsers(self):
        with tempfile.TemporaryDirectory(prefix="nvim-real-parsers-") as td:
            home = Path(td)
            env = dict(os.environ, HOME=td, DOTFILES_PROFILE="desktop", NVIM_APPNAME="nvim")
            for key, suffix in {"XDG_CONFIG_HOME": ".config", "XDG_DATA_HOME": ".local/share",
                                "XDG_STATE_HOME": ".local/state", "XDG_CACHE_HOME": ".cache"}.items():
                env[key] = str(home / suffix)
            tools = home / "bin"
            tools.mkdir()
            (tools / "tree-sitter").symlink_to(Path(CLI).resolve())
            env["PATH"] = str(tools) + ":/usr/bin:/bin"
            spec_path = ROOT / ".config/nvim/lua/plugins/treesitter.lua"
            probe = home / "revision.lua"
            probe.write_text("local spec = dofile(" + json.dumps(str(spec_path)) + ")\n"
                             "vim.fn.writefile({spec.commit or 'origin/main'}, vim.env.HOME .. '/revision')\n")
            subprocess.run([NVIM, "--headless", "-u", "NONE", "-l", str(probe)],
                           env=env, check=True, capture_output=True, timeout=10)
            revision = (home / "revision").read_text().strip()
            archive = subprocess.check_output(["git", "-C", SOURCE, "archive", revision], timeout=120)
            plugin = home / "treesitter"
            plugin.mkdir()
            with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
                tar.extractall(plugin, filter="data")
            manager = home / ".local/share/nvim/lazy/lazy.nvim"
            shutil.copytree(LAZY, manager)
            lua = home / ".config/nvim/lua"
            (lua / "config").mkdir(parents=True)
            (lua / "plugins").mkdir()
            (lua / "config/lazy.lua").symlink_to(ROOT / ".config/nvim/lua/config/lazy.lua")
            (lua / "plugins/treesitter.lua").write_text(
                "local spec = dofile(" + json.dumps(str(spec_path)) + ")\n"
                "spec.dir = " + json.dumps(str(plugin)) + "\n"
                "return {{'folke/lazy.nvim', dir=" + json.dumps(str(manager)) + ", pin=true}, spec}\n")
            # Fail after the real installer writes lua.so and its revision, before
            # queries are linked. A retry must repair this partial installation.
            fail_once = home / "fail-queries.lua"
            fail_once.write_text(r'''
local original = vim.uv.fs_symlink
vim.uv.fs_symlink = function(path, target, flags, callback)
  if target:match('/queries/lua$') then
    vim.schedule(function() callback('EACCES: controlled query installation failure') end)
  else
    original(path, target, flags, callback)
  end
end
''')
            result = subprocess.run([NVIM, "--headless", "-u", str(fail_once), "-i", "NONE", "-n",
                                     "-l", str(ROOT / ".config/nvim/maintain.lua"), "plugins", "install"],
                                    env=env, cwd=home, capture_output=True, text=True, timeout=600)
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("controlled query installation failure", result.stdout + result.stderr)
            site = home / ".local/share/nvim/site"
            lua_parser = site / "parser/lua.so"
            lua_queries = site / "queries/lua"
            self.assertTrue(lua_parser.is_file())
            self.assertFalse(lua_queries.exists())
            for mode, remove in (("install", None), ("update", lua_queries), ("install", lua_parser)):
                # Exercise retry via both maintenance modes, then missing parser repair.
                if remove is not None:
                    remove.unlink()
                result = subprocess.run([NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n",
                                         "-l", str(ROOT / ".config/nvim/maintain.lua"), "plugins", mode],
                                        env=env, cwd=home, capture_output=True, text=True, timeout=600)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(lua_parser.is_file())
                self.assertTrue((lua_queries / "highlights.scm").is_file(),
                                f"{mode} reported success with missing queries")
            before = {p.name: p.stat().st_mtime_ns for p in (site / "parser").glob("*.so")}
            result = subprocess.run([NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n",
                                     "-l", str(ROOT / ".config/nvim/maintain.lua"), "plugins", "install"],
                                    env=env, cwd=home, capture_output=True, text=True, timeout=600)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(before, {p.name: p.stat().st_mtime_ns for p in (site / "parser").glob("*.so")},
                             "healthy parser was rebuilt by repeat install")
            parsers = sorted((home / ".local/share/nvim/site/parser").glob("*.so"))
            self.assertEqual(len(parsers), 17, [p.name for p in parsers])
            check = home / "check.lua"
            check.write_text("vim.opt.rtp:prepend(" + json.dumps(str(plugin / "runtime")) + ")\n"
                             "for _, lang in ipairs(" + "{" + ",".join(json.dumps(p.stem) for p in parsers) + "}" + ") do\n"
                             "  vim.treesitter.get_string_parser('', lang):parse()\n"
                             "  assert(vim.treesitter.query.get(lang, 'highlights'), lang .. ' has no highlights query')\n"
                             "end\n")
            result = subprocess.run([NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(check)],
                                    env=env, cwd=home, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


            # Ordinary startup must repair a missing parser without updating healthy ones.
            python_parser = site / "parser/python.so"
            python_parser.unlink()
            healthy = {p.name: p.stat().st_mtime_ns for p in (site / "parser").glob("*.so")}
            (home / 'startup.py').write_text('value = 1\n')
            (home / 'startup.markdown').write_text('# Title\n\ntext\n')
            failing_cc = tools / 'failing-cc'
            failing_cc.write_text('#!/bin/sh\necho "controlled compiler failure" >&2\nexit 42\n')
            failing_cc.chmod(0o755)
            startup = home / 'startup.lua'
            startup.write_text(r'''
vim.opt.loadplugins = true
vim.opt.rtp:prepend(vim.fn.stdpath('config'))
local errors = {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = tostring(message)
    io.stderr:write(tostring(message) .. '\n')
  end
end
require('config.lazy')
local lang = vim.env.TEST_STARTUP_LANGUAGE or 'python'
local filename = lang == 'markdown' and 'startup.markdown' or 'startup.py'
vim.cmd.edit(vim.fn.fnameescape(vim.env.HOME .. '/' .. filename))
vim.bo.filetype = lang
local parser = vim.fn.stdpath('data') .. '/site/parser/' .. lang .. '.so'
if vim.env.TEST_COMPILER_FAILURE == '1' then
  assert(vim.wait(180000, function() return #errors > 0 end), 'compiler failure was hidden')
  assert(vim.fn.filereadable(parser) == 0, 'failed compiler produced a parser')
else
  assert(vim.wait(180000, function()
    return vim.fn.filereadable(parser) == 1
      and vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil
  end), 'startup parser installation/highlighting did not finish')
  assert(#errors == 0, table.concat(errors, '\n'))
end
''')
            for fails in (True, False):
                startup_env = dict(env)
                if fails:
                    startup_env.update(CC=str(failing_cc), TEST_COMPILER_FAILURE='1')
                result = subprocess.run([NVIM, '--headless', '-u', 'NONE', '-i', 'NONE', '-n',
                                         '-l', str(startup)], env=startup_env, cwd=home,
                                        capture_output=True, text=True, timeout=240)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if fails:
                    self.assertIn('controlled compiler failure', result.stdout + result.stderr)
                else:
                    self.assertTrue(python_parser.is_file())
                self.assertEqual(healthy, {p.name: p.stat().st_mtime_ns
                                          for p in (site / 'parser').glob('*.so') if p.name != 'python.so'},
                                 'startup rebuilt an existing healthy parser')


            # Markdown expands to markdown_inline upstream; healthy dependencies stay untouched.
            markdown_parser = site / 'parser/markdown.so'
            markdown_parser.unlink()
            healthy = {p.name: p.stat().st_mtime_ns for p in (site / 'parser').glob('*.so')}
            inline = site / 'parser/markdown_inline.so'
            inline_contents = inline.read_bytes()
            revision_file = site / 'parser-info/markdown_inline.revision'
            inline_revision = revision_file.read_bytes()
            result = subprocess.run([NVIM, '--headless', '-u', 'NONE', '-i', 'NONE', '-n',
                                     '-l', str(startup)], env=dict(env, TEST_STARTUP_LANGUAGE='markdown'),
                                    cwd=home, capture_output=True, text=True, timeout=240)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(markdown_parser.is_file())
            self.assertEqual(inline.read_bytes(), inline_contents)
            self.assertEqual(revision_file.read_bytes(), inline_revision)
            self.assertEqual(healthy, {p.name: p.stat().st_mtime_ns
                                      for p in (site / 'parser').glob('*.so') if p.name != 'markdown.so'},
                             'Markdown recovery rebuilt a healthy dependency')


if __name__ == "__main__":
    unittest.main()
