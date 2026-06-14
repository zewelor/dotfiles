-- conform.nvim — formatting engine (format-on-save)
local function rubocop_project_root(bufnr)
  local root = vim.fs.root(bufnr, ".rubocop.yml")

  if root and vim.fn.filereadable(root .. "/Gemfile") == 1 then
    return root
  end

  return nil
end

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

      ruby = function(bufnr)
        if rubocop_project_root(bufnr) then
          return { "rubocop" }
        end

        return { "rubyfmt" }
      end,
    },

    formatters = {
      rubocop = function(bufnr)
        local root = rubocop_project_root(bufnr)
        local bin = root and (root .. "/bin/rubocop") or nil

        return {
          command = bin and vim.fn.executable(bin) == 1 and bin or "rubocop",
          args = { "-a", "-f", "quiet", "--stderr", "--stdin", "$FILENAME" },
          cwd = root,
          env = { RUBOCOP_CACHE_ROOT = "tmp/rubocop" },
          exit_codes = { 0, 1 },
        }
      end,
      shfmt = {
        append_args = { "-i", "2" },
      },
    },
  },
}
