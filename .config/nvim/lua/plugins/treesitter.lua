-- nvim-treesitter — Tree-sitter parsers and queries (Neovim 0.11+)
local has_nvim_011 = vim.g.dotfiles_has_nvim_011 == true

return {
  "nvim-treesitter/nvim-treesitter",
  enabled = has_nvim_011,
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup({
      -- Install parsers and queries into Neovim's site directory.
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    -- Enable tree-sitter highlighting for commonly used filetypes.
    local group = vim.api.nvim_create_augroup("DotfilesTreesitter", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = {
        "lua",
        "vim",
        "vimdoc",
        "query",
        "sh",
        "bash",
        "zsh",
        "python",
        "json",
        "jsonc",
        "yaml",
        "toml",
        "markdown",
        "dockerfile",
        "gitconfig",
        "gitcommit",
        "diff",
        "helm",
      },
      callback = function(args)
        -- `vim.treesitter.start()` is built into Neovim and uses installed parsers.
        pcall(vim.treesitter.start, args.buf)
      end,
      desc = "Start tree-sitter highlighting",
    })
  end,
}
