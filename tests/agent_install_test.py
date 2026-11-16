"""Install declared agent configuration in isolated homes and Git repositories."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AgentInstallTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-agents-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.repo = self.root / "repo"
        self.origin = self.root / "private-origin"
        self.home.mkdir()
        self.repo.mkdir()
        self.origin.mkdir()
        self.env = {**os.environ, "HOME": str(self.home), "ZDOTDIR": str(self.home),
                    "XDG_CONFIG_HOME": str(self.home / ".config"),
                    "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_ALLOW_PROTOCOL": "file", "DOTFILES_STOW_CONFIRM_APPLY": "1"}
        self.env.pop("DOTFILES_PROFILE", None)
        for name, content in {
            ".agents/skills/example/SKILL.md": "approved skill\n",
            ".agents/commands/git.md": "approved command\n",
            ".agents/.skill-lock.json": '{}\n',
            ".config/foot/foot.ini": "desktop only\n",
            ".config/mise/plugins/example/plugin": "private plugin\n",
            ".ssh/config.d/example": "private desktop fixture\n",
        }.items():
            self.write(self.origin / name, content)
        shutil.copy(ROOT / "prv/.stow-local-ignore", self.origin / ".stow-local-ignore")
        self.git(self.origin, "init", "-q", "--initial-branch=main")
        self.git(self.origin, "add", ".")
        self.git(self.origin, "commit", "-qm", "private fixture")
        self.git(self.repo, "init", "-q", "--initial-branch=main")
        self.git(self.repo, "submodule", "add", "-q", str(self.origin), "prv")
        self.git(self.repo, "commit", "-qm", "pin private fixture")
        self.write(self.repo / ".zsh/helpers.zsh", (ROOT / ".zsh/helpers.zsh").read_text())
        shutil.copy(ROOT / "install", self.repo / "install")
        shutil.copy(ROOT / "Makefile", self.repo / "Makefile")
        self.write(self.repo / ".codex/AGENTS.md", "approved instructions\n")
        self.write(self.repo / ".codex/agents/example.toml", 'name = "example"\n')
        self.write(self.repo / ".opencode/AGENTS.md", "opencode instructions\n")
        self.write(self.repo / ".gemini/antigravity-cli/GEMINI.md", "agy instructions\n")
        self.profile("server")

    def write(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def git(self, cwd, *args):
        result = subprocess.run(["git", "-c", "user.name=Fixture", "-c",
                                 "user.email=fixture@example.invalid", "-c", "core.hooksPath=/dev/null",
                                 "-c", "commit.gpgsign=false", *args], cwd=cwd, env=self.env,
                                text=True, capture_output=True, timeout=15, check=True)
        return result.stdout.strip()

    def profile(self, name):
        self.write(self.home / ".zshrc.d/profile.zsh", f'export DOTFILES_PROFILE="{name}"\n')

    def declare(self, clients):
        self.write(self.home / ".config/dotfiles/agents", clients)

    def run_section(self, name, **env):
        return subprocess.run(["zsh", str(self.repo / "install"), "--section", name],
                              cwd=self.home, env={**self.env, **env}, stdin=subprocess.DEVNULL,
                              text=True, capture_output=True, timeout=15)

    def test_server_codex_uses_pin_and_preserves_local_runtime_on_repeat(self):
        self.declare("codex\n")
        self.git(self.repo, "submodule", "deinit", "-f", "--", "prv")
        runtime = self.home / ".codex/config.toml"
        self.write(runtime, "local runtime fixture\n")
        for _ in range(2):
            result = self.run_section("ai")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(runtime.read_text(), "local runtime fixture\n")
            self.assertEqual((self.home / ".codex/AGENTS.md").resolve(), self.repo / ".codex/AGENTS.md")
            self.assertEqual((self.home / ".agents/skills/example/SKILL.md").resolve(),
                             self.repo / "prv/.agents/skills/example/SKILL.md")
            self.assertFalse((self.home / ".agents").is_symlink())
            self.assertFalse((self.home / ".codex").is_symlink())
            for name in (".config/foot", ".config/mise", ".ssh", ".var", ".opencode", ".gemini", ".summarize"):
                self.assertFalse((self.home / name).exists(), name)
        self.assertEqual(self.git(self.repo, "rev-parse", "HEAD:prv"),
                         self.git(self.repo / "prv", "rev-parse", "HEAD"))

    def test_skills_alone_needs_no_client_declaration_or_desktop(self):
        result = subprocess.run(["make", "-s", "-C", str(self.repo), "skills"],
                                env=self.env, stdin=subprocess.DEVNULL, text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / ".agents/skills/example/SKILL.md").is_symlink())
        self.assertFalse((self.home / ".codex").exists())
        self.assertFalse((self.home / ".var").exists())

    def test_invalid_declaration_or_missing_selection_fails_before_private_checkout(self):
        for declaration in (None, "", "codex\nunknown\n", "codex extra\n"):
            with self.subTest(declaration=declaration):
                config = self.home / ".config/dotfiles/agents"
                if declaration is not None:
                    self.declare(declaration)
                elif config.exists():
                    config.unlink()
                self.git(self.repo, "submodule", "deinit", "-f", "--", "prv")
                result = self.run_section("ai")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("agents", result.stderr.lower())
                self.assertFalse((self.repo / "prv/.git").exists())
                self.assertFalse((self.home / ".agents").exists())

    def test_confirmation_is_required_before_checkout(self):
        self.declare("codex\n")
        self.git(self.repo, "submodule", "deinit", "-f", "--", "prv")
        result = self.run_section("ai", DOTFILES_STOW_CONFIRM_APPLY="0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CONFIRM_APPLY", result.stderr)
        self.assertFalse((self.repo / "prv/.git").exists())

    def test_existing_local_instructions_are_not_adopted_or_overwritten(self):
        self.declare("codex\n")
        target = self.home / ".codex/AGENTS.md"
        self.write(target, "operator owned\n")
        result = self.run_section("ai")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("conflict", result.stderr.lower())
        self.assertEqual(target.read_text(), "operator owned\n")
        self.assertFalse(target.is_symlink())

    def test_changed_private_skill_is_not_installed_as_approved(self):
        target = self.repo / "prv/.agents/skills/example/SKILL.md"
        target.write_text("local edit\n")
        result = self.run_section("skills")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(".agents", result.stderr)
        self.assertEqual(target.read_text(), "local edit\n")
        self.assertFalse((self.home / ".agents").exists())

    def test_untracked_and_ignored_resources_are_not_installed(self):
        self.write(self.repo / "prv/.gitignore", "*.generated\n")
        for name in ("extra.md", "cache.generated"):
            with self.subTest(name=name):
                target = self.repo / "prv/.agents/skills/example" / name
                target.write_text("unapproved content\n")
                result = self.run_section("skills")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("local changes", result.stderr)
                self.assertFalse((self.home / ".agents").exists())
                target.unlink()

    def test_local_shared_commands_are_preserved_but_not_used_as_client_sources(self):
        self.declare("codex\n")
        local = self.home / ".agents/commands/local.md"
        self.write(local, "local only\n")
        result = self.run_section("ai")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(local.read_text(), "local only\n")
        self.assertFalse((self.home / ".codex/commands/local.md").exists())
        self.assertEqual((self.home / ".codex/commands/git.md").resolve(),
                         self.repo / "prv/.agents/commands/git.md")

    def test_directory_link_created_during_preparation_stops_before_stow(self):
        foreign = self.root / "foreign"
        foreign.mkdir()
        self.write(foreign / "keep", "operator owned\n")
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        mkdir = fake_bin / "mkdir"
        mkdir.write_text('#!/bin/sh\nfor arg do target="$arg"; done\n'
                         'if [ "$target" = "$HOME/.agents" ]; then\n'
                         '  /usr/bin/ln -s "$TEST_FOREIGN" "$target"\nfi\n'
                         'exec /usr/bin/mkdir "$@"\n')
        mkdir.chmod(0o755)
        result = self.run_section("skills", PATH=f'{fake_bin}:{self.env["PATH"]}', TEST_FOREIGN=str(foreign))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("real directory", result.stderr)
        self.assertEqual(list(foreign.iterdir()), [foreign / "keep"])
        self.assertEqual((foreign / "keep").read_text(), "operator owned\n")

    def test_existing_managed_desktop_directory_links_remain_usable(self):
        self.profile("desktop")
        for target, source in {
            ".agents/skills": "prv/.agents/skills",
            ".agents/commands": "prv/.agents/commands",
            ".codex/agents": ".codex/agents",
        }.items():
            path = self.home / target
            path.parent.mkdir(parents=True, exist_ok=True)
            path.symlink_to(os.path.relpath(self.repo / source, path.parent))
        for target, source in {
            ".codex/commands/git.md": ".agents/commands/git.md",
            ".opencode/commands/git.md": ".agents/commands/git.md",
            ".gemini/antigravity-cli/skills/example": ".agents/skills/example",
        }.items():
            path = self.home / target
            path.parent.mkdir(parents=True, exist_ok=True)
            path.symlink_to(os.path.relpath(self.home / source, path.parent))
        result = self.run_section("ai")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.home / ".agents/skills/example/SKILL.md").read_text(), "approved skill\n")

    def test_full_server_only_initializes_private_resources_when_declared(self):
        script = (self.repo / "install").read_text().rsplit("\nrun_installation", 1)[0]
        # Keep routing and agent installation real; isolate unrelated host setup.
        for name in ("require_zsh_login_shell", "prepare_stow_targets", "migrate_retired_managed_links",
                     "stow_base_dotfiles", "configure_git_conflict_style", "setup_vim"):
            script += f"\n{name}() {{ return 0 }}\n"
        script += '\nhas() { return 1 }\nrun_installation "$@"\n'
        (self.repo / "install").write_text(script)
        self.write(self.repo / "bin/update-shell-completions", "#!/bin/sh\nexit 0\n")
        (self.repo / "bin/update-shell-completions").chmod(0o755)
        self.git(self.repo, "submodule", "deinit", "-f", "--", "prv")
        for declaration in (None, "", "codex\n"):
            with self.subTest(declaration=declaration):
                if declaration is not None:
                    self.declare(declaration)
                result = subprocess.run(["zsh", str(self.repo / "install")], cwd=self.home,
                                        env={**self.env, "DOTFILES_PROFILE": "server"},
                                        stdin=subprocess.DEVNULL, text=True, capture_output=True, timeout=15)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.repo / "prv/.git").exists(), bool(declaration))
                self.assertEqual((self.home / ".codex/AGENTS.md").exists(), bool(declaration))
                self.assertFalse((self.home / ".config/mise").exists())
                self.assertFalse((self.home / ".config/foot").exists())

    def test_desktop_defaults_to_existing_clients_without_summarize(self):
        self.profile("desktop")
        result = self.run_section("ai")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in (".codex/AGENTS.md", ".opencode/AGENTS.md", ".gemini/antigravity-cli/GEMINI.md"):
            self.assertTrue((self.home / name).is_symlink(), name)
        self.assertFalse((self.home / ".summarize").exists())

    def test_declared_subset_overrides_desktop_default(self):
        self.profile("desktop")
        self.declare("# This machine uses Codex only.\ncodex\n")
        result = self.run_section("ai")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / ".codex/AGENTS.md").exists())
        self.assertFalse((self.home / ".opencode").exists())
        self.assertFalse((self.home / ".gemini").exists())

    def test_linked_declaration_is_refused(self):
        source = self.root / "foreign-agents"
        source.write_text("codex\n")
        target = self.home / ".config/dotfiles/agents"
        target.parent.mkdir(parents=True)
        target.symlink_to(source)
        result = self.run_section("ai")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("regular local file", result.stderr)
        self.assertFalse((self.home / ".agents").exists())


if __name__ == "__main__":
    unittest.main()
