-- mini.surround — add/delete/replace surroundings (custom keymaps live in lua/config/keymaps.lua)
return {
  "nvim-mini/mini.surround",
  main = "mini.surround",
  opts = {
    -- Disable built-in keymaps (we use gsa/gsd/gsr/... instead)
    mappings = {
      add = "",
      delete = "",
      find = "",
      find_left = "",
      highlight = "",
      replace = "",
      suffix_last = "",
      suffix_next = "",
    },
  },
}
