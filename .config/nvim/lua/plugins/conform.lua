-- conform.nvim — formatting engine (format-on-save)
return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    -- Disable autoformat for Markdown/Dockerfile (manual formatting still possible).
    format_on_save = function(bufnr)
      local ft = vim.bo[bufnr].filetype
      local filename = vim.api.nvim_buf_get_name(bufnr)
      local is_tmuxinator = filename:match("/%.tmuxinator/.*%.yml$") or filename:match("/%.tmuxinator/.*%.yaml$")

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
        local filename = vim.api.nvim_buf_get_name(bufnr)
        -- tmuxinator allows ERB/Ruby inside YAML, which prettier cannot parse.
        if filename:match("/%.tmuxinator/.*%.yml$") or filename:match("/%.tmuxinator/.*%.yaml$") then
          return {}
        end

        return { "prettier" }
      end,
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
