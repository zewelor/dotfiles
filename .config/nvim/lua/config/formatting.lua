-- Share project selection between save, manual formatting and diagnostics.
local M = {}
local active, busy
local config_names = {
  "dprint.json", "dprint.jsonc", ".dprint.json", ".dprint.jsonc",
  ".config/dprint.json", ".config/dprint.jsonc",
}
local project_types = {
  yaml = true, ["yaml.tmuxinator"] = true, ["yaml.docker-compose"] = true,
  javascript = true, javascriptreact = true, typescript = true, typescriptreact = true,
  json = true, jsonc = true, json5 = true, css = true, graphql = true, markdown = true,
}

local function remaining(deadline)
  local ms = math.floor((deadline - vim.uv.hrtime()) / 1e6)
  if ms <= 0 then
    error("Formatting exceeded the 2000 ms budget", 0)
  end
  return ms
end

local function run(argv, cwd, deadline, mise)
  local opts = { cwd = cwd, text = true, timeout = remaining(deadline) }
  if mise then
    -- An inherited override must not hide the directory's configured request.
    opts.env = vim.fn.environ()
    opts.env.MISE_DPRINT_VERSION = nil
    opts.clear_env = true
  end
  local result = vim.system(argv, opts):wait()
  if result.code == 124 then
    error("Formatting timeout (2000 ms total budget): " .. argv[1], 0)
  end
  if result.code ~= 0 then
    error(string.format("%s failed (exit %s): %s", argv[1], result.code,
      vim.trim(result.stderr or "")), 0)
  end
  remaining(deadline)
  return vim.trim(result.stdout or "")
end

local function json(stdout, opening, description)
  if stdout:sub(1, 1) ~= opening then
    error("Invalid JSON " .. description, 0)
  end
  local value = vim.json.decode(stdout)
  if type(value) ~= "table" then
    error("Invalid JSON " .. description, 0)
  end
  return value
end

local function binary_for(dirname, deadline)
  local find = require("conform.util").find_executable({ "node_modules/.bin/dprint" }, "")
  local local_bin = find(nil, { dirname = dirname })
  if local_bin ~= "" then
    return local_bin, "node_modules"
  end
  local mise = vim.fn.exepath("mise")
  if mise == "" then
    error("mise is required to resolve the configured dprint version", 0)
  end
  local requests = json(run({ mise, "-C", dirname, "ls", "--current", "--json", "dprint" },
    dirname, deadline, true), "[", "from mise")
  if #requests > 1 then
    error("Multiple mise dprint versions are configured; select one version", 0)
  elseif #requests == 1 then
    local request = requests[1]
    if type(request) ~= "table" or request.installed ~= true then
      error("The mise dprint version is not installed; install it explicitly", 0)
    end
    if type(request.version) ~= "string" or request.version == "" then
      error("mise did not report a resolved dprint version", 0)
    end
    return run({ mise, "-C", dirname, "which", "dprint", "--tool", "dprint@" .. request.version },
      dirname, deadline, true), "mise"
  end
  -- Mason owns the default; do not accidentally execute a stale mise shim.
  return require("mason.settings").current.install_root_dir .. "/bin/dprint", "mason"
end

local function resolve(bufnr, trigger, deadline)
  local plan = { kind = "default", bufnr = bufnr }
  local ft = vim.bo[bufnr].filetype
  if not require("config.profile").is_desktop() then
    plan.kind, plan.reason = "skip", "Project formatting requires the desktop profile"
  elseif ft == "eruby.yaml.tmuxinator" or (trigger == "save" and ft == "dockerfile") then
    plan.kind, plan.reason = "skip", "This filetype is excluded from formatting"
  elseif project_types[ft] then
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename == "" then
      plan.kind, plan.reason = "skip", "Name the buffer before project formatting"
      return plan
    end
    local dirname = vim.fs.dirname(filename)
    local config = vim.fs.find(config_names, { path = dirname, upward = true, type = "file", limit = 1 })[1]
    if config then
      plan.config = config
      plan.cwd = vim.fs.dirname(config)
      if vim.fs.basename(plan.cwd) == ".config" then
        plan.cwd = vim.fs.dirname(plan.cwd)
      end
      plan.command, plan.source = binary_for(dirname, deadline)
      if vim.fn.executable(plan.command) ~= 1 then
        error("dprint is not executable: " .. plan.command, 0)
      end
      local output = run({ plan.command, "--version" }, plan.cwd, deadline)
      local version = vim.version.parse(output:match("^dprint%s+(%S+)") or "")
      if not version or not vim.version.ge(version, { 0, 64, 3 }) then
        error("dprint >= 0.64.3 is required; selected " .. plan.command .. " reported: " .. output, 0)
      end
      plan.version = tostring(version)
      local plugins = json(run({ plan.command, "resolved-config", "--config", config, "--file", filename },
        plan.cwd, deadline), "{", "from dprint")
      if next(plugins) ~= nil then
        plan.kind = "project"
      else
        plan.reason = "No dprint plugin matches this file; use the default formatter"
      end
    end
    if plan.kind == "default" and ft == "markdown" then
      plan.kind, plan.reason = "skip", "No project dprint plugin formats this Markdown file"
    end
  end
  return plan
end

local function operation(bufnr, trigger, dispatch)
  if busy then
    vim.notify("Formatting is already in progress", vim.log.levels.WARN, { title = "Format" })
    return nil
  end
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  -- Keep the context only for this synchronous operation, including error paths.
  busy = true
  local ok, result = xpcall(function()
    local deadline = vim.uv.hrtime() + 2000 * 1e6
    local plan = resolve(bufnr, trigger, deadline)
    if dispatch and plan.kind ~= "skip" then
      active = plan
      local opts = { bufnr = bufnr, async = false, timeout_ms = remaining(deadline), lsp_format = "fallback" }
      if plan.kind == "project" then
        opts.formatters, opts.lsp_format = { "project_dprint" }, "never"
      end
      require("conform").format(opts)
    elseif dispatch and trigger == "manual" then
      vim.notify(plan.reason, vim.log.levels.INFO, { title = "Format" })
    end
    return plan
  end, function(err) return tostring(err) end)
  active, busy = nil, false
  if not ok then
    vim.notify(result, vim.log.levels.ERROR, { title = "Format" })
    return nil
  end
  return result
end

function M.format(bufnr, trigger)
  return operation(bufnr, trigger or "manual", true)
end

function M.info(bufnr)
  return operation(bufnr, "manual", false)
end

function M.project_formatter(bufnr)
  if not active or active.kind ~= "project" or active.bufnr ~= bufnr then
    return { inherit = "dprint", condition = function() return false end }
  end
  local plan = active
  return {
    inherit = "dprint",
    command = plan.command,
    args = { "fmt", "--config", plan.config, "--stdin", "$FILENAME" },
    cwd = function() return plan.cwd end,
  }
end

return M
