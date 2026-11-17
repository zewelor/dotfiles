-- Binary versions/backends live in mise/config.toml; only editor policy belongs here.
local M = {}
M.minimum_versions = {
  dprint = { 0, 64, 3 }, -- Project plugin/config discovery
  shfmt = { 3, 13, 1 }, -- Zsh dialect support
}

-- Only explicitly activated executables from this project override mise.
function M.project_executable(binary, root)
  if not root then
    return nil
  end
  local path = vim.fn.exepath(binary)
  local owner = path ~= "" and vim.fs.root(vim.fs.dirname(path), { "Gemfile", ".git" }) or nil
  local prefix = vim.fs.normalize(root) .. "/"
  if path ~= "" and vim.fs.normalize(path):sub(1, #prefix) == prefix then
    if not owner or vim.fs.normalize(owner) == vim.fs.normalize(root) then
      return path, owner
    end
  end
  return nil, owner
end

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
