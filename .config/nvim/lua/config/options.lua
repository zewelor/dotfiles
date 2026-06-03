-- Centralized Neovim options
-- This file sets core editor behavior. Loaded from init.lua via require("config.options").

-- Line numbers
vim.opt.number         = true      -- Show absolute number on the current line
vim.opt.relativenumber = true      -- Show relative numbers on other lines

-- UI gutters / colors / cursor
vim.opt.signcolumn     = "yes"     -- Keep sign column visible to avoid text shifting
vim.opt.termguicolors  = true      -- Enable 24-bit colors (truecolor) in terminal
vim.opt.cursorline     = true      -- Highlight the current line

-- System clipboard
-- Keep delete/change operations out of the system clipboard; only yanks copy there.
vim.opt.clipboard      = ""
if vim.env.SSH_CONNECTION or vim.env.SSH_TTY then
  vim.g.clipboard = "osc52"
end
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    if vim.v.event.operator == "y" then
      vim.fn.setreg("+", vim.v.event.regcontents, vim.v.event.regtype)
    end

    vim.highlight.on_yank({ timeout = 150 })
  end,
})
-- Linux tip: install xclip (X11) or wl-clipboard (Wayland)

-- Indentation & tabs
-- Basic indent (expandtab, shiftwidth, tabstop) managed by .editorconfig via editorconfig-vim plugin
-- These options are not supported by editorconfig, so kept here:
vim.opt.softtabstop    = -1        -- Use shiftwidth for <Tab>/<BS> in insert mode (−1 follows shiftwidth)
vim.opt.autoindent     = true      -- Copy indent from current line when starting a new one
vim.opt.smartindent    = true      -- Smart auto-indenting for new lines in many languages
vim.opt.smarttab       = true      -- <Tab> at line start uses shiftwidth (harmless with expandtab)

-- Search behavior
vim.opt.incsearch      = true      -- Incremental search: highlight matches as you type
vim.opt.hlsearch       = true      -- Highlight all search matches
vim.opt.ignorecase     = true      -- Case-insensitive search by default…
vim.opt.smartcase      = true      -- …but case-sensitive if the pattern contains uppercase

-- Files, backups, undo
vim.opt.swapfile       = false     -- Do not create swap files (.swp)
vim.opt.backup         = false     -- Do not create backup files
vim.opt.undofile       = true      -- Persist undo history to an undo file
vim.opt.undolevels     = 10000     -- Generous undo levels per buffer

-- Splits & window management
vim.opt.splitright     = true      -- New vertical splits open to the right
vim.opt.splitbelow     = true      -- New horizontal splits open below
vim.opt.equalalways    = true      -- Keep windows evenly sized when opening/closing splits

-- Faster feedback from LSP/diagnostics and mapped key sequences
vim.opt.updatetime  = 200          -- affects CursorHold, diagnostics refresh
vim.opt.timeoutlen  = 400          -- shorter wait for keymaps (tweak to taste)

-- Scrolling ergonomics
vim.opt.scrolloff     = 4          -- keep N lines of context above/below cursor
vim.opt.sidescrolloff = 8          -- keep N columns of context left/right

-- Safer writes + persistent undo files in XDG location
local state = vim.fn.stdpath("state") -- e.g. ~/.local/state/nvim
vim.opt.undodir     = state .. "/undo//"    -- '//' keeps full path to avoid name collisions
vim.opt.undoreload  = 10000                 -- lines kept when reloading a buffer
vim.opt.writebackup = true                  -- safe write: temp file -> atomic replace
vim.opt.directory   = state .. "/swap//"    -- harmless with swapfile=false; ready if you enable it
vim.opt.backupdir   = state .. "/backup//"  -- used only if you later set backup=true

-- Better completion UX (for nvim-cmp)
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- Small QoL
vim.opt.mouse   = ""              -- disable mouse; keyboard-driven workflow
vim.opt.confirm = true            -- prompt to save when quitting modified buffers

-- Filetype detection
-- Helm chart templates should use `helm` filetype so helm_ls can attach.
vim.filetype.add({
  filename = {
    ["fdockerfile"] = "dockerfile",
  },
  pattern = {
    [".*/[fF][dD]ockerfile[^/]*"] = "dockerfile",
    [".*/templates/.*%.ya?ml"] = "helm",
    [".*/templates/.*%.tpl"] = "helm",
    [".*/%.tmuxinator/.*%.ya?ml"] = function(path, bufnr)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for _, line in ipairs(lines) do
        if line:match("<%%[=#%-]?") then
          return "eruby.yaml.tmuxinator"
        end
      end

      return "yaml.tmuxinator"
    end,
    [".*%.gotmpl"] = "helm",
  },
})
