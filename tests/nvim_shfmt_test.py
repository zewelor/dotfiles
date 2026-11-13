"""Exercise the real Conform-to-shfmt Zsh formatting path in isolation.

This test uses the installed Conform source and existing Mason shfmt binary,
injected through a mise fixture. It never loads the user's Neovim config or
runs Lazy, Mason, or an installer.
"""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
ZSH = shutil.which("zsh")
CONFORM = Path.home() / ".local/share/nvim/lazy/conform.nvim"
SHFMT = Path.home() / ".local/share/nvim/mason/bin/shfmt"
REVIEW_DIR = Path("/tmp/mca116-shfmt-review")

SOURCE = r'''#!/usr/bin/env zsh
setopt extendedglob
typeset -a files=( *.item(N) )
pick_names() { local -a picked; picked=("${(@M)files:#*keep*}"); print -r -- "${(@j:,:)picked}"; }
typeset -a quoted=("${(@q)files}")
print -r -- "all=${(j:|:)files}"
print -r -- "selected=$(pick_names '*keep*')"
print -r -- "quoted=${(j:|:)quoted}"
for file in "${files[@]}"; do
  print -r -- "${file:t}:${(U)file}"
done
'''

EXPECTED_OUTPUT = (
    "all=alpha.item|drop.item|keep one.item\n"
    "selected=keep one.item\n"
    "quoted=alpha.item|drop.item|keep\\ one.item\n"
    "alpha.item:ALPHA.ITEM\n"
    "drop.item:DROP.ITEM\n"
    "keep one.item:KEEP ONE.ITEM\n"
)

LUA_FORMAT = r'''
vim.opt.rtp:append(vim.env.FMT_CONFORM)
local spec = require("plugins.conform")
local conform = require("conform")
spec.config({ name = "conform.nvim" }, spec.opts)
local notifications = {}
vim.notify = function(message)
  table.insert(notifications, tostring(message))
end

for _, case in ipairs(vim.json.decode(vim.env.FMT_CASES)) do
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(bufnr, case.filename)
  vim.bo[bufnr].filetype = case.filetype
  vim.bo[bufnr].expandtab = true
  vim.bo[bufnr].shiftwidth = 2
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(case.input))
  conform.format({ bufnr = bufnr, async = false, lsp_format = "never", timeout_ms = 5000 })
  if case.wait_for_notification then
    vim.wait(200, function() return #notifications > 0 end)
  end
  vim.fn.writefile(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), case.output)
end
vim.fn.writefile({ vim.json.encode(notifications) }, vim.env.FMT_NOTIFICATIONS)
'''


@unittest.skipUnless(NVIM and ZSH, "Neovim and Zsh are required")
class NeovimShfmtTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not CONFORM.is_dir():
            raise unittest.SkipTest("installed conform.nvim source is required")
        if not SHFMT.is_file() or not os.access(SHFMT, os.X_OK):
            raise unittest.SkipTest("installed Mason shfmt binary is required")
        version = subprocess.check_output([str(SHFMT), "--version"], text=True).strip()
        match = re.match(r"^v?(\d+)\.(\d+)\.(\d+)", version)
        if match is None or tuple(map(int, match.groups())) < (3, 13, 1):
            raise unittest.SkipTest(f"shfmt v3.13.1 or newer is required, found {version}")
        REVIEW_DIR.mkdir(parents=True, exist_ok=True)

    def run_conform(self, cases, temp):
        bin_dir = temp / "bin"
        bin_dir.mkdir(exist_ok=True)
        wrapper = bin_dir / "shfmt"
        wrapper.write_text(
            "#!/bin/sh\n"
            "{ printf '%s\\n' \"$@\"; printf '\\n'; } >> \"$SHFMT_ARGS_LOG\"\n"
            "exec \"$SHFMT_REAL\" \"$@\"\n",
            encoding="utf-8",
        )
        wrapper.chmod(0o755)
        mise = bin_dir / "mise"
        mise.write_text(
            "#!/bin/sh\n"
            "printf '%s\\n' \"$@\" >> \"$MISE_ARGS_LOG\"\n"
            "printf '\\n' >> \"$MISE_ARGS_LOG\"\n"
            "if [ \"$3\" != which ] || [ \"$4\" != shfmt ]; then exit 2; fi\n"
            "printf '%s\\n' \"$SHFMT_COMMAND\"\n",
            encoding="utf-8",
        )
        mise.chmod(0o755)
        beautysh = bin_dir / "beautysh"
        beautysh.write_text(
            "#!/bin/sh\n"
            "printf 'called\\n' >> \"$BEAUTYSH_CALL_LOG\"\n"
            "exec /bin/cat\n",
            encoding="utf-8",
        )
        beautysh.chmod(0o755)

        log_path = temp / "shfmt-args.log"
        mise_log_path = temp / "mise-args.log"
        beautysh_log = temp / "beautysh-calls.log"
        notifications_path = temp / "notifications.json"
        xdg = temp / "xdg"
        env = {
            "HOME": str(temp / "home"),
            "PATH": str(bin_dir),
            "XDG_CONFIG_HOME": str(xdg / "config"),
            "XDG_DATA_HOME": str(xdg / "data"),
            "XDG_STATE_HOME": str(xdg / "state"),
            "XDG_CACHE_HOME": str(xdg / "cache"),
            "DOTFILES_PROFILE": "desktop",
            "FMT_CONFORM": str(CONFORM),
            "FMT_CASES": json.dumps(cases),
            "FMT_NOTIFICATIONS": str(notifications_path),
            "SHFMT_REAL": str(SHFMT),
            "SHFMT_COMMAND": str(wrapper),
            "SHFMT_ARGS_LOG": str(log_path),
            "MISE_ARGS_LOG": str(mise_log_path),
            "BEAUTYSH_CALL_LOG": str(beautysh_log),
            "LC_ALL": "C",
        }
        (temp / "home").mkdir()
        script = temp / "format.lua"
        script.write_text(
            "package.path = "
            + json.dumps(str(ROOT / ".config/nvim/lua/?.lua") + ";")
            + " .. package.path\n"
            + LUA_FORMAT,
            encoding="utf-8",
        )
        result = subprocess.run(
            [NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(script)],
            env=env,
            capture_output=True,
            text=True,
            timeout=20,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        blocks = []
        if log_path.exists():
            blocks = [
                [line for line in block.splitlines() if line]
                for block in log_path.read_text(encoding="utf-8").strip().split("\n\n")
                if block.strip()
            ]
        mise_blocks = []
        if mise_log_path.exists():
            mise_blocks = [
                [line for line in block.splitlines() if line]
                for block in mise_log_path.read_text(encoding="utf-8").strip().split("\n\n")
                if block.strip()
            ]
        notifications = json.loads(notifications_path.read_text(encoding="utf-8"))
        return blocks, beautysh_log, notifications, mise_blocks

    def test_zsh_uses_shfmt_with_zsh_dialect_and_preserves_behavior(self):
        with tempfile.TemporaryDirectory(prefix="nvim-shfmt-", dir=REVIEW_DIR) as directory:
            temp = Path(directory)
            source_path = temp / "source.zsh"
            formatted_path = temp / "formatted.zsh"
            repeated_path = temp / "formatted-again.zsh"
            sh_source = temp / "source.sh"
            sh_formatted = temp / "formatted.sh"
            bash_source = temp / "source.bash"
            bash_formatted = temp / "formatted.bash"
            source_path.write_text(SOURCE, encoding="utf-8")
            sh_source.write_text(
                '#!/bin/sh\nif [ "$1" = ok ]; then\nprintf \'%s\\n\' "$1"\nfi\n',
                encoding="utf-8",
            )
            bash_source.write_text(
                '#!/usr/bin/env bash\nif [ "$1" = ok ]; then\nprintf \'%s\\n\' "$1"\nfi\n',
                encoding="utf-8",
            )

            blocks, beautysh_log, _notifications, mise_blocks = self.run_conform(
                [
                    {
                        "input": str(source_path),
                        "output": str(formatted_path),
                        "filename": str(source_path),
                        "filetype": "zsh",
                    },
                    {
                        "input": str(formatted_path),
                        "output": str(repeated_path),
                        "filename": str(formatted_path),
                        "filetype": "zsh",
                    },
                    {
                        "input": str(sh_source),
                        "output": str(sh_formatted),
                        "filename": str(sh_source),
                        "filetype": "sh",
                    },
                    {
                        "input": str(bash_source),
                        "output": str(bash_formatted),
                        "filename": str(bash_source),
                        "filetype": "bash",
                    },
                ],
                temp,
            )

            self.assertEqual(len(blocks), 4, f"Expected four real shfmt calls, got {blocks!r}")
            self.assertGreaterEqual(len(mise_blocks), 4, "mise did not resolve shfmt for each buffer")
            self.assertTrue(
                all(block == ["-C", str(temp), "which", "shfmt"] for block in mise_blocks),
                f"mise resolved shfmt with unexpected arguments: {mise_blocks!r}",
            )
            for args in blocks[:2]:
                self.assertTrue(
                    any(args[index:index + 2] == ["-ln", "zsh"] for index in range(len(args) - 1)),
                    f"shfmt was not explicitly given the Zsh dialect: {args!r}",
                )
                self.assertTrue(
                    any(args[index:index + 2] == ["-i", "2"] for index in range(len(args) - 1)),
                    f"shfmt was not given the existing two-space indentation: {args!r}",
                )
            for args in blocks[2:]:
                self.assertFalse(
                    any(args[index:index + 2] == ["-ln", "zsh"] for index in range(len(args) - 1)),
                    f"sh/bash formatter unexpectedly used the Zsh dialect: {args!r}",
                )
                self.assertTrue(
                    any(args[index:index + 2] == ["-i", "2"] for index in range(len(args) - 1)),
                    f"shfmt was not given the existing two-space indentation: {args!r}",
                )
            self.assertFalse(beautysh_log.exists(), "Conform invoked beautysh as a Zsh fallback")

            formatted = formatted_path.read_text(encoding="utf-8")
            repeated = repeated_path.read_text(encoding="utf-8")
            self.assertNotEqual(formatted, SOURCE, "Conform did not format the Zsh fixture")
            self.assertEqual(formatted, repeated, "Zsh formatting is not idempotent")
            self.assertIn("pick_names() {\n  local -a picked\n", formatted)
            self.assertNotEqual(sh_formatted.read_text(encoding="utf-8"), sh_source.read_text(encoding="utf-8"))
            self.assertNotEqual(bash_formatted.read_text(encoding="utf-8"), bash_source.read_text(encoding="utf-8"))

            execution = temp / "execution"
            execution.mkdir()
            (execution / "alpha.item").touch()
            (execution / "drop.item").touch()
            (execution / "keep one.item").touch()
            original_script = execution / "original.zsh"
            formatted_script = execution / "formatted.zsh"
            original_script.write_text(SOURCE, encoding="utf-8")
            formatted_script.write_text(formatted, encoding="utf-8")

            for path in (original_script, formatted_script):
                syntax = subprocess.run(
                    [ZSH, "-f", "-n", str(path)],
                    cwd=execution,
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                self.assertEqual(syntax.returncode, 0, syntax.stdout + syntax.stderr)

            original = subprocess.run(
                [ZSH, "-f", str(original_script)],
                cwd=execution,
                capture_output=True,
                text=True,
                timeout=5,
            )
            formatted_result = subprocess.run(
                [ZSH, "-f", str(formatted_script)],
                cwd=execution,
                capture_output=True,
                text=True,
                timeout=5,
            )
            self.assertEqual(original.returncode, 0, original.stderr)
            self.assertEqual(formatted_result.returncode, 0, formatted_result.stderr)
            self.assertEqual(original.stdout, EXPECTED_OUTPUT)
            self.assertEqual(formatted_result.stdout, original.stdout)
            self.assertEqual(formatted_result.stderr, original.stderr)

    def test_valid_zsh_dynamic_pattern_failure_is_visible_without_fallback(self):
        source = 'value="*.zsh"\nprint -r -- "${~value}"\n'
        with tempfile.TemporaryDirectory(prefix="nvim-shfmt-diagnostic-", dir=REVIEW_DIR) as directory:
            temp = Path(directory)
            source_path = temp / "dynamic-pattern.zsh"
            output_path = temp / "after-format.zsh"
            source_path.write_text(source, encoding="utf-8")

            syntax = subprocess.run(
                [ZSH, "-f", "-n", str(source_path)],
                capture_output=True,
                text=True,
                timeout=5,
            )
            self.assertEqual(syntax.returncode, 0, syntax.stdout + syntax.stderr)

            blocks, beautysh_log, notifications, mise_blocks = self.run_conform(
                [
                    {
                        "input": str(source_path),
                        "output": str(output_path),
                        "filename": str(source_path),
                        "filetype": "zsh",
                        "wait_for_notification": True,
                    }
                ],
                temp,
            )

            self.assertEqual(len(blocks), 1, f"Expected one shfmt call, got {blocks!r}")
            self.assertGreaterEqual(len(mise_blocks), 1, "mise did not resolve shfmt")
            self.assertTrue(all(block == ["-C", str(temp), "which", "shfmt"] for block in mise_blocks))
            args = blocks[0]
            self.assertTrue(
                any(args[index:index + 2] == ["-ln", "zsh"] for index in range(len(args) - 1)),
                f"shfmt was not explicitly given the Zsh dialect: {args!r}",
            )
            self.assertFalse(beautysh_log.exists(), "Conform invoked beautysh after shfmt rejected valid Zsh")
            self.assertEqual(output_path.read_text(encoding="utf-8"), source)
            diagnostics = "\n".join(notifications)
            self.assertIn("Formatter failed. See :ConformInfo for details", diagnostics)


if __name__ == "__main__":
    unittest.main()
