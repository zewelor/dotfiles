"""Check editor package selection without running package installation."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class EditorPackagesTest(unittest.TestCase):
    def test_neovim_patch_boundary_selects_a_supported_editor(self):
        for candidate, expected in (("0.11.2-1", "vim"), ("0.11.3-1", "neovim")):
            with self.subTest(candidate=candidate), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                log = base / "packages.log"
                for name, body in {
                    "sudo": 'printf "%s\\n" "$*" >> "$TEST_PACKAGE_LOG"\n',
                    "apt-cache": 'printf "  Candidate: %s\\n" "$TEST_CANDIDATE"\n',
                }.items():
                    tool = base / name
                    tool.write_text("#!/bin/sh\n" + body)
                    tool.chmod(0o755)
                result = subprocess.run(
                    ["/usr/bin/make", "--no-print-directory", "packages"], cwd=ROOT,
                    env=dict(os.environ, PATH=f"{base}:/usr/bin:/bin",
                             TEST_PACKAGE_LOG=str(log), TEST_CANDIDATE=candidate),
                    capture_output=True, text=True, timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(log.read_text().splitlines()[-1],
                                 f"apt-get install -y --no-install-recommends {expected}")


if __name__ == "__main__":
    unittest.main()
