-- conform.nvim — formatting engine (format-on-save)
local profile = require("config.profile")

local function rubocop_project_root(bufnr)
  local root = vim.fs.root(bufnr, ".rubocop.yml")

  if root and vim.fn.filereadable(root .. "/Gemfile") == 1 then
    return root
  end

  return nil
end

return {
  "stevearc/conform.nvim",
  cond = profile.is_desktop,
  event = { "BufReadPre", "BufNewFile" },
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

    format_on_save = function(bufnr)
      -- The shared wrapper already formats synchronously; avoid a second dispatch.
      require("config.formatting").format(bufnr, "save")
      return nil
    end,

    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_format" },
      toml = { "taplo" },
      go = { "goimports", "gofumpt" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt" },

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

      ruby = function(bufnr)
        if rubocop_project_root(bufnr) then
          return { "rubocop" }
        end

        return {} -- Standalone Ruby formatting is an explicit optional action.
      end,
    },

    formatters = {
      project_dprint = function(bufnr)
        return require("config.formatting").project_formatter(bufnr)
      end,
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
      stylua = { command = function(_, ctx) return require("config.tools").resolve("stylua", ctx.dirname) end },
      ruff_format = { command = function(_, ctx) return require("config.tools").resolve("ruff", ctx.dirname) end },
      taplo = { command = function(_, ctx) return require("config.tools").resolve("taplo", ctx.dirname) end },
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
      yamlfmt = { command = function(_, ctx) return require("config.tools").resolve("yamlfmt", ctx.dirname) end },
      goimports = { command = function(_, ctx) return require("config.tools").resolve("goimports", ctx.dirname) end },
      gofumpt = { command = function(_, ctx) return require("config.tools").resolve("gofumpt", ctx.dirname) end },
      shfmt = {
        command = function(_, ctx) return require("config.tools").resolve("shfmt", ctx.dirname) end,
        append_args = function(_, ctx)
          if vim.bo[ctx.buf].filetype == "zsh" then
            return { "-i", "2", "-ln", "zsh" }
          end
          return { "-i", "2" }
        end,
      },
    },
  },
}
