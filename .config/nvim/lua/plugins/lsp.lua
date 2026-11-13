-- lsp — Language Server Protocol for intelligent code features
local profile = require("config.profile")

local servers = require("config.tools").servers

-- Resolve the Ruby tool from mise rather than an old Mason wrapper.
-- Some Mason Ruby gem wrappers can keep stale shebangs after a Ruby upgrade, so
-- Ruby tools must resolve through mise instead of falling back to PATH.
local function mise_bin(tool, opts)
  opts = opts or {}
  if not opts.prefer_mise and vim.fn.executable(tool) == 1 then
    return tool
  end
  if not profile.is_desktop() or vim.fn.executable("mise") ~= 1 then
    return nil
  end

  local path = vim.fn.system({ "mise", "which", tool }):gsub("%s+$", "")
  if vim.v.shell_error ~= 0 or path == "" then
    return nil
  end
  return path
end

-- Build the per-server options shared by the native LSP configurations.
local function make_server_opts(server)
  local opts = {}
  if server == "helm_ls" then
    opts.filetypes = { "helm" }
  elseif server == "ruby_lsp" then
    local path = mise_bin("ruby-lsp", { prefer_mise = true })
    if path then
      opts.cmd = { path }
    end
  end
  return opts
end

return {
  -- Mason: optional manual packages, kept outside PATH
  {
    "williamboman/mason.nvim",
    cond = profile.is_desktop,
    opts = { PATH = "skip" },
  },
  -- LSP configuration
  {
    "neovim/nvim-lspconfig",
    cond = profile.is_desktop,
    config = function()
      if vim.fn.exists(':LspInfo') == 0 then
        vim.api.nvim_create_user_command('LspInfo', ':checkhealth vim.lsp', { desc = 'Alias to `:checkhealth vim.lsp`' })
      end

      local extra_servers = { "ruby_lsp" }

      -- Neovim 0.11+: configure servers through the native LSP API.
      for _, server in ipairs(servers) do
        local opts = make_server_opts(server)
        local default_command = vim.deepcopy(vim.lsp.config[server].cmd)
        opts.cmd = function(dispatchers, config)
          local root = config.root_dir or vim.fn.getcwd()
          local command = vim.deepcopy(default_command)
          command[1] = require("config.tools").resolve(command[1], root)
          return vim.lsp.rpc.start(command, dispatchers, { cwd = root })
        end
        vim.lsp.config(server, opts)
        vim.lsp.enable(server)
      end
      for _, server in ipairs(extra_servers) do
        local opts = make_server_opts(server)
        -- Only enable if mise resolved the binary (fail-fast)
        if opts.cmd and vim.fn.executable(opts.cmd[1]) == 1 then
          vim.lsp.config(server, opts)
          vim.lsp.enable(server)
        end
      end
    end,
  },
}
