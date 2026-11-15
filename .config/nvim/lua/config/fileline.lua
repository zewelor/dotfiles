-- Adapted from lewis6991/fileline.nvim at c116aa8dd7aa7e1db6938f872285e598dc9ee00b.
-- Copyright (c) 2023 Lewis Russell; MIT license: see ../../LICENSE.fileline.
vim.api.nvim_create_autocmd("BufNewFile", {
  group = vim.api.nvim_create_augroup("dotfiles_fileline", { clear = true }),
  pattern = "*:[0-9]*",
  nested = true,
  callback = function(event)
    local reference = vim.api.nvim_buf_get_name(event.buf):gsub(":(%d+)%-%d+$", ":%1")
    local file, line = reference:match("^(.+):(%d+)$")
    if not file or vim.fn.filereadable(file) == 0 then
      return
    end

    -- Unload and unlist the placeholder as soon as no window displays it.
    vim.bo[event.buf].bufhidden = "delete"
    vim.cmd.edit({ vim.fn.fnameescape(file), mods = { keepalt = true } })
    -- Explicitly setting this option stops BufNewFile from clearing it on return.
    if vim.bo.modified then
      vim.bo.modified = true
    end

    line = math.min(math.max(1, tonumber(line)), vim.api.nvim_buf_line_count(0))
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    vim.cmd.normal({ "zvzz", bang = true })
  end,
})
