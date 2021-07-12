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

# export DIRENV_LOG_FORMAT=
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
has()      { type "${1:?too few arguments}" &>/dev/null   }

### Added by zinit's installer
source "${HOME}/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### End of zinit's installer chunk

# if [ -f "${ZINIT[BIN_DIR]}/zmodules/Src/zdharma/zplugin.so" ]; then
#   module_path+=( "$HOME/.zinit/bin/zmodules/Src" )
#   zmodload zdharma/zplugin
# else
#   if [ -x "$(command -v gcc)" ]; then
#     echo "Missing zinit binary module, compile it using 'zinit module build'"
#   fi
# fi


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
zinit light-mode lucid wait has"minikube" for id-as"minikube_completion" as"completion" atclone"minikube completion zsh > _minikube" atpull"%atclone" run-atpull zdharma/null
# zplugin wait lucid for OMZ::plugins/kubectl/kubectl.plugin.zsh

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
# zinit ice from"gh-r" as"program" mv"direnv* -> direnv" atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' src"zhook.zsh" pick"direnv" ; zinit light direnv/direnv
zinit ice from"gh-r" as"program" mv"bat-*/bat -> bat"; zinit light sharkdp/bat
# zinit ice wait"2" as"program" from"gh-r" pick"lazygit" lucid ; zinit light jesseduffield/lazygit
# zinit ice wait"2" as"program" from"gh-r" pick"lazydocker" lucid ; zinit light jesseduffield/lazydocker
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
export ENHANCD_HYPHEN_ARG="--"
zstyle ":prezto:module:enhancd" filter "fzy:fzf"
zstyle ":prezto:module:enhancd" command "cd"

if [ -x "$(command -v kubectl)" ]; then
  function start-k8s-work () {
    alias k="kubectl"
    if [ -z "$(typeset -p POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS G kubecontext)" ] ; then
      typeset -ga POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=($POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS kubecontext)
    fi
    zinit ice from"gh-r" as"program" mv"krew-linux_amd64 -> kubectl-krew" if'[[ $MACHTYPE == "x86_64" ]]' atpull'%atclone' atclone'rm -f krew-*' bpick"krew.tar.gz" ; zinit light kubernetes-sigs/krew
    zinit light-mode lucid wait has"kubectl" for id-as"kubectl_completion" as"completion" atclone"kubectl completion zsh > _kubectl" atpull"%atclone" run-atpull zdharma/null

    zinit ice svn pick"init.zsh"; zinit snippet 'https://github.com/prezto-contributions/prezto-kubectl/trunk'

    zinit ice from"gh-r" as"program" mv"kubeseal-* -> kubeseal"; zinit light bitnami-labs/sealed-secrets

    for krew_plugin in get-all view-allocations pod-lens; do
      if [ ! -f "$HOME/.krew/receipts/$krew_plugin.yaml" ]; then
        kubectl krew install $krew_plugin
      fi
    done
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
if has "git"; then
  alias gst='git status'
  alias ga='git add'
  alias gd='git diff'
  alias grbm='git rebase master'
  alias gpo="git push -u origin"
  alias gcm='git checkout master'
  alias gcmm="git commit -m"
  alias gds='git diff --staged'
  alias gpl='git pull'
  alias git-delete-merged='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d && git fetch -p'
  alias gpf='git push --force-with-lease'
  alias grbi='git rebase -i `git merge-base ${1:-master} HEAD`'
  alias grh='git reset HEAD'
  alias grhh='git reset HEAD --hard'
  alias git-undo-commit='git reset --soft HEAD~;'
  alias gripfp="gcmm 'awd' -a && grbi --autosquash && gpf";

  function gcb () {
    git switch $1 2>/dev/null || git switch -c $1; 
  }
fi

# Bonus
alias update_bonus="ssh bonuswww@94.23.226.99 -t 'cd ~/www ; git pull origin'"

function gcmmpoa () {
  gcmm "$1" "$@[2,-1]" -a -u && gpl ; gpo
}
#
# Utils
#
alias dotfiles_update='cd ~/dotfiles && gpl && git submodule update --recursive --remote && ./install && cd -'
alias t='tail -f'
alias extract='unarchive'
alias ..='cd ..'
alias export_dotenv='export $(grep -v "^#" .env | xargs -d "\n")'

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

#
# Cli improvements
#
if has "bat"; then
  alias cat='bat --theme="Solarized (light)" -p'
fi

if has "docker"; then
  export DOCKER_BUILDKIT=1
  alias czysc_docker='docker container prune ; dkrmI'

  function dkEsh () {
    dkE $1 sh
  }

  zpcompdef _docker dkEsh='_docker_complete_containers_names'
fi

if [ -n "$DISPLAY" ]; then
  alias rekde="kquitapp5 plasmashell || killall plasmashell && kstart5 plasmashell"
fi

if [ -n "$KONSOLE_DBUS_SERVICE" ]; then
  set-konsole-tab-title-type ()
  {
      local _title=$1
      local _type=${2:-0}
      [[ -z "${_title}" ]]               && return 1
      [[ -z "${KONSOLE_DBUS_SERVICE}" ]] && return 1
      [[ -z "${KONSOLE_DBUS_SESSION}" ]] && return 1
      qdbus >/dev/null "${KONSOLE_DBUS_SERVICE}" "${KONSOLE_DBUS_SESSION}" setTabTitleFormat "${_type}" "${_title}"
  }
  set-konsole-tab-title ()
  {
      set-konsole-tab-title-type $1 && set-konsole-tab-title-type $1 1
  }
fi

# Add alias only if rvm installed on system wide
if [ -s "/usr/local/rvm/scripts/rvm" ] ; then
  # Unset AUTO_NAME_DIRS since auto adding variable-stored paths to ~ list
  # conflicts with RVM.
  alias loadrvm='[[ -s "/usr/local/rvm/scripts/rvm" ]] && unsetopt AUTO_NAME_DIRS ; . "/usr/local/rvm/scripts/rvm"'
fi

function loadrails() {
  if has "bundle"; then

    alias be='bundle exec'
    alias ror='bundle exec rails'
    alias rorc='bundle exec rails console'
    alias rordc='bundle exec rails dbconsole'
    alias rordm='bundle exec rake db:migrate'
    alias rordM='bundle exec rake db:migrate db:test:clone'
    alias rordr='bundle exec rake db:rollback'
    alias rorg='bundle exec rails generate'
    alias rorl='tail -f "$(ruby-app-root)/log/development.log"'
    alias rorlc='bundle exec rake log:clear'
    alias rorp='bundle exec rails plugin'
    alias rorr='bundle exec rails runner'
    alias rors='bundle exec rails server'
    alias rorsd='bundle exec rails server --debugger'
    alias rorx='bundle exec rails destroy'
  else
    echo "Missing bundle, rails aliases not loaded"
  fi
}


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
  alias update-slic3r='lastversion -d $HOME/bin/Slic3rPE.AppImage prusa3d/PrusaSlicer'
fi


# # Add alias only if conda installed on system
# if [ -f "$HOME/anaconda3/bin/conda" ]; then
#   function loadconda() {
#     # >>> conda initialize >>>
#     # !! Contents within this block are managed by 'conda init' !!
#     __conda_setup="$("$HOME/anaconda3/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
#     if [ $? -eq 0 ]; then
#         eval "$__conda_setup"
#     else
#         if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
# # . "$HOME/anaconda3/etc/profile.d/conda.sh"  # commented out by conda initialize
#         else
# # export PATH="~/anaconda3/bin:$PATH"  # commented out by conda initialize
#         fi
#     fi
#     unset __conda_setup
#     # <<< conda initialize <<<
#     zinit ice as"completion" ; zinit snippet https://github.com/esc/conda-zsh-completion/blob/master/_conda
#     compinit
#   }
# else
#   function loadconda() {
#     echo "Please install conda in $HOME/anaconda3/bin/conda"
#   }
# fi

if [ -x "$(command -v youtube-dl)" ]; then
  function youtube-extract-audio () {
    youtube-dl --ignore-errors -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o '~/Music/youtube/%(title)s.%(ext)s' "$@"
  }
  function youtube-mp3-playlist () {
    youtube-dl --ignore-errors -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o '~/Music/youtube/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s' "$@"
  }
fi

if has "docker-compose"; then
  zinit ice as"completion" ; zinit snippet https://github.com/docker/compose/blob/master/contrib/completion/zsh/_docker-compose

  function dkcrs () {
    dkc stop $1 && dkc up --force-recreate "$@[2,-1]" $1    
  }

  zpcompdef _docker-compose dkcrs="_docker-compose_services"

  function dkcrsd () {
    dkcrs $1 -d
  }

  zpcompdef _docker-compose dkcrsd="_docker-compose_services"

  function dkcrsdl () {
    dkcrsd $1 && dkcl -f $1
  }

  zpcompdef _docker-compose dkcrsdl="_docker-compose_services"

  function dkcupdate () {
    dkc stop $1 && dkc pull $1 && dkc up -d $1 && sleep 5 && dkcl -f $1
  }

  zpcompdef _docker-compose dkcupdate="_docker-compose_services"

  function dkcupdated () {
    dkc stop $1 && dkc pull $1 && dkc up -d $1
  }

  zpcompdef _docker-compose dkcupdated="_docker-compose_services"
fi

function du_sorted () {
  if [ -z "$@" ]; then
    ARGS='.'
  else
    ARGS="$@"
  fi

  du -h --max-depth=1 $ARGS | sort -h
}

if [ -x "$(command -v mixxx)" ]; then
  function start-dj () {
    sudo nice -n -10 su -c mixxx omen
  }
fi


if has "codium"; then
  alias code='codium'
fi
#
# Zinit options overrides
#

unsetopt SHARE_HISTORY
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=100000
export HISTIGNORE="ignorespace"
export SAVEHIST=100000  
# setopt  NO_NOMATCH
# unset PAGER


#
# Functions
#

if has "ruby"; then
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
fi


# Local config
# [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
