#!/usr/bin/python3
"""Offline regression checks for shell startup helpers and terminal titles."""
import errno
import os
from pathlib import Path
import pty
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def osc_title(text):
    prefix = "# " if os.geteuid() == 0 else ""
    return f"\x1b]2;{prefix}{text}\x07"


class ShellStartupTests(unittest.TestCase):
    def run_zsh(self, script, *args, tty=False):
        env = dict(os.environ, TERM="xterm-256color")
        for name in ("TMUX", "SSH_CONNECTION", "SSH_CLIENT"):
            env.pop(name, None)
        command = ["/usr/bin/zsh", "-f", "-c", script, "test", str(ROOT), *map(str, args)]
        if not tty:
            return subprocess.run(command, env=env, capture_output=True, text=True)
        master, slave = pty.openpty()
        try:
            result = subprocess.run(command, env=env, stdin=slave, stdout=slave,
                                    stderr=subprocess.PIPE, text=True)
            os.close(slave)
            slave = None
            output = b""
            while True:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not chunk:
                    break
                output += chunk
            result.stdout = output.decode()
            return result
        finally:
            os.close(master)
            if slave is not None:
                os.close(slave)

    def title(self, setup, value, max_length=0):
        result = self.run_zsh('''source "$1/.zsh/terminal_title.zsh" >/dev/null
ZSH_TITLE_MAX=$3
''' + setup + '\n_title_terminal "$2"', value, max_length, tty=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_title_expands_prompt_escapes(self):
        result = self.title('', '%d %%')
        self.assertEqual(result, osc_title(f"{Path.cwd()} %"))

    def test_title_keeps_remote_prefix(self):
        result = self.title('SSH_CONNECTION=remote; HOSTNAME=remote.example; LOGNAME=alice', 'work')
        self.assertEqual(result, osc_title("alice@remote.example: work"))

    def test_remote_title_works_without_external_hostname(self):
        result = self.title('''unset HOSTNAME
SSH_CLIENT=remote; HOST=remote.example; LOGNAME=alice
hostname() { return 127; }''', 'work')
        self.assertEqual(result, osc_title("alice@remote: work"))

    def test_title_truncation(self):
        self.assertEqual(self.title('', 'abcdefghij', 8), osc_title("abcde..."))

    def test_command_title_keeps_literal_percent(self):
        result = self.run_zsh('''source "$1/.zsh/terminal_title.zsh" >/dev/null
ZSH_TITLE_MAX=0
_title_terminal_cmd 'nvim 100%name'
''', tty=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, osc_title("nvim 100%name"))

    def test_title_skips_tmux_and_nonterminal(self):
        for setup, tty in [('TMUX=session', True), ('', False)]:
            result = self.run_zsh('''source "$1/.zsh/terminal_title.zsh" >/dev/null
''' + setup + '\n_title_terminal work', tty=tty)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")

    def test_symlink_helper_handles_dangling_and_changed_targets(self):
        with tempfile.TemporaryDirectory() as temp:
            link = Path(temp) / "nested" / "link"
            result = self.run_zsh('''source "$1/.zsh/helpers.zsh"
set -e
ensure_symlink_target missing "$2"
ensure_symlink_target missing "$2"
ensure_symlink_target changed "$2"
''', link)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(os.readlink(link), "changed")

    def test_symlink_helper_stops_when_parent_creation_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            link = Path(temp) / "link"
            result = self.run_zsh('''source "$1/.zsh/helpers.zsh"
mkdir() { return 42; }
ensure_symlink_target missing "$2"
''', link)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(link.is_symlink())

    def test_atuin_gate_preserves_supported_unsupported_and_server_paths(self):
        rc = (ROOT / ".zshrc").read_text()
        start = rc.index("\nif is_desktop &&", rc.index("# Includes,"))
        gate = rc[start:rc.index("# Local includes", start)]
        for profile, version, status, expected in [
            ("desktop", "glibc 2.42", 0, "atuinsh/atuin"),
            ("desktop", "glibc 2.31", 0, "zsh-fzf-history-search"),
            ("desktop", "", 1, "zsh-fzf-history-search"),
            ("server", "", 99, "zsh-fzf-history-search"),
        ]:
            with self.subTest(profile=profile, version=version, status=status):
                result = self.run_zsh('''autoload -Uz is-at-least
is_desktop() { [[ "$profile" == desktop ]]; }
getconf() { print -u2 -- getconf-called; print -r -- "$version"; return "$lookup_status"; }
uname() { print -r -- x86_64; }
zinit() { print -r -- "$@"; }
profile=$2; version=$3; lookup_status=$4
''' + gate + '\nprint -- reached-end', profile, version, status)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected, result.stdout)
                self.assertIn("reached-end", result.stdout)
                self.assertEqual("getconf-called" in result.stderr, profile == "desktop")

    def test_cache_directory_creation_failure_is_reported(self):
        with tempfile.TemporaryDirectory() as temp:
            result = self.run_zsh('''set -e
XDG_CACHE_HOME=$2
mkdir() { return 42; }
source "$1/.zsh/zstyle.zsh"
''', temp)
            self.assertNotEqual(result.returncode, 0)

    def test_agent_browser_uses_desktop_browser_and_preserves_override(self):
        for profile, browser, override, expected in [
            ("desktop", "/usr/bin/brave-origin-stable", "", "/usr/bin/brave-origin-stable"),
            ("desktop", "/usr/bin/brave-origin-stable --incognito", "", "/usr/bin/brave-origin-stable"),
            ("desktop", "/usr/bin/brave-origin-stable", "/opt/custom/chrome", "/opt/custom/chrome"),
            ("desktop", "", "", "unset"),
            ("server", "/usr/bin/brave-origin-stable", "", "unset"),
        ]:
            with self.subTest(profile=profile, browser=browser, override=override):
                result = self.run_zsh('''unset BROWSER AGENT_BROWSER_EXECUTABLE_PATH
profile=$2
resolved_browser=$3
is_desktop() { [[ "$profile" == desktop ]]; }
resolve_browser_cmd() { print -r -- "$resolved_browser"; }
[[ -z "$4" ]] || export AGENT_BROWSER_EXECUTABLE_PATH="$4"
source "$1/.zsh/webapps.zsh"
/usr/bin/zsh -f -c 'print -r -- "${BROWSER:-unset}|${AGENT_BROWSER_EXECUTABLE_PATH:-unset}"'
''', profile, browser, override)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), f"{browser or 'unset'}|{expected}")

        result = self.run_zsh('''unset AGENT_BROWSER_EXECUTABLE_PATH
export BROWSER=/usr/bin/brave-origin-stable
is_desktop() { return 0; }
resolve_browser_cmd() { return 1; }
source "$1/.zsh/webapps.zsh"
/usr/bin/zsh -f -c 'print -r -- "${AGENT_BROWSER_EXECUTABLE_PATH:-unset}"'
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "/usr/bin/brave-origin-stable")

    def test_title_expands_home_directory(self):
        result = self.title('cd "$HOME" >/dev/null', '%~')
        self.assertEqual(result, osc_title("~"))


if __name__ == "__main__":
    unittest.main()
