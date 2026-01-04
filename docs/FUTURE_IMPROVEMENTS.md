# Future Improvements

Pomysły na ulepszenia dotfiles - do zrobienia gdy będzie czas/potrzeba.

## Neovim

### conform.nvim (auto-formatting)
- Auto-format on save dla lua, sh, yaml, json, markdown, python
- Formattery: stylua, shfmt, prettier, ruff
- Priorytet: niski (LSP formatting zazwyczaj wystarczy)
- Repo: [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim)

### gitsigns.nvim
- Git diff w gutterze
- Stage/reset hunks
- Blame line
- Priorytet: niski (lazygit via snacks.nvim już jest)
- Repo: [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)

### nvim-dap (debugging)
- DAP dla Python, Node.js
- Priorytet: bardzo niski (k8s debugging = kubectl/k9s)
- Repo: [mfussenegger/nvim-dap](https://github.com/mfussenegger/nvim-dap)

## Shell / Tooling

### Wersjonowanie binarek (zinit vs mise)
- Obecnie: zinit pobiera z GitHub Releases (latest)
- Alternatywa: mise z backendem aqua/ubi (checksums, pinning)
- Rozważyć gdy: pojawią się problemy z wersjami między hostami
- Notatka: pojedyncze narzędzia mogą mieć pinowane wersje w zinit jeśli trzeba

### Neovim na Debian stable (AppImage fallback)
- Makefile już obsługuje fallback do Vim
- Opcja: dodać AppImage download gdy apt ma stary nvim
- Rozważyć gdy: potrzeba nvim na starym Debianie

## Nie robić

- **direnv** - preferencja: tmuxinator/Docker zamiast (nie lubię hooków na cd)
- **chezmoi** - stow działa, mamy profile + Vault
- **więcej rust tools** - mamy wystarczająco (eza, bat, zoxide, delta)
- **nvim distros** - mamy dobry custom setup
