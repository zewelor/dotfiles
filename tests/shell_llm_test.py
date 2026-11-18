#!/usr/bin/python3
"""Offline checks for AI client shortcuts and temporary workspaces."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AiWorkspaceTests(unittest.TestCase):
    def test_workspace_creation_failure_does_not_start_codex(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(
                ["/usr/bin/zsh", "-f", "-c", '''
source "$1/.zsh/helpers.zsh"
zpcompdef() { :; }
codex() { print -r -- "unexpected Codex invocation"; }
source "$1/.zsh/_after_local/ai-clients.zsh"
cdxtmp
''', "test", str(ROOT)],
                cwd=tmp, env=dict(os.environ, TMPDIR=str(Path(tmp) / "missing")),
                text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertEqual(result.stdout, "")
            self.assertIn("mktemp", result.stderr)

    def test_workspace_remains_current_and_preserves_files_and_exit_code(self):
        for shortcut, exit_code in (("cdxtmp", 0), ("octmp", 23)):
            with self.subTest(shortcut=shortcut), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                workspace_root = base / "temporary workspaces"
                workspace_root.mkdir()
                result = subprocess.run(
                    ["/usr/bin/zsh", "-f", "-c", '''
source "$1/.zsh/helpers.zsh"
zpcompdef() { :; }
record_session() {
  print -r -- "$PWD" > "$TEST_RECORD"
  printf '%s\\n' "$@" >> "$TEST_RECORD"
  print -r -- 'session output' > artifact.txt
  return "$TEST_EXIT_CODE"
}
codex() { record_session "$@"; }
opencode() {
  [[ "$1" == "$PWD" ]] || return 99
  shift
  record_session "$@"
}
source "$1/.zsh/_after_local/ai-clients.zsh"
"$2" 'prompt with spaces' --model fixture
result=$?
printf '%s\\n' "$PWD" "$result"
''', "test", str(ROOT), shortcut],
                    cwd=base,
                    env=dict(os.environ, TMPDIR=str(workspace_root),
                             TEST_RECORD=str(base / "record"),
                             TEST_EXIT_CODE=str(exit_code)),
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                cwd, actual_exit_code = result.stdout.splitlines()
                workspace = Path(cwd)
                self.assertEqual(workspace.parent, workspace_root)
                self.assertEqual(actual_exit_code, str(exit_code))
                self.assertEqual((base / "record").read_text().splitlines(), [
                    cwd, 'prompt with spaces', '--model', 'fixture',
                ])
                self.assertEqual((workspace / "artifact.txt").read_text(),
                                 'session output\n')


    def test_workspace_is_preserved_on_interrupt(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(
                ["/usr/bin/zsh", "-f", "-c", '''
source "$1/.zsh/helpers.zsh"
zpcompdef() { :; }
opencode() {
  print -r -- "$PWD"
  print -r -- 'session output' > artifact.txt
  kill -s INT -- -$$
}
source "$1/.zsh/_after_local/ai-clients.zsh"
octmp
''', "test", str(ROOT)],
                cwd=tmp, env=dict(os.environ, TMPDIR=tmp), text=True, capture_output=True,
                start_new_session=True, timeout=5,
            )
            self.assertEqual(result.returncode, -signal.SIGINT, result.stderr)
            workspace = Path(result.stdout.strip())
            self.assertEqual(workspace.parent, Path(tmp))
            self.assertEqual((workspace / "artifact.txt").read_text(), "session output\n")


class ShellAiAvailabilityTests(unittest.TestCase):
    def test_local_aliases_and_functions_take_precedence_over_defaults(self):
        result = subprocess.run(
            ["/usr/bin/zsh", "-f", "-c", '''
source "$1/.zsh/helpers.zsh"
zpcompdef() { :; }
codex() { :; }
opencode() { :; }
alias oc='local-opencode'
alias codexrl='local-codex-resume'
alias cdxtmp='local-codex-tmp'
codexgo() { print -r -- 'local codexgo'; }
source "$1/.zsh/_after_local/ai-clients.zsh"
[[ "${aliases[oc]}" == local-opencode && "${aliases[codexrl]}" == local-codex-resume ]] || exit 1
[[ "${aliases[cdxtmp]}" == local-codex-tmp ]] || exit 1
[[ "$(codexgo)" == 'local codexgo' && "${aliases[ocp]}" == 'opencode --port' ]]
''', "test", str(ROOT)], text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_profiles_and_available_clients(self):
        codex = {"cdxc", "cdxrl", "codexrl", "codexgo", "cdxtmp"}
        opencode = {"oc", "occ", "ocp", "octmp"}
        agy = {"agyp", "agyc", "agyi"}
        commits = {"gsum", "gsumpo", "gsumpoa"}
        for profile, tools, expected in (
            ("server", (), set()),
            ("server", ("codex",), codex),
            ("server", ("opencode",), opencode),
            ("server", ("agy",), agy),
            ("desktop", (), commits),
            ("desktop", ("codex", "opencode", "agy"), codex | opencode | agy | commits),
        ):
            with self.subTest(profile=profile, tools=tools), tempfile.TemporaryDirectory() as tmp:
                for tool in tools:
                    executable = Path(tmp) / tool
                    executable.write_text('#!/bin/sh\nexit 99\n')
                    executable.chmod(0o755)
                result = subprocess.run(
                    ["/usr/bin/zsh", "-f", "-c", '''
source "$1/.zsh/helpers.zsh"
is_desktop() { [[ "$DOTFILES_PROFILE" == desktop ]]; }
zpcompdef() { :; }
for module in "$1/.zsh/_after_local/ai-clients.zsh" "$1/.zsh/shell_llm.zsh"; do
  source "$module"
done
for name in "${@[2,-1]}"; do
  if whence "$name" >/dev/null; then
    print -r -- "$name"
  fi
done
''', "test", str(ROOT), *sorted(codex | opencode | agy | commits)],
                    env=dict(os.environ, PATH=tmp, DOTFILES_PROFILE=profile),
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(set(result.stdout.splitlines()), expected)


if __name__ == "__main__":
    unittest.main()
