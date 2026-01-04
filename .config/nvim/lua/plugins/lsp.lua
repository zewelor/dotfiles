-- lsp — Language Server Protocol for intelligent code features
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
        "bashls",        -- Bash/Zsh
        "yamlls",        -- YAML (K8s, docker-compose)
        "jsonls",        -- JSON
        "helm_ls",       -- Helm charts
        "basedpyright",  -- Python
      },
      automatic_installation = true,
    },
  },
  -- LSP configuration
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      local lspconfig = require("lspconfig")
      local servers = { "lua_ls", "bashls", "yamlls", "jsonls", "helm_ls", "basedpyright" }

      for _, server in ipairs(servers) do
        local opts = {}
        -- lua_ls specific: recognize vim global
        if server == "lua_ls" then
          opts.settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
            },
          }
        end
        lspconfig[server].setup(opts)
      end
    end,
  },
}
