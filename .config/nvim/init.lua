-- Bootstrap lazy.nvim and core configuration

-- This configuration relies on Neovim's native LSP API introduced in 0.11.
if vim.fn.has("nvim-0.11") ~= 1 then
  error("This configuration requires Neovim 0.11 or newer")
end

-- An editor command must not implicitly install a missing mise tool.
vim.env.MISE_AUTO_INSTALL = "false"

require("config.lazy")

-- Core Neovim options (moved to a dedicated module)
require("config.options")

-- Keymaps (custom keyboard shortcuts)
require("config.keymaps")

-- Open existing file:line references without an external plugin.
require("config.fileline")
