# https://github.com/jeffreytse/zsh-vi-mode
ZVM_INIT_MODE=sourcing
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT

zinit ice depth=1
zinit light jeffreytse/zsh-vi-mode

ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
# ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
