-- Force 2-space indentation for Markdown (runtime default is 4)
local o = vim.opt_local
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2

-- Softer wrapping for prose
o.wrap = true          -- visually wrap long lines
o.linebreak = true     -- wrap at word boundaries
o.breakindent = true   -- preserve indent on wrapped lines
