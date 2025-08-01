# Disable Powerlevel10k configuration wizard
export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
#
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [ ! -f "$HOME/.zshrc.zwc" -o "$HOME/.zshrc" -nt "$HOME/.zshrc.zwc" ]; then
  zcompile $HOME/.zshrc
fi

setopt globdots               # Include hidden files (those starting with a dot) in pathname expansion
setopt nullglob               # Allows filename patterns which match no files to expand to a null string, rather than themselves
setopt noflowcontrol          # Disable flow control (e.g., prevent Ctrl-S and Ctrl-Q from stopping output)
setopt interactivecomments    # Enable the use of comments in interactive shells
typeset -U path

# Path manipulation
if [ -d "$HOME/bin" ]; then
  path+=("$HOME/bin")
fi

if [ -d "$HOME/.local/bin" ]; then
  path+=("$HOME/.local/bin")
fi

if [ -d "$HOME/.krew/bin" ]; then
  path+=("$HOME/.krew/bin")
fi

if [ -d "$HOME/.local/share/yabridge/" ]; then
  path+=("$HOME/.local/share/yabridge/")

  function update-yabridge () {
    wget "$(docker run --rm ghcr.io/dvershinin/lastversion:latest robbert-vdh/yabridge --assets --filter '^((?!ubuntu).)*$')" -O "/tmp/yabridge.tar.gz" && \
    cd "/tmp" && \
    tar zxvf "yabridge.tar.gz" && \
    rm -rf "$HOME/.local/share/yabridge/" && \
    mv -f "yabridge" "$HOME/.local/share" && \
    rm "/tmp/yabridge.tar.gz"
    yabridgectl sync
  }
fi

if [ -d "$HOME/go/bin" ]; then
  path+=("$HOME/go/bin")
fi

# For snap
if [ -f /etc/profile.d/apps-bin-path.sh ]; then
  source /etc/profile.d/apps-bin-path.sh
fi

DISABLE_AUTO_TITLE="true"

export VISUAL=vim
export EDITOR=$VISUAL
export DEFAULT_USER=$(whoami)

# export DIRENV_LOG_FORMAT=
# make it more responsive
export KEYTIMEOUT=1

export MC_SKIN=$HOME/.mc/solarized.ini

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
zinit light-mode lucid nocd depth='1' for @romkatv/powerlevel10k

#
# Completions
#

# zinit ice as"completion" mv"chezmoi* -> _chezmoi"; zinit snippet https://github.com/twpayne/chezmoi/blob/master/completions/chezmoi.zsh

# Local snippets

zinit light-mode for \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-link-man \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-binary-symlink \
  zdharma-continuum/z-a-submods \
  le0me55i/zsh-extract

# ## Enhancd
# zinit light b4b4r07/enhancd
# # https://github.com/babarot/enhancd#configuration
# export ENHANCD_ARG_DOUBLE_DOT="..."
# export ENHANCD_ARG_HYPHEN="--"
# export ENHANCD_FILTER="fzf --height 40%:fzy"

#
# Programs
#
##########################

zinit light-mode as"program" pick"bin/tat" for @thoughtbot/dotfiles # Attach or create tmux session named the same as current directory.

zinit ice wait lucid from"gh-r" as"program" mv"fzf* -> fzf" pick"fzf/fzf" ; zinit light junegunn/fzf
export ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS="--height 40% --reverse"

zinit light-mode from"gh-r" as"program" for @zellij-org/zellij

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
# Lucid - Turbo mode is verbose, so you need an option for quiet.
zinit light-mode wait"2" lucid as"program" pick"git-fixup" for @keis/git-fixup

zinit light-mode wait"2" lucid from"gh-r" as"program" \
  atclone"./just --completions zsh > _just" atpull"%atclone" \
  pick"just" for @casey/just

zinit light-mode from"gh-r" as"program" \
  atclone"./gh completion -s zsh > _gh" atpull"%atclone" \
  mv"gh_*/bin/gh -> gh" for @cli/cli

# zinit light-mode src"asdf.sh" atclone'%atpull' atclone'ln -sf $PWD/asdf.sh $HOME/.asdf/' for @asdf-vm/asdf

# mise
zinit light-mode as'program' bpick'mise-*.tar.gz' from'gh-r' for \
    pick'mise/bin/mise' \
    atclone'./mise/bin/mise complete zsh >_mise' atpull'%atclone' \
    @jdx/mise

zinit light-mode wait"1" lucid from"gh-r" as"program" pick"usage" for @jdx/usage

##########################

zinit wait lucid for \
  light-mode \
  atinit"
    # Hash holding paths that shouldn't be grepped (globbed) – blacklist for slow disks, mounts, etc.
    # https://github.com/zdharma-continuum/fast-syntax-highlighting/blob/cf318e06a9b7c9f2219d78f41b46fa6e06011fd9/CHANGELOG.md?plain=1#L104
    typeset -gA FAST_BLIST_PATTERNS; FAST_BLIST_PATTERNS[/mnt/*]=1
    ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay
  " \
    zdharma-continuum/fast-syntax-highlighting \
  light-mode atinit"ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=80" atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions

#
# Aliases
#
#

# Apt
# Use sudo without aliases
alias instaluj="\sudo apt install -y"
alias szukaj="\sudo apt-cache search"
alias czysc_dpkg="\sudo apt autoremove -y --purge ; dpkg --list |grep \"^rc\" | cut -d \" \" -f 3 | xargs --no-run-if-empty \sudo dpkg --purge"
# Pipx nees to be updated as user
function update () {
  local user='#1000'

  sudo apt autoremove -y --purge &&
  sudo apt update &&
  sudo apt full-upgrade -y &&
  sudo apt autoremove -y --purge

  if has "flatpak"; then
    sudo -u "$user" flatpak update -y
  fi

  if has "snap"; then
    snap refresh
  fi

  if has "pipx"; then
    sudo -u "$user" pipx upgrade-all --include-injected
  fi
}

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
    git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null \
      | sed 's@^refs/remotes/origin/@@'
  }

  function grhco () {
    grh $1 && gco $1
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
alias -g T='| tail'
alias -g X='| xargs'
alias -g J='| jq'
alias -g JL='| jq -C | less -R'

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


#
# Cli improvements
#
if has "bat"; then
  alias cat='bat --theme="Solarized (light)" -p'
fi

if has "rg"; then
  alias rg='rg -i'
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
# Store history in XDG compliant location
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ ! -d ${HISTFILE:h} ]] && mkdir -p "${HISTFILE:h}"
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

  function loadrails() {
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
fi

function cpu_performance {
  powerprofilesctl set performance
}

function cpu_powersave {
  powerprofilesctl set balanced
}

export_on_demand_env() {
  local ENV_NAME VAULT_URL response value

  # Check if environment variable name is provided
  if [[ -z "$1" ]]; then
    echo "Usage: export_on_demand_env <ENV_NAME>"
    return 1
  fi

  ENV_NAME="$1"

  # Check if VAULT_TOKEN is already set, else prompt for it
  if [[ -z "${VAULT_TOKEN:-}" ]]; then
    read -rs "VAULT_TOKEN?Please enter your Vault token: "
    echo
  fi

  # Define Vault URL for the specific on-demand secret
  VAULT_URL="https://vault.8567153.xyz/v1/shell_envs/data/on_demand"

  # Fetch the secret from Vault
  response=$(curl -sf -H "X-Vault-Token: $VAULT_TOKEN" -X GET "$VAULT_URL") || {
    echo "Failed to fetch secret for '$ENV_NAME' from Vault." >&2
    return 1
  }

  # Extract the value of the specified environment variable using jq
  value=$(echo "$response" | jq -r ".data.data.\"$ENV_NAME\"") || {
    echo "Failed to parse the secret data for '$ENV_NAME'." >&2
    return 1
  }

  # Export the environment variable in the current shell session
  export "$ENV_NAME"="$value"

  echo "Environment variable '$ENV_NAME' has been exported."
}

# Includes, it needs to be here to prevent some fuckups with atuin ctrl + r
for file in $HOME/.zsh/*.zsh; do
  source $file
  # echo "Sourced $file"
  # echo "Bindkey `bindkey |grep 'R'`"
done

if is-at-least '2.32' `getconf GNU_LIBC_VERSION | rev | cut -d " " -f 1 | rev` ; then
  zinit light-mode as"program" from"gh-r" bpick"atuin-*.tar.gz" mv"atuin*/atuin -> atuin" \
    atclone"./atuin init zsh --disable-up-arrow > init.zsh; ./atuin gen-completions --shell zsh > _atuin" \
    atpull"%atclone" src"init.zsh" for @atuinsh/atuin
else
  zinit light-mode for joshskidmore/zsh-fzf-history-search
fi

# Local includes
if [[ -d "$HOME/.zshrc.d" ]]; then
  for file in "$HOME"/.zshrc.d/*.zsh(N); do
    source "$file"
  done
fi

eval "$(mise activate zsh --shims)"

if has "tmuxinator" ; then
  zinit ice as"completion" mv"tmuxinator* -> _tmuxinator"; zinit snippet https://raw.githubusercontent.com/tmuxinator/tmuxinator/master/completion/tmuxinator.zsh

  alias mux="tmuxinator"
fi

(( ! ${+functions[p10k]} )) || p10k finalize
