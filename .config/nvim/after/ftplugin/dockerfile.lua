-- Dockerfile specific settings
-- Align RUN commands by using 4 spaces for indentation (matching 'RUN ')

vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4
vim.bo.tabstop = 4

-- Neovim's smartindent can sometimes interfere with filetype-specific indent scripts
vim.bo.smartindent = false
