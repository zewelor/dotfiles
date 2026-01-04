-- nvim-treesitter — Better syntax highlighting and code understanding
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    ensure_installed = {
      "lua", "vim", "vimdoc", "query",  -- Neovim essentials
      "bash",                            -- Shell scripts (.zshrc)
      "python",                          -- Python
      "json", "yaml", "toml",            -- Config files
      "markdown", "markdown_inline",     -- Documentation
      "dockerfile",                      -- Docker
      "git_config", "gitcommit", "diff", -- Git
    },
    highlight = { enable = true },
    indent = { enable = true },
  },
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}
