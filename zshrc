PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
PATH=$PATH:$HOME/bin

source ~/.antigen/antigen.zsh

antigen use oh-my-zsh

DISABLE_AUTO_TITLE="true"

antigen bundle capistrano
antigen bundle common-aliases
antigen bundle cp
antigen bundle bundler
antigen bundle extract
antigen bundle git
antigen bundle history
antigen bundle rails
antigen bundle rake
antigen bundle rvm
antigen bundle adb
antigen bundle vagrant

export DEFAULT_USER="omen"
# POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
POWERLEVEL9K_SHORTEN_STRATEGY="truncate_middle"
POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status vi_mode)
POWERLEVEL9K_STATUS_VERBOSE=false
POWERLEVEL9K_COLOR_SCHEME="light"

antigen theme bhilburn/powerlevel9k powerlevel9k

antigen apply

alias instaluj="sudo apt-get install"
alias szukaj="sudo apt-cache search"
alias czysc_dpkg="sudo apt-get autoremove -y ; dpkg --list |grep \"^rc\" | cut -d \" \" -f 3 | xargs sudo dpkg --purge"
alias update="sudo apt-get autoremove -y --purge && sudo apt-get update && sudo apt-get dist-upgrade -y"

alias gpo="git push origin"
alias gcmm="git commit -m"
alias gds='git diff --staged'
alias gpl='git pull'
alias git_undo_commit='git reset "HEAD^"'
alias git_delete_merged='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d && git fetch -p'
alias gpf='git push --force-with-lease'

unalias rm
unalias cp
unalias mv

unsetopt share_history
setopt hist_ignore_all_dups
unset PAGER

# Make ctrl + s work
vim()
{
    local STTYOPTS="$(stty --save)"
    stty stop '' -ixoff
    command vim "$@"
    stty "$STTYOPTS"
}

export VISUAL=vim
export EDITOR=$VISUAL

# VI-Mode
# general activation
bindkey -v

# set some nice hotkeys
bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward

# make it more responsive
export KEYTIMEOUT=1

export MC_SKIN=$HOME/.mc/solarized.ini

# Local config
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
