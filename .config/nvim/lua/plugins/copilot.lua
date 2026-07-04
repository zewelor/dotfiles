-- copilot.lua - GitHub Copilot integration with lightweight inline suggestions
return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	opts = {
		panel = {
			enabled = false,
		},
		suggestion = {
			enabled = true,
			auto_trigger = true,
			hide_during_completion = true,
			debounce = 500,
			trigger_on_accept = false,
			keymap = {
				accept = false,
				accept_word = false,
				accept_line = false,
				next = false,
				prev = false,
				dismiss = false,
				toggle_auto_trigger = false,
			},
		},
		nes = {
			enabled = false,
			auto_trigger = false,
		},
		filetypes = {
			markdown = false,
			text = false,
			yaml = false,
			gitcommit = false,
			gitrebase = false,
			help = false,
		},
		should_attach = function(bufnr)
			return vim.bo[bufnr].buflisted
				and vim.bo[bufnr].buftype == ""
				and vim.api.nvim_buf_line_count(bufnr) < 5000
		end,
		logger = {
			print_log_level = vim.log.levels.WARN,
			trace_lsp = "off",
			trace_lsp_progress = false,
			log_lsp_messages = false,
		},
	},
}
