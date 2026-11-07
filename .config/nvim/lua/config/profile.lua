-- Installing unrelated CLI tools must not enable development tooling on servers.
local M = {}

function M.is_desktop()
  return vim.env.DOTFILES_PROFILE == "desktop"
end

return M
