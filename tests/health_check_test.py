"""Exercise the production health check against an isolated repository fixture."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class HealthCheckSyntaxTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-health-check-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)

        shutil.copytree(ROOT / ".zsh", self.repo / ".zsh")
        for name in (".zshenv", ".zshrc", "install", "install-font",
                     ".stow-local-ignore", "bin/dotfiles-health-check",
                     "bin/update-shell-completions", "tests/vault_test.zsh"):
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)

        config = self.repo / ".config/mise/config.toml"
        config.parent.mkdir(parents=True)
        config.write_text("[tools]\n")

    def run_doctor(self):
        return subprocess.run(
            ["zsh", str(self.repo / "bin/dotfiles-health-check"), "doctor"],
            capture_output=True, text=True, timeout=20,
        )

    def assert_syntax_error_is_reported(self, relative_path, contents):
        invalid_script = self.repo / relative_path
        invalid_script.parent.mkdir(parents=True, exist_ok=True)
        invalid_script.write_text(contents)
        result = self.run_doctor()

        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"Shell syntax check failed: {relative_path}", result.stdout)

    def test_reports_syntax_errors_in_later_zsh_helpers(self):
        self.assert_syntax_error_is_reported(
            ".zsh/zz-invalid.zsh", "if [[ then\n  print broken\nfi\n")

    def test_checks_zshenv_and_zshrc_individually(self):
        for relative_path in (".zshenv", ".zshrc"):
            with self.subTest(relative_path=relative_path):
                self.assert_syntax_error_is_reported(
                    relative_path, "if [[ then\n  print broken\nfi\n")

    def test_checks_zsh_scripts_in_bin_by_shebang(self):
        self.assert_syntax_error_is_reported(
            "bin/invalid-zsh-helper", "#!/bin/zsh\nif [[ then\n  print broken\nfi\n")

    def test_skips_bash_scripts_in_bin(self):
        bash_script = self.repo / "bin/bash-only-helper"
        bash_script.write_text("#!/bin/bash\narray=([key]=value)\n")

        result = self.run_doctor()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("bin/bash-only-helper", result.stdout)


if __name__ == "__main__":
    unittest.main()
