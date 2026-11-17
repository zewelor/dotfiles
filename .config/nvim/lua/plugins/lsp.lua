-- Native LSP defaults for optional navigation and diagnostics on the desktop.
return {
  "neovim/nvim-lspconfig",
  cond = require("config.profile").is_desktop,
  config = function()
    if vim.fn.exists(':LspInfo') == 0 then
      vim.api.nvim_create_user_command('LspInfo', ':checkhealth vim.lsp', { desc = 'Alias to `:checkhealth vim.lsp`' })
    end
    -- Tools come from the editor's PATH; project/container runtime selection is external.
    vim.lsp.config("*", { cmd_env = { MISE_AUTO_INSTALL = "false" } })
    vim.lsp.config("helm_ls", { filetypes = { "helm" } })
    vim.lsp.enable({
      "helm_ls",  -- Helm chart LSP
      "ruff",     -- Python LSP, linting and formatting
      "taplo",    -- TOML LSP and formatting
      "marksman", -- Markdown LSP
      "gopls",    -- Go LSP (Conform owns formatting)
    })
  end,
}
