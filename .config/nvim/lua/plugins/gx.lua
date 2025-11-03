-- gx.nvim - enhanced gx behavior to open URLs from Neovim
return {
  "chrishrb/gx.nvim",
  keys = {
    {
      "gx",
      "<cmd>Browse<CR>",
      mode = { "n", "x" },
      desc = "Open link under cursor or selection",
    },
  },
  cmd = { "Browse" },
  init = function()
    -- disable netrw's gx mapping so gx.nvim takes over
    vim.g.netrw_nogx = 1
  end,
  config = function()
    local browser = "xdg-open"

    if vim.fn.executable(browser) ~= 1 then
      local env_browser = vim.env.BROWSER
      if env_browser and vim.fn.executable(env_browser) == 1 then
        browser = env_browser
      else
        vim.notify(
          "gx.nvim: could not find a browser command. Install xdg-open or set $BROWSER.",
          vim.log.levels.WARN
        )
        return
      end
    end

    require("gx").setup({
      open_browser_app = browser,
    })
  end,
  submodules = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}
