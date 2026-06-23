-- lsp — Language Server Protocol for intelligent code features
local has_nvim_011 = vim.g.dotfiles_has_nvim_011 == true

-- Resolve a mise-managed binary path (works with `mise activate` PATH, no shims needed).
-- Some Mason Ruby gem wrappers can keep stale shebangs after a Ruby upgrade, so
-- Ruby tools prefer mise before falling back to PATH.
local function mise_bin(tool, opts)
  opts = opts or {}
  if opts.prefer_mise then
    local path = vim.fn.system({ "mise", "which", tool }):gsub("%s+$", "")
    if vim.v.shell_error == 0 and path ~= "" then
      return path
    end
  end

  if vim.fn.executable(tool) == 1 then
    return tool
  end
  local path = vim.fn.system({ "mise", "which", tool }):gsub("%s+$", "")
  if vim.v.shell_error ~= 0 or path == "" then
    return nil
  end
  return path
end

-- Build per-server opts table (shared between 0.11+ and <0.11 paths)
local function make_server_opts(server)
  local opts = {}
  if server == "lua_ls" then
    opts.settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false },
      },
    }
  elseif server == "helm_ls" then
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
  -- Mason: LSP server manager
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    opts = {},
  },
  -- Bridge between mason and lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = {
        "lua_ls",        -- Lua (Neovim config)
        "helm_ls",       -- Helm charts
        "ruff",          -- Python (lightweight LSP / linter / formatter)
        "taplo",         -- TOML (compiled LSP / formatter)
        "marksman",      -- Markdown
        "gopls",         -- Go
      },
      automatic_installation = true,
      -- Neovim 0.11 introduced `vim.lsp.enable()` / `vim.lsp.config()`. Newer
      -- mason-lspconfig versions use that API for auto-enabling; keep it off on 0.10.
      automatic_enable = has_nvim_011,
    },
  },
  -- LSP configuration
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      if vim.fn.exists(':LspInfo') == 0 then
        vim.api.nvim_create_user_command('LspInfo', ':checkhealth vim.lsp', { desc = 'Alias to `:checkhealth vim.lsp`' })
      end

      local mason_servers = { "lua_ls", "helm_ls", "ruff", "taplo", "marksman", "gopls" }
      local extra_servers = { "ruby_lsp" }

      if has_nvim_011 then
        -- Neovim 0.11+: use native vim.lsp.config() + vim.lsp.enable().
        -- mason-lspconfig handles vim.lsp.enable() for Mason-managed servers.

        for _, server in ipairs(mason_servers) do
          vim.lsp.config(server, make_server_opts(server))
        end
        for _, server in ipairs(extra_servers) do
          local opts = make_server_opts(server)
          -- Only enable if mise resolved the binary (fail-fast)
          if opts.cmd and vim.fn.executable(opts.cmd[1]) == 1 then
            vim.lsp.config(server, opts)
            vim.lsp.enable(server)
          end
        end
      else
        -- Neovim <0.11: fall back to deprecated lspconfig.setup() API.
        local lspconfig = require("lspconfig")
        local all_servers = vim.list_extend(vim.deepcopy(mason_servers), extra_servers)
        for _, server in ipairs(all_servers) do
          lspconfig[server].setup(make_server_opts(server))
        end
      end
    end,
  },
}
