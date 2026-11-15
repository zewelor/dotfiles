"""Open file:line references in real Neovim without plugin maintenance."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")


@unittest.skipUnless(NVIM, "Neovim is not installed")
class FilelineTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-fileline-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.file = self.directory / "example name | literal.lua"
        self.file.write_text("".join(f"-- line {line}\n" for line in range(1, 31)))
        (self.directory / ".editorconfig").write_text(
            "root = true\n[*]\nindent_style = space\nindent_size = 3\n"
        )
        self.init = self.directory / "init.lua"
        self.init.write_text(
            "package.path = " + json.dumps(str(ROOT / ".config/nvim/lua/?.lua") + ";")
            + " .. package.path\n"
            + "package.loaded['config.lazy'] = true\n"
            + "dofile(" + json.dumps(str(ROOT / ".config/nvim/init.lua")) + ")\n"
        )

    def run_nvim(self, arguments, expected_file, line, *, before="", assertions="", profile="server", listed_files=None):
        expected_listed = ", ".join(
            "[" + json.dumps(str(path)) + "] = true" for path in (listed_files or (expected_file,))
        )
        check = self.directory / "check.lua"
        check.write_text("local ok, err = pcall(function()\n" + before + "\nend)\n"
            + "if not ok then print(err); vim.cmd('cquit!') end\n"
            + "vim.schedule(function()\n"
            + "local ok, err = pcall(function()\n"
            + "assert(vim.v.errmsg == '', vim.v.errmsg)\n"
            + "assert(vim.api.nvim_buf_get_name(0) == " + json.dumps(str(expected_file))
            + ", 'opened wrong file: ' .. vim.api.nvim_buf_get_name(0))\n"
            + f"assert(vim.api.nvim_win_get_cursor(0)[1] == {line}, 'wrong cursor line')\n"
            + ("assert(vim.bo.filetype == 'lua', 'lost filetype detection')\n"
               + "assert(vim.bo.shiftwidth == 3, 'lost EditorConfig settings')\n"
               if expected_file == self.file else "")
            + "local expected_listed = {" + expected_listed + "}\n"
            + "for _, buf in ipairs(vim.api.nvim_list_bufs()) do\n"
            + "  if vim.bo[buf].buflisted then\n"
            + "    local name = vim.api.nvim_buf_get_name(buf)\n"
            + "    assert(expected_listed[name], 'unexpected listed buffer: ' .. name)\n"
            + "    expected_listed[name] = nil\n"
            + "  end\nend\nassert(next(expected_listed) == nil, 'a real file disappeared from the buffer list')\n"
            + assertions + "\nend)\n"
            + "if not ok then print(err); vim.cmd('cquit!') else vim.cmd('qa!') end\nend)\n"
        )
        env = {"HOME": str(self.directory), "PATH": os.defpath, "DOTFILES_PROFILE": profile}
        for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
            env[name] = str(self.directory / name.lower())
        result = subprocess.run(
            [NVIM, "--headless", "-u", str(self.init), "-i", "NONE", "-n",
             *arguments, "-c", "luafile " + str(check)],
            cwd=self.directory, env=env, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_cli_opens_existing_file_at_line_in_both_profiles(self):
        for profile in ("server", "desktop"):
            with self.subTest(profile=profile):
                self.run_nvim([str(self.file) + ":12"], self.file, 12, profile=profile)

    def test_edit_command_opens_reference(self):
        self.run_nvim([], self.file, 12, before="vim.cmd.edit(vim.fn.fnameescape("
                      + json.dumps(str(self.file) + ":12") + "))")

    def test_line_ranges_open_at_first_line_without_selection(self):
        for profile in ("server", "desktop"):
            for reference, expected in (("1-60", 1), ("12-23", 12), ("0-5", 1), ("9999-10000", 30)):
                with self.subTest(profile=profile, reference=reference):
                    self.run_nvim([str(self.file) + ":" + reference], self.file, expected,
                                  profile=profile, assertions="assert(vim.fn.mode() == 'n', 'range unexpectedly selected text')")

    def test_edit_command_opens_line_range(self):
        self.run_nvim([], self.file, 12, before="vim.cmd.edit(vim.fn.fnameescape("
                      + json.dumps(str(self.file) + ":12-23") + "))",
                      assertions="assert(vim.fn.mode() == 'n', 'range unexpectedly selected text')")

    def test_relative_range_in_nested_markdown_path(self):
        relative = Path("docs/plans/agent-sandbox-mcp.md")
        target = self.directory / relative
        target.parent.mkdir(parents=True)
        target.write_text("".join(f"Markdown line {line}\n" for line in range(1, 71)))
        self.run_nvim([str(relative) + ":1-60"], target, 1,
                      assertions="assert(vim.fn.mode() == 'n', 'range unexpectedly selected text')")

    def test_real_filename_with_range_suffix_takes_precedence(self):
        literal = Path(str(self.file) + ":1-60")
        literal.write_text("literal range filename\n")
        self.run_nvim([str(literal)], literal, 1,
                      assertions="assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'literal range filename')")

    def test_consecutive_reference_opens_resolve_before_returning(self):
        second = self.directory / "second.lua"
        second.write_text("".join(f"-- second line {line}\n" for line in range(1, 31)))
        before = (
            "local first = vim.fn.fnameescape(" + json.dumps(str(self.file) + ":12") + ")\n"
            + "local second = vim.fn.fnameescape(" + json.dumps(str(second) + ":23") + ")\n"
            + "vim.cmd('edit ' .. first .. ' | edit ' .. second .. ' | edit ' .. first)\n"
            + "assert(vim.api.nvim_buf_get_name(0) == " + json.dumps(str(self.file))
            + ", 'reopened an empty placeholder instead of the real file')\n"
            + "assert(vim.api.nvim_win_get_cursor(0)[1] == 12, 'wrong line before returning')\n"
            + "assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == '-- line 1', 'lost file content')\n"
        )
        self.run_nvim([], self.file, 12, before=before, listed_files=(self.file, second))

    def test_startup_argdo_updates_both_real_files(self):
        second = self.directory / "second.lua"
        original = self.file.read_text()
        second.write_text(original)
        self.run_nvim([str(self.file) + ":12", str(second) + ":23"], second, 30,
                      before="vim.cmd('argdo %s/line/replaced/ge | update')",
                      listed_files=(self.file, second))
        self.assertEqual(self.file.read_text(), original.replace("line", "replaced"))
        self.assertEqual(second.read_text(), original.replace("line", "replaced"))
        self.assertFalse(Path(str(self.file) + ":12").exists())
        self.assertFalse(Path(str(second) + ":23").exists())

    def test_relative_reference_with_readonly_flag(self):
        self.run_nvim(["-R", self.file.name + ":12"], self.file, 12,
                      assertions="assert(vim.bo.readonly, 'lost the readonly flag')")

    def test_out_of_range_lines_are_clamped(self):
        for requested, expected in ((0, 1), (9999, 30)):
            with self.subTest(requested=requested):
                self.run_nvim([str(self.file) + f":{requested}"], self.file, expected)

    def test_real_filename_with_numeric_suffix_takes_precedence(self):
        literal = Path(str(self.file) + ":12")
        literal.write_text("literal filename\n")
        self.run_nvim([str(literal)], literal, 1)

    def test_reopening_modified_file_keeps_unsaved_changes_marked_immediately(self):
        self.run_nvim([str(self.file)], self.file, 12, before="""
vim.api.nvim_buf_set_lines(0, 0, 1, false, { '-- UNSAVED' })
vim.cmd.edit(vim.fn.fnameescape(vim.api.nvim_buf_get_name(0) .. ':12'))
assert(vim.bo.modified, 'lost modified flag before returning from :edit')
""", assertions="""
assert(vim.bo.modified, 'lost modified flag after deferred cleanup')
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == '-- UNSAVED', 'lost unsaved content')
"""
        )

    def test_duplicate_reference_in_tabs_does_not_delete_placeholder_twice(self):
        reference = str(self.file) + ":12"
        self.run_nvim(["-p", reference, reference], self.file, 12,
                      assertions="assert(#vim.api.nvim_list_tabpages() == 2, 'lost a tab')")

    def test_save_after_reopening_is_not_marked_modified_by_deferred_cleanup(self):
        self.run_nvim([str(self.file)], self.file, 12, before="""
vim.api.nvim_buf_set_lines(0, 0, 1, false, { '-- UNSAVED' })
vim.cmd.edit(vim.fn.fnameescape(vim.api.nvim_buf_get_name(0) .. ':12'))
vim.cmd.write()
""", assertions="assert(not vim.bo.modified, 'a saved buffer was marked modified again')")
        self.assertTrue(self.file.read_text().startswith("-- UNSAVED\n"))

    def test_missing_files_and_other_suffixes_are_left_alone(self):
        for name in ("missing.lua:12", "missing.lua:1-60", self.file.name + ":12:5", self.file.name + "(12)",
                     self.file.name + ":word", self.file.name + ":12-", self.file.name + ":-23",
                     self.file.name + ":12--23", self.file.name + ":12-3x"):
            with self.subTest(name=name):
                literal = self.directory / name
                self.run_nvim([str(literal)], literal, 1)
                self.assertFalse(literal.exists(), "opening a reference created a file")


if __name__ == "__main__":
    unittest.main()
