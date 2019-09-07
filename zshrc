PATH=$PATH:$HOME/bin

if [ -f "$HOME/.zplugin/bin/zmodules/Src/zdharma/zplugin.so" ]; then
  module_path+=( "$HOME/.zplugin/bin/zmodules/Src" )
  zmodload zdharma/zplugin
else
  if [ -x "$(command -v gcc)" ]; then
    echo "Missing zplugin binary module, compile it using 'zplugin module build'"
  fi
fi

if [ -x "$(command -v snap)" ]; then
  PATH=$PATH:/snap/bin
fi

DISABLE_AUTO_TITLE="true"

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

export DEFAULT_USER=`whoami`

# make it more responsive
export KEYTIMEOUT=1

export MC_SKIN=$HOME/.mc/solarized.ini

if [ -d $HOME/.zshrc.d ]; then
  for file in $HOME/.zshrc.d/*.zsh; do
    source $file
  done
fi

#unalias rm
#unalias cp
#unalias mv

#
# Zplugin
#

zcompile ~/.zplugin/bin/zplugin.zsh

### Added by Zplugin's installer
source "${HOME}/.zplugin/bin/zplugin.zsh"
autoload -Uz _zplugin
(( ${+_comps} )) && _comps[zplugin]=_zplugin
### End of Zplugin's installer chunk

#
# Themes
#

# # Zinc
# zplugin ice nocompletions atpull'prompt_zinc_compile' compile"{zinc_functions/*,segments/*,zinc.zsh}" ; zplugin load robobenklein/zinc
# zplugin ice wait'1' lucid atload'zinc_optional_depenency_loaded' ; zplugin load romkatv/gitstatus
# Powerlevel10k
zplugin ice wait'!' lucid atload'source ~/.p10k.zsh; _p9k_precmd' nocd ; zplugin light romkatv/powerlevel10k
# Powerlevel10k from PZT
# zplugin ice svn submods'romkatv/powerlevel10k -> external/powerlevel10k' atload"prompt powerlevel10k"
# zplugin snippet PZT::modules/prompt

zplugin light zdharma/z-p-submods

#
# Completions
#

zplugin ice as"completion" ; zplugin snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker
zplugin ice as"completion" ; zplugin snippet https://github.com/tmuxinator/tmuxinator/blob/master/completion/tmuxinator.zsh

#
# Programs
#
zplugin ice as"program" pick"bin/tat" ; zplugin light thoughtbot/dotfiles # Attach or create tmux session named the same as current directory.

#
# Prezto
#
zplugin snippet PZT::modules/helper/init.zsh

# Settings
# Set case-sensitivity for completion, history lookup, etc.
zstyle ':prezto:*:*' case-sensitive 'yes'
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' key-bindings 'vi'

# Plugins
zplugin ice svn pick ""; zplugin snippet PZT::modules/archive # No files to source, pick nothing to prevent snippet not loaded warning
zplugin ice svn; zplugin snippet PZT::modules/git
zplugin ice svn; zplugin snippet PZT::modules/dpkg
zplugin ice svn; zplugin snippet PZT::modules/history
zplugin ice svn; zplugin snippet PZT::modules/utility
zplugin ice load'[[ -x "$(command -v docker)" ]]' svn lucid ; zplugin snippet PZT::modules/docker

# Don't load tmux module inside tmux session
zplugin ice load'[[ -z "$TMUX" ]]' svn lucid ; zplugin snippet PZT::modules/tmux

# This module must be loaded after the utility module.
zplugin ice wait"0" lucid svn blockf atclone'git clone --depth 3 https://github.com/zsh-users/zsh-completions.git external'
zplugin snippet PZT::modules/completion

zplugin ice svn; zplugin snippet PZT::modules/editor

typeset -gA FAST_BLIST_PATTERNS
FAST_BLIST_PATTERNS[/mnt/*]=1
zplugin load zdharma/history-search-multi-word

zplugin ice wait"0" lucid atinit"ZPLGM[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay"
zplugin light zdharma/fast-syntax-highlighting

zplugin ice svn submods'zsh-users/zsh-autosuggestions -> external'
zplugin snippet PZT::modules/autosuggestions

#
# Aliases
#
#

# Apt
# Use sudo without aliases
alias instaluj="\sudo apt install -y"
alias szukaj="\sudo apt-cache search"
alias czysc_dpkg="\sudo apt autoremove -y ; dpkg --list |grep \"^rc\" | cut -d \" \" -f 3 | xargs \sudo dpkg --purge"
alias update="\sudo apt autoremove -y --purge && \sudo apt update && \sudo apt full-upgrade -y"

# Git
alias gst='git status'
alias ga='git add'
alias gd='git diff'
alias gpo="git push -u origin"
alias gcmm="git commit -m"
alias gds='git diff --staged'
alias gpl='git pull'
alias git_delete_merged='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d && git fetch -p'
alias gpf='git push --force-with-lease'
alias grbi='git rebase -i `git merge-base ${1:-master} HEAD`'
alias t='tail -f'

alias extract='unarchive'

# Global
alias -g ...='../..'
alias -g ....='../../..'
alias -g C='| wc -l'
alias -g G='| grep -E'  # egrep is deprecated
alias -g L='| less'
alias -g RNS='| sort -nr'
alias -g S='| sort'
alias -g TL='| tail -20'
alias -g T='| tail'
alias -g TF='| tail -f'
alias -g X0G='| xargs -0 egrep'
alias -g X0='| xargs -0'
alias -g XG='| xargs egrep'
alias -g X='| xargs'

if [ -n "$DISPLAY" ]; then
  alias rekde="kquitapp5 plasmashell && kstart5 plasmashell"
fi

# Add alias only if rvm installed on system
if [ -s "$HOME/.rvm/scripts/rvm" ]; then
  alias loadrvm='[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"'
fi

#
# Zplugin options overrides
#

unsetopt SHARE_HISTORY
export HISTFILE="$HOME/.zsh_history"
# setopt  NO_NOMATCH
# unset PAGER

# Local config
# [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
