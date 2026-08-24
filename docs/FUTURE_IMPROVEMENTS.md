# Future Improvements

Pomysły na ulepszenia dotfiles - do zrobienia gdy będzie czas/potrzeba.

## Neovim

### nvim-dap (debugging)
- DAP dla Python, Node.js
- Priorytet: bardzo niski (k8s debugging = kubectl/k9s)
- Repo: [mfussenegger/nvim-dap](https://github.com/mfussenegger/nvim-dap)

## Shell / Tooling

### Neovim na Debian stable (AppImage fallback)
- Makefile używa Vim jako fallbacku, gdy apt nie oferuje Neovim 0.11+
- Opcja: dodać AppImage download gdy apt ma stary nvim
- Rozważyć gdy: potrzeba nvim na starym Debianie

## Nie robić

- **direnv** - preferencja: tmuxinator/Docker zamiast (nie lubię hooków na cd)
- **chezmoi** - stow działa, mamy profile + Vault
- **więcej rust tools** - mamy wystarczająco (eza, bat, zoxide, delta)
- **nvim distros** - mamy dobry custom setup
