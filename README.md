# Dotfiles

Some examples here:
[https://github.com/zdharma-continuum/zinit-configs](https://github.com/zdharma-continuum/zinit-configs)

## Installation

```bash
make install
```

## Local customizations

Local customization can be done by putting files in the ~/.zshrc.d/ directory. These files will be sourced by the main .zshrc file.

## Benchmarking / Profiling

```zsh
zinit times
```

## Neovim config (lazy.nvim)

- Minimal Neovim config is under `.config/nvim/` and bootstraps `lazy.nvim`.
- `make install` (or running `./install`) uses `stow` to link `.config/nvim` into `~/.config/nvim`.
- After install, launch Neovim and lazy.nvim will be cloned automatically on first run.

Try it:

```zsh
nvim
```

This setup is intentionally bare (no plugins yet). We will add plugin specs next.
