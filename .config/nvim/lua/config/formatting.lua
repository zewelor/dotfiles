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

local function remaining(deadline, budget_ms)
  local ms = math.floor((deadline - vim.uv.hrtime()) / 1e6)
  if ms <= 0 then
    error("Formatting exceeded the " .. (budget_ms or 2000) .. " ms budget", 0)
  end
  return ms
end

local function run(argv, cwd, deadline, mise, budget_ms)
  budget_ms = budget_ms or 2000
  local opts = { cwd = cwd, text = true, timeout = remaining(deadline, budget_ms) }
  if mise then
    -- An inherited override must not hide the directory's configured request.
    opts.env = vim.fn.environ()
    opts.env.MISE_DPRINT_VERSION = nil
    opts.clear_env = true
  end
  local result = vim.system(argv, opts):wait()
  if result.code == 124 then
    error("Formatting timeout (" .. budget_ms .. " ms total budget): " .. argv[1], 0)
  end
  if result.code ~= 0 then
    error(string.format("%s failed (exit %s): %s", argv[1], result.code,
      vim.trim(result.stderr or "")), 0)
  end
  remaining(deadline, budget_ms)
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
  error("No mise dprint version is configured", 0)
end

local function resolve(bufnr, trigger, deadline)
  local plan = { kind = "default", bufnr = bufnr }
  local ft = vim.bo[bufnr].filetype
  if not require("config.profile").is_desktop() then
    plan.kind, plan.reason = "skip", "Project formatting requires the desktop profile"
  elseif ft == "eruby.yaml.tmuxinator" or (trigger == "save" and ft == "dockerfile") then
    plan.kind, plan.reason = "skip", "This filetype is excluded from formatting"
  elseif ft == "dockerfile" then
    local info = require("conform").get_formatter_info("dockerfmt", bufnr)
    if not info.available then
      error(info.available_msg or "dockerfmt is not available; prepare the desktop tools first", 0)
    end
  elseif ft == "ruby" then
    local ruby = require("config.ruby")
    local root = ruby.root(bufnr)
    if ruby.is_gem(vim.api.nvim_buf_get_name(bufnr)) then
      plan.kind, plan.reason = "skip", "Gem sources are read-only"
    elseif ruby.project_lsp(root) then
      if not ruby.rubocop_root(bufnr) then
        plan.kind, plan.reason = "skip", "No project RuboCop configuration"
      else
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "ruby_lsp" })) do
          if client.initialized and client:supports_method("textDocument/formatting", bufnr) then
            plan.kind, plan.client_id, plan.cwd = "ruby_lsp", client.id, root
            break
          end
        end
        if plan.kind ~= "ruby_lsp" then
          error("Ruby LSP [" .. root .. "]: no ready client supports formatting; see :LspLog", 0)
        end
      end
    elseif #require("conform").list_formatters_for_buffer(bufnr) == 0 then
      plan.kind, plan.reason = "skip", "No project RuboCop; rubyfmt is available only through explicit formatting"
    end
  elseif project_types[ft] then
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename == "" then
      plan.kind, plan.reason = "skip", "Name the buffer before project formatting"
      return plan, deadline
    end
    local dirname = vim.fs.dirname(filename)
    local config = vim.fs.find(config_names, { path = dirname, upward = true, type = "file", limit = 1 })[1]
    if config then
      plan.config = vim.fn.fnamemodify(config, ":p")
      plan.filename = vim.fn.fnamemodify(filename, ":p")
      plan.cwd = vim.fs.dirname(plan.config)
      if vim.fs.basename(plan.cwd) == ".config" then
        plan.cwd = vim.fs.dirname(plan.cwd)
      end
      local root = vim.fs.root(dirname, { "Gemfile", ".git" }) or plan.cwd
      local project_bin = require("config.tools").project_executable("dprint", root)
      if project_bin then
        plan.command, plan.source = project_bin, "project_path"
        plan.cwd, plan.budget_ms = root, 10000
        deadline = deadline + 8000 * 1e6
      else
        plan.command, plan.source = binary_for(dirname, deadline)
        plan.budget_ms = 2000
      end
      if vim.fn.executable(plan.command) ~= 1 then
        error("dprint is not executable: " .. plan.command, 0)
      end
      local output = run({ plan.command, "--version" }, plan.cwd, deadline, false, plan.budget_ms)
      local version = vim.version.parse(output:match("^dprint%s+(%S+)") or "")
      if not version or not vim.version.ge(version, require("config.tools").minimum_versions.dprint) then
        error("dprint >= 0.64.3 is required; selected " .. plan.command .. " reported: " .. output, 0)
      end
      plan.version = tostring(version)
      local resolved_config = run(
        { plan.command, "resolved-config", "--config", plan.config, "--file", plan.filename },
        plan.cwd, deadline, false, plan.budget_ms)
      local plugins = json(resolved_config, "{", "from dprint")
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
  return plan, deadline
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
    local plan
    plan, deadline = resolve(bufnr, trigger, deadline)
    if dispatch and plan.kind ~= "skip" then
      active = plan
      local opts = { bufnr = bufnr, async = false, timeout_ms = remaining(deadline, plan.budget_ms), lsp_format = "fallback" }
      if plan.kind == "project" then
        opts.formatters, opts.lsp_format = { "project_dprint" }, "never"
      elseif plan.kind == "ruby_lsp" then
        opts.formatters, opts.lsp_format, opts.id = {}, "fallback", plan.client_id
      elseif vim.bo[bufnr].filetype == "go" or vim.bo[bufnr].filetype == "dockerfile" then
        opts.lsp_format = "never"
      end
      -- Native LSP formatting parameters use the current buffer, even with an explicit bufnr.
      vim.api.nvim_buf_call(bufnr, function() require("conform").format(opts) end)
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
    args = { "fmt", "--config", plan.config, "--stdin", plan.filename },
    cwd = function() return plan.cwd end,
  }
end

return M
