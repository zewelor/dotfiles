-- Keymaps (skróty klawiszowe)
-- Ten plik definiuje własne mapowania klawiszy
-- Ładowany z init.lua przez require("config.keymaps")

-- Funkcja pomocnicza dla czytelności
local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ============================================================================
-- LEADER KEY MAPPINGS (Leader = Spacja)
-- ============================================================================

-- Neo-tree: File Explorer
keymap("n", "<leader>e", ":Neotree toggle<CR>", { desc = "Toggle Neo-tree file explorer" })
keymap("n", "<leader>o", ":Neotree focus<CR>", { desc = "Focus Neo-tree" })

-- Wyszukiwanie: Telescope
keymap("n", "<leader>ff", function()
	require("telescope.builtin").find_files()
end, { desc = "Find files (Telescope)" })
keymap("n", "<leader>fg", function()
	require("telescope.builtin").live_grep()
end, { desc = "Live grep (Telescope)" })

-- Szybkie zapisywanie i wychodzenie
keymap("n", "<leader>w", ":w<CR>", { desc = "Save file" })
keymap("n", "<leader>q", ":q<CR>", { desc = "Quit" })
keymap("n", "<leader>Q", ":qa!<CR>", { desc = "Quit all without saving" })

-- Bufory (otwarte pliki)
-- keymap("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete current buffer" })
-- keymap("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" })
-- keymap("n", "<leader>bp", ":bprevious<CR>", { desc = "Previous buffer" })

-- Okna (splits)
keymap("n", "<leader>sv", ":vsplit<CR>", { desc = "Split window vertically" })
keymap("n", "<leader>sh", ":split<CR>", { desc = "Split window horizontally" })
keymap("n", "<leader>sc", ":close<CR>", { desc = "Close current split" })

-- Wyłącz podświetlanie wyszukiwania
-- keymap("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- ============================================================================
-- INNE UŻYTECZNE MAPPINGI (bez leadera)
-- ============================================================================

-- Lepsze poruszanie się między oknami
keymap("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Cykliczna nawigacja między oknami (jak w .vimrc)
keymap("n", "<Tab>", "<C-w>w", { desc = "Cycle to next window" })
keymap("n", "<S-Tab>", "<C-w>W", { desc = "Cycle to previous window" })

-- Zmiana rozmiaru okien
keymap("n", "<C-Up>", ":resize +2<CR>", opts)
keymap("n", "<C-Down>", ":resize -2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Otwieranie linków i zasobów w przeglądarce
keymap({ "n", "x" }, "gx", "<cmd>Browse<CR>", { desc = "Open link under cursor or selection" })
keymap("n", "<C-LeftMouse>", function()
	-- Attempt gx-style open; fallback to default tag jump when no browser handler
	local browse_available = vim.fn.exists(":Browse") == 2
	local link_filetypes = {
		markdown = true,
		help = true,
		text = true,
		gitcommit = true,
	}

	if browse_available and link_filetypes[vim.bo.filetype] then
		vim.cmd("Browse")
		return
	end

	if browse_available then
		local line = vim.api.nvim_get_current_line()
		local col = vim.api.nvim_win_get_cursor(0)[2] + 1
		local left = line:sub(1, col):match("[%w%p]+$") or ""
		local right = line:sub(col + 1):match("^[%w%p]+");
		local token = left .. (right or "")

		if token:match("https?://") or token:match("%w+%.[%w%.%-_]+/%S*") then
			vim.cmd("Browse")
			return
		end
	end

	if not browse_available then
		vim.notify("Browse command not available. Load gx.nvim first?", vim.log.levels.WARN)
	end

	local term = vim.api.nvim_replace_termcodes("<C-LeftMouse>", true, false, true)
	vim.api.nvim_feedkeys(term, "n", true)
end, { desc = "Open link under mouse cursor", silent = true })

-- Lepsze wcięcia w trybie Visual
keymap("v", "<", "<gv", { desc = "Indent left and reselect" })
keymap("v", ">", ">gv", { desc = "Indent right and reselect" })

-- -- Przesuwanie linii w górę/dół
-- keymap("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
-- keymap("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })
-- keymap("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
-- keymap("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- ============================================================================
-- TRYBY w Vimie:
-- "n" = Normal mode (domyślny tryb)
-- "i" = Insert mode (edycja tekstu)
-- "v" = Visual mode (zaznaczanie)
-- "x" = Visual block mode
-- "t" = Terminal mode
-- ============================================================================
