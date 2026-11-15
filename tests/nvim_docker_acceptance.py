#!/usr/bin/env python3
"""Run the optional Docker-backed Ruby LSP acceptance against prepared copies."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
LUA_SCRIPT = Path(__file__).with_name("nvim_docker_acceptance.lua")
EDITOR_SERVICE = "editor"
BLOCKED_TOOLS = ("ruby", "bundle", "gem", "ruby-lsp", "rubocop", "mise")
RESULT_PREFIX = "MCA118_RESULT:"


class AcceptanceError(RuntimeError):
    pass


def under(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def in_system_temp(path: Path, label: str) -> Path:
    try:
        resolved = path.expanduser().resolve(strict=True)
        temp_root = Path(tempfile.gettempdir()).resolve(strict=True)
    except OSError as error:
        raise AcceptanceError(f"{label} must be an existing path: {path}") from error
    if not under(resolved, temp_root):
        raise AcceptanceError(f"{label} must be within the system temporary directory")
    return resolved


def safe_env(*, sentinel: str | None = None) -> dict[str, str]:
    allowed = {
        "PATH",
        "HOME",
        "DOCKER_CONFIG",
        "DOCKER_CONTEXT",
        "DOCKER_HOST",
        "DOCKER_TLS_VERIFY",
        "DOCKER_CERT_PATH",
        "XDG_RUNTIME_DIR",
        "SSH_AUTH_SOCK",
    }
    env = {key: value for key, value in os.environ.items() if key in allowed}
    env["PATH"] = os.environ.get("PATH", "/usr/bin:/bin")
    env["HOME"] = str(Path.home())
    if sentinel is not None:
        env["MCA118_ENV_SECRET"] = sentinel
    return env


def run_command(
    argv: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    timeout: int = 30,
    label: str,
) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(
            argv,
            cwd=cwd,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise AcceptanceError(f"{label} could not complete") from error
    if result.returncode != 0:
        raise AcceptanceError(f"{label} failed (exit {result.returncode})")
    return result


def wrapper_metadata(root: Path) -> dict[str, Any]:
    wrapper = root / "dockerized.sh"
    if not wrapper.is_file() or not os.access(wrapper, os.X_OK):
        raise AcceptanceError(f"prepared root lacks executable dockerized.sh: {root}")
    if not (root / "Gemfile").is_file() or not (root / "Gemfile.lock").is_file():
        raise AcceptanceError(f"prepared root needs Gemfile and Gemfile.lock: {root}")
    if not os.access(root / ".dev" / "bin" / "ruby-lsp", os.X_OK):
        raise AcceptanceError(f"prepared root lacks the executable project ruby-lsp wrapper: {root}")

    result = run_command(
        [str(wrapper), "compose", "--profile", "editor", "config", "--no-env-resolution", "--format", "json"],
        cwd=root,
        env=safe_env(),
        label=f"{root.name} read-only Compose metadata",
    )
    try:
        config = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise AcceptanceError(f"{root.name} wrapper returned invalid Compose metadata") from error
    if not isinstance(config, dict):
        raise AcceptanceError(f"{root.name} wrapper returned invalid Compose metadata")

    project = config.get("name")
    services = config.get("services")
    editor = services.get(EDITOR_SERVICE) if isinstance(services, dict) else None
    if not isinstance(project, str) or not project or not isinstance(editor, dict):
        raise AcceptanceError(f"{root.name} Compose metadata lacks project/editor identity")
    if editor.get("network_mode") != "none" or editor.get("read_only") is not True:
        raise AcceptanceError(f"{root.name} editor service must use network_mode none and read_only")
    if editor.get("build"):
        raise AcceptanceError(f"{root.name} editor service must not have a build definition")
    if editor.get("ports"):
        raise AcceptanceError(f"{root.name} editor service must not publish ports")
    if editor.get("env_file"):
        raise AcceptanceError(f"{root.name} editor service must not declare env_file")

    expected_cache = root / ".bundle" / "gems"
    if not expected_cache.is_dir():
        raise AcceptanceError(f"prepared bundle cache is missing for {root.name}")
    expected_cache = expected_cache.resolve(strict=True)
    if not under(expected_cache, root):
        raise AcceptanceError(f"prepared bundle cache escapes the project directory for {root.name}")
    environment = editor.get("environment") or {}
    if any(environment.get(key) != str(expected_cache) for key in ("BUNDLE_PATH", "GEM_HOME")):
        raise AcceptanceError(f"{root.name} bundle environment does not use the checkout-local gems")
    for volume in editor.get("volumes", []):
        target = Path(volume.get("target", "/"))
        if under(target, root) and under(expected_cache, target):
            if volume.get("type") != "bind" or Path(volume.get("source", "")).resolve() != target:
                raise AcceptanceError(f"{root.name} has an overlapping mount hiding checkout-local gems")
    bind_pairs = {
        (Path(volume["source"]).resolve(), Path(volume["target"]))
        for volume in editor.get("volumes", [])
        if isinstance(volume, dict)
        and volume.get("type") == "bind"
        and volume.get("source")
        and volume.get("target")
    }
    if (root, root) not in bind_pairs:
        raise AcceptanceError(f"{root.name} Compose binds do not preserve the prepared project path")

    lock = root / "Gemfile.lock"
    composed_gemfile = root / ".ruby-lsp" / "Gemfile"
    if composed_gemfile.exists() or composed_gemfile.is_symlink():
        raise AcceptanceError(f"refusing a root with an existing .ruby-lsp/Gemfile: {root}")
    return {
        "root": root,
        "project": project,
        "lock": lock,
        "lock_sha256": hashlib.sha256(lock.read_bytes()).hexdigest(),
        "lock_mtime_ns": lock.stat().st_mtime_ns,
        "composed_gemfile": composed_gemfile,
        "ruby_version_file": root / "lib" / "base_projects" / "version.rb",
        "bundle_cache": expected_cache,
    }


def docker_json(argv: list[str], *, label: str) -> Any:
    result = run_command(argv, label=label)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise AcceptanceError(f"{label} returned invalid JSON") from error


def project_container_ids(project: str) -> set[str]:
    result = run_command(
        ["docker", "ps", "-aq", "--filter", f"label=com.docker.compose.project={project}"],
        label="Docker container inventory",
    )
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def editor_container_ids(project: str) -> set[str]:
    result = run_command(
        [
            "docker",
            "ps",
            "-aq",
            "--filter",
            f"label=com.docker.compose.project={project}",
            "--filter",
            f"label=com.docker.compose.service={EDITOR_SERVICE}",
        ],
        label="Docker editor-container inventory",
    )
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def container_is_absent(container_id: str) -> bool:
    result = subprocess.run(
        ["docker", "inspect", container_id],
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        timeout=5,
        check=False,
    )
    if result.returncode == 0:
        return False
    if "No such object" in result.stderr or "No such container" in result.stderr:
        return True
    raise AcceptanceError("Docker inspect failed while checking container cleanup")


def stop_child(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        process.wait()
        return
    try:
        process.terminate()
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        try:
            process.kill()
        except ProcessLookupError:
            pass
        process.wait(timeout=10)


def inspect_container(container_id: str) -> dict[str, Any]:
    value = docker_json(["docker", "inspect", container_id], label="Docker container inspection")
    if not isinstance(value, list) or len(value) != 1 or not isinstance(value[0], dict):
        raise AcceptanceError("Docker returned unexpected container metadata")
    return value[0]


def verify_container(container_id: str, metadata: dict[str, Any], marker_name: str) -> dict[str, Any]:
    info = inspect_container(container_id)
    labels = info.get("Config", {}).get("Labels") or {}
    host = info.get("HostConfig") or {}
    config = info.get("Config") or {}
    mounts = info.get("Mounts") or []
    if labels.get("com.docker.compose.project") != metadata["project"]:
        raise AcceptanceError("observed editor container has the wrong Compose project label")
    if labels.get("com.docker.compose.service") != EDITOR_SERVICE:
        raise AcceptanceError("a non-editor container started during the acceptance")
    if host.get("NetworkMode") != "none" or host.get("ReadonlyRootfs") is not True:
        raise AcceptanceError("editor container is not network-isolated and read-only")
    if host.get("PortBindings"):
        raise AcceptanceError("editor container has published ports")
    if any(mount.get("Type") == "bind" and mount.get("Source") != mount.get("Destination") for mount in mounts):
        raise AcceptanceError("editor container has a bind mount that changes the source path")
    env_names = {entry.partition("=")[0] for entry in config.get("Env") or []}
    if marker_name in env_names:
        raise AcceptanceError("host credential-marker variable reached the editor container")
    version = run_command(
        ["docker", "exec", container_id, "ruby", "--version"],
        label="container Ruby version query",
    ).stdout.strip()
    if not version.startswith("ruby "):
        raise AcceptanceError("editor container did not report a Ruby version")
    return {
        "container_id": container_id[:12],
        "ruby_version": version,
        "network_mode": host.get("NetworkMode"),
        "read_only_rootfs": host.get("ReadonlyRootfs"),
        "published_ports": False,
        "env_file": False,
        "credential_marker_present": False,
    }


def install_host_tool_blocks(directory: Path, marker_file: Path) -> None:
    marker = str(marker_file)
    for name in BLOCKED_TOOLS:
        executable = directory / name
        executable.write_text(
            "#!/bin/sh\n"
            f"printf '%s\\n' {shlex.quote(name)} >> {shlex.quote(marker)}\n"
            f"echo 'blocked host executable: {name}' >&2\n"
            "exit 97\n",
            encoding="utf-8",
        )
        executable.chmod(0o755)

def fixture_file(root: Path, relative: Path, source: str) -> Path:
    target = root / relative
    parent = target.parent
    try:
        resolved_parent = parent.resolve(strict=True)
    except OSError as error:
        raise AcceptanceError(f"fixture directory is missing in prepared root: {parent}") from error
    if not under(resolved_parent, root):
        raise AcceptanceError(f"fixture path escapes prepared root: {target}")
    if target.exists() or target.is_symlink():
        raise AcceptanceError(f"fixture path already exists; refusing to overwrite: {target.name}")
    try:
        with target.open("x", encoding="utf-8", newline="\n") as stream:
            stream.write(source)
    except FileExistsError as error:
        raise AcceptanceError(f"fixture path appeared before creation: {target.name}") from error
    except Exception:
        with contextlib.suppress(FileNotFoundError):
            target.unlink()
        raise
    return target


def make_receipt(args: argparse.Namespace) -> dict[str, Any]:
    temp_root = Path(tempfile.gettempdir()).resolve(strict=True)
    roots = {
        "ruby_base": in_system_temp(args.ruby_base, "--ruby-base"),
        "r3x": in_system_temp(args.r3x, "--r3x"),
    }
    for name, root in roots.items():
        if not root.is_dir():
            raise AcceptanceError(f"--{name.replace('_', '-')} must be a directory")
    if roots["ruby_base"] == roots["r3x"]:
        raise AcceptanceError("RubyBase and R3X must be separate prepared copies")
    if not (roots["r3x"] / "app" / "lib" / "r3x").is_dir():
        raise AcceptanceError("R3X copy lacks app/lib/r3x for the real custom-cop fixture")
    if not (roots["r3x"] / ".rubocop.yml").is_file():
        raise AcceptanceError("R3X copy lacks its RuboCop configuration")
    if not (roots["r3x"] / ".rubocop" / "cop" / "r3x" / "prefer_r3x_env.rb").is_file():
        raise AcceptanceError("R3X copy lacks its PreferR3xEnv custom cop")

    metadata = {
        name: wrapper_metadata(root)
        for name, root in roots.items()
    }
    baseline_ids = {}
    for name, item in metadata.items():
        ids = project_container_ids(item["project"])
        if editor_container_ids(item["project"]):
            raise AcceptanceError(f"preexisting editor containers found for {name}; refusing shared cleanup")
        baseline_ids[name] = ids

    nvim_path = shutil.which("nvim")
    if not nvim_path:
        raise AcceptanceError("Neovim is not available on PATH")
    nvim = str(Path(nvim_path).resolve(strict=True))
    host_data = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share")))
    try:
        lazy_root = host_data.expanduser().resolve(strict=True) / "nvim" / "lazy"
    except OSError as error:
        raise AcceptanceError("installed Neovim data directory is missing") from error
    for plugin in ("nvim-lspconfig", "conform.nvim"):
        if not (lazy_root / plugin).is_dir():
            raise AcceptanceError(f"installed Neovim plugin is missing: {plugin}")
    if not LUA_SCRIPT.is_file():
        raise AcceptanceError(f"Neovim acceptance Lua file is missing: {LUA_SCRIPT.name}")

    observed_ids: set[str] = set()
    proof: dict[str, dict[str, Any]] = {}
    proof_ids = {name: set() for name in metadata}
    lua_result: dict[str, Any] | None = None
    failed = True
    process: subprocess.Popen[bytes] | None = None
    fixture_paths: list[Path] = []

    try:
        token = secrets.token_hex(8)
        ruby_source = 'require "zeitwerk"\nZeitwerk::Loader.new\n'
        if metadata["ruby_base"]["ruby_version_file"].is_file():
            ruby_source += "BaseProjects::VERSION\n"
        ruby_fixture = fixture_file(
            roots["ruby_base"],
            Path(f"nvim_acceptance_{token}.rb"),
            ruby_source,
        )
        fixture_paths.append(ruby_fixture)
        r3x_fixture = fixture_file(
            roots["r3x"],
            Path("app/lib/r3x") / f"nvim_acceptance_{token}.rb",
            'module R3x\n  module NvimAcceptance\n    value = 1\n      other = ENV.fetch("R3X_DRY_RUN")\n  end\nend\n',
        )
        fixture_paths.append(r3x_fixture)
        marker_value = secrets.token_urlsafe(24)
        marker_name = "MCA118_ENV_SECRET"
        with tempfile.TemporaryDirectory(prefix="nvim-docker-acceptance-") as scratch_name:
            scratch = Path(scratch_name)
            blocked = scratch / "no-host-ruby"
            blocked.mkdir()
            blocked_marker = scratch / "forbidden-host-tools"
            install_host_tool_blocks(blocked, blocked_marker)
            nvim_env = safe_env(sentinel=marker_value)
            nvim_env.update(
                {
                    "DOTFILES_PROFILE": "desktop",
                    "XDG_CONFIG_HOME": str(scratch / "config"),
                    "XDG_DATA_HOME": str(scratch / "data"),
                    "XDG_STATE_HOME": str(scratch / "state"),
                    "PATH": f"{blocked}{os.pathsep}{nvim_env['PATH']}",
                    "MCA118_CONFIG_LUA": str(REPO_ROOT / ".config" / "nvim" / "lua"),
                    "MCA118_LAZY_ROOT": str(lazy_root),
                    "MCA118_RUBY_BASE": str(roots["ruby_base"]),
                    "MCA118_R3X": str(roots["r3x"]),
                    "MCA118_RUBY_BASE_FIXTURE": str(ruby_fixture),
                    "MCA118_R3X_FIXTURE": str(r3x_fixture),
                    "MCA118_RUBY_BASE_BUNDLE": str(metadata["ruby_base"]["bundle_cache"]),
                    "MCA118_ORDER": "r3x,ruby_base" if args.reverse else "ruby_base,r3x",
                    "MCA118_BASE_VERSION_AVAILABLE": "1"
                    if metadata["ruby_base"]["ruby_version_file"].is_file()
                    else "0",
                }
            )
            for key in ("BUNDLE_GEMFILE", "GEM_HOME", "GEM_PATH", "RUBYOPT", "RUBYLIB"):
                nvim_env.pop(key, None)

            with tempfile.TemporaryFile(mode="w+b") as nvim_log:
                process = subprocess.Popen(
                    [nvim, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(LUA_SCRIPT)],
                    cwd=temp_root,
                    env=nvim_env,
                    stdout=nvim_log,
                    stderr=subprocess.STDOUT,
                )
                deadline = time.monotonic() + 360
                while process.poll() is None:
                    for name, item in metadata.items():
                        current = project_container_ids(item["project"])
                        newly_seen = current - baseline_ids[name] - proof_ids[name]
                        observed_ids.update(newly_seen)
                        running_editors = editor_container_ids(item["project"])
                        for container_id in newly_seen:
                            if container_id not in running_editors:
                                if process.poll() is not None and container_is_absent(container_id):
                                    continue
                                raise AcceptanceError("acceptance started a non-editor project container")
                            if process.poll() is not None and container_is_absent(container_id):
                                continue
                            proof[name] = verify_container(container_id, item, marker_name)
                            proof_ids[name].add(container_id)
                    if process.poll() is not None:
                        break
                    if time.monotonic() >= deadline:
                        process.terminate()
                        try:
                            process.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait(timeout=10)
                        raise AcceptanceError("Neovim Docker acceptance timed out")
                    time.sleep(0.2)
                return_code = process.wait()
                nvim_log.seek(0)
                log_text = nvim_log.read().decode("utf-8", errors="replace")
            for line in log_text.splitlines():
                if line.startswith(RESULT_PREFIX):
                    try:
                        lua_result = json.loads(line[len(RESULT_PREFIX):])
                    except json.JSONDecodeError:
                        raise AcceptanceError("Neovim emitted an invalid acceptance receipt")
            if blocked_marker.exists():
                raise AcceptanceError("a host Ruby-related executable was invoked")
            if return_code != 0 or not isinstance(lua_result, dict) or lua_result.get("ok") is not True:
                detail = lua_result.get("error") if isinstance(lua_result, dict) else None
                if detail:
                    reason = str(detail).strip().replace(marker_value, "[redacted]")[:1000]
                else:
                    reason = log_text[-1000:].replace(marker_value, "[redacted]").strip()
                    if not reason:
                        reason = f"Neovim exited with status {return_code}"
                raise AcceptanceError(f"Neovim acceptance failed: {reason}")
            if set(proof) != set(metadata):
                raise AcceptanceError("container runtime proof is incomplete for both roots")
            if any(len(ids) != 1 for ids in proof_ids.values()):
                raise AcceptanceError("expected exactly one observed editor container per root")

        for name, item in metadata.items():
            if hashlib.sha256(item["lock"].read_bytes()).hexdigest() != item["lock_sha256"]:
                raise AcceptanceError(f"Gemfile.lock contents changed for {name}")
            if item["lock"].stat().st_mtime_ns != item["lock_mtime_ns"]:
                raise AcceptanceError(f"Gemfile.lock mtime changed for {name}")
            if item["composed_gemfile"].exists() or item["composed_gemfile"].is_symlink():
                raise AcceptanceError(f".ruby-lsp/Gemfile appeared for {name}")
        for _ in range(30):
            leftovers = {
                name: project_container_ids(item["project"]) - baseline_ids[name]
                for name, item in metadata.items()
            }
            if not any(leftovers.values()):
                break
            time.sleep(0.2)
        if any(leftovers.values()):
            raise AcceptanceError("new editor containers remained after ordinary Neovim shutdown")
        failed = False
        return {
            "ok": True,
            "acceptance": "docker_ruby_nvim",
            "roots": {name: str(item["root"]) for name, item in metadata.items()},
            "bundle_directories": {name: str(item["bundle_cache"]) for name, item in metadata.items()},
            "order": "r3x,ruby_base" if args.reverse else "ruby_base,r3x",
            "checks": lua_result["checks"],
            "clients": lua_result["clients"],
            "containers": proof,
            "lockfiles_unchanged": True,
            "ruby_lsp_gemfile_absent": True,
            "host_ruby_tools_invoked": False,
            "new_containers_left_after_shutdown": False,
            "shutdown": lua_result["shutdown"],
            "fixtures": {
                "ruby_base": ruby_fixture.name,
                "r3x": str(r3x_fixture.relative_to(roots["r3x"])),
                "removed": True,
            },
        }
    finally:
        cleanup_errors = []
        child_stopped = process is None
        if process is not None:
            try:
                stop_child(process)
                child_stopped = process.poll() is not None
                if not child_stopped:
                    cleanup_errors.append("Neovim child remained active")
            except Exception:
                child_stopped = process.poll() is not None
                cleanup_errors.append("could not stop and wait for Neovim child")
        if failed and observed_ids:
            # Discovery does not establish ownership: never delete observed containers.
            for container_id in sorted(observed_ids):
                try:
                    if not container_is_absent(container_id):
                        cleanup_errors.append(f"observed container {container_id[:12]} remains; inspect before manual cleanup")
                except Exception:
                    cleanup_errors.append(f"could not check observed container {container_id[:12]}; inspect manually")
        for path in fixture_paths:
            try:
                path.unlink()
            except FileNotFoundError:
                pass
            except OSError:
                cleanup_errors.append(f"could not remove fixture {path.name}")
        if cleanup_errors:
            active_error = sys.exc_info()[1]
            if active_error is None:
                raise AcceptanceError("; ".join(cleanup_errors))
            active_error.cleanup_errors = cleanup_errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ruby-base", required=True, type=Path, metavar="PATH")
    parser.add_argument("--r3x", required=True, type=Path, metavar="PATH")
    parser.add_argument("--reverse", action="store_true", help="open R3X before RubyBase")
    parser.add_argument("--output", type=Path, metavar="JSON", help="also write the JSON receipt to this path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    requested_output = args.output
    args.output = None
    try:
        if requested_output is not None:
            output_paths = {
                Path(os.path.abspath(requested_output.expanduser())),
                requested_output.expanduser().resolve(),
            }
            protected_paths = set()
            for path in (args.ruby_base, args.r3x):
                expanded = path.expanduser()
                protected_paths.add(Path(os.path.abspath(expanded)))
                protected_paths.add(expanded.resolve(strict=True))
            if any(under(output, protected) for output in output_paths for protected in protected_paths):
                raise AcceptanceError("--output must be outside the prepared roots and bundle cache")
            args.output = requested_output.expanduser().resolve()
        receipt = make_receipt(args)
        status = 0
    except Exception as error:
        message = str(error) or type(error).__name__
        cleanup_errors = getattr(error, "cleanup_errors", [])
        if cleanup_errors:
            message += "; cleanup: " + "; ".join(cleanup_errors)
        receipt = {
            "ok": False,
            "acceptance": "docker_ruby_nvim",
            "error": message,
        }
        status = 1
    output = json.dumps(receipt, indent=2, sort_keys=True)
    if args.output is not None:
        try:
            args.output.expanduser().write_text(output + "\n", encoding="utf-8")
        except OSError:
            receipt = {
                "ok": False,
                "acceptance": "docker_ruby_nvim",
                "error": "could not write the requested JSON receipt",
            }
            output = json.dumps(receipt, indent=2, sort_keys=True)
            status = 1
    print(output)
    return status


if __name__ == "__main__":
    sys.exit(main())
