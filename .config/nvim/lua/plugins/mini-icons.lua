-- mini.icons - lekka alternatywa dla nvim-web-devicons
-- Dostarcza ikony dla plików, folderów, LSP, diagnostics itp.
return {
  "nvim-mini/mini.icons",
  lazy = true,
  opts = {},
  init = function()
    -- Mock nvim-web-devicons dla kompatybilności z pluginami które go wymagają
    package.preload["nvim-web-devicons"] = function()
      require("mini.icons").mock_nvim_web_devicons()
      return package.loaded["nvim-web-devicons"]
    end
  end,
}
