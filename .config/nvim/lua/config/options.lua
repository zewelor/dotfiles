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
vim.opt.clipboard      = "unnamedplus" -- Use the system clipboard for all yanks/pastes
-- Linux tip: install xclip (X11) or wl-clipboard (Wayland)

-- Indentation & tabs (project defaults; override per filetype in after/ftplugin)
vim.opt.expandtab      = true      -- Insert spaces when pressing <Tab>
vim.opt.shiftwidth     = 2         -- Autoindent width and << / >> shift size
vim.opt.tabstop        = 2         -- Display width of a literal <Tab> character
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
vim.opt.mouse   = "a"             -- quick resize/click when needed
vim.opt.confirm = true            -- prompt to save when quitting modified buffers
