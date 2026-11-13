-- Headless maintenance entry point. The shell helper owns profile/environment checks.
local stage, mode = unpack(arg)
local function run()
  assert(vim.fn.has("nvim-0.11") == 1, "Neovim >= 0.11 is required")
  assert(stage == "plugins", "Expected plugins stage")
  assert(mode == "install" or mode == "update", "Expected install or update mode")
  vim.opt.rtp:prepend(vim.fn.stdpath("config"))
  vim.g.dotfiles_maintenance = true
  vim.opt.loadplugins = true
  local errors = {}
  vim.notify = function(message, level)
    if level == vim.log.levels.ERROR then
      errors[#errors + 1] = message
    end
    io.stderr:write(tostring(message) .. "\n")
  end
  require("config.lazy")
  local config = require("lazy.core.config")
  local pending_file = vim.fn.stdpath("state") .. "/pending-plugin-builds.json"
  local pending = {}
  if vim.fn.filereadable(pending_file) == 1 then
    pending = vim.json.decode(table.concat(vim.fn.readfile(pending_file), "\n"))
    assert(type(pending) == "table", "Invalid pending plugin builds state")
  end
  for name in pairs(pending) do
    if config.plugins[name] then
      config.plugins[name]._.build = true
    else
      pending[name] = nil
    end
  end
  -- Preserve setup's tasks too: Lazy may already have attempted a missing build.
  require("lazy")[mode == "install" and "install" or "sync"]({ wait = true, show = false, clear = false })
  for name, plugin in pairs(config.plugins) do
    for _, task in ipairs(plugin._.tasks or {}) do
      if task.name == "build" then
        pending[name] = task:has_errors() and true or nil
      end
    end
  end
  -- Save before checking errors so all failed builds survive the next process.
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  assert(vim.fn.writefile({ vim.json.encode(pending) }, pending_file) == 0,
    "Could not save pending plugin builds")
  local function check(plugin)
    for _, task in ipairs(plugin._.tasks or {}) do
      assert(not task:has_errors(), plugin.name .. ": " .. task:output())
    end
  end
  for _, plugin in pairs(config.plugins) do
    check(plugin)
    assert(plugin._.installed, "Missing Neovim plugin: " .. plugin.name)
  end
  for _, plugin in ipairs(config.to_clean) do
    check(plugin)
  end
  assert(#errors == 0, table.concat(errors, "\n"))

end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write("Neovim " .. tostring(stage) .. " maintenance failed: " .. err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
