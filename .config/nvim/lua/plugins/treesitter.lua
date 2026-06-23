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

    -- Auto-install commonly used parsers if missing.
    -- nvim-treesitter 1.0+ removed ensure_installed from setup();
    -- install() is async and handles missing parsers gracefully.
    local needed = {
      "lua", "vim", "vimdoc", "query", "bash", "python",
      "json", "yaml", "toml", "markdown", "markdown_inline",
      "dockerfile", "git_config", "gitcommit", "diff", "helm",
      "go",
    }
    local installed = require("nvim-treesitter.config").get_installed()
    local missing = {}
    for _, lang in ipairs(needed) do
      if not vim.tbl_contains(installed, lang) then
        table.insert(missing, lang)
      end
    end
    if #missing > 0 then
      require("nvim-treesitter").install(missing)
    end

    vim.treesitter.language.register("yaml", { "yaml.tmuxinator", "eruby.yaml.tmuxinator" })

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
        "yaml.tmuxinator",
        "eruby.yaml.tmuxinator",
        "toml",
        "markdown",
        "dockerfile",
        "gitconfig",
        "gitcommit",
        "diff",
        "helm",
        "go",
      },
      callback = function(args)
        -- `vim.treesitter.start()` is built into Neovim and uses installed parsers.
        pcall(vim.treesitter.start, args.buf)
      end,
      desc = "Start tree-sitter highlighting",
    })
  end,
}
