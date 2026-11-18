"""Check the maintained editor CLI declarations without touching user state."""

from pathlib import Path
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]

EXPECTED_AQUA_TOOLS = {
    "aqua:mrjosh/helm-ls",
    "aqua:astral-sh/ruff",
    "aqua:tamasfe/taplo",
    "aqua:artempyanykh/marksman",
    "aqua:mvdan/gofumpt",
    "aqua:JohnnyMorganz/StyLua",
    "aqua:mvdan/sh",
    "aqua:reteps/dockerfmt",
    "aqua:dprint/dprint",
}
EXPECTED_GO_TOOLS = {
    "go:golang.org/x/tools/gopls",
    "go:golang.org/x/tools/cmd/goimports",
}


class NeovimToolDeclarationsTest(unittest.TestCase):
    def test_mise_config_declares_all_maintained_binaries_with_explicit_backends(self):
        config = tomllib.loads((ROOT / ".config/mise/config.toml").read_text())
        tools = config["tools"]
        self.assertEqual(tools["aqua:tree-sitter/tree-sitter"], "0.26.1")
        self.assertNotIn("aqua:LuaLS/lua-language-server", tools)
        self.assertNotIn("aqua:google/yamlfmt", tools)
        self.assertNotIn("aqua:oxc-project/oxc/oxfmt", tools)
        for name in EXPECTED_AQUA_TOOLS:
            self.assertEqual(tools[name], "latest", name)
        for name in EXPECTED_GO_TOOLS:
            self.assertEqual(tools[name]["version"], "latest", name)
            self.assertEqual(tools[name]["install_env"]["GOTOOLCHAIN"], "local", name)


if __name__ == "__main__":
    unittest.main()
