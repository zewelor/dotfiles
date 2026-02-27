-- Set light background early, before lazy.nvim loads plugins
vim.o.background = "light"

-- For Neovim < 0.11: mock missing vim.lsp.enable (auto-removes on upgrade)
if vim.version().minor < 11 then
  vim.lsp.enable = function() end
end

require("config.lazy")

-- Core Neovim options (moved to a dedicated module)
require("config.options")

-- Keymaps (custom keyboard shortcuts)
require("config.keymaps")


