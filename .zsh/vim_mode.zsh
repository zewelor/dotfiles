# https://github.com/jeffreytse/zsh-vi-mode

# https://github.com/BilderLoong/dotfiles/blob/e75daa3234b8b8a2bd4008d71f5d9de104ed6c58/zsh/zsh/custom/zinit.sh#L28
zinit light-mode for \
  atinit"
    ZVM_INIT_MODE=sourcing
  "\
  jeffreytse/zsh-vi-mode

ZVM_LAZY_KEYBINDINGS=false  
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
