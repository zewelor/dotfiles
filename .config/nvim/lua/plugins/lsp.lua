-- lsp — Language Server Protocol for intelligent code features
local has_nvim_011 = vim.g.dotfiles_has_nvim_011 == true

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
        elseif server == "yamlls" then
          -- ESPHome / HA-style YAML custom tags (avoid "Unresolved tag" diagnostics)
          opts.settings = {
            yaml = {
              customTags = {
                "!secret scalar",
                "!lambda scalar",
                "!include scalar",
                "!include_dir_list scalar",
                "!include_dir_merge_list scalar",
                "!include_dir_merge_named scalar",
              },
            },
          }
        end
        lspconfig[server].setup(opts)
      end
    end,
  },
}
