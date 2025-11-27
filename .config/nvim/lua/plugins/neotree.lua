-- Neo-tree provides a modern file explorer sidebar
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-mini/mini.icons", -- Ikony (zamiast nvim-web-devicons)
  },
  lazy = false, -- neo-tree will lazily load itself
}
