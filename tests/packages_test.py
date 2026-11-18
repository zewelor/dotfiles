"""Check APT package selection without running package installation."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PackagesTest(unittest.TestCase):
    def run_packages(self, *, editor_candidate="0.11.3-1", optional_policy="",
                     policy_status=0, install_status=0):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            log = base / "packages.log"
            for name, body in {
                "sudo": r'''
printf "%s\n" "$*" >> "$TEST_PACKAGE_LOG"
case "$*" in
    *" duf") exit "$TEST_INSTALL_STATUS" ;;
esac
''',
                "apt-cache": r'''
printf "apt-cache %s\n" "$*" >> "$TEST_PACKAGE_LOG"
if [ "$*" = "policy neovim" ]; then
    printf "  Candidate: %s\n" "$TEST_EDITOR_CANDIDATE"
else
    printf "%s" "$TEST_OPTIONAL_POLICY"
    exit "$TEST_POLICY_STATUS"
fi
''',
            }.items():
                tool = base / name
                tool.write_text("#!/bin/sh\n" + body)
                tool.chmod(0o755)
            result = subprocess.run(
                ["/usr/bin/make", "--no-print-directory", "packages"], cwd=ROOT,
                env=dict(os.environ, PATH=f"{base}:/usr/bin:/bin",
                         TEST_PACKAGE_LOG=str(log), TEST_EDITOR_CANDIDATE=editor_candidate,
                         TEST_OPTIONAL_POLICY=optional_policy, TEST_POLICY_STATUS=str(policy_status),
                         TEST_INSTALL_STATUS=str(install_status)),
                capture_output=True, text=True, timeout=10,
            )
            return result, log.read_text().splitlines()

    def test_neovim_patch_boundary_selects_a_supported_editor(self):
        for candidate, expected in (("0.11.2-1", "vim"), ("0.11.3-1", "neovim")):
            with self.subTest(candidate=candidate):
                result, calls = self.run_packages(editor_candidate=candidate)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(calls[-1], f"apt-get install -y --no-install-recommends {expected}")

    def test_optional_packages_install_only_available_candidates(self):
        for lazygit_policy in ("", "lazygit:\n  Installed: (none)\n  Candidate: (none)\n"):
            with self.subTest(lazygit_policy=lazygit_policy):
                result, calls = self.run_packages(
                    optional_policy=lazygit_policy + "duf:\n  Installed: (none)\n  Candidate: 0.8.1-1+b6\n",
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("Skipping optional APT package lazygit", result.stdout)
                self.assertEqual(calls[1:-2], [
                    "apt-cache policy lazygit duf",
                    "apt-get install -y --no-install-recommends duf",
                ])

    def test_no_optional_candidates_skip_install(self):
        result, calls = self.run_packages()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls[1:-2], ["apt-cache policy lazygit duf"])

    def test_available_optional_packages_share_one_transaction(self):
        result, calls = self.run_packages(
            optional_policy="lazygit:\n  Candidate: 0.44.1\n"
                            "duf:\n  Installed: 0.8.1-1+b6\n  Candidate: 0.8.1-1+b6\n",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls[1:-2], [
            "apt-cache policy lazygit duf",
            "apt-get install -y --no-install-recommends lazygit duf",
        ])

    def test_optional_apt_errors_stop_before_editor_selection(self):
        for statuses in ({"policy_status": 100}, {"install_status": 100}):
            with self.subTest(statuses=statuses):
                result, calls = self.run_packages(
                    optional_policy="duf:\n  Candidate: 0.8.1-1+b6\n", **statuses,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn("apt-cache policy neovim", calls)
                if "policy_status" in statuses:
                    self.assertNotIn("apt-get install -y --no-install-recommends duf", calls)


if __name__ == "__main__":
    unittest.main()
