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

is_vscode_terminal() {
  [[ "${TERM_PROGRAM:-}" == "vscode" ]]
}

setopt globdots               # Include hidden files (those starting with a dot) in pathname expansion
setopt nullglob               # Allows filename patterns which match no files to expand to a null string, rather than themselves
setopt noflowcontrol          # Disable flow control (e.g., prevent Ctrl-S and Ctrl-Q from stopping output)
setopt interactivecomments    # Enable the use of comments in interactive shells
typeset -U path fpath

# Path manipulation
if [ -d "$HOME/bin" ]; then
  path+=("$HOME/bin")
fi

if [ -d "$HOME/.local/bin" ]; then
  path+=("$HOME/.local/bin")
fi

if [ -d "$HOME/.local/share/mise/shims" ]; then
  path+=("$HOME/.local/share/mise/shims")
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

#
# Completions
#

# zinit ice as"completion" mv"chezmoi* -> _chezmoi"; zinit snippet https://github.com/twpayne/chezmoi/blob/master/completions/chezmoi.zsh

# Local snippets

zinit light-mode wait lucid for \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-link-man \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-binary-symlink \
  zdharma-continuum/z-a-submods

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
alias l='ls -1a'
alias ll='ls -lh'
alias la='ls -lah'
alias lt='ls -T'  # tree view

# zoxide - smarter cd with frecency
zinit light-mode from"gh-r" as"program" \
  atclone"./zoxide init zsh > init.zsh" atpull"%atclone" src"init.zsh" \
  for @ajeetdsouza/zoxide

# Override cd to use zoxide when available, fallback to builtin otherwise
# This prevents errors in non-interactive shells (e.g., Claude Code)
function cd() {
  if (( $+functions[__zoxide_z] )); then
    __zoxide_z "$@"
  else
    builtin cd "$@"
  fi
}

# Interactive directory selection with fzf and zoxide
# Securely change to a directory chosen from zoxide's database
function cdls() {
  if ! has "fzf"; then
    echo "cdls: fzf is not installed" >&2
    return 1
  fi

  if ! has "zoxide"; then
    echo "cdls: zoxide is not installed" >&2
    return 1
  fi

  local dir
  dir=$(zoxide query --list | fzf --header "Choose directory:") || return $?

  if [[ -z "$dir" ]]; then
    echo "cdls: no directory selected" >&2
    return 1
  fi

  cd -- "$dir"
}

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

  zinit light-mode from"gh-r" as"program" \
    atclone"./opencode completion > _opencode; echo 'compdef _opencode_yargs_completions oc' >> _opencode" atpull"%atclone" \
    bpick"$(
      emulate -L zsh

      typeset os arch ext baseline_suffix musl_suffix
      baseline_suffix=""
      musl_suffix=""

      case "$OSTYPE" in
        linux*)  os="linux";  ext="tar.gz" ;;
        darwin*) os="darwin"; ext="zip" ;;
        *)       os="linux";  ext="tar.gz" ;;
      esac

      case "$(uname -m)" in
        x86_64)        arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)             arch="x64" ;;
      esac

      if [[ "$arch" == "x64" ]]; then
        if [[ "$os" == "linux" ]] && [[ -r /proc/cpuinfo ]]; then
          grep -qi 'avx2' /proc/cpuinfo || baseline_suffix="-baseline"
        elif [[ "$os" == "darwin" ]] && command -v sysctl >/dev/null 2>&1; then
          [[ "$(sysctl -n hw.optional.avx2_0 2>/dev/null)" == "1" ]] || baseline_suffix="-baseline"
        fi
      fi

      if [[ "$os" == "linux" ]]; then
        if [[ -f /etc/alpine-release ]]; then
          musl_suffix="-musl"
        elif command -v ldd >/dev/null 2>&1 && ldd --version 2>/dev/null | grep -qi 'musl'; then
          musl_suffix="-musl"
        fi
      fi

      print -r -- "opencode-${os}-${arch}${baseline_suffix}${musl_suffix}.${ext}"
    )" \
    pick"opencode" \
    for @anomalyco/opencode
fi

##########################

zinit wait lucid for \
  light-mode \
  atinit"
    # Hash holding paths that shouldn't be grepped (globbed) – blacklist for slow disks, mounts, etc.
    # https://github.com/zdharma-continuum/fast-syntax-highlighting/blob/cf318e06a9b7c9f2219d78f41b46fa6e06011fd9/CHANGELOG.md?plain=1#L104
    typeset -gA FAST_BLIST_PATTERNS; FAST_BLIST_PATTERNS[/mnt/*]=1
    ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay
    # Set up zoxide completion for z and cd (after compinit)
    # Note: zoxide's own compdef runs before compinit, so we must set it up here
    (( $+functions[__zoxide_z_complete] )) && compdef __zoxide_z_complete z cd
  " \
    zdharma-continuum/fast-syntax-highlighting \
  light-mode atinit"ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=80" atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions

#
# Aliases
#

# AI tools
if has "opencode"; then
  alias oc="opencode"
fi

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

  # Include mise shims so npm is discoverable when running via sudo
  local npm_env_path="${target_home}/.local/share/mise/shims:${target_home}/.local/share/mise/bin:${target_home}/.local/bin:/usr/local/bin:/usr/bin:/bin"

  if sudo -H -u "${target_user}" env PATH="${npm_env_path}" sh -lc 'command -v npm >/dev/null 2>&1'; then
    echo
    echo "[npm] Updating global npm packages"
    if sudo -H -u "${target_user}" env PATH="${npm_env_path}" NPM_CONFIG_LOGLEVEL=error npm update -g; then
      echo "[npm] Update complete"
    else
      echo "[npm] Update failed"
    fi
  else
    echo
    echo "[npm] Skipping npm update: npm not found for user '${target_user}'."
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

  # Worktree
  alias gwtls='git worktree list'
  alias gwtrm='git worktree remove'
  alias gwtpr='git worktree prune'

  function gwta() {
    local branch=$1
    local base=${2:-$(git_main_branch)} # Default to main branch from origin if missing
    local dir="$PWD"
    local root=""
    local new_wt_path=""
    # Define files to link from main worktree
    local files_to_link=( ".env" )

    if [[ -z "$branch" ]]; then
      echo "Usage: gwta <branch-name> [base]"
      return 1
    fi

    if [[ "$branch" =~ "/" ]]; then
      echo "Error: Branch name cannot contain '/' to prevent accidental subdirectory creation."
      return 1
    fi

    # Walk up the directory tree to find .bare
    while [[ "$dir" != "/" ]]; do
      if [[ -d "$dir/.bare" ]]; then
        root="$dir"
        break
      fi
      dir=$(dirname "$dir")
    done

    if [[ -n "$root" ]]; then
      echo "Found .bare root at: $root"
      new_wt_path="$root/$branch"
      git -C "$root/.bare" worktree add -b "$branch" "$new_wt_path" "$base"
    else
      # Fallback for standard repositories (sibling folder strategy)
      echo "No .bare found, assuming standard repo."
      new_wt_path="${PWD:h}/$branch"
      git worktree add -b "$branch" "../$branch" "$base"
    fi

    local ret=$?
    if [[ $ret -eq 0 ]]; then
      local main_branch_name
      main_branch_name=$(git_main_branch 2>/dev/null)

      if [[ -n "$main_branch_name" ]]; then
         local main_wt_path
         if [[ -n "$root" ]]; then
            main_wt_path=$(git -C "$root/.bare" worktree list | grep " \[${main_branch_name}\]$" | awk '{print $1}' | head -n 1)
         else
            main_wt_path=$(git worktree list | grep " \[${main_branch_name}\]$" | awk '{print $1}' | head -n 1)
         fi

         if [[ -n "$main_wt_path" ]]; then
           for file in "${files_to_link[@]}"; do
             if [[ -f "$main_wt_path/$file" ]]; then
               echo "Linking $file from $main_wt_path to $new_wt_path"
               ln -s "$main_wt_path/$file" "$new_wt_path/$file"
             fi
           done
         fi
      fi
    fi
    return $ret
  }

  function git_main_branch () {
    git ls-remote --symref origin HEAD | sed -n 's#^ref: refs/heads/\(.*\)\s\+HEAD#\1#p'
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
  # X cli
  alias bird='SWEET_COOKIE_CHROME_SAFE_STORAGE_PASSWORD=$(kwallet-query --read-password "Brave Safe Storage" --folder "Brave Keys" kdewallet) bird --cookie-source chrome --chrome-profile-dir ~/.config/BraveSoftware/Brave-Browser/Default'
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

# Directory listing
unalias ls 2>/dev/null
alias ls='eza --icons --group-directories-first'
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


if has "bat" && is_interactive ; then
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

  # Connect VS Code to a pod's codeserver container
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

  code_pod_cleanup() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl) || {
      echo "kubectl not found in PATH"
      return 1
    }

    if [[ "$1" == "--all" || "$1" == "-a" ]]; then
      echo "Cleaning up all debug pods..."
      "$kubectl_bin" delete pods -A -l code-pod.debug=true
      return $?
    fi

    if [[ -z "$1" ]]; then
      echo "usage: code_pod_cleanup <app-name> | --all"
      echo ""
      echo "Active debug pods:"
      "$kubectl_bin" get pods -A -l code-pod.debug=true -o wide 2>/dev/null || echo "  (none)"
      return 1
    fi

    local app="$1"
    local debug_pod="${app}-debug-pod"

    # Find namespace
    local ns
    ns=$("$kubectl_bin" get pods -A -l "code-pod.debug=true,app.kubernetes.io/name=$app" \
      -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)

    if [[ -z "$ns" ]]; then
      echo "No debug pod found for app: $app"
      return 1
    fi

    echo "Deleting debug pod: $debug_pod (namespace: $ns)"
    "$kubectl_bin" delete pod "$debug_pod" -n "$ns"
  }

  # Specialized function for Home Assistant development
  # Usage: code_hass <instance>
  code_hass() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl) || { echo "kubectl not found"; return 1; }
    command -v jq &>/dev/null || { echo "jq required"; return 1; }

    # List available instances if no argument
    if [[ -z "$1" ]]; then
      echo "Usage: code_hass <instance>"
      echo ""
      echo "Available instances:"
      "$kubectl_bin" get pods -n iot -l app.kubernetes.io/name -o json 2>/dev/null | \
        jq -r '.items[].metadata.labels["app.kubernetes.io/name"] // empty' | \
        grep '^homeassistant-' | sed 's/homeassistant-/  /' | sort -u
      return 0
    fi

    local instance="$1"
    local app="homeassistant-${instance}"
    local ns="iot"
    local debug_pod="${app}-debug-pod"

    # Check if debug pod exists and is actually running (not terminating)
    local pod_info existing_phase is_terminating
    pod_info=$("$kubectl_bin" get pod "$debug_pod" -n "$ns" --ignore-not-found \
      -o jsonpath='{.status.phase} {.metadata.deletionTimestamp}' 2>/dev/null)
    existing_phase="${pod_info%% *}"
    is_terminating="${pod_info#* }"

    if [[ "$existing_phase" == "Running" && -z "$is_terminating" ]]; then
      echo "Reusing existing debug pod: $debug_pod" >&2
    else
      # Find source pod
      local src_pod
      src_pod=$("$kubectl_bin" get pods -n "$ns" -l "app.kubernetes.io/name=$app" \
        -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')

      [[ -z "$src_pod" ]] && { echo "No running pod for $app"; return 1; }

      # Cleanup old pod if exists (including Terminating state)
      if [[ -n "$existing_phase" ]]; then
        local status_msg="$existing_phase"
        [[ -n "$is_terminating" ]] && status_msg="Terminating"
        echo "Cleaning up old pod ($status_msg)..." >&2
        "$kubectl_bin" delete pod "$debug_pod" -n "$ns" --force --grace-period=0 >/dev/null 2>&1
        # Wait for pod to be gone
        while "$kubectl_bin" get pod "$debug_pod" -n "$ns" >/dev/null 2>&1; do
          sleep 1
        done
      fi

      # Get pod spec components
      local node volume_spec tolerations_json env_json labels_json
      node=$("$kubectl_bin" get pod "$src_pod" -n "$ns" -o jsonpath='{.spec.nodeName}')
      volume_spec=$("$kubectl_bin" get pod "$src_pod" -n "$ns" -o json | \
        jq -c '.spec.volumes[] | select(.name=="config")')
      tolerations_json=$("$kubectl_bin" get pod "$src_pod" -n "$ns" -o json | jq -c '.spec.tolerations // []')
      # Copy labels from original pod (for NetworkPolicy), but change controller to avoid service selector match
      labels_json=$("$kubectl_bin" get pod "$src_pod" -n "$ns" -o json | \
        jq -c '.metadata.labels | del(.["pod-template-hash"]) | .["code-pod.debug"] = "true" | .["app.kubernetes.io/controller"] = "debug"')

      # Get env vars, fix localhost -> external IP (NetworkPolicy allows 192.168.x.x)
      local svc_ip
      svc_ip=$("$kubectl_bin" get svc "${app}-app" -n "$ns" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
      [[ -z "$svc_ip" ]] && svc_ip=$("$kubectl_bin" get svc "${app}-app" -n "$ns" -o jsonpath='{.spec.clusterIP}')
      env_json=$("$kubectl_bin" get pod "$src_pod" -n "$ns" -o json | \
        jq -c --arg svc "$svc_ip" '
          .spec.containers[] | select(.name=="codeserver") | .env // [] |
          map(if .value then .value |= gsub("localhost"; $svc) | . else . end)
        ')

      echo "Creating debug pod: $debug_pod (node: $node)" >&2

      # Create debug pod
      jq -n \
        --arg name "$debug_pod" \
        --arg node "$node" \
        --argjson labels "$labels_json" \
        --argjson tolerations "$tolerations_json" \
        --argjson volspec "$volume_spec" \
        --argjson env "$env_json" \
        '{
          apiVersion: "v1",
          kind: "Pod",
          metadata: {
            name: $name,
            labels: $labels
          },
          spec: {
            activeDeadlineSeconds: 21600,
            hostNetwork: true,
            dnsPolicy: "ClusterFirstWithHostNet",
            nodeSelector: { "kubernetes.io/hostname": $node },
            tolerations: $tolerations,
            restartPolicy: "Never",
            containers: [{
              name: "debug",
              image: "ubuntu:24.04",
              command: ["sleep", "infinity"],
              env: ($env + [{ name: "VSCODE_AGENT_FOLDER", value: "/config/.vscode-server" }]),
              volumeMounts: [{ name: "config", mountPath: "/config" }],
              resources: { requests: { memory: "256Mi", cpu: "100m" }, limits: { memory: "4Gi", cpu: "2" } }
            }],
            volumes: [$volspec]
          }
        }' | "$kubectl_bin" apply -n "$ns" -f - >&2

      echo "Waiting for pod..." >&2
      "$kubectl_bin" wait pod "$debug_pod" -n "$ns" --for=condition=Ready --timeout=120s >&2 || return 1
    fi

    echo "" >&2
    echo "HASS debug pod ready! (auto-shutdown 6h)" >&2
    echo "Cleanup: code_pod_cleanup $app" >&2
    echo "" >&2

    # Connect VS Code
    local ctx json hex
    ctx=$("$kubectl_bin" config current-context 2>/dev/null || printf "default")
    json=$(printf '{"context":"%s","podname":"%s","namespace":"%s","name":"debug"}' "$ctx" "$debug_pod" "$ns")
    hex=$(printf '%s' "$json" | xxd -p -c 999 | tr -d '\n')
    code --folder-uri="vscode-remote://k8s-container%2B${hex}/config"
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
  }
  add-zsh-hook precmd _mise_lazy_init
fi

# Lazy-load complist only when you press TAB the first time
_lazy_tab_complete() {
  zmodload -i zsh/complist
  bindkey -M menuselect '^[ ' send-break 2>/dev/null   # (ignore; see next line)
  bindkey -M menuselect '^[' send-break                # ESC closes the menu

  # After first run, replace TAB back to normal (so this runs only once)
  bindkey '^I' expand-or-complete

  zle .expand-or-complete
}
zle -N _lazy_tab_complete
bindkey '^I' _lazy_tab_complete

if has "tmuxinator" ; then
  zinit ice as"completion" mv"tmuxinator.zsh -> _tmuxinator"; zinit snippet https://raw.githubusercontent.com/tmuxinator/tmuxinator/master/completion/tmuxinator.zsh

  alias mux="tmuxinator"
fi

# Auto-select starship config based on REMOTE_FS environment variable
# REMOTE_FS=1 indicates a slow/network filesystem mount (e.g., SSHFS)
if [[ -n "${REMOTE_FS:-}" ]]; then
  export STARSHIP_CONFIG="${HOME}/.config/starship-network-fs.toml"
else
  export STARSHIP_CONFIG="${HOME}/.config/starship.toml"
fi

# Initialize Starship prompt last to avoid recursive ZLE wrappers when using vi-mode/atuin.
# We also use a guard to prevent multiple initializations if .zshrc is sourced again.
if [[ -z "$STARSHIP_INITIALIZED" ]]; then
  zinit ice as"command" from"gh-r" \
            atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
            atpull"%atclone" src"init.zsh"
  zinit light starship/starship
  STARSHIP_INITIALIZED=1
fi

_title_terminal_pwd

# Fix SSH agent forwarding for tmux (creates symlink that .tmux.conf expects)
if [[ -n "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock" ]]; then
  ln -sfn "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
fi

if is_desktop && is_interactive && [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  # SSH agent management (desktop only). Avoid overriding an existing agent/forwarded SSH_AUTH_SOCK.
  SSH_ENV="$HOME/.ssh/agent-environment"

  function _start_agent {
      echo "Starting new SSH agent..."
      ssh-agent | sed 's/^echo/#echo/' > "$SSH_ENV"
      chmod 600 "$SSH_ENV"
      . "$SSH_ENV" > /dev/null
  }

  # Check if agent is already running
  if [[ -f "$SSH_ENV" ]]; then
      . "$SSH_ENV" > /dev/null
      # Check if the agent is actually running
      if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
          _start_agent
      fi
  else
      _start_agent
  fi
fi

# Disable git completion on remote filesystems to avoid lag
# When REMOTE_FS is set (e.g., SSHFS mounts), use simple file completion instead
if [[ -n "${REMOTE_FS:-}" ]]; then
  # Override git completion with simple file completion to avoid I/O lag
  # zcompdef is zinit's wrapper around compdef - we prefer it for consistency
  # with other completions in this zshrc, but fall back to standard compdef
  # if zinit hasn't loaded yet (e.g., in minimal/non-interactive shells)
  if (( $+functions[zcompdef] )); then
    zcompdef _files git
  elif (( $+functions[compdef] )); then
    compdef _files git
  fi
fi

