-- nvim-treesitter — Tree-sitter parsers and queries (Neovim 0.11+)
local needed = {
  "lua", "vim", "vimdoc", "query", "bash", "python",
  "json", "yaml", "toml", "markdown", "markdown_inline",
  "dockerfile", "git_config", "gitcommit", "diff", "helm",
  "go",
}
local function incomplete()
  local config = require("nvim-treesitter.config")
  return vim.tbl_filter(function(lang)
    return vim.fn.filereadable(config.get_install_dir("parser") .. "/" .. lang .. ".so") == 0
      or vim.fn.filereadable(config.get_install_dir("queries") .. "/" .. lang .. "/highlights.scm") == 0
  end, needed)
end
return {
  "nvim-treesitter/nvim-treesitter",
  -- This revision supports Neovim 0.11; newer main requires Neovim 0.12.
  -- Upgrade this together with our supported Neovim version and parser acceptance.
  commit = "f873ec2955098fc4b7c3abfe891bdd49fa7947e2",
  -- Server profiles use built-in syntax highlighting without parser compilation.
  enabled = vim.env.DOTFILES_PROFILE == "desktop",
  -- Maintenance must check out the compatible revision before loading its Lua modules.
  lazy = vim.g.dotfiles_maintenance == true,
  dotfiles_install_parsers = function()
    -- Upstream treats a parser alone as installed, even after query installation failed.
    -- Force only incomplete languages; healthy parsers keep their existing build.
    local missing = incomplete()
    if #missing > 0 then
      -- Reset only incomplete assets; force=true would also rebuild healthy dependencies.
      require("nvim-treesitter").uninstall(missing):wait(300000)
      assert(require("nvim-treesitter").install(missing):wait(300000),
        "Tree-sitter parser installation failed")
    end
    assert(#incomplete() == 0, "Tree-sitter parser installation incomplete: missing parser or highlights")
  end,
  config = function()
    require("nvim-treesitter").setup({
      -- Install parsers and queries into Neovim's site directory.
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

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

    if not vim.g.dotfiles_maintenance then
      local missing = incomplete()
      if #missing > 0 then
        -- Startup installs only incomplete languages; version updates remain explicit.
        local function finished(err, ok)
          if err or not ok or #incomplete() > 0 then
            vim.notify("Tree-sitter parser installation failed: " .. tostring(err or "missing parser or highlights")
              .. "; run make install-neovim for diagnostics", vim.log.levels.ERROR)
            return
          end
          -- FileType may have fired before the parser was available.
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf)
                and vim.tbl_contains(missing, vim.treesitter.language.get_lang(vim.bo[buf].filetype)) then
              local started, reason = pcall(vim.treesitter.start, buf)
              if not started then
                vim.notify("Tree-sitter highlighting failed: " .. tostring(reason), vim.log.levels.ERROR)
              end
            end
          end
        end
        local treesitter = require("nvim-treesitter")
        -- Uninstall skips dependencies; the normal installer then preserves healthy ones.
        treesitter.uninstall(missing):await(vim.schedule_wrap(function(err)
          if err then
            finished(err, false)
          else
            treesitter.install(missing):await(vim.schedule_wrap(finished))
          end
        end))
      end
    end
  end,
}
