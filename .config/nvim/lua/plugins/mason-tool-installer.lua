-- mason-tool-installer — auto-install formatters and linters
return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  dependencies = { "williamboman/mason.nvim" },
  event = "VeryLazy",
  opts = {
    ensure_installed = {
      -- Formatters used by conform.nvim
      "stylua",
      "shfmt",
      "ruff",
      "prettier",

      -- Useful CLI tools
      "hadolint",
    },
    auto_update = false,
    run_on_start = true,
    start_delay = 3000, -- ms
  },
}
