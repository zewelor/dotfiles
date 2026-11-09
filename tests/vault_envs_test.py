"""Test installer environment generation without contacting Vault or changing HOME."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]


class VaultEnvsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / ".zsh").mkdir()
        (self.root / ".zsh/helpers.zsh").write_text((ROOT / ".zsh/helpers.zsh").read_text())
        self.home = self.root / "home"
        (self.home / ".zshrc.d").mkdir(parents=True)
        self.target = self.home / ".zshrc.d/envs.zsh"
        self.target.write_text("old content\n")
        self.responses = self.root / "responses"
        self.responses.mkdir()
        self.response("envs", {"EXISTING": "hello 'world'\nnext"})
        self.response("feedway", {"api_token": "feed ' token"})
        self.response("sourcetap", {"MCP_AUTH_TOKEN": "source $ token"})
        script = (ROOT / "install").read_text().rsplit("\nrun_installation", 1)[0]
        script += r'''
is_interactive() { return 0 }
vault_http_get() {
  case "$1" in
    */shell_envs/data/envs.zsh) cat "$FIXTURES/envs" ;;
    */secret/data/auth/feedway) cat "$FIXTURES/feedway" ;;
    */secret/data/auth/sourcetap) cat "$FIXTURES/sourcetap" ;;
    *) return 1 ;;
  esac
}
add_secret_envs_from_vault
[[ "$VAULT_TOKEN" == "test-vault-token" ]]
'''
        (self.root / "install").write_text(script)

    def response(self, name, data):
        (self.responses / name).write_text(json.dumps({"data": {"data": data}}))

    def run_generator(self):
        env = os.environ | {"HOME": str(self.home), "FIXTURES": str(self.responses)}
        return subprocess.run(["zsh", str(self.root / "install")], input="y\ntest-vault-token\n",
                              text=True, capture_output=True, env=env)

    def test_generates_quoted_values_and_source_comments(self):
        result = self.run_generator()
        self.assertEqual(result.returncode, 0, result.stderr)
        content = self.target.read_text()
        for path in ("shell_envs/envs.zsh", "secret/auth/feedway", "secret/auth/sourcetap"):
            self.assertIn("# " + path, content)
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o600)
        check = subprocess.run(["zsh", "-c", 'source "$1"; print -rn -- "$EXISTING"$\'\\0\'"$FEEDWAY_API_TOKEN"$\'\\0\'"$SOURCETAP_MCP_TOKEN"',
                                "--", str(self.target)], text=True, capture_output=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertEqual(check.stdout.split("\0"), ["hello 'world'\nnext", "feed ' token", "source $ token"])
        for secret in ("test-vault-token", "feed ' token", "source $ token", "hello 'world'"):
            self.assertNotIn(secret, result.stdout + result.stderr)

    def test_failures_preserve_existing_file(self):
        for case in ("missing", "empty", "collision", "invalid_name", "http_error",
                     "nul_main", "nul_feedway"):
            with self.subTest(case=case):
                self.response("envs", {"EXISTING": "ok"})
                self.response("feedway", {"api_token": "ok"})
                self.response("sourcetap", {"MCP_AUTH_TOKEN": "ok"})
                if case == "missing": self.response("sourcetap", {})
                if case == "empty": self.response("feedway", {"api_token": ""})
                if case == "collision": self.response("envs", {"FEEDWAY_API_TOKEN": "duplicate"})
                if case == "invalid_name": self.response("envs", {"BAD-NAME": "bad"})
                if case == "http_error": (self.responses / "sourcetap").unlink()
                if case == "nul_main": self.response("envs", {"EXISTING": "bad\x00value"})
                if case == "nul_feedway": self.response("feedway", {"api_token": "bad\x00value"})
                result = self.run_generator()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.target.read_text(), "old content\n")
                self.assertEqual(list(self.target.parent.iterdir()), [self.target])

    def test_directory_targets_are_rejected_without_writing_secrets(self):
        self.target.unlink()
        for kind in ("directory", "directory_symlink"):
            with self.subTest(kind=kind):
                outside = self.root / "outside"
                outside.mkdir(exist_ok=True)
                if kind == "directory":
                    self.target.mkdir()
                    destination = self.target
                else:
                    self.target.symlink_to(outside, target_is_directory=True)
                    destination = outside
                try:
                    result = self.run_generator()
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(list(destination.iterdir()), [])
                    self.assertEqual([p for p in self.target.parent.iterdir() if p != self.target], [])
                finally:
                    if self.target.is_symlink():
                        self.target.unlink()
                    else:
                        shutil.rmtree(self.target)
                    for item in outside.iterdir():
                        item.unlink()

    def test_symlinked_secrets_directory_is_rejected_without_changing_target(self):
        secrets_dir = self.home / ".zshrc.d"
        external = self.root / "external"
        shutil.move(secrets_dir, external)
        external.chmod(0o755)
        secrets_dir.symlink_to(external, target_is_directory=True)
        result = self.run_generator()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(secrets_dir.is_symlink())
        self.assertEqual(external.stat().st_mode & 0o777, 0o755)
        self.assertEqual((external / "envs.zsh").read_text(), "old content\n")
        self.assertEqual([p.name for p in external.iterdir()], ["envs.zsh"])

    def test_dangling_secrets_directory_symlink_is_rejected(self):
        secrets_dir = self.home / ".zshrc.d"
        shutil.rmtree(secrets_dir)
        missing = self.root / "missing"
        secrets_dir.symlink_to(missing, target_is_directory=True)
        result = self.run_generator()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(secrets_dir.is_symlink())
        self.assertFalse(missing.exists())

    def test_interruption_cleans_partial_secret_file(self):
        script_file = self.root / "install"
        script = script_file.read_text()
        original = '*/secret/data/auth/feedway) cat "$FIXTURES/feedway" ;;'
        delayed = '*/secret/data/auth/feedway) touch "$FIXTURES/started"; sleep 2; cat "$FIXTURES/feedway" ;;'
        self.assertIn(original, script)
        script_file.write_text(script.replace(original, delayed))
        env = os.environ | {"HOME": str(self.home), "FIXTURES": str(self.responses)}
        for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=sig.name):
                marker = self.responses / "started"
                marker.unlink(missing_ok=True)
                process = subprocess.Popen(["zsh", str(script_file)], stdin=subprocess.PIPE,
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                           text=True, env=env, start_new_session=True)
                try:
                    process.stdin.write("y\ntest-vault-token\n")
                    process.stdin.close()
                    deadline = time.monotonic() + 10
                    while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertTrue(marker.exists(), "generator did not reach the delayed Vault read")
                    os.killpg(process.pid, sig)
                    self.assertNotEqual(process.wait(timeout=5), 0)
                    # The parent can exit before the subshell finishes its EXIT trap.
                    deadline = time.monotonic() + 3
                    while list(self.target.parent.glob('.envs.zsh.*')) and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertEqual(self.target.read_text(), "old content\n")
                    self.assertEqual(list(self.target.parent.iterdir()), [self.target])
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=5)
                    for leftover in self.target.parent.glob('.envs.zsh.*'):
                        leftover.unlink()

    def test_terminating_installer_does_not_leave_a_writer_running(self):
        script_file = self.root / "install"
        script = script_file.read_text()
        original = '*/secret/data/auth/feedway) cat "$FIXTURES/feedway" ;;'
        delayed = '*/secret/data/auth/feedway) touch "$FIXTURES/started"; sleep 1; cat "$FIXTURES/feedway" ;;'
        self.assertIn(original, script)
        script_file.write_text(script.replace(original, delayed))
        env = os.environ | {"HOME": str(self.home), "FIXTURES": str(self.responses)}
        for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=sig.name):
                marker = self.responses / "started"
                marker.unlink(missing_ok=True)
                process = subprocess.Popen(["zsh", str(script_file)], stdin=subprocess.PIPE,
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                           text=True, env=env, start_new_session=True)
                try:
                    process.stdin.write("y\ntest-vault-token\n")
                    process.stdin.close()
                    deadline = time.monotonic() + 10
                    while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertTrue(marker.exists(), "generator did not start")
                    os.kill(process.pid, sig)
                    self.assertNotEqual(process.wait(timeout=5), 0)
                    time.sleep(1.2)
                    self.assertEqual(self.target.read_text(), "old content\n")
                    self.assertEqual(list(self.target.parent.iterdir()), [self.target])
                finally:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    if process.poll() is None:
                        process.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
