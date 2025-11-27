-- Keymaps
-- This file defines custom key mappings
-- Loaded from init.lua via require("config.keymaps")

-- Helper references for brevity
local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ============================================================================
-- LEADER KEY MAPPINGS (Leader = Space)
-- ============================================================================

-- Neo-tree: File Explorer
keymap("n", "<leader>e", ":Neotree toggle<CR>", { desc = "Toggle Neo-tree file explorer" })
keymap("n", "<leader>o", ":Neotree focus<CR>", { desc = "Focus Neo-tree" })

-- Search: Telescope
keymap("n", "<leader>ff", function()
	require("telescope.builtin").find_files()
end, { desc = "Find files (Telescope)" })
keymap("n", "<leader>fg", function()
	require("telescope.builtin").live_grep()
end, { desc = "Live grep (Telescope)" })

-- Quick save and quit
keymap("n", "<leader>w", ":w<CR>", { desc = "Save file" })
keymap("n", "<leader>q", ":q<CR>", { desc = "Quit" })
keymap("n", "<leader>Q", ":qa!<CR>", { desc = "Quit all without saving" })

-- Buffers (open files)
-- keymap("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete current buffer" })
-- keymap("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" })
-- keymap("n", "<leader>bp", ":bprevious<CR>", { desc = "Previous buffer" })

-- Windows (splits)
keymap("n", "<leader>sv", ":vsplit<CR>", { desc = "Split window vertically" })
keymap("n", "<leader>sh", ":split<CR>", { desc = "Split window horizontally" })
keymap("n", "<leader>sc", ":close<CR>", { desc = "Close current split" })

-- Clear search highlight
-- keymap("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- ============================================================================
-- OTHER USEFUL MAPPINGS (non-leader)
-- ============================================================================

-- Align text (mini.align) – keep mappings here to follow repo rule
keymap("n", "ga", function()
	-- Use operatorfunc so the next motion selects the region to align
	vim.o.operatorfunc = "v:lua.MiniAlign.align_user"
	return "g@"
end, { expr = true, desc = "Align (mini.align)" })
keymap("x", "ga", function()
	local mode = ({ v = "char", V = "line", ["\22"] = "block" })[vim.fn.mode(1)]
	require("mini.align").align_user(mode)
end, { desc = "Align selection (mini.align)" })

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Circular window navigation (like in .vimrc)
keymap("n", "<Tab>", "<C-w>w", { desc = "Cycle to next window" })
keymap("n", "<S-Tab>", "<C-w>W", { desc = "Cycle to previous window" })

-- Resize windows
keymap("n", "<C-Up>", ":resize +2<CR>", opts)
keymap("n", "<C-Down>", ":resize -2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Better indentation in Visual mode
keymap("v", "<", "<gv", { desc = "Indent left and reselect" })
keymap("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Keep sign column hidden whenever line numbers are disabled to remove the gutter.
keymap("n", "<C-n><C-n>", function()
	local number = vim.wo.number
	local relativenumber = vim.wo.relativenumber

	if not number and not relativenumber then
		-- currently off → switch to absolute
		vim.wo.number = true
		vim.wo.relativenumber = false
		vim.wo.signcolumn = "yes"
		if vim.notify then vim.notify("Line numbers: absolute", vim.log.levels.INFO, { title = "Numbers" }) end
	elseif number and not relativenumber then
		-- absolute → switch to relative
		vim.wo.number = true
		vim.wo.relativenumber = true
		vim.wo.signcolumn = "yes"
		if vim.notify then vim.notify("Line numbers: relative", vim.log.levels.INFO, { title = "Numbers" }) end
	else
		-- relative (or any other state) → turn off
		vim.wo.number = false
		vim.wo.relativenumber = false
		vim.wo.signcolumn = "no"
		if vim.notify then vim.notify("Line numbers: off", vim.log.levels.INFO, { title = "Numbers" }) end
	end
end, { desc = "Cycle line numbers (off → abs → rel)" })

-- Save file with Ctrl+S (based on legacy .vimrc behavior)
keymap("n", "<C-s>", ":w<CR>", { desc = "Save file" })
keymap("i", "<C-s>", "<Esc>:w<CR>", { desc = "Save file" })

-- Comment toggling (Neovim 0.10+ built-in 'gc')
-- Note: terminals send Ctrl+/ as <C-_>
keymap("n", "<C-_>", "gcc", { remap = true, silent = true, desc = "Toggle comment line" })
keymap("x", "<C-_>", "gc",  { remap = true, silent = true, desc = "Toggle comment selection" })
