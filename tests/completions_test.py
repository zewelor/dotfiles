#!/usr/bin/python3
"""Offline checks for static shell completion generation and registration."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ("sourcetap", "gog", "opencode", "dockerfmt")


MISE = shutil.which("mise")


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

    def refresh(self, cwd=None):
        return subprocess.run([str(ROOT / "bin/update-shell-completions")],
                              cwd=cwd or self.home, env=self.env, text=True, capture_output=True)

    def test_refresh_skips_user_zshenv(self):
        startup_log = self.home / "startup-log"
        self.env["STARTUP_LOG"] = str(startup_log)
        (self.home / ".zshenv").write_text('print -r -- sourced >> "$STARTUP_LOG"\n')
        self.good_tool("gog")
        result = self.refresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.cache / "_gog").is_file())
        self.assertFalse(startup_log.exists())

    def test_generates_supported_scripts_and_command_arguments(self):
        for tool in TOOLS:
            self.good_tool(tool)
        result = self.refresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            "sourcetap:completion zsh", "gog:completion zsh",
            "opencode:--completions zsh", "dockerfmt:completion zsh"])
        for tool in TOOLS:
            self.assertIn(f"_{tool}()", (self.cache / f"_{tool}").read_text())
        self.assertEqual(sorted(p.name for p in self.cache.iterdir()),
                         sorted("_" + tool for tool in TOOLS))

    def test_unavailable_tools_are_optional(self):
        self.good_tool("dockerfmt")
        result = self.refresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Skipping sourcetap: not found in PATH", result.stdout)
        self.assertIn("Updated dockerfmt", result.stdout)
        self.assertEqual(self.log.read_text().splitlines(), ["dockerfmt:completion zsh"])

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

    def test_directory_created_at_target_during_generation_is_not_written_into(self):
        self.env["COMPLETION_TARGET"] = str(self.cache / "_gog")
        self.tool("gog", '''mkdir -p "$COMPLETION_TARGET"
printf '%s\\n' 'unmanaged' > "$COMPLETION_TARGET/sentinel"
printf '%s\\n' '#compdef gog' '_gog() { :; }'
''')
        result = self.refresh()
        self.assertNotEqual(result.returncode, 0)
        target = self.cache / "_gog"
        self.assertEqual((target / "sentinel").read_text(), "unmanaged\n")
        self.assertEqual(sorted(p.name for p in target.iterdir()), ["sentinel"])
        self.assertEqual(sorted(p.name for p in self.cache.iterdir()), ["_gog"])

    def test_custom_cache_directory(self):
        self.env["ZSH_CACHE_DIR"] = str(self.home / "custom-cache")
        self.good_tool("opencode")
        result = self.refresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / "custom-cache/completions/_opencode").exists())
        self.assertFalse(self.cache.exists())

    def test_relative_cache_directory_stays_relative_to_caller(self):
        project = self.home / "project"
        project.mkdir()
        self.env["ZSH_CACHE_DIR"] = "custom-cache"
        self.good_tool("gog")
        result = self.refresh(cwd=project)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((project / "custom-cache/completions/_gog").exists())
        self.assertFalse((self.home / "custom-cache").exists())

    @unittest.skipUnless(MISE, "real mise executable is required")
    def test_refresh_ignores_project_mise_configs_and_preserves_caller_policy(self):
        project = self.home / "dotfiles"
        project_config = project / ".config/mise/config.toml"
        global_config = self.home / ".config/mise/config.toml"
        local_config = global_config.with_name("config.local.toml")
        system_config = self.home / "system.toml"
        for config, content in (
            (project_config, '[tools]\n"github:zewelor/sourcetap" = "latest"\n'),
            (global_config, '[tools]\njq = "1.8.1"\n'),
            (local_config, '[tools]\nyq = "4.45.4"\n'),
            (system_config, '[tools]\nruby = "3.4.0"\n'),
            (self.home / "mise.toml", '[tools]\nnode = "22.0.0"\n'),
            (self.home / ".tool-versions", "python 3.12.0\n"),
        ):
            config.parent.mkdir(parents=True, exist_ok=True)
            config.write_text(content)
        config_log = self.home / "mise-configs.json"
        self.tool("gog", '''"$TEST_MISE" config ls --json > "$MISE_CONFIG_LOG" || exit
printf '%s\\n' '#compdef gog' '_gog() { :; }'
''')
        self.env = {
            "HOME": str(self.home), "ZDOTDIR": str(self.home),
            "PATH": f"{self.bin}:/usr/bin:/bin", "TEST_MISE": MISE,
            "MISE_CONFIG_LOG": str(config_log), "MISE_OFFLINE": "1",
            "MISE_CONFIG_DIR": str(self.home / "caller-config"),
            "MISE_DATA_DIR": str(self.home / "mise-data"),
            "MISE_STATE_DIR": str(self.home / "mise-state"),
            "MISE_CACHE_DIR": str(self.home / "mise-cache"),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "XDG_CACHE_HOME": str(self.home / "cache"),
        }
        policies = (
            ("desktop", None, str(system_config),
             {str(global_config), str(local_config), str(system_config)}),
            ("server", str(global_config), "/dev/null/mise.toml", {str(global_config)}),
            ("server", "../.config/mise/config.toml", "../system.toml",
             {str(global_config), str(system_config)}),
            ("desktop", "~/.config/mise/config.toml", "~/system.toml",
             {str(global_config), str(system_config)}),
        )
        for profile, global_override, system_override, expected in policies:
            with self.subTest(profile=profile, global_override=global_override,
                              system_override=system_override):
                self.env["DOTFILES_PROFILE"] = profile
                self.env.pop("MISE_GLOBAL_CONFIG_FILE", None)
                if global_override is not None:
                    self.env["MISE_GLOBAL_CONFIG_FILE"] = global_override
                self.env["MISE_SYSTEM_CONFIG_FILE"] = system_override
                result = self.refresh(cwd=project)
                self.assertEqual(result.returncode, 0, result.stderr)
                loaded = {(project / config["path"]).resolve()
                          for config in json.loads(config_log.read_text())}
                expected = {Path(path).resolve() for path in expected}
                self.assertEqual(loaded, expected)
                self.assertTrue((self.cache / "_gog").exists())

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
for tool in sourcetap gog opencode dockerfmt; do
  [[ "${_comps[$tool]}" == "_$tool" ]] || exit 1
done
[[ "${_comps[oc]}" == _opencode ]]
'''], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
