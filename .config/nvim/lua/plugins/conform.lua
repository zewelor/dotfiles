-- conform.nvim — formatting engine (format-on-save)
return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
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
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "beautysh" },

      yaml = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == "yaml.tmuxinator" or ft == "eruby.yaml.tmuxinator" then
          return {}
        end

        return { "prettier" }
      end,
      ["yaml.tmuxinator"] = { "prettier" },
      ["eruby.yaml.tmuxinator"] = {},
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
