-- Keep Ruby roots, project tools and read-only gem sources consistent.
local M = {}
function M.is_gem(filename)
  return vim.fs.normalize(filename):find("/.bundle/gems/", 1, true) ~= nil
end

function M.root(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" or M.is_gem(filename) then
    return nil
  end
  return vim.fs.root(bufnr, { "Gemfile", ".git" }) or vim.fs.dirname(filename)
end

function M.project_lsp(root)
  return require("config.tools").project_executable("ruby-lsp", root)
end

function M.rubocop_root(bufnr)
  local root = vim.fs.root(bufnr, ".rubocop.yml")
  if root and vim.fn.filereadable(root .. "/Gemfile") == 1 then
    return root
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("ProjectGemSources", { clear = true }),
    desc = "Read container gem sources without editing or starting another LSP",
    callback = function(args)
      if M.is_gem(vim.api.nvim_buf_get_name(args.buf)) then
        vim.bo[args.buf].readonly = true
        vim.bo[args.buf].modifiable = false
      end
    end,
  })
end

return M
