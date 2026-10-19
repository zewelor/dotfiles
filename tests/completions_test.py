#!/usr/bin/python3
"""Offline checks for static shell completion generation and registration."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ("sourcetap", "gog", "opencode", "workmux")


class CompletionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.cache = self.home / "cache" / "zinit" / "completions"
        self.log = self.home / "calls"
        self.env = dict(os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
                        PATH=f"{self.bin}:/usr/bin:/bin", XDG_CACHE_HOME=str(self.home / "cache"),
                        CALLS=str(self.log))
        self.env.pop("ZSH_CACHE_DIR", None)

    def tool(self, name, body):
        script = self.bin / name
        script.write_text("#!/bin/sh\n" + body)
        script.chmod(0o755)

    def good_tool(self, name):
        self.tool(name, f'''printf '%s:%s\\n' '{name}' "$*" >> "$CALLS"
printf '%s\\n' '#compdef {name}' '_{name}() {{ :; }}'
''')

    def refresh(self):
        return subprocess.run(["/usr/bin/zsh", str(ROOT / "bin/update-shell-completions")],
                              env=self.env, text=True, capture_output=True)

    def test_generates_supported_scripts_and_command_arguments(self):
        for tool in TOOLS:
            self.good_tool(tool)
        result = self.refresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            "sourcetap:completion zsh", "gog:completion zsh",
            "opencode:--completions zsh", "workmux:completions zsh"])
        for tool in TOOLS:
            self.assertIn(f"_{tool}()", (self.cache / f"_{tool}").read_text())
        self.assertEqual(sorted(p.name for p in self.cache.iterdir()),
                         sorted("_" + tool for tool in TOOLS))

    def test_unavailable_tools_are_optional(self):
        result = self.refresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())

    def test_failure_preserves_previous_completion(self):
        for body in ["echo partial; exit 7\n", "exit 0\n", "echo 'broken() {'\n"]:
            with self.subTest(body=body):
                self.cache.mkdir(parents=True, exist_ok=True)
                old = self.cache / "_opencode"
                old.write_text("# previous working completion\n")
                self.tool("opencode", body)
                result = self.refresh()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("opencode", result.stderr)
                self.assertEqual(old.read_text(), "# previous working completion\n")
                self.assertEqual([p.name for p in self.cache.iterdir()], ["_opencode"])

    def test_custom_cache_directory(self):
        self.env["ZSH_CACHE_DIR"] = str(self.home / "custom-cache")
        self.good_tool("opencode")
        result = self.refresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / "custom-cache/completions/_opencode").exists())
        self.assertFalse(self.cache.exists())

    def test_loading_cached_completions_never_executes_tools(self):
        self.cache.mkdir(parents=True)
        for tool in TOOLS:
            self.tool(tool, f'echo {tool} >> "$CALLS"; exit 99\n')
            (self.cache / f"_{tool}").write_text(f"#compdef {tool}\n_{tool}() {{ :; }}\n")
        self.env["COMPLETION_LOADER"] = str(ROOT / ".zsh/completions.zsh")
        result = subprocess.run(["/usr/bin/zsh", "-f", "-c", '''
set -eu
ZSH_CACHE_DIR="$XDG_CACHE_HOME/zinit"
fpath=("$ZSH_CACHE_DIR/completions" $fpath)
queued=()
zpcompdef() { queued+=("${(j: :)@}"); }
source "$COMPLETION_LOADER"
autoload -Uz compinit
compinit -u -d "$HOME/.zcompdump"
for definition in "${queued[@]}"; do compdef ${(z)definition}; done
for tool in sourcetap gog opencode workmux; do
  [[ "${_comps[$tool]}" == "_$tool" ]] || exit 1
done
[[ "${_comps[oc]}" == _opencode ]]
'''], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
