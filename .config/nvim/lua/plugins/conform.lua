-- conform.nvim — formatting engine (format-on-save)
return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    notify_no_formatters = false,

    -- Disable autoformat for Markdown/Dockerfile (manual formatting still possible).
    format_on_save = function(bufnr)
      local ft = vim.bo[bufnr].filetype
      local is_tmuxinator = ft == "eruby.yaml.tmuxinator"

      if ft == "markdown" or ft == "dockerfile" or is_tmuxinator then
        return nil
      end

      return {
        timeout_ms = 2000,
        lsp_format = "fallback",
      }
    end,

    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_format" },
      toml = { "taplo" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "beautysh" },

      javascript = { "oxfmt" },
      javascriptreact = { "oxfmt" },
      typescript = { "oxfmt" },
      typescriptreact = { "oxfmt" },
      css = { "oxfmt" },
      graphql = { "oxfmt" },

      yaml = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == "yaml.tmuxinator" or ft == "eruby.yaml.tmuxinator" then
          return {}
        end

        return { "yamlfmt" }
      end,
      ["yaml.tmuxinator"] = { "yamlfmt" },
      ["eruby.yaml.tmuxinator"] = {},
      ["yaml.docker-compose"] = { "yamlfmt" },

       json = { "oxfmt" },
       jsonc = { "oxfmt" },
       json5 = { "oxfmt" },

       ruby = { "rubyfmt" },
     },

    formatters = {
      shfmt = {
        append_args = { "-i", "2" },
      },
    },
  },
}
