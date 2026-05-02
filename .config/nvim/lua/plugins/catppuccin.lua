-- catppuccin/nvim — soothing pastel theme for Neovim
-- Source: https://github.com/catppuccin/nvim
return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    flavour = "latte",
    transparent_background = true,
  },
  config = function(_, opts)
    vim.o.termguicolors = true
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
