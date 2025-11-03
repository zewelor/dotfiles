-- which-key.nvim - pokazuje dostępne keybindings w popup menu
return {
  "folke/which-key.nvim",
  event = "VeryLazy", -- ładuj leniwie dla szybszego startu
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
  config = function(_, opts)
    local wk = require("which-key")

    -- Wymuś ASCII dla ikon, aby uniknąć "niebieskich kwadratów"
    opts = vim.tbl_deep_extend("force", {
      icons = {
        breadcrumb = ">", -- ścieżka na górze popupu
        separator = "->",  -- separator między klawiszem a opisem
        group = "",        -- brak symbolu grupy
        mappings = false,   -- wyłącz ikony przy mapowaniach/rules
        rules = false,
        -- ASCII dla specjalnych klawiszy (zamiast glifów Nerd Font)
        keys = {
          Up = "Up ",
          Down = "Down ",
          Left = "Left ",
          Right = "Right ",
          C = "C-",
          M = "M-",
          D = "D-",
          S = "S-",
          CR = "CR ",
          Esc = "Esc ",
          ScrollWheelDown = "SWD ",
          ScrollWheelUp = "SWU ",
          NL = "Enter ",
          BS = "BS ",
          Space = "SPC ",
          Tab = "TAB ",
          F1 = "F1 ", F2 = "F2 ", F3 = "F3 ", F4 = "F4 ", F5 = "F5 ", F6 = "F6 ",
          F7 = "F7 ", F8 = "F8 ", F9 = "F9 ", F10 = "F10 ", F11 = "F11 ", F12 = "F12 ",
        },
      },
    }, opts or {})

    wk.setup(opts)
  end,
}
