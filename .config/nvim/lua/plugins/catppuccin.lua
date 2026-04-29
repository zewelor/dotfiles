-- catppuccin/nvim — soothing pastel theme for Neovim
return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    flavour = "latte",
  },
  config = function(_, opts)
    vim.o.termguicolors = true
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
