local config_lua = assert(vim.env.MCA118_CONFIG_LUA)
local lazy_root = assert(vim.env.MCA118_LAZY_ROOT)
local ruby_base = assert(vim.env.MCA118_RUBY_BASE)
local r3x = assert(vim.env.MCA118_R3X)
local ruby_base_bundle = assert(vim.env.MCA118_RUBY_BASE_BUNDLE)
local ruby_fixture = assert(vim.env.MCA118_RUBY_BASE_FIXTURE)
local r3x_fixture = assert(vim.env.MCA118_R3X_FIXTURE)
local order = vim.split(assert(vim.env.MCA118_ORDER), ",", { plain = true })

package.path = config_lua .. "/?.lua;" .. package.path
vim.opt.rtp:prepend(config_lua .. "/..")
vim.opt.rtp:append(lazy_root .. "/nvim-lspconfig")
vim.opt.rtp:append(lazy_root .. "/conform.nvim")
vim.lsp.set_log_level("warn")

local lsp_loaded = false
for _, spec in ipairs(require("plugins.lsp")) do
  if spec[1] == "neovim/nvim-lspconfig" then
    spec.config()
    lsp_loaded = true
  end
end
assert(lsp_loaded, "the repository's native LSP configuration was not found")
require("conform").setup(require("plugins.conform").opts)

local notices = {}
local result = { clients = {}, checks = {} }
vim.notify = function(message, level)
  notices[#notices + 1] = { message = tostring(message), level = level }
end

local roots = { ruby_base = ruby_base, r3x = r3x }
local fixtures = { ruby_base = ruby_fixture, r3x = r3x_fixture }
local initial_path = vim.env.PATH

-- Simulate explicitly activating each disposable project's executable wrappers.
local function activate(root)
  vim.env.PATH = root .. "/.dev/bin:" .. initial_path
end

local function open_ruby(path, expected_root)
  activate(expected_root)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.bo.filetype = "ruby"
  local bufnr = vim.api.nvim_get_current_buf()
  assert(vim.wait(120000, function()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "ruby_lsp" })) do
      if client.initialized then
        return true
      end
    end
    return false
  end, 100), "Ruby LSP did not initialize for " .. path)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "ruby_lsp" })[1]
  assert(client and client.root_dir == expected_root, "Ruby LSP selected the wrong project root")
  return bufnr, client
end

local function definition(client, bufnr, line, character)
  local location
  -- Initialization precedes background indexing of project and gem definitions.
  vim.wait(120000, function()
    local response = client:request_sync("textDocument/definition", {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      position = { line = line, character = character },
    }, 10000, bufnr)
    local locations = response and response.result
    if type(locations) == "table" then
      location = locations.uri and locations or locations[1]
    end
    return location ~= nil
  end, 500)
  return location
end

local function location_path(location)
  local uri = location.uri or location.targetUri
  assert(uri, "definition response has no URI")
  return vim.fs.normalize(vim.uri_to_fname(uri))
end

local function client_count()
  return #vim.lsp.get_clients()
end

local ok, err = xpcall(function()
  local initial_cwd = vim.fn.getcwd()
  local buffers = {}
  for _, name in ipairs(order) do
    local bufnr, client = open_ruby(fixtures[name], roots[name])
    buffers[name] = bufnr
    result.clients[name] = {
      id = client.id,
      root = client.root_dir,
      server = client.server_info,
    }
  end

  assert(result.clients.ruby_base and result.clients.r3x, "both Ruby projects must be opened")
  assert(result.clients.ruby_base.id ~= result.clients.r3x.id, "different roots reused one Ruby LSP client")
  assert(client_count() == 2, "expected exactly one Ruby LSP client per project")
  assert(vim.fn.getcwd() == initial_cwd, "opening project files changed Neovim's working directory")
  result.checks.two_roots = true

  local r3x_buf = buffers.r3x
  activate(r3x)
  assert(vim.wait(120000, function()
    for _, diagnostic in ipairs(vim.diagnostic.get(r3x_buf)) do
      local code = tostring(diagnostic.code or "")
      if code:find("R3x/PreferR3xEnv", 1, true)
        or diagnostic.message:find("R3x::Env", 1, true) then
        return true
      end
    end
    return false
  end, 100), "the actual R3X PreferR3xEnv cop did not diagnose direct ENV access")
  result.checks.r3x_cop = true

  vim.api.nvim_set_current_buf(r3x_buf)
  local disk_before = table.concat(vim.fn.readfile(r3x_fixture), "\n")
  local buffer_before = table.concat(vim.api.nvim_buf_get_lines(r3x_buf, 0, -1, false), "\n")
  local plan = require("config.formatting").format(r3x_buf, "manual")
  assert(plan and plan.kind == "ruby_lsp", "container Ruby LSP formatter was not selected")
  local buffer_after = table.concat(vim.api.nvim_buf_get_lines(r3x_buf, 0, -1, false), "\n")
  local disk_after = table.concat(vim.fn.readfile(r3x_fixture), "\n")
  assert(buffer_after ~= buffer_before, "safe autocorrect did not change the unsaved buffer")
  assert(buffer_after:find("\n    value = 1\n    other = ENV.fetch", 1, true),
    "Ruby LSP did not align the fixture's indentation: " .. vim.inspect(buffer_after))
  assert(disk_after == disk_before, "formatting wrote the unsaved buffer to disk")
  result.checks.unsaved_autocorrect = true

  local base_buf = buffers.ruby_base
  local base_client = vim.lsp.get_clients({ bufnr = base_buf, name = "ruby_lsp" })[1]
  local gem_location = definition(base_client, base_buf, 1, 13)
  assert(gem_location, "Ruby LSP did not resolve Zeitwerk::Loader")
  local gem_path = location_path(gem_location)
  local gem_prefix = vim.fs.normalize(ruby_base_bundle) .. "/"
  assert(gem_path:sub(1, #gem_prefix) == gem_prefix,
    "gem definition did not resolve under the prepared same-path bundle cache")
  assert(vim.fn.filereadable(gem_path) == 1, "host cannot read the container gem source")
  assert(vim.lsp.util.show_document(gem_location, base_client.offset_encoding, { focus = true }),
    "Neovim could not open the gem source")
  local gem_buf = vim.api.nvim_get_current_buf()
  assert(vim.bo[gem_buf].readonly and not vim.bo[gem_buf].modifiable,
    "container gem source must open read-only")
  vim.wait(200)
  assert(client_count() == 2, "opening gem source started another LSP client")
  result.checks.gem_definition = { path = gem_path, readonly = true }
  vim.api.nvim_set_current_buf(base_buf)
  assert(vim.lsp.get_clients({ bufnr = base_buf, name = "ruby_lsp" })[1].id == base_client.id,
    "returning from gem source did not reuse the original project client")
  result.checks.reuse_after_gem = true

  if vim.env.MCA118_BASE_VERSION_AVAILABLE == "1" then
    local project_location = definition(base_client, base_buf, 2, 16)
    assert(project_location, "Ruby LSP did not resolve BaseProjects::VERSION")
    local project_path = location_path(project_location)
    local project_prefix = vim.fs.normalize(ruby_base .. "/lib") .. "/"
    assert(project_path:sub(1, #project_prefix) == project_prefix,
      "BaseProjects::VERSION resolved outside the disposable project's lib tree")
    result.checks.project_definition = project_path
  else
    result.checks.project_definition = "skipped: lib/base_projects/version.rb is absent"
  end
end, debug.traceback)

local client_ids = {}
for _, client in ipairs(vim.lsp.get_clients()) do
  client_ids[#client_ids + 1] = client.id
  client:stop()
end
local graceful = vim.wait(4000, function()
  return client_count() == 0
end, 20)
local forced_client_ids = {}
if not graceful then
  for _, client in ipairs(vim.lsp.get_clients()) do
    forced_client_ids[#forced_client_ids + 1] = client.id
    client:stop(true)
  end
  vim.wait(2000, function()
    return client_count() == 0
  end, 20)
end

result.ok = ok and graceful and client_count() == 0
result.shutdown = {
  graceful = graceful and client_count() == 0,
  clients_remaining = client_count(),
  initial_client_ids = client_ids,
  forced_client_ids = forced_client_ids,
}
if not ok then
  result.error = err
elseif not result.ok then
  result.error = "Ruby LSP clients required forced shutdown"
end
result.notices = notices
print("MCA118_RESULT:" .. vim.json.encode(result))
if not result.ok then
  vim.cmd("cquit")
else
  vim.cmd("qa!")
end
