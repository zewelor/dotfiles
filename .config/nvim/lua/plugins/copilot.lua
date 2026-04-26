-- GitHub Copilot for AI-assisted code completions
-- Copilot is fed as a source to blink.cmp via blink-copilot; inline suggestions disabled
return {
  "zbirenbaum/copilot.lua",
  enabled = vim.g.dotfiles_has_nvim_011 == true,
  cmd = "Copilot",
  build = ":Copilot auth",
  event = "InsertEnter",
  opts = {
    suggestion = { enabled = false },
    panel = { enabled = false },
    filetypes = { markdown = true, help = true },
  },
}
