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
    -- Markdown is only autoformatted on save if a dprint.json config file is present.
    format_on_save = function(bufnr)
      local ft = vim.bo[bufnr].filetype
      local is_tmuxinator = ft == "eruby.yaml.tmuxinator"

      if ft == "markdown" then
        local name = vim.api.nvim_buf_get_name(bufnr)
        local has_dprint = name ~= "" and vim.fs.find({ "dprint.json" }, { path = name, upward = true })[1] ~= nil
        if not has_dprint then
          return nil
        end
      elseif ft == "dockerfile" or is_tmuxinator then
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

      javascript = { "dprint", "oxfmt", stop_after_first = true },
      javascriptreact = { "dprint", "oxfmt", stop_after_first = true },
      typescript = { "dprint", "oxfmt", stop_after_first = true },
      typescriptreact = { "dprint", "oxfmt", stop_after_first = true },
      css = { "dprint", "oxfmt", stop_after_first = true },
      graphql = { "dprint", "oxfmt", stop_after_first = true },

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

      json = { "dprint", "oxfmt", stop_after_first = true },
      jsonc = { "dprint", "oxfmt", stop_after_first = true },
      json5 = { "dprint", "oxfmt", stop_after_first = true },

      markdown = { "dprint" },

      ruby = function(bufnr)
        if rubocop_project_root(bufnr) then
          return { "rubocop" }
        end

        return { "rubyfmt" }
      end,
    },

    formatters = {
      dprint = {
        condition = function(self, ctx)
          return vim.fs.find({ "dprint.json" }, { path = ctx.filename, upward = true })[1] ~= nil
        end,
      },
      rubocop = function(bufnr)
        local root = rubocop_project_root(bufnr)

        return {
          command = function()
            local bin = root and (root .. "/bin/rubocop") or nil

            if bin and vim.fn.executable(bin) == 1 then
              return bin
            end

            return root and "bundle" or "rubocop"
          end,
          args = function(self, ctx)
            local args = vim.deepcopy(require("conform.formatters.rubocop").args)
            local bin = root and (root .. "/bin/rubocop") or nil

            if root and not (bin and vim.fn.executable(bin) == 1) then
              args = { "exec", "rubocop", unpack(args) }
            end

            return args
          end,
          cwd = function()
            return root
          end,
          env = { RUBOCOP_CACHE_ROOT = "tmp/rubocop" },
        }
      end,
      shfmt = {
        append_args = { "-i", "2" },
      },
    },
  },
}
