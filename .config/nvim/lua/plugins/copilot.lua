-- GitHub Copilot for AI-assisted code completions
-- Using copilot.lua (Lua-native implementation) for better integration with blink.cmp
return {
  "zbirenbaum/copilot.lua",
  enabled = vim.g.dotfiles_has_nvim_011 == true,
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      suggestion = { enabled = false }, -- Disable inline suggestions (handled by blink-copilot)
      panel = { enabled = false },      -- Disable panel (handled by blink-copilot)
    })
  end,
}
