# Skip all customizations if ZSHRC_SKIP_CUSTOMIZATIONS is set
# Useful for AI agents (VS Code Copilot, etc.) that need a minimal shell
[[ -n "${ZSHRC_SKIP_CUSTOMIZATIONS:-}" ]] && return

if [ ! -f "$HOME/.zshrc.zwc" -o "$HOME/.zshrc" -nt "$HOME/.zshrc.zwc" ]; then
  zcompile $HOME/.zshrc
fi

# Load dotfiles profile (Desktop/Server)
if [ -f "$HOME/.zshrc.d/profile.zsh" ]; then
  source "$HOME/.zshrc.d/profile.zsh"
fi

is_desktop() {
  local profile="${DOTFILES_PROFILE:-server}"
  if [[ "$profile" != "desktop" && "$profile" != "server" ]]; then
    echo "zshrc: Invalid DOTFILES_PROFILE '$profile'. Assuming 'server'." >&2
    return 1
  fi
  [[ "$profile" == "desktop" ]]
}

is_interactive() {
  [[ -t 0 ]]
}

is_slow_fs() {
  [[ "$PWD" == /mnt/nas* ]]
}

is_vscode_terminal() {
  [[ "${TERM_PROGRAM:-}" == "vscode" ]]
}

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

export DEFAULT_USER=$(whoami)

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
# Global zinit paths for current user
ZINIT_SCRIPT_REL=".zinit/bin/zinit.zsh"
ZINIT_SCRIPT="${HOME}/${ZINIT_SCRIPT_REL}"

source "${ZINIT_SCRIPT}"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
unalias zi 2>/dev/null  # Remove zinit's zi alias to preserve zoxide's zi
### End of zinit's installer chunk

# Url quotes magic
autoload -Uz bracketed-paste-url-magic
zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# Prompt download / initialization
#
if ! is_vscode_terminal; then
  zinit ice as"command" from"gh-r" \
            atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
            atpull"%atclone" src"init.zsh"
  zinit light starship/starship
fi

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

#
# Programs
#
##########################

if has "tmux"; then
  # Attach or create tmux session named after current directory.
  tat() {
    local session="${PWD##*/}"

    if [[ -n "$TMUX" ]]; then
      tmux has-session -t "$session" 2>/dev/null || tmux new-session -ds "$session"
      tmux switch-client -t "$session"
    else
      tmux attach -t "$session" 2>/dev/null || tmux new -s "$session"
    fi
  }
fi

zinit ice wait lucid from"gh-r" as"program" mv"fzf* -> fzf" pick"fzf/fzf" ; zinit light junegunn/fzf
export ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS="--height 40% --reverse"

# Not using now
# zinit light-mode from"gh-r" as"program" for @zellij-org/zellij

# A cat clone with syntax highlighting and Git integration.
zinit light-mode from"gh-r" as"program" mv"bat-*/bat -> bat" for @sharkdp/bat

# A viewer for git and diff output
zinit light-mode from"gh-r" as"program" mv"delta-*/delta -> delta" for @dandavison/delta

# A more intuitive version of du written in rust.
zinit light-mode from"gh-r" as"program" mv"dust-*/dust -> dust" for @bootandy/dust

# eza - modern ls replacement with icons and git integration
zinit light-mode from"gh-r" as"program" mv"eza -> eza" for @eza-community/eza
alias ls='eza --icons --group-directories-first'
alias l='eza -1a --icons --group-directories-first'
alias ll='eza -lh --icons --group-directories-first'
alias la='eza -lah --icons --group-directories-first'
alias lt='eza -T --icons --group-directories-first'  # tree view

# zoxide - smarter cd with frecency
zinit light-mode from"gh-r" as"program" \
  atclone"./zoxide init zsh > init.zsh" atpull"%atclone" src"init.zsh" \
  for @ajeetdsouza/zoxide
alias cd='z'

# Lucid - Turbo mode is verbose, so you need an option for quiet.
zinit light-mode wait"2" lucid as"program" pick"git-fixup" for @keis/git-fixup

zinit light-mode wait"2" lucid from"gh-r" as"program" \
  atclone"./just --completions zsh > _just" atpull"%atclone" \
  pick"just" for @casey/just

if is_desktop; then
  zinit light-mode from"gh-r" as"program" \
    atclone"./gh completion -s zsh > _gh" atpull"%atclone" \
    mv"gh_*/bin/gh -> gh" for @cli/cli

  zinit light-mode as'program' bpick'mise-*.tar.gz' from'gh-r' for \
      pick'mise/bin/mise' \
      atclone'./mise/bin/mise complete zsh >_mise' atpull'%atclone' \
      @jdx/mise

  # Fixes:
  # Error: usage CLI not found. This is required for completions to work in mise.
  # See https://usage.jdx.dev for more information.
  zinit light-mode wait"1" lucid from"gh-r" as"program" pick"usage" for @jdx/usage

  zinit light-mode from"gh-r" as"program" \
    bpick"codex-x86_64-unknown-linux-musl.tar.gz" \
    mv"codex-x86_64-unknown-linux-musl -> codex" \
    for @openai/codex
fi

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

# Apt
# Use sudo without aliases
alias instaluj="\sudo apt install -y"
alias szukaj="\sudo apt-cache search"
alias czysc_dpkg="\sudo apt autoremove -y --purge ; dpkg --list |grep \"^rc\" | cut -d \" \" -f 3 | xargs --no-run-if-empty \sudo dpkg --purge"

# Pipx nees to be updated as user
function update () {
  sudo sh -c 'apt autoremove -y --purge && apt update && apt full-upgrade -y && apt autoremove -y --purge'
}

function update-all () {
  # Determine target non-root user for user-scoped updates
  # Prefer the invoking sudo user, otherwise fall back to UID 1000 or current user
  local target_user
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    target_user="${SUDO_USER}"
  else
    target_user="$(id -nu 1000 2>/dev/null)"
    [[ -z "${target_user}" ]] && target_user="${USER}"
  fi

  # Resolve target user's home directory
  local target_home
  target_home="$(getent passwd "${target_user}" 2>/dev/null | cut -d: -f6)"
  [[ -z "${target_home}" ]] && target_home="$HOME"

  echo "[apt] Running system package maintenance"
  if update; then
    echo "[apt] System package maintenance complete"
  else
    echo "[apt] System package maintenance failed"
  fi

  if has "flatpak"; then
    echo
    echo "[flatpak] Updating flatpak apps"
    if sudo -H -u "${target_user}" flatpak update -y; then
      echo "[flatpak] Update complete"
    else
      echo "[flatpak] Update failed"
    fi
  fi

  if has "snap"; then
    echo
    echo "[snap] Refreshing snaps"
    if snap refresh; then
      echo "[snap] Refresh complete"
    else
      echo "[snap] Refresh failed"
    fi
  fi

  if has "pipx"; then
    echo
    echo "[pipx] Upgrading pipx packages"
    if sudo -H -u "${target_user}" pipx upgrade-all --include-injected; then
      echo "[pipx] Upgrade complete"
    else
      echo "[pipx] Upgrade failed"
    fi
  fi

  # Update zinit-managed plugins for the target user with concise messaging
  local zinit_script="${target_home}/${ZINIT_SCRIPT_REL}"
  if [[ -f "${zinit_script}" ]]; then
    local zinit_command="source \"${zinit_script}\"; zinit update -q --all"
    echo
    echo "[zinit] Updating plugins"
    sudo -H -u "${target_user}" zsh -lc "${zinit_command}" >/dev/null 2>&1
    local _ec=$?
    if (( _ec == 0 )); then
      echo "[zinit] Update complete"
    else
      echo "[zinit] Update failed (exit ${_ec}) try running: 'sudo -H -u ${target_user} zsh -lc \"${zinit_command}\"' to see details."
    fi
  else
    echo
    echo "[zinit] Skipping zinit update: '${zinit_script}' not found for user '${target_user}'."
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
    git reset HEAD $1 && git checkout -- $1
  }

  function gcb () {
    git switch $1 2>/dev/null || git switch -c $1;
  }

  function gcmmpoa () {
    git commit -m "$1" "$@[2,-1]" -a -u && git pull ; git push -u origin
  }
fi


if is_desktop; then
  # Bonus
  alias update_bonus="ssh bonus -t 'cd ~/bonus_docker ; git pull origin'"
fi

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

# Directory listing (eza with slow fs fallback)
function ls() {
  if is_slow_fs; then
    command ls --color=auto "$@"
  else
    command eza --icons --group-directories-first "$@"
  fi
}
# eza aliases are defined above with zinit; these are kept for slow fs fallback reference
alias lr='ll -R'         # Lists human readable sizes, recursively.
alias lm='la | "$PAGER"' # Lists human readable sizes, hidden files through pager.
alias lk='ll -Sr'        # Lists sorted by size, largest last.
alias lc='ll -tr -c'     # Lists sorted by date, most recent last, shows change time.
alias lu='ll -tr -u'     # Lists sorted by date, most recent last, shows access time.

# Disable globbing.
alias fc='noglob fc'
alias find='noglob find'
alias ftp='noglob ftp'
alias history='noglob history'
alias locate='noglob locate'
alias scp='noglob scp'
alias sftp='noglob sftp'

# Secure double check
alias rm='rm -I'

# Editor configuration is handled by ~/.zshrc.d/editor.zsh (generated by install script)

#
# Cli improvements
#
if has "rsync"; then
  alias rsync='noglob rsync'
  alias cpx='rsync -avz --info=progress2 --human-readable'
fi


if has "bat" && is_interactive && ! is_vscode_terminal ; then
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

if has "ledfx"; then
  # Start ledfx in while loop for auto restart
  function start-ledfx () {
    # Check if docker is running

    while true; do
      ledfx --offline --host 0.0.0.0
    done
  }

  function start-ledfx-full-setup () {
    function __ledfx_cleanup () {
      trap - EXIT
      trap '' INT TERM

      echo "Enabling bluetooth"
      sudo rfkill unblock bluetooth

      echo "Turn on docker"
      sudo systemctl start docker
      sudo systemctl start docker.socket

      trap - INT TERM
      unset -f __ledfx_cleanup
    }

    # Ensure bluetooth and docker get restored even if interrupted.
    trap '__ledfx_cleanup' EXIT
    trap '__ledfx_cleanup; return 130' INT
    trap '__ledfx_cleanup; return 143' TERM

    echo "Disabling bluetooth"
    sudo rfkill block bluetooth

    echo "Turn off docker"
    sudo systemctl stop docker
    sudo systemctl stop docker.socket

    echo "Starting ledfx"
    start-ledfx
    local exit_code=$?

    trap - EXIT INT TERM
    __ledfx_cleanup

    return $exit_code
  }
fi

if has "code"; then
  alias codenw="code -n -w ."


  code_pod() {
    local input="$1"
    local app folder
    app="${input%%/*}"
    folder="${input#*/}"
    if [[ -z $input || $app == "$input" || -z $folder ]]; then
      echo "usage: code_pod <app-name>/<path>"
      return 1
    fi

    local kubectl_bin
    kubectl_bin=$(command -v kubectl) || {
      echo "kubectl not found in PATH"
      return 1
    }

    local line ns pod
    line=$("$kubectl_bin" get pods -A -l app.kubernetes.io/name="$app" \
      -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.namespace} {.metadata.name}{"\n"}{end}' \
      | head -n1)

    ns=${line%% *}
    pod=${line#* }

    if [[ -z $pod || -z $ns || $pod == "$line" ]]; then
      echo "no running pod found for app=$app"
      return 1
    fi

    local ctx json hex path_esc
    ctx=$("$kubectl_bin" config current-context 2>/dev/null || printf "default")
    json=$(printf '{"context":"%s","podname":"%s","namespace":"%s","name":"codeserver"}' "$ctx" "$pod" "$ns")
    hex=$(printf '%s' "$json" | xxd -p -c 999 | tr -d '\n')
    path_esc=${folder// /%20}

    code --folder-uri="vscode-remote://k8s-container%2B${hex}/${path_esc}"
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
export SAVEHIST=1000000
# Ignore trivial commands in history
export HISTORY_IGNORE="(ls|pwd|exit|curl)*"
# Don't record commands that start with a space (zsh option)
setopt HIST_IGNORE_SPACE
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

if is_desktop && is-at-least '2.32' `getconf GNU_LIBC_VERSION | rev | cut -d " " -f 1 | rev` ; then
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

if has "mise"; then
  # Lazy-load mise activation for faster startup
  _mise_lazy_init() {
    unfunction _mise_lazy_init
    eval "$(mise activate zsh)"
    # Override mise hook to disable it in /mnt/nas
    _mise_hook() {
      if is_slow_fs; then
        return
      fi
      local previous_exit_status=$?;
      trap -- '' SIGINT;
      eval "$(mise export zsh)";
      trap - SIGINT;
      return $previous_exit_status;
    }
  }
  add-zsh-hook precmd _mise_lazy_init
fi

# Switch Starship config based on directory
function _starship_config_switch() {
  if is_slow_fs; then
    export STARSHIP_CONFIG="$HOME/.config/starship-lite.toml"
  else
    unset STARSHIP_CONFIG
  fi
}
add-zsh-hook chpwd _starship_config_switch
_starship_config_switch # Run once on init

if has "tmuxinator" ; then
  zinit ice as"completion" mv"tmuxinator.zsh -> _tmuxinator"; zinit snippet https://raw.githubusercontent.com/tmuxinator/tmuxinator/master/completion/tmuxinator.zsh

  alias mux="tmuxinator"
fi

# Starship is already initialized via zinit above; avoid double init to prevent recursive zle wrappers.
_title_terminal_pwd
