-- lsp — Language Server Protocol for intelligent code features
local profile = require("config.profile")

local tools = require("config.tools")
local servers = tools.servers

-- Build the per-server options shared by the native LSP configurations.
local function make_server_opts(server)
  local opts = {}
  if server == "helm_ls" then
    opts.filetypes = { "helm" }
  elseif server == "ruby_lsp" then
    local failed_roots = {}
    opts.root_dir = function(bufnr, on_dir)
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename == "" then
        return
      end
      -- Standalone files use their directory rather than Neovim's startup cwd.
      local root = vim.fs.root(bufnr, { "Gemfile", ".git" }) or vim.fs.dirname(filename)
      if not failed_roots[root] then
        on_dir(root)
      end
    end
    opts.cmd = function(dispatchers, config)
      local root = config.root_dir
      local ok, rpc = pcall(function()
        -- With auto-install disabled, mise exec can otherwise use Ruby from PATH.
        tools.resolve("ruby", root)
        local path = tools.resolve("ruby-lsp", root)
        local on_exit = dispatchers.on_exit
        dispatchers.on_exit = function(code, signal)
          -- Native Neovim also ignores SIGTERM from an explicit client stop.
          if code ~= 0 or (signal ~= 0 and signal ~= 15) then
            failed_roots[root] = true
            vim.schedule(function()
              local message = ("Ruby LSP [%s]: exited with code %s, signal %s; see :LspLog"):format(root, code, signal)
              vim.notify_once(message, vim.log.levels.ERROR)
            end)
          end
          on_exit(code, signal)
        end
        -- mise selects Ruby's environment; Ruby LSP must compose its own bundle.
        return vim.lsp.rpc.start({
          vim.fn.exepath("mise"), "-C", root, "exec", "--",
          vim.fn.exepath("env"), "-u", "BUNDLE_GEMFILE", path,
        }, dispatchers, {
          cwd = root,
          env = { MISE_AUTO_INSTALL = "false" },
        })
      end)
      if not ok then
        failed_roots[root] = true
        error("Ruby LSP [" .. root .. "]: " .. rpc, 0)
      end
      return rpc
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
          command[1] = tools.resolve(command[1], root)
          return vim.lsp.rpc.start(command, dispatchers, { cwd = root })
        end
        vim.lsp.config(server, opts)
        vim.lsp.enable(server)
      end
      for _, server in ipairs(extra_servers) do
        vim.lsp.config(server, make_server_opts(server))
        vim.lsp.enable(server)
      end
    end,
  },
}
