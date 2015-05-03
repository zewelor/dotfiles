PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting

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

antigen theme flazz

antigen apply

alias instaluj="sudo apt-get install"
alias szukaj="sudo apt-cache search"
alias czysc_dpkg="dpkg --list |grep \"^rc\" | cut -d \" \" -f 3 | xargs sudo dpkg --purge"
alias update="sudo apt-get update && sudo apt-get dist-upgrade -y"

alias gpo="git push origin"
alias gcmm="git commit -m"
alias gds='git diff --staged'
alias gpl='git pull'
alias git_undo_commit='git reset "HEAD^"'
alias git_delete_merged='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d && git fetch -p'

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

# Local config
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
