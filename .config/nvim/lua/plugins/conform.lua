-- conform.nvim — formatting engine (format-on-save)
return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    -- Disable autoformat for Markdown (manual formatting still possible).
    format_on_save = function(bufnr)
      if vim.bo[bufnr].filetype == "markdown" then
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
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt" },

      yaml = { "prettier" },
      ["yaml.docker-compose"] = { "prettier" },

      json = { "prettier" },
      jsonc = { "prettier" },
      json5 = { "prettier" },
    },

    formatters = {
      shfmt = {
        append_args = { "-i", "2" },
      },
    },
  },
}
