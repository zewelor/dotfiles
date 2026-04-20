vim.filetype.add({
  pattern = {
    [".*/%.ssh/config%.d/.*"] = "sshconfig",
  },
})
