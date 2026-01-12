-- ~/.config/nvim/lua/config/lazy.lua
-- Structured Setup per lazy.nvim documentation

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before loading lazy.nvim
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Shared feature flags for plugin specs.
-- Keep this before `lazy.setup()` so `lua/plugins/*.lua` can read it.
vim.g.dotfiles_has_nvim_011 = vim.fn.has("nvim-0.11") == 1

-- nvim-lspconfig started warning loudly on Neovim <0.11 via its runtime plugin file.
-- The module still works fine for our usage, so skip the runtime plugin on older Neovim.
if not vim.g.dotfiles_has_nvim_011 then
  vim.g.lspconfig = 1
end

-- Setup lazy.nvim
require("lazy").setup({
  -- import your plugins from lua/plugins
  spec = {
    { import = "plugins" },
  },
  -- automatically check for plugin updates
  checker = {
    enabled = true,
    frequency = 604800 -- check every week
  },
})
