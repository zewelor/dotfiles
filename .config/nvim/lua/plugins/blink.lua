-- Completion engine powered by blink.cmp for modern autocompletion features
local dependencies = {
  -- optional: provides snippets for the snippet source
  'rafamadriz/friendly-snippets',
}

local source_defaults = { 'lsp', 'path', 'snippets', 'buffer' }
local providers = {
  -- Keep buffer words as a fallback to LSP, matching the recommended blink.cmp setup.
  lsp = {
    fallbacks = { 'buffer' },
  },
}

return {
  'saghen/blink.cmp',
  dependencies = dependencies,

  -- use a release tag to download pre-built binaries
  version = '1.*',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
    -- 'super-tab' for mappings similar to vscode (tab to accept)
    -- 'enter' for enter to accept
    -- 'none' for no mappings
    --
    -- All presets have the following mappings:
    -- C-space: Open menu or open docs if already open
    -- C-n/C-p or Up/Down: Select next/previous item
    -- C-e: Hide menu
    -- C-k: Toggle signature help (if signature.enabled = true)
    --
    -- See :h blink-cmp-config-keymap for defining your own keymap
    -- Enter accepts a selected suggestion; Tab remains available for snippets and indentation.
    keymap = { preset = 'enter' },

    cmdline = {
      keymap = {
        preset = 'cmdline',
        -- Keep Left/Right for editing the command text instead of cycling items.
        ['<Left>'] = false,
        ['<Right>'] = false,
        -- Navigate completion items when the menu is open; fall back to command history otherwise.
        ['<Up>'] = { 'select_prev', 'fallback' },
        ['<Down>'] = { 'select_next', 'fallback' },
      },
      completion = {
        -- Avoid preselecting so Enter runs the typed command unless an item is explicitly picked.
        list = {
          selection = {
            preselect = function()
              return vim.fn.getcmdtype() ~= ':'
            end,
          },
        },
        menu = {
          auto_show = function(ctx)
            return ctx.mode == 'cmdwin' or vim.fn.getcmdtype() == ':'
          end,
        },
      },
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono'
    },

    -- (Default) Only show the documentation popup when manually triggered
    completion = {
      documentation = { auto_show = false },
      -- Keep Enter as a newline until a completion is explicitly selected.
      list = { selection = { preselect = false } },
      menu = {
        auto_show_delay_ms = function(ctx)
          return ctx.mode == 'cmdline' and 0 or 2000
        end,
      },
    },

    -- Default list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    sources = {
      default = source_defaults,
      providers = providers,
    },

    -- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
    -- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
    -- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
    --
    -- See the fuzzy documentation for more information
    fuzzy = { implementation = "prefer_rust_with_warning" }
  },
  opts_extend = { "sources.default" }
}
