-- Tmuxinator configs are YAML-first, even when they embed ERB.
vim.opt_local.comments = ":#"
vim.bo.commentstring = "# %s"
vim.opt_local.formatoptions:remove("t")
vim.opt_local.formatoptions:append("croql")
