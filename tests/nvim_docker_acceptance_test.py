"""Check Docker acceptance failure cleanup without accessing a Docker daemon."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import nvim_docker_acceptance as acceptance


class Child:
    def __init__(self, *args, **kwargs):
        self.returncode = None

    def poll(self):
        return self.returncode

    def terminate(self):
        self.returncode = -15

    def wait(self, timeout=None):
        return self.returncode


class DockerAcceptanceCleanupTest(unittest.TestCase):
    def test_editor_metadata_uses_only_the_checkout_local_bundle(self):
        with tempfile.TemporaryDirectory(prefix="local-bundle-metadata-") as directory:
            root = Path(directory)
            (root / ".bundle/gems").mkdir(parents=True)
            (root / ".dev/bin").mkdir(parents=True)
            for name in ("dockerized.sh", ".dev/bin/ruby-lsp"):
                path = root / name
                path.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
                path.chmod(0o755)
            (root / "Gemfile").touch()
            (root / "Gemfile.lock").touch()
            editor = {"network_mode": "none", "read_only": True,
                      "environment": {"BUNDLE_PATH": str(root / ".bundle/gems"), "GEM_HOME": str(root / ".bundle/gems")},
                      "volumes": [{"type": "bind", "source": str(root), "target": str(root)}]}
            result = subprocess.CompletedProcess([], 0, json.dumps({"name": "local-fixture", "services": {"editor": editor}}))
            with patch.object(acceptance, "run_command", return_value=result):
                metadata = acceptance.wrapper_metadata(root)
            self.assertEqual(metadata["bundle_cache"], root / ".bundle/gems")
            with self.subTest(configuration="foreign bundle environment"):
                editor["environment"]["BUNDLE_PATH"] = "/bundle"
                wrong = subprocess.CompletedProcess([], 0, json.dumps({"name": "local-fixture", "services": {"editor": editor}}))
                with patch.object(acceptance, "run_command", return_value=wrong):
                    with self.assertRaisesRegex(acceptance.AcceptanceError, "bundle environment"):
                        acceptance.wrapper_metadata(root)
                editor["environment"]["BUNDLE_PATH"] = str(root / ".bundle/gems")
            with self.subTest(configuration="foreign overlapping mount"):
                editor["volumes"].append({"type": "bind", "source": str(root / "elsewhere"), "target": str(root / ".bundle")})
                wrong = subprocess.CompletedProcess([], 0, json.dumps({"name": "local-fixture", "services": {"editor": editor}}))
                with patch.object(acceptance, "run_command", return_value=wrong):
                    with self.assertRaisesRegex(acceptance.AcceptanceError, "overlapping mount"):
                        acceptance.wrapper_metadata(root)
                editor["volumes"].pop()
            # A project-local spelling must not hide a global/sibling cache symlink.
            with tempfile.TemporaryDirectory(prefix="foreign-bundle-") as outside:
                (root / ".bundle/gems").rmdir()
                (root / ".bundle/gems").symlink_to(outside, target_is_directory=True)
                with patch.object(acceptance, "run_command", return_value=result):
                    with self.assertRaisesRegex(acceptance.AcceptanceError, "escapes the project"):
                        acceptance.wrapper_metadata(root)

    def test_concurrent_project_container_is_reported_without_removal(self):
        with tempfile.TemporaryDirectory(prefix="acceptance-cleanup-") as directory:
            root = Path(directory)
            ruby, r3x = (root / name for name in ("ruby", "r3x"))
            for path in (ruby, r3x / "app/lib/r3x",
                         root / "data/nvim/lazy/nvim-lspconfig", root / "data/nvim/lazy/conform.nvim"):
                path.mkdir(parents=True)
            (r3x / ".rubocop.yml").touch()
            cop = r3x / ".rubocop/cop/r3x/prefer_r3x_env.rb"
            cop.parent.mkdir(parents=True)
            cop.touch()
            args = argparse.Namespace(ruby_base=ruby, r3x=r3x, reverse=False)

            def metadata(project):
                return {"root": project, "project": project.name,
                        "ruby_version_file": project / "missing-version.rb", "bundle_cache": project / ".bundle/gems"}

            inventories = iter((set(), set(), {"concurrent-app-container"}))
            with patch.dict(os.environ, {"XDG_DATA_HOME": str(root / "data")}), \
                    patch.object(acceptance, "wrapper_metadata", side_effect=metadata), \
                    patch.object(acceptance, "project_container_ids", side_effect=lambda _: next(inventories)), \
                    patch.object(acceptance, "editor_container_ids", return_value=set()), \
                    patch.object(acceptance, "container_is_absent", return_value=False), \
                    patch.object(acceptance.shutil, "which", return_value="/usr/bin/true"), \
                    patch.object(acceptance.subprocess, "Popen", side_effect=Child), \
                    patch.object(acceptance.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run, \
                    patch.object(acceptance.time, "sleep"):
                with self.assertRaisesRegex(acceptance.AcceptanceError, "non-editor"):
                    acceptance.make_receipt(args)
                self.assertEqual(run.call_args_list, [], "the harness must not remove an unowned container")
            self.assertEqual(list(ruby.glob("nvim_acceptance_*.rb")), [])
            self.assertEqual(list((r3x / "app/lib/r3x").glob("nvim_acceptance_*.rb")), [])


if __name__ == "__main__":
    unittest.main()
