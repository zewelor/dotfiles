-- conform.nvim — explicit formatting through the manual mapping
local profile = require("config.profile")


return {
  "stevearc/conform.nvim",
  cond = profile.is_desktop,
  cmd = { "ConformInfo", "FormatInfo" },
  config = function(_, opts)
    require("conform").setup(opts)
    vim.api.nvim_create_user_command("FormatInfo", function()
      local plan = require("config.formatting").info(0)
      if plan then
        vim.notify(vim.inspect(plan), vim.log.levels.INFO, { title = "FormatInfo" })
      end
    end, { desc = "Show the current buffer's formatting decision" })
  end,
  opts = {
    notify_no_formatters = false,

    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_format" },
      toml = { "taplo" },
      go = { "goimports", "gofumpt" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt" },
      dockerfile = { "dockerfmt" },

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

      markdown = {},

      ruby = {},
    },

    formatters = {
      dockerfmt = {
        -- dockerfmt cannot read EditorConfig on stdin; use the buffer's indentation.
        append_args = function(_, ctx)
          return vim.bo[ctx.buf].expandtab and { "--indent", tostring(ctx.shiftwidth) } or { "--use-tabs" }
        end,
      },
      project_dprint = function(bufnr)
        return require("config.formatting").project_formatter(bufnr)
      end,
      -- The standalone CLI formats files; stdin support belongs to the npm wrapper.
      oxfmt = function(bufnr)
        local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)) or vim.fn.getcwd()
        local find = require("conform.util").find_executable({ "node_modules/.bin/oxfmt" }, "")
        local local_bin = find(nil, { dirname = dirname })
        if local_bin ~= "" then
          -- Project-owned npm tools retain their upstream stdin/filename contract.
          return { command = local_bin }
        end
        return {
          inherit = false,
          command = function(_, ctx) return require("config.tools").resolve("oxfmt", ctx.dirname) end,
          args = { "$FILENAME" },
          stdin = false,
          tmpfile_format = ".conform.$RANDOM.$FILENAME",
          cwd = function(self, ctx)
            return require("conform.util").root_file({ ".oxfmtrc.json", ".oxfmtrc.jsonc" })(self, ctx)
          end,
        }
      end,
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
