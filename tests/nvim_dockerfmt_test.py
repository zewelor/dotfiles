"""Dockerfile manual formatting through the project's Conform mapping."""

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
REAL_DOCKERFMT = os.environ.get("DOTFILES_TEST_DOCKERFMT") or shutil.which("dockerfmt")

DOCKERFILE = '''FROM alpine
RUN if [ -n "$MODE" ]; then \\
case "$MODE" in \\
fast) echo fast;; \\
*) echo slow;; \\
esac; \\
else \\
echo fallback; \\
fi
'''


def formatted_dockerfile(unit):
    return [
        "FROM alpine",
        'RUN if [ -n "$MODE" ]; then \\',
        f'{unit * 2}case "$MODE" in \\',
        f"{unit * 3}fast) echo fast ;; \\",
        f"{unit * 3}*) echo slow ;; \\",
        f"{unit * 2}esac; \\",
        f"{unit}else \\",
        f"{unit * 2}echo fallback; \\",
        f"{unit}fi",
    ]


FAKE_DOCKERFMT = r'''#!PYTHON
import json, os, sys
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps({"args": sys.argv[1:]}) + "\n")
if sys.stdin.read() != os.environ["DOCKERFILE_INPUT"]:
    sys.exit("unexpected Dockerfile input")
if os.environ.get("TOOL_MODE") == "fail":
    sys.exit("fixture dockerfmt failure")
sys.stdout.write(os.environ["EXPECTED_OUTPUT"])
'''.replace("PYTHON", sys.executable)

FAKE_MISE = r'''#!PYTHON
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ["MISE_LOG"], "a") as log:
    log.write(json.dumps(args) + "\n")
expected = ["-C", os.environ["PROJECT"], "which", "dockerfmt"]
if args != expected:
    sys.exit("unexpected mise arguments: " + repr(args))
binary = pathlib.Path(os.environ["DOCKERFMT_PATH"])
if not binary.is_file():
    print("fixture dockerfmt is unavailable", file=sys.stderr)
    sys.exit(1)
print(binary)
'''.replace("PYTHON", sys.executable)


@unittest.skipUnless(NVIM and CONFORM.is_dir(), "Neovim and installed Conform are required")
class DockerfmtManualFormattingTest(unittest.TestCase):
    def run_case(self, *, tool="success", expandtab=True, shiftwidth=4, repeat=False):
        with tempfile.TemporaryDirectory(prefix="nvim-dockerfmt-") as directory:
            temp = Path(directory)
            project = temp / "project"
            project.mkdir()
            source = project / "Dockerfile"
            source.write_text(DOCKERFILE)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            executable = bin_dir / "dockerfmt"
            mise = bin_dir / "mise"
            mise.write_text(FAKE_MISE)
            mise.chmod(0o755)
            if tool in ("success", "fail"):
                executable.write_text(FAKE_DOCKERFMT)
                executable.chmod(0o755)
            elif tool == "real":
                executable.write_text(
                    f'''#!{sys.executable}
import json, os, sys
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps({{"args": sys.argv[1:]}}) + "\\n")
os.execv(os.environ["REAL_DOCKERFMT"], [os.environ["REAL_DOCKERFMT"], *sys.argv[1:]])
'''
                )
                executable.chmod(0o755)

            result_file = temp / "result.json"
            script = temp / "check.lua"
            script.write_text(
                "vim.opt.rtp:append(" + json.dumps(str(CONFORM)) + ")\n"
                + "package.path = "
                + json.dumps(str(ROOT / ".config/nvim/lua/?.lua") + ";")
                + " .. package.path\n"
                + '''
vim.g.mapleader = " "
require("config.keymaps")
local conform = require("conform")
local plugin_opts = require("plugins.conform").opts
conform.setup(plugin_opts)
vim.cmd("filetype on")
vim.cmd.edit(vim.fn.fnameescape(vim.env.SOURCE))
assert(vim.bo.filetype == "dockerfile", "Dockerfile filetype was not detected")
vim.bo.shiftwidth = tonumber(vim.env.SHIFTWIDTH)
vim.bo.expandtab = vim.env.EXPANDTAB == "true"
local messages = {}
vim.notify = function(message) messages[#messages + 1] = tostring(message) end
local lsp_calls = 0
local lsp_format = require("conform.lsp_format")
lsp_format.get_format_clients = function()
  return { { id = 1, name = "fixture-lsp" } }
end
lsp_format.format = function(_, callback)
  lsp_calls = lsp_calls + 1
  callback(nil, false)
end
local mapping = vim.fn.maparg(" cf", "n", false, true)
assert(mapping.desc == "Format buffer (conform)", "manual format mapping was not loaded")
assert(type(mapping.callback) == "function", "manual format mapping has no callback")
vim.cmd.write()
assert(vim.fn.filereadable(vim.env.CALL_LOG) == 0, "saving invoked dockerfmt")
assert(vim.fn.filereadable(vim.env.MISE_LOG) == 0, "saving invoked mise")
mapping.callback()
local first = vim.api.nvim_buf_get_lines(0, 0, -1, false)
if vim.env.REPEAT == "true" then
  mapping.callback()
  assert(vim.deep_equal(first, vim.api.nvim_buf_get_lines(0, 0, -1, false)),
    "repeated manual formatting changed the Dockerfile again")
end
vim.wait(50, function() return false end)
vim.fn.writefile({ vim.json.encode({
  lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
  notifications = messages,
  lsp_calls = lsp_calls,
  uses_mise_resolver = type(plugin_opts.formatters.dockerfmt.command) == "function",
}) }, vim.env.RESULT)
'''
            )
            expected_output = formatted_dockerfile(" " * shiftwidth if expandtab else "\t")
            env = dict(
                os.environ,
                HOME=directory,
                PATH=str(bin_dir),
                SOURCE=str(source),
                RESULT=str(result_file),
                CALL_LOG=str(temp / "calls.jsonl"),
                MISE_LOG=str(temp / "mise.jsonl"),
                PROJECT=str(project),
                DOCKERFMT_PATH=str(executable),
                DOCKERFILE_INPUT=DOCKERFILE,
                EXPECTED_OUTPUT="\n".join(expected_output) + "\n",
                TOOL_MODE="fail" if tool == "fail" else "success",
                SHIFTWIDTH=str(shiftwidth),
                EXPANDTAB="true" if expandtab else "false",
                REPEAT="true" if repeat else "false",
                DOTFILES_PROFILE="desktop",
            )
            if tool == "real":
                env["REAL_DOCKERFMT"] = str(REAL_DOCKERFMT)
            for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
                env[name] = str(temp / name)
            result = subprocess.run(
                [NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(script)],
                env=env,
                cwd=temp,
                capture_output=True,
                text=True,
                timeout=15,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            calls_file = temp / "calls.jsonl"
            calls = [json.loads(line) for line in calls_file.read_text().splitlines()] if calls_file.exists() else []
            mise_file = temp / "mise.jsonl"
            mise_calls = [json.loads(line) for line in mise_file.read_text().splitlines()] if mise_file.exists() else []
            observation = json.loads(result_file.read_text())
            observation["calls"] = calls
            observation["mise_calls"] = mise_calls
            observation["source"] = source.read_text()
            observation["project"] = str(project)
            return observation

    def assert_mise_resolution(self, result, *, project):
        if result["uses_mise_resolver"]:
            self.assertTrue(result["mise_calls"], "mise resolver did not run")
        else:
            self.assertEqual(result["mise_calls"], [])
        for args in result["mise_calls"]:
            self.assertEqual(args, ["-C", str(project), "which", "dockerfmt"])

    def assert_style_args(self, call, *, expandtab, shiftwidth):
        args = call["args"]
        if expandtab:
            index = args.index("--indent")
            self.assertEqual(args[index + 1], str(shiftwidth))
            self.assertNotIn("--use-tabs", args)
        else:
            self.assertIn("--use-tabs", args)
            self.assertNotIn("--indent", args)

    def test_save_skips_dockerfmt_and_manual_mapping_formats_buffer_only(self):
        for expandtab, shiftwidth, unit in ((True, 3, "   "), (False, 4, "\t")):
            with self.subTest(expandtab=expandtab, shiftwidth=shiftwidth):
                result = self.run_case(expandtab=expandtab, shiftwidth=shiftwidth)
                self.assertEqual(result["lines"], formatted_dockerfile(unit))
                self.assertEqual(result["source"], DOCKERFILE)
                self.assertEqual(result["lsp_calls"], 0)
                self.assertEqual(len(result["calls"]), 1)
                self.assert_mise_resolution(result, project=Path(result["project"]))
                self.assert_style_args(result["calls"][0], expandtab=expandtab, shiftwidth=shiftwidth)

    def test_missing_or_failed_dockerfmt_leaves_buffer_unchanged_without_lsp_fallback(self):
        for tool in ("missing", "fail"):
            with self.subTest(tool=tool):
                result = self.run_case(tool=tool)
                self.assertEqual(result["lines"], DOCKERFILE.splitlines())
                self.assertEqual(result["source"], DOCKERFILE)
                self.assertEqual(result["lsp_calls"], 0)
                self.assertTrue(result["notifications"], "formatter failure was not visible")
                self.assertEqual(len(result["calls"]), 0 if tool == "missing" else 1)
                self.assert_mise_resolution(result, project=Path(result["project"]))

    @unittest.skipUnless(REAL_DOCKERFMT, "Set DOTFILES_TEST_DOCKERFMT or put dockerfmt on PATH")
    def test_real_dockerfmt_formats_nested_run_if_case_idempotently_without_saving(self):
        for expandtab, unit in ((True, "    "), (False, "\t")):
            with self.subTest(expandtab=expandtab):
                result = self.run_case(tool="real", expandtab=expandtab, repeat=True)
                self.assertEqual(result["lines"], formatted_dockerfile(unit))
                self.assertEqual(result["source"], DOCKERFILE)
                self.assertEqual(len(result["calls"]), 2)
                self.assert_mise_resolution(result, project=Path(result["project"]))
                for call in result["calls"]:
                    self.assert_style_args(call, expandtab=expandtab, shiftwidth=4)


if __name__ == "__main__":
    unittest.main()
