-- Full development tooling is available only on profiles managed by mise.
local M = {}

function M.enabled()
  return vim.fn.executable("mise") == 1
end

return M
