-- telescope.nvim provides a fuzzy finder for files, buffers, and more
local use_native = vim.env.DOTFILES_PROFILE == "desktop" and vim.fn.executable("make") == 1

return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      -- Keep server profiles free of native compilation dependencies.
      enabled = use_native,
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
    if use_native then
      pcall(telescope.load_extension, "fzf")
    end
  end,
}
