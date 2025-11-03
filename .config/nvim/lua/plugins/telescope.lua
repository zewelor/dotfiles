-- telescope.nvim provides a fuzzy finder for files, buffers, and more
return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      cond = function()
        return vim.fn.executable("make") == 1
      end,
    },
  },
  config = function()
    local telescope = require("telescope")
    local opts = {}

    if vim.fn.executable("fd") == 1 then
      opts.pickers = {
        find_files = {
          find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" },
        },
      }
    end

    telescope.setup(opts)
    pcall(telescope.load_extension, "fzf")
  end,
}
