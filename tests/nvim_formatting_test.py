"""Exercise shared Neovim formatting with Conform and controlled subprocesses.

The regular suite uses fixture executables and never starts Lazy or Mason. An
optional real dprint YAML check can be enabled with local paths:

    DOTFILES_TEST_DPRINT=/path/to/dprint \
    DOTFILES_TEST_DPRINT_PLUGIN=/path/to/pretty_yaml.wasm \
      python3 tests/nvim_formatting_test.py

No test downloads or installs tools.
"""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
LAZY = Path.home() / ".local/share/nvim/lazy"
CONFORM = LAZY / "conform.nvim"
MASON_BIN = LAZY.parent / "mason/bin"
MASON_GOFUMPT = MASON_BIN / "gofumpt"
MASON_GOIMPORTS = MASON_BIN / "goimports"
REAL_DPRINT = os.environ.get("DOTFILES_TEST_DPRINT")
REAL_DPRINT_PLUGIN = os.environ.get("DOTFILES_TEST_DPRINT_PLUGIN")
REAL_OXFMT = os.environ.get("DOTFILES_TEST_OXFMT")

FIXTURE = r'''#!{python}
import json
import os
from pathlib import Path
import sys
import time

program = str(Path(sys.argv[0]))
name = Path(program).name
args = sys.argv[1:]
log = os.environ.get("FMT_TEST_LOG")
entry = {
    "program": program,
    "name": name,
    "args": args,
    "cwd": os.getcwd(),
    "mise_dprint_version": os.environ.get("MISE_DPRINT_VERSION"),
    "sentinel": os.environ.get("FMT_TEST_SENTINEL"),
}
if log:
    with open(log, "a", encoding="utf-8") as stream:
        stream.write(json.dumps(entry) + "\n")

if name == "mise":
    if "ls" in args:
        fail_root = os.environ.get("FMT_TEST_MISE_FAIL_ROOT")
        if fail_root and fail_root in args:
            print("fixture mise failure", file=sys.stderr)
            raise SystemExit(9)
        multi_root = os.environ.get("FMT_TEST_MISE_MULTI_ROOT")
        if multi_root and multi_root in args:
            print(os.environ.get("FMT_TEST_MISE_MULTI_JSON", "[]"))
            raise SystemExit(0)
        print(os.environ.get("FMT_TEST_MISE_JSON", "[]"))
        raise SystemExit(0)
    if "which" in args:
        binary = args[args.index("which") + 1]
        binaries = json.loads(os.environ.get("FMT_TEST_MISE_BINARIES", "{}"))
        path = binaries.get(binary)
        if not path:
            print("fixture mise has no configured binary: " + binary, file=sys.stderr)
            raise SystemExit(9)
        print(path)
        raise SystemExit(0)
    raise SystemExit(2)

if "dprint" in name:
    old_path = os.environ.get("FMT_TEST_OLD_DPRINT_PATH")
    version = "0.63.9" if program == old_path else "0.64.3"
    if args == ["--version"]:
        print("dprint " + version)
        raise SystemExit(0)
    if args and args[0] == "resolved-config":
        config = Path(args[args.index("--config") + 1])
        content = config.read_text(encoding="utf-8")
        if "SLEEP_QUERY" in content:
            time.sleep(4)
        if "QUERY_ERROR" in content:
            print("fixture query failure", file=sys.stderr)
            raise SystemExit(7)
        if "MALFORMED" in content:
            print("{broken")
        else:
            print('{"plugins":["fixture"]}')
        raise SystemExit(0)
    if args and args[0] == "fmt":
        config = Path(args[args.index("--config") + 1]) if "--config" in args else None
        content = config.read_text(encoding="utf-8") if config else ""
        filename = args[args.index("--stdin") + 1] if "--stdin" in args else ""
        source = sys.stdin.read()
        if "FORMAT_ERROR" in content:
            print("fixture formatter failure", file=sys.stderr)
            raise SystemExit(8)
        if "EXCLUDE_YAML" in content and filename.endswith((".yaml", ".yml")):
            sys.stdout.write(source)
        else:
            sys.stdout.write("formatted:" + name + ":" + source)
        raise SystemExit(0)
    raise SystemExit(2)

source = sys.stdin.read()
if name == "oxfmt" and args:
    if "--stdin-filepath" in args:
        sys.stdout.write("formatted:oxfmt:" + source)
        raise SystemExit(0)
    filename = Path(args[-1])
    source = filename.read_text(encoding="utf-8")
    filename.write_text("formatted:oxfmt:" + source, encoding="utf-8")
    raise SystemExit(0)
sys.stdout.write("formatted:" + name + ":" + source)
'''

LUA_SETUP = r'''
local function setup_conform()
  local spec = require('plugins.conform')
  local conform = require('conform')
  spec.config({ name = 'conform.nvim' }, spec.opts)
  return require('config.formatting'), spec, conform
end

local function make_buffer(path, filetype, text)
  if path then
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
  end
  local bufnr = vim.api.nvim_create_buf(true, false)
  if path then
    vim.api.nvim_buf_set_name(bufnr, path)
  end
  vim.bo[bufnr].filetype = filetype
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { text })
  return bufnr
end

local function buffer_text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end
'''


@unittest.skipUnless(NVIM, "Neovim is not installed")
class NeovimFormattingTest(unittest.TestCase):
    MISE_BINARIES = (
        "dprint", "gofumpt", "goimports", "oxfmt", "ruff", "shfmt",
        "stylua", "taplo", "yamlfmt",
    )

    @classmethod
    def setUpClass(cls):
        output = subprocess.check_output([NVIM, "--version"], text=True, timeout=5)
        version = re.match(r"NVIM v(\d+)\.(\d+)", output)
        if version is None:
            raise RuntimeError("Cannot determine Neovim version")
        if tuple(map(int, version.groups())) < (0, 11):
            raise unittest.SkipTest("Neovim 0.11 or newer is required")
        if not CONFORM.is_dir():
            raise unittest.SkipTest("installed conform.nvim source is required")

    @staticmethod
    def write_fixture(path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(FIXTURE.replace("{python}", sys.executable), encoding="utf-8")
        path.chmod(0o755)

    @classmethod
    def install_local_binary(cls, root, *, name="dprint"):
        target = root / "node_modules/.bin" / name
        cls.write_fixture(target)
        return target

    def run_nvim(self, code, *, profile="desktop", extra_env=None, prepare=None, timeout=15):
        with tempfile.TemporaryDirectory(prefix="dotfiles-formatting-") as directory:
            temp = Path(directory)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            self.write_fixture(bin_dir / "mise")
            tool_dir = temp / "mise-tools"
            binaries = {}
            for name in self.MISE_BINARIES:
                binary = tool_dir / name
                self.write_fixture(binary)
                binaries[name] = str(binary)
            log_path = temp / "calls.jsonl"
            env = {
                "HOME": str(temp),
                "PATH": str(bin_dir),
                "DOTFILES_PROFILE": profile,
                "FMT_TEST_LOG": str(log_path),
                "FMT_TEST_MISE_JSON": "[]",
                "FMT_TEST_MISE_BINARIES": json.dumps(binaries),
                "XDG_CONFIG_HOME": str(temp / "xdg_config_home"),
                "XDG_DATA_HOME": str(temp / "xdg_data_home"),
                "XDG_STATE_HOME": str(temp / "xdg_state_home"),
                "XDG_CACHE_HOME": str(temp / "xdg_cache_home"),
            }
            if prepare:
                env.update(prepare(temp, bin_dir, tool_dir))
            if extra_env:
                env.update(extra_env)

            script = temp / "test.lua"
            script.write_text(
                "package.path = " + json.dumps(str(ROOT / ".config/nvim/lua/?.lua") + ";")
                + " .. package.path\n"
                + "vim.opt.rtp:append(" + json.dumps(str(CONFORM)) + ")\n"
                + LUA_SETUP + "\n" + code,
                encoding="utf-8",
            )
            result = subprocess.run(
                [NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(script)],
                env=env, capture_output=True, text=True, timeout=timeout,
            )
            calls = []
            if log_path.exists():
                calls = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(
                result.returncode, 0,
                result.stdout + result.stderr + "\nFixture calls:\n" + json.dumps(calls, indent=2),
            )
            return calls

    @staticmethod
    def calls_named(calls, name):
        return [call for call in calls if call["name"] == name]

    @classmethod
    def mise_which_calls(cls, calls, binary):
        return [
            call for call in cls.calls_named(calls, "mise")
            if "which" in call["args"]
            and call["args"][call["args"].index("which") + 1] == binary
        ]

    @staticmethod
    def dprint_calls(calls, first_arg):
        return [
            call for call in calls
            if "dprint" in call["name"] and call["args"][:1] == [first_arg]
        ]

    def test_project_routing_uses_buffer_roots_and_clears_only_mise_override(self):
        def prepare(temp, _bin_dir, _tools):
            root_a = temp / "project-a"
            root_b = temp / "project-b"
            root_a.mkdir(parents=True)
            (root_a / "dprint.json").write_text('{"plugins":["fixture"]}', encoding="utf-8")
            (root_b / ".config").mkdir(parents=True)
            (root_b / ".config/dprint.jsonc").write_text('{"plugins":["fixture"]}', encoding="utf-8")
            self.install_local_binary(root_a)
            return {
                "FMT_PROJECT_A": str(root_a),
                "FMT_PROJECT_B": str(root_b),
                "FMT_TEST_MISE_JSON": '[{"tool":"dprint","version":"0.64.3","installed":true}]',
            }

        calls = self.run_nvim(r'''
local formatting, spec = setup_conform()
local root_a, root_b = vim.env.FMT_PROJECT_A, vim.env.FMT_PROJECT_B
local a = make_buffer(root_a .. '/src/a.js', 'javascript', 'before')
local b = make_buffer(root_b .. '/src/b.ts', 'typescript', 'before')
vim.api.nvim_set_current_buf(b)
assert(spec.opts.format_on_save(a) == nil, 'save callback must not dispatch Conform twice')
assert(vim.api.nvim_get_current_buf() == b, 'formatting a non-current buffer changed the current buffer')
assert(buffer_text(a):match('^formatted:dprint:'))
local plan = formatting.format(b, 'manual')
assert(plan and plan.kind == 'project')
assert(buffer_text(b):match('^formatted:dprint:'))

vim.g.mapleader = ' '
require('config.keymaps')
local format_map = vim.fn.maparg(' cf', 'n', false, true)
assert(type(format_map.callback) == 'function', 'manual format mapping is missing')
format_map.callback()
assert(buffer_text(b):match('^formatted:dprint:'))
''', prepare=prepare, extra_env={
            "MISE_DPRINT_VERSION": "inherited-parent-override",
            "FMT_TEST_SENTINEL": "preserved-value",
        })

        self.assertEqual(len(self.dprint_calls(calls, "fmt")), 3)
        project_calls = self.dprint_calls(calls, "fmt")
        local_invocations = [call for call in project_calls if call["program"].endswith("project-a/node_modules/.bin/dprint")]
        managed_invocations = [call for call in project_calls if call["program"].endswith("mise-tools/dprint")]
        self.assertEqual(len(local_invocations), 1)
        self.assertEqual(len(managed_invocations), 2)
        mise_calls = self.calls_named(calls, "mise")
        self.assertTrue(any("ls" in call["args"] for call in mise_calls))
        self.assertTrue(any("which" in call["args"] for call in mise_calls))
        self.assertTrue(all(call["mise_dprint_version"] is None for call in mise_calls))
        self.assertTrue(all(call["sentinel"] == "preserved-value" for call in mise_calls))
        self.assertTrue(all(call["mise_dprint_version"] == "inherited-parent-override" for call in local_invocations + managed_invocations))
        self.assertTrue(all(call["sentinel"] == "preserved-value" for call in local_invocations + managed_invocations))

    def test_routed_types_and_all_supported_dprint_config_locations(self):
        types = [
            ("yaml", "data.yaml"), ("yaml.tmuxinator", "tmux.yaml"),
            ("yaml.docker-compose", "compose.yaml"),
            ("javascript", "script.js"), ("javascriptreact", "view.jsx"),
            ("typescript", "typed.ts"), ("typescriptreact", "component.tsx"),
            ("json", "data.json"), ("jsonc", "data.jsonc"), ("json5", "data.json5"),
            ("css", "style.css"), ("graphql", "query.graphql"), ("markdown", "notes.md"),
        ]
        config_names = [
            "dprint.json", "dprint.jsonc", ".dprint.json", ".dprint.jsonc",
            ".config/dprint.json", ".config/dprint.jsonc",
        ]

        expected_configs = []

        def prepare(temp, _bin_dir, _mason):
            cases = []
            type_root = temp / "all-types"
            type_root.mkdir(parents=True)
            (type_root / "dprint.json").write_text('{"plugins":["fixture"]}', encoding="utf-8")
            self.install_local_binary(type_root)
            expected_configs.append(str(type_root / "dprint.json"))
            for index, (filetype, filename) in enumerate(types):
                cases.append({"path": str(type_root / f"{index}-{filename}"), "filetype": filetype})
            configs = []
            for index, config_name in enumerate(config_names):
                root = temp / f"config-{index}"
                config = root / config_name
                config.parent.mkdir(parents=True, exist_ok=True)
                config.write_text('{"plugins":["fixture"]}', encoding="utf-8")
                self.install_local_binary(root)
                configs.append({"path": str(root / f"candidate-{index}.js"), "config": str(config)})
                expected_configs.append(str(config))
            return {
                "FMT_TYPE_CASES": json.dumps(cases),
                "FMT_CONFIG_CASES": json.dumps(configs),
            }

        calls = self.run_nvim(r'''
local formatting = setup_conform()
for _, case in ipairs(vim.json.decode(vim.env.FMT_TYPE_CASES)) do
  local buf = make_buffer(case.path, case.filetype, 'before')
  local plan = formatting.format(buf, 'manual')
  assert(plan and plan.kind == 'project', case.filetype .. ': expected project dprint')
  assert(buffer_text(buf):match('^formatted:dprint:'), case.filetype .. ': wrong formatter output')
end
for _, case in ipairs(vim.json.decode(vim.env.FMT_CONFIG_CASES)) do
  local buf = make_buffer(case.path, 'javascript', 'before')
  local plan = formatting.format(buf, 'manual')
  assert(plan and plan.kind == 'project', case.config .. ': expected project plan')
  assert(plan.config == case.config, case.config .. ': selected a different config')
end
''', prepare=prepare)

        fmt = self.dprint_calls(calls, "fmt")
        self.assertEqual(len(fmt), len(types) + len(config_names))
        resolved = self.dprint_calls(calls, "resolved-config")
        self.assertEqual(len(resolved), len(fmt))
        resolved_configs = {
            call["args"][call["args"].index("--config") + 1] for call in resolved
        }
        self.assertEqual(resolved_configs, set(expected_configs))
        for call in fmt:
            self.assertIn(call["args"][call["args"].index("--config") + 1], expected_configs)

    def test_defaults_markdown_and_explicit_exclusions(self):
        def prepare(temp, _bin_dir, _mason):
            root = temp / "default-project"
            excluded = temp / "excluded-project"
            (excluded / "dprint.json").parent.mkdir(parents=True)
            (excluded / "dprint.json").write_text("EXCLUDE_YAML", encoding="utf-8")
            self.install_local_binary(excluded)
            return {"FMT_DEFAULT_ROOT": str(root), "FMT_EXCLUDED_ROOT": str(excluded)}

        calls = self.run_nvim(r'''
local formatting, spec, conform = setup_conform()
local root = vim.env.FMT_DEFAULT_ROOT
local js = make_buffer(root .. '/src/code.js', 'javascript', 'before')
formatting.format(js, 'manual')
assert(buffer_text(js):match('^formatted:oxfmt:'))
local json_buf = make_buffer(root .. '/data.json', 'json', 'before')
formatting.format(json_buf, 'manual')
assert(buffer_text(json_buf):match('^formatted:oxfmt:'))
local yaml = make_buffer(root .. '/compose.yaml', 'yaml.docker-compose', 'before')
formatting.format(yaml, 'manual')
assert(buffer_text(yaml):match('^formatted:yamlfmt:'))

local markdown_save = make_buffer(root .. '/notes-save.md', 'markdown', 'before')
local markdown_manual = make_buffer(root .. '/notes-manual.md', 'markdown', 'before')
assert(spec.opts.format_on_save(markdown_save) == nil)
formatting.format(markdown_manual, 'manual')
assert(buffer_text(markdown_save) == 'before' and buffer_text(markdown_manual) == 'before')

local docker = make_buffer(root .. '/Dockerfile', 'dockerfile', 'before')
assert(spec.opts.format_on_save(docker) == nil)
assert(buffer_text(docker) == 'before')
local erb = make_buffer(root .. '/config.yml.erb', 'eruby.yaml.tmuxinator', 'before')
assert(spec.opts.format_on_save(erb) == nil)
formatting.format(erb, 'manual')
assert(buffer_text(erb) == 'before')

local excluded = make_buffer(vim.env.FMT_EXCLUDED_ROOT .. '/settings.yaml', 'yaml', 'before')
local plan = formatting.format(excluded, 'manual')
assert(plan and plan.kind == 'project')
assert(buffer_text(excluded) == 'before', 'excluded YAML unexpectedly changed')

local unnamed = make_buffer(nil, 'javascript', 'before')
local unnamed_plan = formatting.format(unnamed, 'manual')
assert(unnamed_plan and unnamed_plan.kind == 'skip')
assert(buffer_text(unnamed) == 'before')

for filetype, expected in pairs({ lua = 'stylua', python = 'ruff_format' }) do
  local buf = make_buffer(root .. '/default.' .. filetype, filetype, 'before')
  local names = conform.list_formatters_for_buffer(buf)
  assert(vim.tbl_contains(names, expected), filetype .. ': previous default formatter changed')
end
''', prepare=prepare)

        self.assertEqual(len(self.calls_named(calls, "oxfmt")), 2)
        self.assertEqual(len(self.calls_named(calls, "yamlfmt")), 1)
        self.assertEqual(len(self.dprint_calls(calls, "fmt")), 1)
        self.assertEqual(len(self.dprint_calls(calls, "resolved-config")), 1)
        self.assertEqual(len(self.dprint_calls(calls, "--version")), 1)

    def test_project_local_oxfmt_precedes_mise_and_receives_full_filename(self):
        expected_filename = []

        def prepare(temp, _bin_dir, _tools):
            root = temp / "project-with-local-oxfmt"
            root.mkdir()
            self.install_local_binary(root, name="oxfmt")
            expected_filename.append(str(root / "src/component.tsx"))
            return {"FMT_LOCAL_OXFMT_ROOT": str(root)}

        calls = self.run_nvim(r'''
local formatting = setup_conform()
local root = vim.env.FMT_LOCAL_OXFMT_ROOT
local filename = root .. '/src/component.tsx'
local buf = make_buffer(filename, 'typescriptreact', 'before')
assert(formatting.format(buf, 'manual'), 'project-local oxfmt was skipped')
assert(buffer_text(buf) == 'formatted:oxfmt:before')
''', prepare=prepare)

        local_calls = self.calls_named(calls, "oxfmt")
        self.assertEqual(len(local_calls), 1)
        self.assertTrue(local_calls[0]["program"].endswith("node_modules/.bin/oxfmt"))
        self.assertEqual(local_calls[0]["args"], ["--stdin-filepath", expected_filename[0]])
        self.assertEqual(self.mise_which_calls(calls, "oxfmt"), [])

    def test_failures_leave_buffers_unchanged_and_release_active_plan(self):
        markers = {
            "old": ("dprint.json", "PLUGIN"),
            "malformed": ("dprint.json", "MALFORMED"),
            "query_error": ("dprint.json", "QUERY_ERROR"),
            "timeout": ("dprint.json", "SLEEP_QUERY"),
            "format_error": ("dprint.json", "FORMAT_ERROR"),
            "recovery": ("dprint.json", "PLUGIN"),
        }

        def prepare(temp, _bin_dir, _mason):
            roots = {}
            for name, (config_name, content) in markers.items():
                root = temp / name
                root.mkdir(parents=True)
                (root / config_name).write_text(content, encoding="utf-8")
                binary = self.install_local_binary(root)
                if name == "old":
                    roots["old_binary"] = str(binary)
                roots[name] = str(root)
            mise_error = temp / "mise-error"
            mise_error.mkdir(parents=True)
            (mise_error / "dprint.json").write_text("PLUGIN", encoding="utf-8")
            roots["mise_error"] = str(mise_error)
            missing = temp / "missing-record"
            missing.mkdir(parents=True)
            (missing / "dprint.json").write_text("PLUGIN", encoding="utf-8")
            roots["missing"] = str(missing)
            multiple = temp / "multiple-records"
            multiple.mkdir(parents=True)
            (multiple / "dprint.json").write_text("PLUGIN", encoding="utf-8")
            roots["multiple"] = str(multiple)
            return {
                "FMT_FAILURE_ROOTS": json.dumps(roots),
                "FMT_TEST_OLD_DPRINT_PATH": roots["old_binary"],
                "FMT_TEST_MISE_FAIL_ROOT": roots["mise_error"],
                "FMT_TEST_MISE_MULTI_ROOT": roots["multiple"],
                "FMT_TEST_MISE_MULTI_JSON": '[{"tool":"dprint","version":"0.64.3","installed":true},{"tool":"dprint","version":"0.65.0","installed":true}]',
                "FMT_TEST_MISE_JSON": '[{"tool":"dprint","version":"0.64.3","installed":false}]',
            }

        calls = self.run_nvim(r'''
local formatting = setup_conform()
local roots = vim.json.decode(vim.env.FMT_FAILURE_ROOTS)
local messages = {}
vim.notify = function(message) table.insert(messages, tostring(message)) end

for _, name in ipairs({ 'missing', 'mise_error', 'multiple', 'old', 'malformed', 'query_error' }) do
  local buf = make_buffer(roots[name] .. '/data.js', 'javascript', 'before')
  local ok, plan = pcall(formatting.format, buf, 'manual')
  assert(ok, name .. ': formatting error escaped')
  assert(plan == nil, name .. ': preparation error did not fail the operation')
  assert(buffer_text(buf) == 'before', name .. ': failed preparation changed the buffer')
end

local reentrant_buf = make_buffer(roots.recovery .. '/reentrant.js', 'javascript', 'before')
local reentrant_plan, intercepted_timeout_query = true, false
local real_system = vim.system
vim.system = function(argv, options)
  if not intercepted_timeout_query
      and argv[2] == 'resolved-config'
      and argv[4] == roots.timeout .. '/dprint.json' then
    intercepted_timeout_query = true
    reentrant_plan = formatting.format(reentrant_buf, 'manual')
  end
  return real_system(argv, options)
end
local timeout_buf = make_buffer(roots.timeout .. '/data.js', 'javascript', 'before')
local timeout_plan = formatting.format(timeout_buf, 'manual')
vim.system = real_system
assert(timeout_plan == nil, 'timed out preparation unexpectedly succeeded')
assert(intercepted_timeout_query, 'timeout query was not reached')
assert(reentrant_plan == nil, 'reentrant formatting was not rejected during the timeout query')
assert(buffer_text(timeout_buf) == 'before' and buffer_text(reentrant_buf) == 'before')

local request_count = 0
vim.lsp.get_clients = function()
  return {{
    id = 999, name = 'fixture-lsp', offset_encoding = 'utf-16',
    supports_method = function() return true end,
    request_sync = function()
      request_count = request_count + 1
      return { result = {{
        newText = 'lsp-formatted',
        range = { start = { line = 0, character = 0 }, ['end'] = { line = 1, character = 0 } },
      }} }
    end,
  }}
end
local failed_formatter = make_buffer(roots.format_error .. '/data.js', 'javascript', 'before')
local plan = formatting.format(failed_formatter, 'manual')
assert(plan and plan.kind == 'project')
vim.wait(30)
assert(buffer_text(failed_formatter) == 'before', 'formatter failure changed the buffer')
assert(request_count == 0, 'project formatter failure fell back to LSP')

local conform = require('conform')
local original_project_formatter = conform.formatters.project_dprint
local throw_once = true
conform.formatters.project_dprint = function(bufnr)
  if throw_once then
    throw_once = false
    error('fixture Conform dispatch failure')
  end
  return original_project_formatter(bufnr)
end
local dispatch_buf = make_buffer(roots.recovery .. '/dispatch.js', 'javascript', 'before')
local ok, dispatch_plan = pcall(formatting.format, dispatch_buf, 'manual')
assert(ok, 'Conform dispatch exception escaped the shared operation')
assert(dispatch_plan == nil, 'Conform dispatch exception reported a prepared operation')
assert(buffer_text(dispatch_buf) == 'before')
conform.formatters.project_dprint = original_project_formatter

local recovered = make_buffer(roots.recovery .. '/data.js', 'javascript', 'before')
local recovered_plan = formatting.format(recovered, 'manual')
assert(recovered_plan and recovered_plan.kind == 'project')
assert(buffer_text(recovered):match('^formatted:dprint:'), 'next project did not format after failure')
local saw_reentrancy = false
for _, message in ipairs(messages) do
  if message:match('already in progress') then saw_reentrancy = true end
end
assert(saw_reentrancy, 'reentrant formatting rejection was not visible')
''', prepare=prepare, timeout=10)

        self.assertEqual(len(self.dprint_calls(calls, "fmt")), 2)

    def test_empty_mise_selection_fails_without_a_mason_fallback(self):
        def prepare(temp, _bin_dir, _tools):
            root = temp / "unconfigured-project"
            root.mkdir(parents=True)
            (root / "dprint.json").write_text('{"plugins":["fixture"]}', encoding="utf-8")
            return {"FMT_UNCONFIGURED_PROJECT": str(root), "FMT_TEST_MISE_JSON": "[]"}

        calls = self.run_nvim(r'''
local formatting = setup_conform()
local root = vim.env.FMT_UNCONFIGURED_PROJECT
local buf = make_buffer(root .. '/data.json', 'json', 'before')
local plan = formatting.format(buf, 'manual')
assert(plan == nil, 'missing mise dprint selection silently fell back')
assert(buffer_text(buf) == 'before', 'missing dprint selection changed the buffer')
''', prepare=prepare)

        self.assertEqual(self.dprint_calls(calls, "fmt"), [])
        self.assertTrue(any("ls" in call["args"] for call in self.calls_named(calls, "mise")))

    def test_server_profile_skips_without_running_any_cli(self):
        def prepare(temp, _bin_dir, _mason):
            root = temp / "server-project"
            root.mkdir(parents=True)
            (root / "dprint.json").write_text('{"plugins":["fixture"]}', encoding="utf-8")
            return {"FMT_SERVER_PROJECT": str(root)}

        calls = self.run_nvim(r'''
local spec = require('plugins.conform')
assert(not spec.cond(), 'Conform must remain desktop-only')
local formatting = require('config.formatting')
local root = vim.env.FMT_SERVER_PROJECT
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, root .. '/server.js')
vim.bo[buf].filetype = 'javascript'
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'before' })
local plan = formatting.format(buf, 'manual')
assert(plan and plan.kind == 'skip')
assert(not package.loaded['conform'], 'server formatting loaded Conform')
''', profile="server", prepare=prepare)
        self.assertEqual(calls, [])

    def test_ruby_without_project_is_manual_only(self):
        def prepare(temp, bin_dir, _mason):
            self.write_fixture(bin_dir / "rubyfmt")
            root = temp / "ruby"
            root.mkdir()
            return {"FMT_RUBY_ROOT": str(root)}

        calls = self.run_nvim(r'''
local formatting, spec, conform = setup_conform()
local buf = make_buffer(vim.env.FMT_RUBY_ROOT .. '/scratch.rb', 'ruby', 'before')
local messages = {}
vim.notify = function(message) messages[#messages + 1] = message end
local get_clients = vim.lsp.get_clients
vim.lsp.get_clients = function() error('Ruby outside RuboCop must not use LSP formatting') end
assert(spec.opts.format_on_save(buf) == nil)
assert(buffer_text(buf) == 'before', 'standalone Ruby was autoformatted')
local plan = formatting.format(buf, 'manual')
assert(plan and plan.kind == 'skip', 'shared manual action should explain the missing project formatter')
vim.lsp.get_clients = get_clients
conform.format({ bufnr = buf, formatters = { 'rubyfmt' }, lsp_format = 'never' })
assert(buffer_text(buf):match('^formatted:rubyfmt:'), 'optional explicit rubyfmt did not run')
''', prepare=prepare)
        self.assertEqual(len(self.calls_named(calls, "rubyfmt")), 1)

    def test_global_defaults_resolve_mise_tools_at_the_buffer_directory(self):
        cases = [
            ("lua", "lua/main.lua", ["stylua"]),
            ("python", "python/main.py", ["ruff"]),
            ("toml", "config/settings.toml", ["taplo"]),
            ("sh", "scripts/run.sh", ["shfmt"]),
            ("bash", "scripts/run.bash", ["shfmt"]),
            ("zsh", "scripts/run.zsh", ["shfmt"]),
            ("javascript", "web/main.js", ["oxfmt"]),
            ("typescript", "web/app.ts", ["oxfmt"]),
            ("json", "data/settings.json", ["oxfmt"]),
            ("css", "web/site.css", ["oxfmt"]),
            ("graphql", "web/schema.graphql", ["oxfmt"]),
            ("yaml", "deploy/app.yaml", ["yamlfmt"]),
            ("go", "cmd/main.go", ["goimports", "gofumpt"]),
        ]

        expected_paths = {}

        def prepare(temp, _bin_dir, _tools):
            root = temp / "default-tools"
            root.mkdir()
            for filetype, filename, binaries in cases:
                expected_paths[filetype] = (str(root / Path(filename).parent), binaries)
            return {"FMT_DEFAULT_TOOLS_ROOT": str(root), "FMT_DEFAULT_TOOLS": json.dumps(cases)}

        calls = self.run_nvim(r'''
local formatting = setup_conform()
local root = vim.env.FMT_DEFAULT_TOOLS_ROOT
for _, case in ipairs(vim.json.decode(vim.env.FMT_DEFAULT_TOOLS)) do
  local filename = root .. '/' .. case[2]
  local buf = make_buffer(filename, case[1], 'before')
  local plan = formatting.format(buf, 'manual')
  assert(plan and plan.kind == 'default', case[1] .. ': default formatting was skipped')
  local expected = 'formatted:' .. case[3][#case[3]] .. ':'
  if case[1] == 'go' then expected = 'formatted:gofumpt:formatted:goimports:' end
  assert(buffer_text(buf):sub(1, #expected) == expected,
    case[1] .. ': wrong formatter chain: ' .. buffer_text(buf))
end
''', prepare=prepare)

        expected = {}
        for filetype, _filename, _binaries in cases:
            target_dir, binaries = expected_paths[filetype]
            for binary in binaries:
                expected.setdefault(binary, []).append(target_dir)
        for binary, target_dirs in expected.items():
            resolved = self.mise_which_calls(calls, binary)
            self.assertGreaterEqual(len(resolved), len(target_dirs), f"mise did not resolve {binary} for each buffer")
            actual = [call["args"] for call in resolved]
            for target in target_dirs:
                self.assertIn(["-C", target, "which", binary], actual)

        formatter_calls = [call for call in calls if call["name"] in self.MISE_BINARIES and call["name"] != "dprint"]
        self.assertEqual(
            [call["name"] for call in formatter_calls],
            [binary for _ft, _filename, binaries in cases for binary in binaries],
        )

    def test_project_rubocop_keeps_binstub_and_bundle_routes(self):
        def prepare(temp, bin_dir, _mason):
            self.write_fixture(bin_dir / "bundle")
            for name in ("binstub", "bundled"):
                root = temp / name
                root.mkdir()
                (root / ".rubocop.yml").write_text("AllCops: {}\n")
                (root / "Gemfile").write_text('gem "rubocop"\n')
                if name == "binstub":
                    self.write_fixture(root / "bin/rubocop")
            return {}

        calls = self.run_nvim(r'''
local formatting = setup_conform()
for _, name in ipairs({ 'binstub', 'bundled' }) do
  local buf = make_buffer(vim.env.HOME .. '/' .. name .. '/app.rb', 'ruby', 'before')
  assert(formatting.format(buf, 'save'), 'project Ruby formatting was skipped')
  local program = name == 'binstub' and 'rubocop' or 'bundle'
  assert(buffer_text(buf) == 'formatted:' .. program .. ':before')
end
''', prepare=prepare)
        self.assertEqual(len(self.calls_named(calls, "rubocop")), 1)
        self.assertEqual(self.calls_named(calls, "bundle")[0]["args"][:2], ["exec", "rubocop"])

    @unittest.skipUnless(MASON_GOIMPORTS.is_file() and MASON_GOFUMPT.is_file() and shutil.which("go"),
                         "existing Mason goimports/gofumpt binaries and Go are required")
    def test_real_goimports_and_gofumpt_preserve_imports_and_style(self):
        # Read an existing toolchain directly; querying mise would resolve unrelated
        # newly declared tools and attempt network/cache writes in the user's HOME.
        go = Path(os.environ.get("DOTFILES_TEST_GO", str(Path.home() / ".local/share/mise/installs/go/latest/bin/go")))
        if not go.is_file():
            self.skipTest("set DOTFILES_TEST_GO to an existing Go executable")

        def prepare(temp, bin_dir, tool_dir):
            root = temp / "go-project"
            root.mkdir()
            (root / "go.mod").write_text("module example.test/formatting\n\ngo 1.20\n", encoding="utf-8")
            binaries = {
                name: str(tool_dir / name)
                for name in self.MISE_BINARIES
            }
            binaries.update({"goimports": str(MASON_GOIMPORTS), "gofumpt": str(MASON_GOFUMPT)})
            return {
                "PATH": str(bin_dir) + ":" + str(go.parent) + ":/usr/bin:/bin",
                "FMT_TEST_MISE_BINARIES": json.dumps(binaries),
                "FMT_GO_ROOT": str(root), "GOPROXY": "off", "GOSUMDB": "off", "GOTOOLCHAIN": "local",
                "GOPATH": str(temp / "gopath"), "GOCACHE": str(temp / "gocache"),
            }

        calls = self.run_nvim(r'''
local formatting, spec = setup_conform()
local root = vim.env.FMT_GO_ROOT
local source = {
  'package main', '', 'import (', '    "os"', ')', '',
  'func main( ){', 'fmt.Println("ready")', 'fmt.Println("again")', '}',
}
local filename = root .. '/main.go'
vim.fn.writefile(source, filename)
local buf = make_buffer(filename, 'go', '')
vim.api.nvim_buf_set_lines(buf, 0, -1, false, source)
local other = make_buffer(root .. '/other.go', 'text', 'untouched')
vim.api.nvim_set_current_buf(other)
vim.lsp.get_clients = function() return {} end
local original = table.concat(source, '\n')
local expected = 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("ready")\n\tfmt.Println("again")\n}'
assert(formatting.format(buf, 'manual'), 'real Go formatter chain failed')
assert(buffer_text(buf) == expected, 'goimports/gofumpt output changed imports or style:\n' .. buffer_text(buf))
assert(table.concat(vim.fn.readfile(filename), '\n') == original, 'manual format wrote the source file')
assert(vim.api.nvim_get_current_buf() == other and buffer_text(other) == 'untouched')
assert(formatting.format(buf, 'manual'), 'already formatted Go failed')
assert(buffer_text(buf) == expected, 'Go formatting is not idempotent')
vim.api.nvim_buf_set_lines(buf, 0, -1, false, source)
vim.api.nvim_buf_call(buf, function() vim.cmd('write!') end)
assert(table.concat(vim.fn.readfile(filename), '\n') == expected, 'save skipped goimports/gofumpt')
''', prepare=prepare, timeout=45)

        self.assertGreaterEqual(len(self.mise_which_calls(calls, "goimports")), 3)
        self.assertGreaterEqual(len(self.mise_which_calls(calls, "gofumpt")), 3)
        for binary in ("goimports", "gofumpt"):
            self.assertTrue(all(call["args"] == ["-C", calls[0]["args"][1], "which", binary]
                                for call in self.mise_which_calls(calls, binary)))

    @unittest.skipUnless(REAL_OXFMT, "set DOTFILES_TEST_OXFMT to an existing native oxfmt binary")
    def test_real_native_oxfmt_formats_five_types_without_touching_sources(self):
        oxfmt = Path(REAL_OXFMT).resolve()
        if not oxfmt.is_file() or not os.access(oxfmt, os.X_OK):
            self.skipTest("configured native oxfmt binary is unavailable")

        samples = [
            ("javascript", "main.js", 'const value={name:"Ada",tags:["go","lua"]};console.log(value)\n'),
            ("typescript", "app.ts", 'type User={name:string;age:number};const user:User={name:"Ada",age:37};console.log(user)\n'),
            ("json", "data.json", '{"name":"Ada","tags":["go","lua"]}\n'),
            ("css", "site.css", 'body{color:red;background-color:#fff}\n'),
            ("graphql", "schema.graphql", 'query User($id:ID!){user(id:$id){id name}}\n'),
        ]
        original_files = []

        def prepare(temp, bin_dir, tool_dir):
            root = temp / "oxfmt-project"
            root.mkdir()
            cases = []
            for filetype, filename, source in samples:
                path = root / filename
                path.write_text(source, encoding="utf-8")
                original_files.append(str(path))
                cases.append({"filetype": filetype, "filename": str(path)})

            wrapper = tool_dir / "native-oxfmt"
            wrapper.write_text(
                f"#!{sys.executable}\n"
                "import json, os, sys\n"
                "entry = {'program': sys.argv[0], 'name': 'native-oxfmt', 'args': sys.argv[1:], 'cwd': os.getcwd()}\n"
                "with open(os.environ['FMT_TEST_LOG'], 'a', encoding='utf-8') as stream:\n"
                "    stream.write(json.dumps(entry) + '\\n')\n"
                "binary = os.environ['FMT_OXFMT_BINARY']\n"
                "os.execvpe(binary, [binary, *sys.argv[1:]], os.environ)\n",
                encoding="utf-8",
            )
            wrapper.chmod(0o755)
            binaries = json.loads(os.environ.get("FMT_TEST_MISE_BINARIES", "{}"))
            binaries["oxfmt"] = str(wrapper)
            return {
                "PATH": str(bin_dir),
                "FMT_TEST_MISE_BINARIES": json.dumps(binaries),
                "FMT_OXFMT_CASES": json.dumps(cases),
                "FMT_OXFMT_BINARY": str(oxfmt),
            }

        calls = self.run_nvim(r'''
local formatting = setup_conform()
assert(vim.fn.exepath('node') == '', 'native oxfmt test unexpectedly found Node on PATH')
local other = make_buffer(vim.env.HOME .. '/unrelated.txt', 'text', 'untouched')
vim.api.nvim_set_current_buf(other)
for _, case in ipairs(vim.json.decode(vim.env.FMT_OXFMT_CASES)) do
  local original = table.concat(vim.fn.readfile(case.filename), '\n')
  local buf = make_buffer(case.filename, case.filetype, '')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(case.filename))
  assert(formatting.format(buf, 'manual'), case.filetype .. ': native formatter was not selected')
  local formatted = buffer_text(buf)
  assert(formatted ~= original, case.filetype .. ': native oxfmt did not change the fixture')
  assert(table.concat(vim.fn.readfile(case.filename), '\n') == original,
    case.filetype .. ': manual format changed the source file')
  assert(#vim.fn.glob(vim.fs.dirname(case.filename) .. '/.conform.*', false, true) == 0,
    case.filetype .. ': Conform left a temporary file behind')
  assert(formatting.format(buf, 'manual'), case.filetype .. ': second native format failed')
  assert(buffer_text(buf) == formatted, case.filetype .. ': native oxfmt output is not idempotent')
  assert(table.concat(vim.fn.readfile(case.filename), '\n') == original,
    case.filetype .. ': repeated manual format changed the source file')
  assert(#vim.fn.glob(vim.fs.dirname(case.filename) .. '/.conform.*', false, true) == 0,
    case.filetype .. ': repeated formatting left a temporary file behind')
end
assert(vim.api.nvim_get_current_buf() == other and buffer_text(other) == 'untouched')
''', prepare=prepare)

        resolved = self.mise_which_calls(calls, "oxfmt")
        self.assertGreaterEqual(len(resolved), 10)
        expected_dir = Path(original_files[0]).parent
        self.assertTrue(all(call["args"] == ["-C", str(expected_dir), "which", "oxfmt"] for call in resolved))
        self.assertEqual(len(original_files), 5)
        native_calls = self.calls_named(calls, "native-oxfmt")
        self.assertEqual(len(native_calls), 10)
        self.assertTrue(all(len(call["args"]) == 1 and ".conform." in call["args"][0]
                            for call in native_calls), "oxfmt was not passed Conform's temporary filename")

    @unittest.skipUnless(REAL_DPRINT and REAL_DPRINT_PLUGIN, "set local dprint and plugin paths for real E2E")
    def test_optional_real_dprint_yaml_plugin(self):
        dprint = Path(REAL_DPRINT).resolve()
        plugin = Path(REAL_DPRINT_PLUGIN).resolve()
        if not dprint.is_file() or not os.access(dprint, os.X_OK) or not plugin.is_file():
            self.skipTest("optional local dprint or plugin path is unavailable")

        def prepare(temp, _bin_dir, _mason):
            root = temp / "real dprint project"
            root.mkdir(parents=True)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / ".gitignore").write_text("ignored/\n", encoding="utf-8")
            (root / "dprint.json").write_text(
                json.dumps({
                    "includes": ["**/*.{yaml,yml}"],
                    "excludes": ["skip.yaml", "excluded/"],
                    "plugins": [plugin.as_uri()],
                }), encoding="utf-8"
            )
            target = root / "node_modules/.bin/dprint"
            target.parent.mkdir(parents=True)
            target.symlink_to(dprint)
            return {"FMT_REAL_DPRINT_PROJECT": str(root)}

        self.run_nvim(r'''
local formatting = setup_conform()
local root = vim.env.FMT_REAL_DPRINT_PROJECT
local buf = make_buffer(root .. '/new.yaml', 'yaml', 'name:    value')
assert(vim.fn.filereadable(root .. '/new.yaml') == 0)
local plan = formatting.format(buf, 'manual')
assert(plan and plan.kind == 'project')
assert(buffer_text(buf):find('name: value', 1, true), 'real YAML plugin did not format input')
assert(vim.fn.filereadable(root .. '/new.yaml') == 0, 'stdin formatting wrote the source file')

for _, name in ipairs({ 'skip.yaml', 'excluded/data.yaml', 'ignored/data.yaml' }) do
  local excluded = make_buffer(root .. '/' .. name, 'yaml', 'name:    value')
  local excluded_plan = formatting.format(excluded, 'manual')
  assert(excluded_plan and excluded_plan.kind == 'project')
  assert(buffer_text(excluded) == 'name:    value', name .. ': real dprint ignored an exclusion')
end

local json = make_buffer(root .. '/data.json', 'json', '{"name":"value"}')
local json_plan = formatting.format(json, 'manual')
assert(json_plan and json_plan.kind == 'default', 'YAML-only dprint claimed JSON')
assert(buffer_text(json):match('^formatted:oxfmt:'), 'unsupported JSON did not use its default formatter')
''', prepare=prepare)


if __name__ == "__main__":
    unittest.main()
