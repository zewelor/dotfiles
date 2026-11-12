"""Test the refresh wrapper using an isolated Summarize configuration."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / ".local/bin/summarize-refresh-free"


class SummarizeRefreshFreeTest(unittest.TestCase):
    def test_enabled_cli_candidates_precede_refreshed_models(self):
        for enabled, model, expected in (
            (["codex"], "cli/codex/gpt-6-luna", ["cli/codex/gpt-6-luna"]),
            (["codex"], " cli/codex/gpt-6-luna ", ["cli/codex/gpt-6-luna"]),
            (["codex", "agy"], "cli/codex/gpt-6-luna", ["cli/codex/gpt-6-luna", "cli/agy"]),
            (["codex", "agy"], {"id": "cli/codex/gpt-6-luna"}, ["cli/codex/gpt-6-luna", "cli/agy"]),
            (["codex"], {"mode": "auto", "rules": []}, ["cli/codex"]),
            (["codex"], {"name": "preferred"}, ["cli/codex"]),
            (["agy", "codex"], "cli/codex/gpt-6-luna", ["cli/agy", "cli/codex/gpt-6-luna"]),
            ([" AGY ", "agy"], "free", ["cli/agy"]),
            ([], "openrouter/example", []),
            (None, "openrouter/example", []),
        ):
            with self.subTest(enabled=enabled), tempfile.TemporaryDirectory() as tmp:
                home = Path(tmp)
                config = home / ".summarize/config.json"
                config.parent.mkdir()
                original = {"model": model, "cli": {"codex": {"extraArgs": ["example"]}},
                            "models": {"custom": {"id": "other"}}, "language": "pl"}
                if enabled is not None:
                    original["cli"]["enabled"] = enabled
                config.write_text(json.dumps(original))
                bin_dir = home / "bin"
                bin_dir.mkdir()
                summarize = bin_dir / "summarize"
                summarize.write_text('''#!/usr/bin/python3
import json, os
from pathlib import Path
assert __import__('sys').argv[1:] == ['refresh-free']
path = Path(os.environ['HOME']) / '.summarize/config.json'
config = json.loads(path.read_text())
config['models']['free'] = {'rules': [{'candidates': ['openrouter/first:free', 'openrouter/second:free']}]}
path.write_text(json.dumps(config))
''')
                summarize.chmod(0o755)
                env = {**os.environ, "HOME": str(home), "PATH": f"{bin_dir}:{os.environ['PATH']}"}
                result = subprocess.run([str(SCRIPT)], env=env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                result_config = json.loads(config.read_text())
                self.assertEqual(result_config["models"]["free"]["rules"][0]["candidates"],
                                 expected + ["openrouter/first:free", "openrouter/second:free"])
                self.assertEqual(result_config["cli"], original["cli"])
                self.assertEqual(result_config["model"], model)
                self.assertEqual(result_config["models"]["custom"], {"id": "other"})
                self.assertEqual(result_config["language"], "pl")

    def test_failed_refresh_does_not_change_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config = home / ".summarize/config.json"
            config.parent.mkdir()
            config.write_text('{"model":"existing"}\n')
            bin_dir = home / "bin"
            bin_dir.mkdir()
            summarize = bin_dir / "summarize"
            summarize.write_text("#!/bin/sh\nexit 42\n")
            summarize.chmod(0o755)
            env = {**os.environ, "HOME": str(home), "PATH": f"{bin_dir}:{os.environ['PATH']}"}
            result = subprocess.run([str(SCRIPT)], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 42)
            self.assertEqual(config.read_text(), '{"model":"existing"}\n')


if __name__ == "__main__":
    unittest.main()
