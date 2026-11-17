-- Manual formatting; project checks remain the authority for committed code.
return {
  "stevearc/conform.nvim",
  cond = require("config.profile").is_desktop,
  cmd = "ConformInfo",
  opts = {
    default_format_opts = { lsp_format = "never", timeout_ms = 2000 },
    notify_no_formatters = true,
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_format" },
      toml = { "taplo" },
      go = { "goimports", "gofumpt" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt" },
      dockerfile = { "dockerfmt" },
      yaml = { "dprint" },
      ["yaml.docker-compose"] = { "dprint" },
      ["yaml.tmuxinator"] = { "dprint" },
      ["eruby.yaml.tmuxinator"] = {},
      javascript = { "dprint" },
      javascriptreact = { "dprint" },
      typescript = { "dprint" },
      typescriptreact = { "dprint" },
      json = { "dprint" },
      jsonc = { "dprint" },
      json5 = { "dprint" },
      css = { "dprint" },
      graphql = { "dprint" },
      markdown = { "dprint" },
      ruby = {},
    },
    formatters = {
      dockerfmt = {
        -- dockerfmt cannot read EditorConfig on stdin; use the buffer's indentation.
        append_args = function(_, ctx)
          return vim.bo[ctx.buf].expandtab
            and { "--indent", tostring(ctx.shiftwidth) }
            or { "--use-tabs" }
        end,
      },
      dprint = {
        command = "dprint",
        -- dprint discovers the project's config, or its global defaults, from the file's directory.
        cwd = function(_, ctx) return ctx.dirname end,
        -- Conform also checks parent filetypes, including yaml in this ERB filetype.
        condition = function(_, ctx) return vim.bo[ctx.buf].filetype ~= "eruby.yaml.tmuxinator" end,
      },
      shfmt = {
        append_args = function(_, ctx)
          if vim.bo[ctx.buf].filetype == "zsh" then
            -- An explicit dialect disables shfmt's EditorConfig lookup; use buffer indentation.
            return { "-ln", "zsh", "-i", tostring(vim.bo[ctx.buf].expandtab and ctx.shiftwidth or 0) }
          end
          return {}
        end,
      },
    },
  },
}
