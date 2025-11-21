-- snacks.nvim — floating LazyGit integration via Snacks.lazygit
return {
  -- https://github.com/folke/snacks.nvim/tree/main
  "folke/snacks.nvim",
  cond = function()
    return vim.fn.executable("lazygit") == 1
  end,
  opts = {
    lazygit = { enabled = true },
  },

  keys = {
    { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
  }
}
