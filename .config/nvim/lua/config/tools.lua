-- Binary versions/backends live in mise/config.toml; only editor policy belongs here.
local M = {}
M.minimum_versions = {
  dprint = { 0, 64, 3 }, -- Project plugin/config discovery
  shfmt = { 3, 13, 1 }, -- Zsh dialect support
}
M.servers = {
  "helm_ls",  -- Helm chart LSP
  "ruff",     -- Python LSP, linting and formatting
  "taplo",    -- TOML LSP and formatting
  "marksman", -- Markdown LSP
  "gopls",    -- Go LSP (Conform owns formatting)
}

function M.resolve(binary, dirname)
  local mise = vim.fn.exepath("mise")
  assert(mise ~= "", "mise is required to resolve " .. binary)
  local result = vim.system({ mise, "-C", dirname, "which", binary },
    { text = true, timeout = 1000 }):wait()
  assert(result.code == 0, "mise cannot resolve " .. binary .. ": " .. vim.trim(result.stderr or ""))
  local path = vim.trim(result.stdout or "")
  assert(path:sub(1, 1) == "/" and vim.fn.executable(path) == 1,
    "mise returned no executable path for " .. binary)
  return path
end
return M
