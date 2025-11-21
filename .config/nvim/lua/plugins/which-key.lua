-- which-key.nvim - pokazuje dostępne keybindings w popup menu
return {
  "folke/which-key.nvim",
  event = "VeryLazy", -- ładuj leniwie dla szybszego startu
  opts = {
    -- auto-expand groups with a single mapping (e.g. <leader>g)
    expand = 1,
    delay = function(ctx)
      -- no delay for built‑in plugins; 500 ms otherwise
      return ctx.plugin and 0 or 500
    end,
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = true })
      end,
      desc = "Global Keymaps (which-key)",
    },
  },
  config = function(_, opts)
    -- Use which-key defaults, including Nerd Font icons
    require("which-key").setup(opts)
  end,
}
