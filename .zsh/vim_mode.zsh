# https://github.com/jeffreytse/zsh-vi-mode

# https://github.com/BilderLoong/dotfiles/blob/e75daa3234b8b8a2bd4008d71f5d9de104ed6c58/zsh/zsh/custom/zinit.sh#L28
zinit light-mode wait lucid for \
  atinit"
    ZVM_INIT_MODE=sourcing
  "\
  jeffreytse/zsh-vi-mode

ZVM_LAZY_KEYBINDINGS=false
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM

function zvm_after_init() {
  # Re-bind atuin keys as zsh-vi-mode overrides them
  if zle -l atuin-search; then
    bindkey -M viins '^r' atuin-search-viins
    bindkey -M vicmd '^r' atuin-search-vicmd
    bindkey -M viins '^[[A' atuin-up-search-viins
    bindkey -M vicmd '^[[A' atuin-up-search-vicmd
    bindkey -M vicmd 'k' atuin-up-search-vicmd
  fi
}
