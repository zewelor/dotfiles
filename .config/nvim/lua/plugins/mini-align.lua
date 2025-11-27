-- mini.align - interactive text alignment
return {
  "nvim-mini/mini.align",
  main = "mini.align",
  opts = {
    -- Disable default keymaps; custom ones live in lua/config/keymaps.lua
    mappings = {
      start = "",
      start_with_preview = "",
    },
  },
}
