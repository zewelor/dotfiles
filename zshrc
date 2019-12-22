setopt nullglob  # allows filename patterns which match no files to expand to a null string, rather than themselves

if [ -d $HOME/bin ]; then
  PATH=$PATH:$HOME/bin
fi

if [ -d $HOME/.local/bin ]; then
  PATH=$PATH:$HOME/.local/bin
fi

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

#
# Zplugin
#

zcompile ~/.zplugin/bin/zplugin.zsh

### Added by Zplugin's installer
source "${HOME}/.zplugin/bin/zplugin.zsh"
autoload -Uz _zplugin
(( ${+_comps} )) && _comps[zplugin]=_zplugin
### End of Zplugin's installer chunk


# Url quotes magic
autoload -Uz bracketed-paste-url-magic
zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

#
# Themes
#

# # Zinc
# zplugin ice nocompletions atpull'prompt_zinc_compile' compile"{zinc_functions/*,segments/*,zinc.zsh}" ; zplugin load robobenklein/zinc
# zplugin ice wait'1' lucid atload'zinc_optional_depenency_loaded' ; zplugin load romkatv/gitstatus
# Powerlevel10k
zplugin ice lucid atload'source ~/.p10k.zsh; _p9k_precmd' nocd ; zplugin light romkatv/powerlevel10k
# Powerlevel10k from PZT
# zplugin ice svn submods'romkatv/powerlevel10k -> external/powerlevel10k' atload"prompt powerlevel10k"
# zplugin snippet PZT::modules/prompt

zplugin light zdharma/z-p-submods

#
# Completions
#

zplugin ice as"completion" ; zplugin snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker
zplugin ice as"completion" mv"chezmoi* -> _chezmoi"; zplugin snippet https://github.com/twpayne/chezmoi/blob/master/completions/chezmoi.zsh

if [ -x "$(command -v tmuxinator)" ]; then
  alias mux="tmuxinator"
fi

#
# Programs
#
zplugin ice as"program" pick"bin/tat" ; zplugin light thoughtbot/dotfiles # Attach or create tmux session named the same as current directory.
zplugin ice from"gh-r" as"program" ; zplugin load birdayz/kaf
zplugin ice from"gh-r" as"program" mv"direnv* -> direnv" atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' src"zhook.zsh" pick"direnv" ; zplugin light direnv/direnv

#
# Prezto
#
zplugin snippet PZT::modules/helper/init.zsh

# Settings
# Set case-sensitivity for completion, history lookup, etc.
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' key-bindings 'vi'
zstyle ':prezto:module:utility' correct 'no'

# Plugins
zplugin ice svn pick ""; zplugin snippet PZT::modules/archive # No files to source, pick nothing to prevent snippet not loaded warning
zplugin ice svn; zplugin snippet PZT::modules/git
zplugin ice svn; zplugin snippet PZT::modules/dpkg
zplugin ice svn; zplugin snippet PZT::modules/history
zplugin ice svn atpull'%atclone' run-atpull atclone'rm functions/make'; zplugin snippet PZT::modules/utility # Remove make function as it breaks make
zplugin ice svn; zplugin snippet PZT::modules/docker
zplugin ice svn; zplugin snippet PZT::modules/tmux
# zplugin ice svn; zplugin snippet PZT::modules/ruby
# zplugin ice svn; zplugin snippet PZT::modules/rails

if [ -x "$(command -v kubectl)" ]; then
  zplugin ice svn; zplugin snippet 'https://github.com/belak/prezto-contrib/trunk/kubernetes'
  function start-k8s-work () {
    if [ -z "$(typeset -p POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS G kubecontext)" ] ; then
      typeset -ga POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=($POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS kubecontext)
    fi
  }
fi

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
alias gcb='git checkout -b'
alias grbm='git rebase master'
alias gpo="git push -u origin"
alias gcm='git checkout master'
alias gcmm="git commit -m"
alias gds='git diff --staged'
alias gpl='git pull'
alias git_delete_merged='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d && git fetch -p'
alias gpf='git push --force-with-lease'
alias grbi='git rebase -i `git merge-base ${1:-master} HEAD`'
alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'
alias gripfp="gcmm 'awd' -a && grbi --autosquash && gpf";

#
# Ruby on Rails
#
alias rorc='rails console'
alias rordc='rails dbconsole'
alias rordm='rake db:migrate'
alias rordM='rake db:migrate db:test:clone'
alias rordr='rake db:rollback'
alias rorg='rails generate'
alias rorl='tail -f "$(ruby-app-root)/log/development.log"'
alias rorlc='rake log:clear'
alias rorp='rails plugin'
alias rorr='rails runner'
alias rors='rails server'

alias dotfiles_update='cd ~/dotfiles && gpl && git submodule update --recursive --remote && cd -'
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
  alias rekde="kquitapp5 plasmashell ; kstart5 plasmashell"
fi

# Add alias only if rvm installed on system wide
if [ -s "/usr/local/rvm/scripts/rvm" ] ; then
  # Unset AUTO_NAME_DIRS since auto adding variable-stored paths to ~ list
  # conflicts with RVM.
  alias loadrvm='[[ -s "/usr/local/rvm/scripts/rvm" ]] && unsetopt AUTO_NAME_DIRS ; . "/usr/local/rvm/scripts/rvm"'
fi

# Add alias only if rvm installed on system
if [ -s "$HOME/.rvm/scripts/rvm" ] ; then
  # Unset AUTO_NAME_DIRS since auto adding variable-stored paths to ~ list
  # conflicts with RVM.
  alias loadrvm='[[ -s "$HOME/.rvm/scripts/rvm" ]] && unsetopt AUTO_NAME_DIRS ; . "$HOME/.rvm/scripts/rvm"'
fi

# Add alias only if conda installed on system
if [ -f "$HOME/anaconda3/bin/conda" ]; then
  function loadconda() {
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$("$HOME/anaconda3/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
# . "$HOME/anaconda3/etc/profile.d/conda.sh"  # commented out by conda initialize
        else
# export PATH="~/anaconda3/bin:$PATH"  # commented out by conda initialize
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<
    zplugin ice as"completion" ; zplugin snippet https://github.com/esc/conda-zsh-completion/blob/master/_conda
    compinit
  }
else
  function loadconda() {
    echo "Please install conda in $HOME/anaconda3/bin/conda"
  }
fi

if [ -x "$(command -v youtube-dl)" ]; then
  function youtube-mp3 () {
    youtube-dl --ignore-errors -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o '~/Music/youtube/%(title)s.%(ext)s' "$1"
  }
  function youtube-mp3-playlist () {
    youtube-dl --ignore-errors -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o '~/Music/youtube/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s' "$1"
  }
fi

if [ -x "$(command -v mixxx)" ]; then
  function start-dj () {
    sudo nice -n -10 pasuspender mixxx
  }
fi
#
# Zplugin options overrides
#

unsetopt SHARE_HISTORY
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000  
# setopt  NO_NOMATCH
# unset PAGER


#
# Functions
#

function ruby-app-root {

  local root_dir="$PWD"

  while [[ "$root_dir" != '/' ]]; do
    if [[ -f "$root_dir/Gemfile" ]]; then
      print "$root_dir"
      break
    fi
    root_dir="$root_dir:h"
  done

  return 1

}


# Local config
# [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
