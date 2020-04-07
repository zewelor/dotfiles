setopt nullglob  # allows filename patterns which match no files to expand to a null string, rather than themselves

if [ -d $HOME/bin ]; then
  PATH=$PATH:$HOME/bin
fi

if [ -d $HOME/.local/bin ]; then
  PATH=$PATH:$HOME/.local/bin
fi

if [ -d $HOME/.krew/bin ]; then
  PATH=$PATH:$HOME/.krew/bin
fi

if [ -f /etc/profile.d/apps-bin-path.sh ]; then
  source /etc/profile.d/apps-bin-path.sh
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

export DIRENV_LOG_FORMAT=
# make it more responsive
export KEYTIMEOUT=1

export MC_SKIN=$HOME/.mc/solarized.ini

if [ -d $HOME/.zshrc.d ]; then
  for file in $HOME/.zshrc.d/*.zsh; do
    source $file
  done
fi

#
# Zinit
#


#################################################################
# FUNCTIONS TO MAKE CONFIGURATION LESS VERBOSE
#

turbo0()   { zinit ice wait"0a" lucid             "${@}"; }
turbo1()   { zinit ice wait"0b" lucid             "${@}"; }
turbo2()   { zinit ice wait"0c" lucid             "${@}"; }
zcommand() { zinit ice wait"0b" lucid as"command" "${@}"; }
zload()    { zinit load                           "${@}"; }
zsnippet() { zinit snippet                        "${@}"; }
has()      { type "${1:?too few arguments}" &>/dev/null     }

# zcompile ~/.zplugin/bin/zinit.zsh

### Added by zinit's installer
source "${HOME}/.zplugin/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### End of zinit's installer chunk

if [ -f "${ZINIT[BIN_DIR]}/zmodules/Src/zdharma/zplugin.so" ]; then
  module_path+=( "$HOME/.zplugin/bin/zmodules/Src" )
  zmodload zdharma/zplugin
else
  if [ -x "$(command -v gcc)" ]; then
    echo "Missing zinit binary module, compile it using 'zinit module build'"
  fi
fi


# Url quotes magic
autoload -Uz bracketed-paste-url-magic
zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

#
# Themes
#

# Powerlevel10k
zinit ice lucid atload'source ~/.p10k.zsh; _p9k_precmd' nocd ; zinit light romkatv/powerlevel10k

zinit light zdharma/z-p-submods

#
# Completions
#

zinit ice as"completion" ; zinit snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker
zinit ice as"completion" mv"chezmoi* -> _chezmoi"; zinit snippet https://github.com/twpayne/chezmoi/blob/master/completions/chezmoi.zsh

if [ -x "$(command -v tmuxinator)" ]; then
  alias mux="tmuxinator"
fi



# local snippets
zinit ice wait"1" lucid
zinit snippet $HOME/.zsh/20_keybinds.zsh

# compinit
#zinit cdreplay -q

#
# Programs
#
zinit ice as"program" pick"bin/tat" ; zinit light thoughtbot/dotfiles # Attach or create tmux session named the same as current directory.
zinit ice from"gh-r" as"program" mv"direnv* -> direnv" atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' src"zhook.zsh" pick"direnv" ; zinit light direnv/direnv
zinit ice from"gh-r" as"program" mv"bat-*/bat -> bat"; zinit light sharkdp/bat
zinit ice wait"2" as"program" from"gh-r" pick"lazygit" lucid ; zinit light jesseduffield/lazygit
zinit ice wait"2" as"program" from"gh-r" pick"lazydocker" lucid ; zinit light jesseduffield/lazydocker
zcommand from"gh-r"; zload junegunn/fzf-bin
zcommand pick"bin/fzf-tmux"; zload junegunn/fzf
# Create and bind multiple widgets using fzf
turbo0 src"shell/completion.zsh" id-as"junegunn/fzf_completions" pick"/dev/null" ; zload junegunn/fzf

# Install `fzy` fuzzy finder, if not yet present in the system
# Also install helper scripts for tmux and dwtm
turbo0 as"command" if'[[ -z "$commands[fzy]" ]]' \
       make"!PREFIX=$ZPFX install" atclone"cp contrib/fzy-* $ZPFX/bin/" pick"$ZPFX/bin/fzy*"
    zload jhawthorn/fzy
# Install fzy-using widgets
turbo0 silent; zload aperezdc/zsh-fzy
bindkey '\ec' fzy-cd-widget
bindkey '^T'  fzy-file-widget
bindkey '^R'  fzy-history-widget
bindkey '^P'  fzy-proc-widget

#
# Prezto
#
zinit snippet PZT::modules/helper/init.zsh

# Settings
# Set case-sensitivity for completion, history lookup, etc.
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' key-bindings 'vi'
zstyle ':prezto:module:utility' correct 'no'

# Plugins
zinit ice svn pick ""; zinit snippet PZT::modules/archive # No files to source, pick nothing to prevent snippet not loaded warning
zinit ice svn; zinit snippet PZT::modules/git
zinit ice svn; zinit snippet PZT::modules/dpkg
zinit ice svn; zinit snippet PZT::modules/history
zinit ice svn atpull'%atclone' run-atpull atclone'rm -f functions/make'; zinit snippet PZT::modules/utility # Remove make function as it breaks make
zinit ice svn; zinit snippet PZT::modules/docker
zinit ice svn; zinit snippet PZT::modules/tmux
# zinit ice svn; zinit snippet PZT::modules/ruby
# zinit ice svn; zinit snippet PZT::modules/rails
zinit ice svn atclone'git clone --depth 3 https://github.com/b4b4r07/enhancd.git external' ; zinit snippet 'https://github.com/belak/prezto-contrib/trunk/enhancd'

export ENHANCD_DOT_ARG="..."
zstyle ":prezto:module:enhancd" filter "fzy:fzf"
zstyle ":prezto:module:enhancd" command "cd"

if [ -x "$(command -v kubectl)" ]; then
  zinit ice from"gh-r" as"program" mv"krew-linux_amd64 -> kubectl-krew" if'[[ $MACHTYPE == "x86_64" ]]' atpull'%atclone' atclone'rm -f krew-*' bpick"krew.tar.gz" ; zinit light kubernetes-sigs/krew
  function start-k8s-work () {
    if [ -z "$(typeset -p POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS G kubecontext)" ] ; then
      typeset -ga POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=($POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS kubecontext)
    fi
  }
fi

# This module must be loaded after the utility module.
zinit ice wait"0" lucid svn blockf atclone'git clone --depth 3 https://github.com/zsh-users/zsh-completions.git external'
zinit snippet PZT::modules/completion

zinit ice svn; zinit snippet PZT::modules/editor

typeset -gA FAST_BLIST_PATTERNS
FAST_BLIST_PATTERNS[/mnt/*]=1
zinit ice wait"0" lucid atinit"ZINIT[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay"
zinit light zdharma/fast-syntax-highlighting

zinit ice svn submods'zsh-users/zsh-autosuggestions -> external'
zinit snippet PZT::modules/autosuggestions

#
# Aliases
#
#

# Apt
# Use sudo without aliases
alias instaluj="\sudo apt install -y"
alias szukaj="\sudo apt-cache search"
alias czysc_dpkg="\sudo apt autoremove -y --purge ; dpkg --list |grep \"^rc\" | cut -d \" \" -f 3 | xargs \sudo dpkg --purge"
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
alias ..='cd ..'

#
# Cli improvements
#
if has "bat"; then
  alias cat='bat --theme=ansi-light'
fi
if has "docker"; then
  alias czysc_docker='docker container prune ; dkrmI'
fi


# Global
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

if [ -s "$HOME/.platformio/penv/bin/activate" ] ; then
  alias load-platformio='source ~/.platformio/penv/bin/activate'
fi

if [ -s "$HOME/bin/Slic3rPE.AppImage" ] ; then
  builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh"
  alias update-slic3r='CPUTYPE="x64" .zinit-get-latest-gh-r-version prusa3d PrusaSlicer ; wget "https://github.com$REPLY" -O $HOME/bin/Slic3rPE.AppImage -q'
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
    zinit ice as"completion" ; zinit snippet https://github.com/esc/conda-zsh-completion/blob/master/_conda
    compinit
  }
else
  function loadconda() {
    echo "Please install conda in $HOME/anaconda3/bin/conda"
  }
fi

if [ -x "$(command -v youtube-dl)" ]; then
  function youtube-mp3 () {
    youtube-dl --ignore-errors -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o '~/Music/youtube/%(title)s.%(ext)s' "$@"
  }
  function youtube-mp3-playlist () {
    youtube-dl --ignore-errors -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o '~/Music/youtube/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s' "$@"
  }
fi

if [ -x "$(command -v mixxx)" ]; then
  function start-dj () {
    sudo nice -n -10 pasuspender mixxx
  }
fi
#
# Zinit options overrides
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
