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
  dependencies = { "williamboman/mason.nvim" },
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

      markdown = {},

      ruby = function(bufnr)
        if rubocop_project_root(bufnr) then
          return { "rubocop" }
        end

        return { "rubyfmt" }
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
      shfmt = {
        append_args = { "-i", "2" },
      },
    },
  },
}
