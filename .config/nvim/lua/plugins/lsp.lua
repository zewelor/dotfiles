-- lsp — Language Server Protocol for intelligent code features
local profile = require("config.profile")

local servers = require("config.tools").servers

return {
  -- LSP configuration
  {
    "neovim/nvim-lspconfig",
    cond = profile.is_desktop,
    config = function()
      if vim.fn.exists(':LspInfo') == 0 then
        vim.api.nvim_create_user_command('LspInfo', ':checkhealth vim.lsp', { desc = 'Alias to `:checkhealth vim.lsp`' })
      end

      -- Neovim 0.11+: configure servers through the native LSP API.
      for _, server in ipairs(servers) do
        local opts = {}
        if server == "helm_ls" then
          opts.filetypes = { "helm" }
        end
        vim.lsp.config(server, opts)
        vim.lsp.enable(server)
      end
    end,
  },
}
