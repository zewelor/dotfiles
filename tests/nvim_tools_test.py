"""Check Neovim's mise-backed tool resolver without touching user state."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")

EXPECTED_AQUA_TOOLS = {
    "aqua:mrjosh/helm-ls",
    "aqua:astral-sh/ruff",
    "aqua:tamasfe/taplo",
    "aqua:artempyanykh/marksman",
    "aqua:mvdan/gofumpt",
    "aqua:JohnnyMorganz/StyLua",
    "aqua:mvdan/sh",
    "aqua:oxc-project/oxc/oxfmt",
    "aqua:dprint/dprint",
    "aqua:google/yamlfmt",
}
EXPECTED_GO_TOOLS = {
    "go:golang.org/x/tools/gopls",
    "go:golang.org/x/tools/cmd/goimports",
}


@unittest.skipUnless(NVIM, "Neovim is not installed")
class NeovimToolResolutionTest(unittest.TestCase):
    def run_lua(self, code, *, mise_exit=0, mise_result=None, result_executable=True, include_mise=True):
        with tempfile.TemporaryDirectory(prefix="dotfiles-nvim-tools-") as directory:
            temp = Path(directory)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            project = temp / "nested project"
            project.mkdir()
            call_log = temp / "mise-args"
            managed_bin = temp / "mise tools" / "shfmt"
            managed_bin.parent.mkdir()
            managed_bin.write_text("#!/bin/sh\nexit 0\n")
            managed_bin.chmod(0o755)
            path_binary = bin_dir / "shfmt"
            path_binary.write_text("#!/bin/sh\nexit 0\n")
            path_binary.chmod(0o755)
            script = temp / "test.lua"
            script.write_text(
                "package.path = "
                + repr(str(ROOT / ".config/nvim/lua/?.lua") + ";")
                + " .. package.path\n"
                + code
            )

            if include_mise:
                mise = bin_dir / "mise"
                mise.write_text(
                    "#!/bin/sh\n"
                    'printf \'%s\\n\' "$@" > "$TOOLS_CALL_LOG"\n'
                    'if [ "$TOOLS_MISE_EXIT" -ne 0 ]; then\n'
                    '  printf \'controlled mise failure\\n\' >&2\n'
                    '  exit "$TOOLS_MISE_EXIT"\n'
                    "fi\n"
                    'printf \'%s\\n\' "$TOOLS_MISE_RESULT"\n'
                )
                mise.chmod(0o755)

            result_path = managed_bin if mise_result is None else Path(mise_result)
            if result_executable and result_path.is_absolute():
                result_path.parent.mkdir(parents=True, exist_ok=True)
                if not result_path.exists():
                    result_path.write_text("#!/bin/sh\nexit 0\n")
                result_path.chmod(0o755)

            env = dict(
                os.environ,
                HOME=directory,
                PATH=str(bin_dir),
                TOOLS_CALL_LOG=str(call_log),
                TOOLS_MISE_EXIT=str(mise_exit),
                TOOLS_MISE_RESULT=str(result_path if mise_result is None else mise_result),
                TOOLS_PROJECT_DIR=str(project),
            )
            for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
                env[name] = str(temp / name.lower())
            for name in ("DOTFILES_PROFILE", "NVIM_APPNAME", "VIMINIT", "EXINIT"):
                env.pop(name, None)

            result = subprocess.run(
                [NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(script)],
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            call_args = call_log.read_text().splitlines() if call_log.is_file() else []
            return result, call_args, path_binary, managed_bin

    def test_mise_config_declares_all_maintained_binaries_with_explicit_backends(self):
        config = tomllib.loads((ROOT / ".config/mise/config.toml").read_text())
        tools = config["tools"]
        aqua_tools = {name for name in tools if name.startswith("aqua:")}
        go_tools = {name for name in tools if name.startswith("go:")}

        self.assertTrue(EXPECTED_AQUA_TOOLS.issubset(aqua_tools))
        self.assertTrue(EXPECTED_GO_TOOLS.issubset(go_tools))
        self.assertEqual(len(EXPECTED_AQUA_TOOLS | EXPECTED_GO_TOOLS), 12)
        self.assertNotIn("aqua:LuaLS/lua-language-server", tools)
        for name in EXPECTED_AQUA_TOOLS:
            self.assertEqual(tools[name], "latest", name)
        for name in EXPECTED_GO_TOOLS:
            self.assertEqual(tools[name]["version"], "latest", name)
            self.assertEqual(tools[name]["install_env"]["GOTOOLCHAIN"], "local", name)

    def test_resolve_uses_mise_for_the_project_even_when_path_has_same_binary(self):
        result, call_args, path_binary, managed_bin = self.run_lua(
            r"""
local tools = require("config.tools")
local resolved = tools.resolve("shfmt", vim.env.TOOLS_PROJECT_DIR)
assert(resolved == vim.env.TOOLS_MISE_RESULT,
       "resolver did not return mise's project-specific executable")
assert(resolved ~= vim.fn.exepath("shfmt"),
       "resolver fell back to the binary on PATH")
"""
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(
            call_args,
            ["-C", str(path_binary.parent.parent / "nested project"), "which", "shfmt"],
        )
        self.assertNotEqual(path_binary, managed_bin)

    def test_resolve_fails_when_mise_fails_or_returns_an_invalid_path(self):
        cases = (
            {"mise_exit": 17, "mise_result": None, "result_executable": True},
            {"mise_exit": 0, "mise_result": "relative/path", "result_executable": False},
            {"mise_exit": 0, "mise_result": "/missing/mise/shfmt", "result_executable": False},
        )
        for options in cases:
            with self.subTest(options=options):
                result, _, _, _ = self.run_lua(
                    r"""
local ok, err = pcall(require("config.tools").resolve, "shfmt", vim.env.TOOLS_PROJECT_DIR)
assert(not ok, "invalid mise resolution unexpectedly succeeded")
assert(tostring(err):find("shfmt", 1, true), "resolution error did not name the binary: " .. tostring(err))
""",
                    **options,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_resolve_requires_mise_instead_of_a_path_fallback(self):
        result, _, _, _ = self.run_lua(
            r"""
local ok, err = pcall(require("config.tools").resolve, "shfmt", vim.env.TOOLS_PROJECT_DIR)
assert(not ok, "resolver used a PATH binary without mise")
assert(tostring(err):find("mise", 1, true), "missing-mise error was not clear: " .. tostring(err))
""",
            include_mise=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
