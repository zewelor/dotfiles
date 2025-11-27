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
  # Fix Esc in menu selection (autocomplete list)
  zmodload zsh/complist
  bindkey -M menuselect '^[' send-break

  # Only run if Atuin's vi widgets exist (atuin >= 18)
  (( $+widgets[atuin-search-viins] && $+widgets[atuin-search-vicmd] )) || return

  # Use zsh-vi-mode helper (plays nicer with its init/lazy keybinding behavior)
  zvm_bindkey viins '^R' atuin-search-viins
  zvm_bindkey vicmd '^R' atuin-search-vicmd

  # Obsluga up arrow
  # local up="${terminfo[kcuu1]}"
  # [[ -n "$up" ]] && {
  #   zvm_bindkey viins "$up" atuin-up-search-viins
  #   zvm_bindkey vicmd "$up" atuin-up-search-vicmd
  # }
  #
  # zvm_bindkey viins '^[[A' atuin-up-search-viins
  # zvm_bindkey viins '^[OA'  atuin-up-search-viins
  # zvm_bindkey vicmd '^[[A' atuin-up-search-vicmd
  # zvm_bindkey vicmd '^[OA'  atuin-up-search-vicmd
  #
  # # Bind 'k' in normal mode to Atuin up-search (matches Atuin defaults)
  # zvm_bindkey vicmd 'k' atuin-up-search-vicmd
}
