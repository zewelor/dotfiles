-- mini.surround - add, delete, and replace surroundings.
return {
  "nvim-mini/mini.surround",
  main = "mini.surround",
  opts = {
    mappings = {
      add = "gsa",
      delete = "gsd",
      find = "gsf",
      find_left = "",
      highlight = "gsh",
      replace = "gsr",
      suffix_last = "",
      suffix_next = "",
    },
  },
}
