"""Exercise gem source validation through the offline doctor command."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MiseSourcesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-mise-sources-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        shutil.copytree(ROOT / ".zsh", self.repo / ".zsh")
        for name in ("bin/dotfiles-health-check", "tests/vault_test.zsh",
                     ".zshrc", "install", "install-font", ".stow-local-ignore"):
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        self.config = self.repo / ".config/mise/config.toml"
        self.config.parent.mkdir(parents=True)
        self.config.write_text('[tools]\nruby = "latest"\n')

    def doctor(self):
        return subprocess.run(
            ["zsh", str(self.repo / "bin/dotfiles-health-check"), "doctor"],
            capture_output=True, text=True, timeout=20,
        )

    def test_rejects_missing_or_invalid_sources(self):
        for entry in (
            '"latest"',
            '[]',
            '{ version = "latest" }',
            '{ version = "latest", source = "" }',
            '{ version = "latest", source = "   " }',
            '{ version = "latest", source = 123 }',
            '{ version = "latest", source = "http://rubygems.org/" }',
            '{ version = "latest", source = "https://" }',
            '{ version = "latest", source = "https://[broken" }',
        ):
            with self.subTest(entry=entry):
                self.config.write_text(f'[tools]\n"gem:example" = {entry}\n')
                result = self.doctor()
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("gem:example", result.stdout)
                self.assertIn("source", result.stdout)

    def test_checks_local_overrides(self):
        local = self.config.with_name("config.local.toml")
        local.write_text('[tools]\n"gem:local-cli" = "latest"\n')
        result = self.doctor()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("config.local.toml", result.stdout)
        self.assertIn("gem:local-cli", result.stdout)

    def test_checks_every_version_in_arrays(self):
        self.config.write_text('''[tools]
"gem:example" = [
  { version = "1.0", source = "https://rubygems.org/" },
  { version = "2.0" },
]
''')
        result = self.doctor()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("gem:example", result.stdout)

    def test_accepts_explicit_sources_and_other_backends(self):
        self.config.write_text('''[tools]
ruby = "latest"
"npm:example" = "latest"
"gem:example" = [
  { version = "1.0", source = "https://rubygems.org/" },
  { version = "2.0", source = "https://gems.example.com/" },
]
''')
        self.config.with_name("config.local.toml").write_text('''[tools]
"gem:local-cli" = { version = "latest", source = "https://rubygems.org/" }
''')
        result = self.doctor()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_invalid_toml(self):
        self.config.write_text('[tools\n')
        result = self.doctor()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("config.toml", result.stdout)

    def test_rejects_missing_shared_config(self):
        self.config.unlink()
        result = self.doctor()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("config.toml", result.stdout)


if __name__ == "__main__":
    unittest.main()
