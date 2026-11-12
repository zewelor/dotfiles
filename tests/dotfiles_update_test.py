#!/usr/bin/python3
"""Exercise dotfiles_update against real local Git repositories."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def git(cwd, env, *args):
    return subprocess.run(["git", *args], cwd=cwd, env=env, text=True,
                          capture_output=True, check=True).stdout.strip()


class DotfilesUpdateTests(unittest.TestCase):
    def test_public_submodules_follow_gitlinks_and_private_is_left_to_installer(self):
        for profile in ("server", "desktop"):
            with self.subTest(profile=profile), tempfile.TemporaryDirectory() as tmp:
                home = Path(tmp)
                repo = home / "dotfiles"
                repo.mkdir()
                env = dict(os.environ, HOME=str(home), GIT_ALLOW_PROTOCOL="file",
                           GIT_AUTHOR_NAME="Test", GIT_AUTHOR_EMAIL="test@example.invalid",
                           GIT_COMMITTER_NAME="Test", GIT_COMMITTER_EMAIL="test@example.invalid",
                           DOTFILES_PROFILE=profile)
                git(repo, env, "init", "-q")
                nested = home / "nested-source"
                nested.mkdir()
                git(nested, env, "init", "-q")
                (nested / "content").write_text("first\n")
                git(nested, env, "add", "content")
                git(nested, env, "commit", "-qm", "first")
                nested_pinned = git(nested, env, "rev-parse", "HEAD")
                (nested / "content").write_text("second\n")
                git(nested, env, "commit", "-qam", "second")
                paths = (".config/tmux/plugins/catppuccin/tmux", "other/plugin", "prv")
                revisions = {}
                for index, path in enumerate(paths):
                    source = home / f"source-{index}"
                    source.mkdir()
                    git(source, env, "init", "-q")
                    (source / "content").write_text("first\n")
                    git(source, env, "add", "content")
                    if index == 1:
                        git(source, env, "submodule", "add", "-q", str(nested), "nested")
                        git(source / "nested", env, "checkout", "-q", "--detach", nested_pinned)
                        git(source, env, "add", ".gitmodules", "nested")
                    git(source, env, "commit", "-qm", "first")
                    pinned = git(source, env, "rev-parse", "HEAD")
                    (source / "content").write_text("second\n")
                    git(source, env, "commit", "-qam", "second")
                    newest = git(source, env, "rev-parse", "HEAD")
                    git(repo, env, "submodule", "add", "-q", str(source), path)
                    git(repo / path, env, "checkout", "-q", "--detach", pinned)
                    revisions[path] = pinned, newest

                git(repo, env, "config", "-f", ".gitmodules", "submodule.prv.update", "none")
                git(repo, env, "config", "submodule.prv.update", "none")
                git(repo, env, "add", ".gitmodules", *paths)
                git(repo, env, "commit", "-qm", "pin submodules")
                for path in paths:
                    git(repo / path, env, "checkout", "-q", "--detach", revisions[path][1])
                if profile == "server":
                    git(repo, env, "submodule", "deinit", "-f", "--", "prv")

                installer = repo / "install"
                installer.write_text("#!/bin/sh\ntouch \"$HOME/installer-ran\"\n")
                installer.chmod(0o755)
                alias = next(line for line in (ROOT / ".zshrc").read_text().splitlines()
                             if line.startswith("alias dotfiles_update="))
                (home / "alias.zsh").write_text(alias + "\n")
                result = subprocess.run(
                    ["zsh", "-f", "-c", 'gpl() { :; }; source "$HOME/alias.zsh"; eval dotfiles_update'],
                    cwd=home, env=env, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                for path in paths[:2]:
                    self.assertEqual(git(repo / path, env, "rev-parse", "HEAD"), revisions[path][0])
                self.assertEqual(git(repo / "other/plugin/nested", env, "rev-parse", "HEAD"), nested_pinned)
                if profile == "server":
                    self.assertTrue(git(repo, env, "submodule", "status", "--", "prv").startswith("-"))
                else:
                    self.assertEqual(git(repo / "prv", env, "rev-parse", "HEAD"), revisions["prv"][1])
                self.assertTrue((home / "installer-ran").is_file())


if __name__ == "__main__":
    unittest.main()
