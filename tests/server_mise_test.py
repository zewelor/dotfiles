"""Check the boundary between desktop-local tools and server inventory."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ServerMiseTest(unittest.TestCase):
    def test_mise_local_refuses_server_but_still_works_on_desktop(self):
        function = re.search(r"(?ms)^  mise-local\(\) \{\n.*?^  \}",
                             (ROOT / ".zshrc").read_text()).group()
        script = '''
is_desktop() { [[ "$DOTFILES_PROFILE" == desktop ]]; }
mise() { print -r -- "called $*"; }
''' + function + '\nmise-local jq@1.8.1'
        with tempfile.TemporaryDirectory() as tmp:
            for profile in ("server", "desktop"):
                with self.subTest(profile=profile):
                    env = {**os.environ, "HOME": tmp, "DOTFILES_PROFILE": profile,
                           "MISE_CONFIG_DIR": str(Path(tmp) / ".config/mise")}
                    result = subprocess.run(["zsh", "-f", "-c", script], cwd=tmp, env=env,
                                            capture_output=True, text=True)
                    if profile == "server":
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn("managed in Ansible inventory", result.stderr)
                        self.assertNotIn("called", result.stdout)
                    else:
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertIn("called use -p", result.stdout)


if __name__ == "__main__":
    unittest.main()
