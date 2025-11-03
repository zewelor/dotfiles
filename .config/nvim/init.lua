-- Set light background early, before lazy.nvim loads plugins
vim.o.background = "light"

require("config.lazy")

-- Core Neovim options (moved to a dedicated module)
require("config.options")


