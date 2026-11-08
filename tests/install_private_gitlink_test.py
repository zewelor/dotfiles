"""Check private submodule pin handling using synthetic Git repositories."""

import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PrivateGitlinkTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.origin = root / "origin"
        self.repo = root / "repo"
        self.origin.mkdir()
        self.repo.mkdir()
        self.env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
                    "GIT_ALLOW_PROTOCOL": "file"}
        self.git(self.origin, "init", "-q", "--initial-branch=main")
        (self.origin / "file").write_text("first\n")
        self.git(self.origin, "add", "file")
        self.git(self.origin, "commit", "-qm", "first")
        self.first = self.git(self.origin, "rev-parse", "HEAD")
        self.git(self.repo, "init", "-q", "--initial-branch=main")
        self.git(self.repo, "submodule", "add", "-q", str(self.origin), "prv")
        self.git(self.repo, "commit", "-qm", "pin first")
        (self.origin / "file").write_text("second\n")
        self.git(self.origin, "add", "file")
        self.git(self.origin, "commit", "-qm", "second")
        self.second = self.git(self.origin, "rev-parse", "HEAD")
        self.git(self.repo / "prv", "fetch", "-q", "origin")
        script = (ROOT / "install").read_text()
        start = script.index("setup_private_submodule() {")
        end = script.index("\n}\n", start) + 3
        self.harness = root / "install-fixture"
        self.harness.write_text("#!/bin/zsh\nset -euo pipefail\nBASE_DIR=" +
                                shlex.quote(str(self.repo)) +
                                "\nis_desktop() { return 0; }\nprint_banner() { :; }\n" +
                                script[start:end] + "\nsetup_private_submodule\n")

    def git(self, cwd, *args):
        cmd = ["git", "-c", "core.hooksPath=/dev/null", "-c", "user.name=Fixture",
               "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", *args]
        return subprocess.run(cmd, cwd=cwd, env=self.env, text=True, capture_output=True,
                              check=True, timeout=15).stdout.strip()

    def run_setup(self):
        return subprocess.run(["zsh", str(self.harness)], env=self.env, text=True,
                              capture_output=True, timeout=15)

    def test_index_mismatch_fails_without_changing_checkout(self):
        self.git(self.repo / "prv", "checkout", "-q", "--detach", self.second)
        self.git(self.repo, "add", "prv")
        self.git(self.repo / "prv", "checkout", "-q", "--detach", self.first)
        self.git(self.repo, "config", "diff.ignoreSubmodules", "all")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("gitlink", result.stderr)
        self.assertEqual(self.git(self.repo / "prv", "rev-parse", "HEAD"), self.first)
        self.assertEqual(self.git(self.repo, "rev-parse", ":prv"), self.second)
        command = next(line.strip() for line in result.stderr.splitlines()
                       if line.strip().startswith("git "))
        explanation = subprocess.run(shlex.split(command), cwd=self.repo, env=self.env,
                                     text=True, capture_output=True, check=True, timeout=15)
        self.assertIn("Submodule prv", explanation.stdout)

    def test_matching_pin_checks_out_recorded_commit(self):
        self.git(self.repo / "prv", "checkout", "-q", "--detach", self.second)
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git(self.repo / "prv", "rev-parse", "HEAD"), self.first)

    def test_matching_pin_initializes_missing_submodule(self):
        self.git(self.repo, "submodule", "deinit", "-f", "--", "prv")
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git(self.repo / "prv", "rev-parse", "HEAD"), self.first)


if __name__ == "__main__":
    unittest.main()
