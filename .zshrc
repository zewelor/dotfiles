# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [ ! -f "$HOME/.zshrc.zwc" -o "$HOME/.zshrc" -nt "$HOME/.zshrc.zwc" ]; then
    zcompile $HOME/.zshrc
fi

setopt nullglob  # allows filename patterns which match no files to expand to a null string, rather than themselves

# Path manipulation
if [ -d $HOME/bin ]; then
  PATH=$PATH:$HOME/bin
fi

if [ -d $HOME/.local/bin ]; then
  PATH=$PATH:$HOME/.local/bin
fi

if [ -d $HOME/.krew/bin ]; then
  PATH=$PATH:$HOME/.krew/bin
fi

if [ -d $HOME/.local/share/yabridge/ ]; then
  PATH=$PATH:$HOME/.local/share/yabridge/

  function update-yabridge () {
    wget `docker run --rm ghcr.io/dvershinin/lastversion:latest robbert-vdh/yabridge --assets --filter '^((?!ubuntu).)*$'` -O /tmp/yabridge.tar.gz && \
    cd /tmp && \
    tar zxvf yabridge.tar.gz && \
    rm -rf /home/omen/.local/share/yabridge/ && \
    mv -f yabridge /home/omen/.local/share && \
    rm /tmp/yabridge.tar.gz
    yabridgectl sync
  }
fi

if [ -d $HOME/go/bin ]; then
  PATH=$PATH:$HOME/go/bin
fi

# For snap
if [ -f /etc/profile.d/apps-bin-path.sh ]; then
  source /etc/profile.d/apps-bin-path.sh
fi

DISABLE_AUTO_TITLE="true"

setopt noflowcontrol
# # Make ctrl + s work
# alias vim="stty stop '' -ixoff ; vim"
# # `Frozing' tty, so after any command terminal settings will be restored
# # ttyctl -f

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

zload()    { zinit load                           "${@}"; }
zsnippet() { zinit snippet                        "${@}"; }
has()      { type "${1:?too few arguments}" &>/dev/null   }

### Added by zinit's installer
source "${HOME}/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### End of zinit's installer chunk

# Url quotes magic
autoload -Uz bracketed-paste-url-magic
zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

#
# Themes
#

# Powerlevel10k
zinit light-mode lucid atload'source ~/.p10k.zsh; _p9k_precmd' nocd for @romkatv/powerlevel10k

zinit light zdharma-continuum/z-a-submods

#
# Completions
#

# zinit ice as"completion" mv"chezmoi* -> _chezmoi"; zinit snippet https://github.com/twpayne/chezmoi/blob/master/completions/chezmoi.zsh
# zinit ice lucid wait has"minikube" for id-as"minikube_completion" as"completion" atclone"minikube completion zsh > _minikube" atpull"%atclone" run-atpull zdharma-continuum/null




# local snippets
zinit ice wait"1" lucid

zinit light zdharma-continuum/zinit-annex-bin-gem-node
zinit light zdharma-continuum/zinit-annex-link-man
zinit light zdharma-continuum/zinit-annex-patch-dl
zinit light b4b4r07/enhancd

#
# Programs
#
##########################

zinit light-mode as"program" pick"bin/tat" for @thoughtbot/dotfiles # Attach or create tmux session named the same as current directory.
zinit ice wait lucid from"gh-r" as"program" mv"fzf* -> fzf" pick"fzf/fzf" ; zinit light junegunn/fzf
# zinit ice lucid wait'0'; zinit light joshskidmore/zsh-fzf-history-search
# A cat clone with syntax highlighting and Git integration.
zinit light-mode from"gh-r" as"program" mv"bat-*/bat -> bat" for @sharkdp/bat
# A viewer for git and diff output
zinit light-mode from"gh-r" as"program" mv"delta-*/delta -> delta" for @dandavison/delta
# A more intuitive version of du written in rust.
zinit light-mode from"gh-r" as"program" mv"dust-*/dust -> dust" for @bootandy/dust
# A simple, fast and user-friendly alternative to find
zinit light-mode from"gh-r" as"program" mv"fd* -> fd" pick"fd/fd" for @sharkdp/fd
# An extremely fast alternative to grep that respects your gitignore
zinit light-mode from"gh-r" as"program" mv"ripgrep-*/rg -> rg" for @BurntSushi/ripgrep
# Feature-rich terminal-based text viewer. It is a so-called terminal pager.
zinit light-mode from"gh-r" as"program" pick"ov" for @noborus/ov
zinit light-mode wait"2" as"program" pick"git-fixup" lucid  for @keis/git-fixup

zinit light-mode from"gh-r" as"program" \
  atclone"./just --completions zsh > _just" atpull"%atclone" \
  pick"just" for @casey/just

zinit light-mode from"gh-r" as"program" \
  atclone"./atuin gen-completions --shell zsh > _atuin" atpull"%atclone" \
  mv"atuin-*/atuin -> atuin" for @atuinsh/atuin

zinit light-mode from"gh-r" as"program" \
  atclone"./gh completion -s zsh > _gh" atpull"%atclone" \
  mv"gh_*/bin/gh -> gh" for @cli/cli

zinit light-mode src"asdf.sh" atclone'%atpull' atclone'ln -sf $PWD/asdf.sh $HOME/.asdf/' for @asdf-vm/asdf
##########################


export ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS="--height 40% --reverse"

#
# Prezto
#
zinit snippet PZT::modules/helper/init.zsh

# Settings
# Set case-sensitivity for completion, history lookup, etc.
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' key-bindings 'vi'

# https://github.com/babarot/enhancd#configuration
export ENHANCD_ARG_DOUBLE_DOT="..."
export ENHANCD_ARG_HYPHEN="--"
export ENHANCD_FILTER="fzf --height 40%:fzy"

# Plugins
# They need svn support
zinit snippet PZT::modules/dpkg
zinit snippet PZT::modules/history
zinit snippet PZT::modules/tmux

zinit light le0me55i/zsh-extract
zinit ice wait"0" lucid blockf atclone'git clone --depth 3 https://github.com/zsh-users/zsh-completions.git external'
zinit snippet PZT::modules/completion

# Includes
source $HOME/.zsh/kubernetes.zsh
source $HOME/.zsh/docker.zsh
source $HOME/.zsh/gh_copilot.zsh

zinit snippet PZT::modules/editor

typeset -gA FAST_BLIST_PATTERNS
FAST_BLIST_PATTERNS[/mnt/*]=1
zinit ice wait"0" lucid atinit"ZINIT[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay"
zinit light zdharma-continuum/fast-syntax-highlighting

zinit ice submods'zsh-users/zsh-autosuggestions -> external'
zinit snippet PZT::modules/autosuggestions

#
# Aliases
#
#

# Apt
# Use sudo without aliases
alias instaluj="\sudo apt install -y"
alias szukaj="\sudo apt-cache search"
alias czysc_dpkg="\sudo apt autoremove -y --purge ; dpkg --list |grep \"^rc\" | cut -d \" \" -f 3 | xargs --no-run-if-empty \sudo dpkg --purge"
alias update="\sudo apt autoremove -y --purge && \sudo apt update && \sudo apt full-upgrade -y"

# Git
if has "git"; then
  # https://github.com/sorin-ionescu/prezto/blob/master/modules/git/alias.zsh

  alias gst='git status'
  alias ga='git add'
  alias gd='git diff'
  alias grbm='git rebase `git_main_branch`'
  alias gco='git checkout'
  alias gpo="git push -u origin"
  alias gcm='git checkout `git_main_branch`'
  alias gcmm="git commit -m"
  alias gds='git diff --staged'
    # Stash (s)
  alias gs='git stash'
  alias gsp='git stash pop'
  alias gpl='git pull'
  alias git-delete-merged='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d && git fetch -p'
  alias gpf='git push --force-with-lease'
  alias grbi='git rebase -i `git merge-base ${1:-master} HEAD`'
  alias grh='git reset HEAD'
  alias grhh='git reset HEAD --hard'
  alias git-undo-commit='git reset --soft HEAD~;'
  alias gripfp="gcmm 'awd' -a && grbi --autosquash && gpf";
  alias glp="git log -p"
  alias git-fixup="ga . && git fixup -c --rebase && gpf"

  function git_main_branch () {
    git branch -l master main | xargs | cut -f 2 -d ' '
  }

  function gcb () {
    git switch $1 2>/dev/null || git switch -c $1;
  }

  function gcmmpoa () {
    git commit -m "$1" "$@[2,-1]" -a -u && git pull ; git push -u origin
  }
fi

# Bonus
alias update_bonus="ssh bonuswww@94.23.226.99 -t 'cd ~/www ; git pull origin'"

#
# Utils
#
alias dotfiles_update='cd ~/dotfiles && gpl && git submodule update --recursive --remote && ./install && cd -'
alias t='tail -f'
alias ..='cd ..'
alias export_dotenv='export $(grep -v "^#" .env | xargs -d "\n")'
alias start_ssh_agent="eval `ssh-agent` && ssh-add"

# Global
alias -g C='| wc -l'
alias -g G='| grep -e'  # egrep is deprecated
alias -g L='| less'
alias -g RNS='| sort -nr'
alias -g S='| sort'
# alias -g TL='| tail -20'
alias -g T='| tail'
# alias -g TF='| tail -f'
# alias -g X0G='| xargs -0 egrep'
# alias -g X0='| xargs -0'
# alias -g XG='| xargs egrep'
alias -g X='| xargs'
alias -g J='| jq'

# Directory listing
alias l='ls -1A'         # Lists in one column, hidden files.
alias ll='ls -lh'        # Lists human readable sizes.
alias lr='ll -R'         # Lists human readable sizes, recursively.
alias la='ll -A'         # Lists human readable sizes, hidden files.
alias lm='la | "$PAGER"' # Lists human readable sizes, hidden files through pager.
alias lk='ll -Sr'        # Lists sorted by size, largest last.
alias lt='ll -tr'        # Lists sorted by date, most recent last.
alias lc='lt -c'         # Lists sorted by date, most recent last, shows change time.
alias lu='lt -u'         # Lists sorted by date, most recent last, shows access time.

# Disable globbing.
alias fc='noglob fc'
alias find='noglob find'
alias ftp='noglob ftp'
alias history='noglob history'
alias locate='noglob locate'
alias rsync='noglob rsync'
alias scp='noglob scp'
alias sftp='noglob sftp'

# export OPENAI_API_IP=127.0.0.1
# export OPENAI_API_PORT=8082
# export OPENAI_API_BASE="http://${OPENAI_API_IP}:${OPENAI_API_PORT}/v1"
#
# # Opencommit
# export OCO_OPENAI_BASE_PATH=${OPENAI_API_BASE}

# Misc
# https://github.com/TheR1D/shell_gpt
# Installed via pipx, because docker version doesn't integrate with shell auto execution ( it executes commands inside docker )
if has "sgpt"; then
  # If OPENAI_API_IP is set and equals 127.0.0.1
  if [ -n "$OPENAI_API_IP" ] && [ "$OPENAI_API_IP" = "127.0.0.1" ]; then
    export OPENAI_API_KEY="whatever"
    export OPENAI_API_HOST="http://${OPENAI_API_IP}:${OPENAI_API_PORT}"
  fi

  alias sgpt4="sgpt --model gpt-4"

  # Shell-GPT integration ZSH v0.2
  _sgpt_zsh() {
  if [[ -n "$BUFFER" ]]; then
      _sgpt_prev_cmd=$BUFFER
      BUFFER+="⌛"
      zle -I && zle redisplay
      BUFFER=$(sgpt --shell <<< "$_sgpt_prev_cmd" --no-interaction)
      zle end-of-line
  fi
  }
  zle -N _sgpt_zsh
  bindkey ^l _sgpt_zsh

  ## git summarize ##
  # Leverage SGPT to produce intelligent and context-sensitive git commit messages.
  # By providing one argument, you can define the type of semantic commit (e.g. feat, fix, chore).
  # When supplying two arguments, the second parameter allows you to include more details for a more explicit prompt.
  gsum() {
    if ! git diff --quiet --cached; then
      git_changes="$(git --no-pager diff --staged)"
      query="Please generate git commit message for following git diff. Respond only with git message. Dont quote it in markdown"
      if [ $# -eq 2 ]; then
          query+="Declare commit message as $1. $2."
      elif [ $# -eq 1 ]; then
          query+="Declare commit message as $1."
      else
      fi
      commit_message="$(echo "$git_changes" | sgpt "$query")"
      printf "%s\n" "$commit_message"
      read -r "response?Do you want to commit your changes with this commit message? [y/N] "
      if [[ $response =~ ^[Yy]$ ]]; then
          git commit -m "$commit_message"
      else
          echo "Commit cancelled."
      fi
    else
      echo "No staged changes found. Do you want to stage changes? [y/N]"
      read -r "response?"
      if [[ $response =~ ^[Yy]$ ]]; then
        git add .
        gsum "$@"
      else
        echo "Commit cancelled."
      fi
    fi
  }

  gsumpoa() {
    git add . && gsum "$@" && git push -u origin
  }
else
  pipx install shell-gpt
  echo "Please restart shell to enable shell-gpt integration"
fi

#
# Cli improvements
#
if has "bat"; then
  alias cat='bat --theme="Solarized (light)" -p'
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

function loadrails() {
  zinit snippet PZT::modules/rails

  alias be='bundle exec'
  alias ror='bundle exec rails'
  alias rorc='bundle exec rails console'
  alias rordc='bundle exec rails dbconsole'
  alias rordm='bundle exec rake db:migrate'
  alias rordM='bundle exec rake db:migrate db:test:clone'
  alias rordr='bundle exec rake db:rollback'
  alias rake='noglob rake'
  alias rorg='bundle exec rails generate'
  alias rorl='tail -f "$(ruby-app-root)/log/development.log"'
  alias rorlc='bundle exec rake log:clear'
  alias rorr='bundle exec rails runner'
  alias rors='bundle exec rails server'
}


if [ -s "$HOME/.platformio/penv/bin/activate" ] ; then
  alias load-platformio='source ~/.platformio/penv/bin/activate'
fi

if has yt-dlp; then
  function youtube-extract-audio () {
    yt-dlp --ignore-errors -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o '~/Music/youtube/%(title)s.%(ext)s' "$@"
  }
  function youtube-mp3-playlist () {
    yt-dlp --ignore-errors -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o '~/Music/youtube/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s' "$@"
  }
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
    cpu_performance
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false 
    qdbus org.kde.KWin /KWin reconfigure
    sudo nice -n -10 su -c mixxx omen
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock true
    qdbus org.kde.KWin /KWin reconfigure
  }
fi

if has "tmuxinator" ; then
  alias mux="tmuxinator"
fi

if has "codium"; then
  alias code='codium'
fi

if has "ledfx"; then
  # Start ledfx in while loop for auto restart
  function start-ledfx () {
    # Check if docker is running

    while true; do
      ledfx --offline --host 0.0.0.0
    done
  }

  function start-ledfx-full-setup () {
    echo "Disabling bluetooth"
    sudo rfkill block bluetooth

    echo "Turn off docker"
    sudo systemctl stop docker
    sudo systemctl stop docker.socket

    echo "Starting ledfx"
    start-ledfx

    echo "Enabling bluetooth"
    sudo rfkill unblock bluetooth

    echo "Turn on docker"
    sudo systemctl start docker
    sudo systemctl start docker.socket
  }
fi

#
# Zinit options overrides
#

# https://martinheinz.dev/blog/110
unsetopt SHARE_HISTORY
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000000
export HISTIGNORE="ignorespace"
export SAVEHIST=1000000
export HISTORY_IGNORE="(ls|cd|pwd|exit|cd)*"
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

function cpu_performance {
  powerprofilesctl set performance
}

function cpu_powersave {
  powerprofilesctl set balanced
}

# Local config
# Not using it anywhere I think ?
# [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

if (( $+commands[atuin] )); then
  source <(atuin init zsh --disable-up-arrow)
fi

# if [ -f /snap/google-cloud-cli/current/completion.zsh.inc ]; then
#   source /snap/google-cloud-cli/current/completion.zsh.inc
# fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
(( ! ${+functions[p10k]} )) || p10k finalize
