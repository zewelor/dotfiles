"""Compare Dockerfile editing with Neovim's standard indentation, offline."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
DOCKERFILE = """FROM alpine
RUN if true; then \\
    echo outer; \\
    if false; then \\
    echo nested; \\
    fi; \\
    else \\
    echo alternative; \\
    fi
"""


@unittest.skipUnless(NVIM, "Neovim is required")
class DockerfileIndentTest(unittest.TestCase):
    def reindent(self, filename, profile, use_config):
        with tempfile.TemporaryDirectory(prefix="nvim-dockerfile-") as directory:
            home = Path(directory)
            (home / ".editorconfig").write_text("root = true\n[*]\nindent_style = space\nindent_size = 4\n")
            source = home / filename
            source.write_text(DOCKERFILE)
            result_file = home / "result.json"
            script = home / "check.lua"
            init = home / "init.lua"
            init.write_text("")
            # Both runs use the same shared options; only the repo's ftplugin layer differs.
            script.write_text(
                "package.path = " + json.dumps(str(ROOT / ".config/nvim/lua/?.lua") + ";") + " .. package.path\n"
                + "require('config.options')\n"
                + ("vim.opt.rtp:prepend(" + json.dumps(str(ROOT / ".config/nvim")) + ")\n"
                   + "vim.opt.rtp:append(" + json.dumps(str(ROOT / ".config/nvim/after")) + ")\n" if use_config else "")
                + "vim.cmd('filetype plugin indent on')\n"
                + "vim.cmd.edit(" + json.dumps(str(source)) + ")\n"
                + "assert(vim.bo.filetype == 'dockerfile', 'lost Dockerfile detection')\n"
                + "assert(vim.bo.shiftwidth == 4 and vim.bo.expandtab, 'lost EditorConfig indentation')\n"
                + "vim.cmd('normal! gg=G')\n"
                + "vim.fn.writefile({ vim.json.encode(vim.api.nvim_buf_get_lines(0, 0, -1, false)) }, "
                + json.dumps(str(result_file)) + ")\n"
            )
            env = dict(os.environ, HOME=directory, PATH="/usr/bin:/bin", DOTFILES_PROFILE=profile)
            for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
                env[name] = str(home / name.lower())
            result = subprocess.run(
                [NVIM, "--headless", "-u", str(init), "-i", "NONE", "-n", "-c", "luafile " + str(script), "-c", "qa!"],
                cwd=directory, env=env, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(source.read_text(), DOCKERFILE, "reindent unexpectedly saved the file")
            return json.loads(result_file.read_text())

    def test_dockerfile_and_alias_use_standard_indentation(self):
        for profile in ("desktop", "server"):
            for filename in ("Dockerfile", "fdockerfile.production"):
                with self.subTest(profile=profile, filename=filename):
                    self.assertEqual(
                        self.reindent(filename, profile, use_config=True),
                        self.reindent(filename, profile, use_config=False),
                    )
