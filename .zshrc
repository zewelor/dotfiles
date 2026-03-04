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

if has "zellij"; then
  # Build a safe default session name from the current directory.
  zellij_session_name_from_pwd() {
    local session="${PWD##*/}"
    session="${session// /_}"
    session="${session//[^[:alnum:]_.-]/_}"
    echo "${session:-main}"
  }

  zellij_session_exists() {
    local session="${1:-}"
    zellij list-sessions --short 2>/dev/null | grep -Fxq "$session"
  }

  # Attach to an existing zellij session or create it.
  # If a project layout exists for the session name, use it for new sessions.
  zux() {
    local session="${1:-}"
    if [[ -z "$session" ]]; then
      session="$(zellij_session_name_from_pwd)"
    fi

    local layout_path="$HOME/.config/zellij/layouts/${session}.kdl"

    if [[ -n "${ZELLIJ:-}" ]]; then
      if zellij_session_exists "$session"; then
        zellij action switch-session "$session"
      else
        echo "Session '$session' does not exist yet. Run zux from a regular shell to create it."
        return 1
      fi
      return 0
    fi

    if zellij_session_exists "$session"; then
      zellij attach "$session"
      return $?
    fi

    if [[ -f "$layout_path" ]]; then
      zellij --session "$session" --new-session-with-layout "$session"
    else
      zellij attach -c "$session"
    fi
  }
fi

# Keep a simple compatibility wrapper for tmuxinator.
mux() {
  if has "tmuxinator"; then
    command tmuxinator "$@"
  else
    echo "mux: tmuxinator is not installed" >&2
    return 1
  fi
}

zinit ice wait lucid from"gh-r" as"program" mv"fzf* -> fzf" pick"fzf/fzf" ; zinit light junegunn/fzf
export ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS="--height 40% --reverse"

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

zinit light-mode wait"2" lucid from"gh-r" as"program" \
  atclone"./just --completions zsh > _just" atpull"%atclone" \
  pick"just" for @casey/just

if is_desktop; then
  zinit light-mode as'program' bpick'mise-*.tar.gz' from'gh-r' for \
      pick'mise/bin/mise' \
      atclone'./mise/bin/mise complete zsh >_mise' atpull'%atclone' \
      @jdx/mise

  # Fixes:
  # Error: usage CLI not found. This is required for completions to work in mise.
  # See https://usage.jdx.dev for more information.
  zinit light-mode wait"1" lucid from"gh-r" as"program" pick"usage" for @jdx/usage

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
  alias occ="opencode -c"
fi

# Guardrails for global package installs when mise is available.
if is_interactive; then
  is_using_mise() {
    [[ -f "${HOME}/.config/mise/config.toml" ]] || has "mise"
  }

  mise_global_guard_enabled() {
    is_using_mise && [[ "${MISE_ALLOW_GLOBAL_INSTALL:-0}" != "1" ]]
  }

  # Extract likely package names from npm install/add arguments.
  _npm_guard_packages() {
    local -a pkgs
    local arg=""
    local skip_next=0
    local npm_subcommand="${1:-}"
    shift || true

    for arg in "$@"; do
      if (( skip_next )); then
        skip_next=0
        continue
      fi

      case "$arg" in
        # Common npm flags with a separate value.
        -C|--prefix|--cache|--registry|--tag|--userconfig|--workspace|-w)
          skip_next=1
          continue
          ;;
        install|i|add)
          # Ignore repeated subcommands in unusual invocations.
          continue
          ;;
        -*)
          continue
          ;;
      esac

      pkgs+=("$arg")
    done

    printf '%s\n' "${pkgs[@]}"
  }

  # Normalize npm spec to a package name that can be used with @latest.
  _npm_guard_pkg_name() {
    local spec="$1"
    local scope=""
    local name_and_version=""

    # Scoped package with version tag, e.g. @scope/pkg@1.2.3.
    if [[ "$spec" == @*/*@* ]]; then
      scope="${spec%%/*}"
      name_and_version="${spec#*/}"
      printf '%s/%s\n' "$scope" "${name_and_version%@*}"
      return
    fi

    # Scoped package without explicit version, e.g. @scope/pkg.
    if [[ "$spec" == @*/* ]]; then
      printf '%s\n' "$spec"
      return
    fi

    # Unscoped package with version/tag, e.g. pkg@1.2.3.
    if [[ "$spec" == *@* ]]; then
      printf '%s\n' "${spec%@*}"
      return
    fi

    printf '%s\n' "$spec"
  }

  # Extract first likely gem package from gem install arguments.
  _gem_guard_package() {
    local arg=""
    local skip_next=0

    for arg in "$@"; do
      if (( skip_next )); then
        skip_next=0
        continue
      fi

      case "$arg" in
        # Common gem flags with a separate value.
        -v|--version|-i|--install-dir|-n|--bindir|-P|--trust-policy|--source)
          skip_next=1
          continue
          ;;
        install)
          continue
          ;;
        -*)
          continue
          ;;
      esac

      printf '%s\n' "$arg"
      return
    done
  }

  npm() {
    if mise_global_guard_enabled; then
      local arg
      local is_global_install=0
      local -a npm_guard_pkgs
      local pkg=""
      local normalized_pkg=""

      if [[ "$1" == "install" || "$1" == "i" || "$1" == "add" ]]; then
        for arg in "$@"; do
          if [[ "$arg" == "-g" || "$arg" == "--global" || "$arg" == "--location=global" ]]; then
            is_global_install=1
            break
          fi
        done
      fi

      if (( is_global_install )); then
        echo "[guard] Avoid npm global installs when using mise."
        npm_guard_pkgs=(${(@f)$(_npm_guard_packages "$@")})
        if (( ${#npm_guard_pkgs[@]} > 0 )); then
          for pkg in "${npm_guard_pkgs[@]}"; do
            normalized_pkg="$(_npm_guard_pkg_name "$pkg")"
            [[ -n "$normalized_pkg" ]] && echo "[guard] Use: mise use -g npm:${normalized_pkg}@latest"
          done
        else
          echo "[guard] Use: mise use -g npm:<package>@latest"
        fi
        echo "[guard] Bypass once: MISE_ALLOW_GLOBAL_INSTALL=1 npm $*"
        return 1
      fi
    fi

    command npm "$@"
  }

  gem() {
    if mise_global_guard_enabled && [[ "$1" == "install" ]]; then
      local gem_pkg=""

      echo "[guard] Avoid gem install when using mise."
      gem_pkg="$(_gem_guard_package "$@")"
      if [[ -n "$gem_pkg" ]]; then
        echo "[guard] Use: mise use -g gem:${gem_pkg}@latest"
      else
        echo "[guard] Use: mise use -g gem:<package>@latest"
      fi
      echo "[guard] Bypass once: MISE_ALLOW_GLOBAL_INSTALL=1 gem $*"
      return 1
    fi

    command gem "$@"
  }
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

  if has "pipx"; then
    echo
    echo "[pipx] Upgrading pipx packages"
    if sudo -H -u "${target_user}" pipx upgrade-all --include-injected; then
      echo "[pipx] Upgrade complete"
    else
      echo "[pipx] Upgrade failed"
    fi
  fi

  # Build an explicit PATH for user-scoped tool updates.
  # This avoids relying on interactive shell initialization when running via sudo.
  local user_tool_env_path="${target_home}/.local/share/mise/shims:${target_home}/.local/share/mise/bin:${target_home}/.local/bin:${target_home}/.zinit/polaris/bin:${target_home}/.zinit/plugins/jdx---mise/mise/bin:/usr/local/bin:/usr/bin:/bin"

  # Update mise-managed tools for the target user.
  local mise_command='mise upgrade'
  echo
  if sudo -H -u "${target_user}" env PATH="${user_tool_env_path}" sh -lc 'command -v mise >/dev/null 2>&1'; then
    echo "[mise] Upgrading mise tools"
    sudo -H -u "${target_user}" env PATH="${user_tool_env_path}" sh -lc "${mise_command}" >/dev/null 2>&1
    local _mise_ec=$?
    if (( _mise_ec == 0 )); then
      echo "[mise] Update complete"
      # Cleanup old versions of tools to save space.
      echo "[mise] Pruning old tool versions"
      sudo -H -u "${target_user}" env PATH="${user_tool_env_path}" sh -lc 'mise prune -y' >/dev/null 2>&1
    else
      echo "[mise] Update failed (exit ${_mise_ec}) try running: 'sudo -H -u ${target_user} env PATH=\"${user_tool_env_path}\" sh -lc \"${mise_command}\"' to see details."
    fi
  else
    echo "[mise] Skipping mise update: mise not found for user '${target_user}'."
  fi

  # Reuse the same PATH so npm from mise shims is discoverable via sudo.
  local npm_env_path="${user_tool_env_path}"

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

  # Native git-based replacement for external git-fixup tool.
  # Usage:
  #   git-fixup                # fixup against HEAD
  #   git-fixup <commit-ish>   # fixup against selected commit
  #   git-fixup <commit> <base-branch>  # optional explicit rebase base
  function git-fixup () {
    local target="${1:-HEAD}"
    local base_branch="${2:-}"
    local target_commit=""
    local rebase_base=""
    local should_push=0

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "git-fixup: not inside a git repository" >&2
      return 1
    fi

    target_commit=$(git rev-parse --verify "$target^{commit}" 2>/dev/null) || {
      echo "git-fixup: target commit '$target' not found" >&2
      return 1
    }

    ga .
    git commit --fixup="$target_commit" || return 1

    if [[ -n "$base_branch" ]]; then
      rebase_base=$(git merge-base "$base_branch" HEAD 2>/dev/null)
    fi

    if [[ -z "$rebase_base" ]]; then
      rebase_base=$(git rev-parse --verify "${target_commit}^" 2>/dev/null)
    fi

    if [[ -t 0 ]]; then
      read -q "should_push?git-fixup: force-push after autosquash rebase? [y/N] "
      echo
    fi

    if [[ -n "$rebase_base" ]]; then
      GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash "$rebase_base" || return 1
    else
      GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash --root || return 1
    fi

    if [[ "$should_push" == "y" ]]; then
      git push --force-with-lease
    fi
  }

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
    local input="${1:-}"
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

    local containers pod_volumes
    containers=$("$kubectl_bin" -n "$ns" get pod "$pod" -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}')
    pod_volumes=$("$kubectl_bin" -n "$ns" get pod "$pod" -o jsonpath='{range .spec.volumes[*]}{.name}{"\n"}{end}')

    local home_path="${CODE_POD_HOME_PATH:-/config}"
    local vscode_agent_folder="${CODE_POD_VSCODE_AGENT_FOLDER:-${home_path}/.vscode-server}"

    local use_debug=false
    case "${CODE_POD_FORCE_DEBUG:-false}" in
    1 | true | TRUE | yes | YES) use_debug=true ;;
    esac

    container_supports_devcontainers() {
      local candidate="$1"
      "$kubectl_bin" -n "$ns" exec "$pod" -c "$candidate" -- sh -lc '
uid="$(id -u)"
home="$(awk -F: -v uid="$uid" "\$3==uid{print \$6; exit}" /etc/passwd 2>/dev/null || true)"
[ -n "$home" ] || home="${HOME:-/}"
mkdir -p "$home/.vscode-server/data/Machine" >/dev/null 2>&1 || exit 12
command -v sh >/dev/null 2>&1 || exit 14
command -v tar >/dev/null 2>&1 || exit 15
  ' >/dev/null 2>&1
    }

    local container=""
    if [[ "$use_debug" == false ]] && grep -qx "app" <<<"$containers" && container_supports_devcontainers "app"; then
      container="app"
    fi

    if [[ -z "$container" ]]; then
      if [[ -z "${CODE_POD_HOME_PATH:-}" ]]; then
        home_path="/tmp/code-pod"
      fi
      if [[ -z "${CODE_POD_VSCODE_AGENT_FOLDER:-}" ]]; then
        vscode_agent_folder="${home_path}/.vscode-server"
      fi

      local debug_container="${CODE_POD_DEBUG_CONTAINER:-vscode-debug}"
      local debug_target="${CODE_POD_DEBUG_TARGET:-app}"
      local debug_image="${CODE_POD_DEBUG_IMAGE:-debian:12-slim}"
      local debug_profile=""
      local -a debug_profile_args
      debug_profile_args=()

      if ! grep -qx "$debug_target" <<<"$containers"; then
        debug_target="$(head -n1 <<<"$containers")"
      fi

      local existing_state="" running_at="" terminated_reason=""
      running_at=$("$kubectl_bin" -n "$ns" get pod "$pod" -o jsonpath="{range .status.ephemeralContainerStatuses[?(@.name==\"$debug_container\")]}{.state.running.startedAt}{end}")
      terminated_reason=$("$kubectl_bin" -n "$ns" get pod "$pod" -o jsonpath="{range .status.ephemeralContainerStatuses[?(@.name==\"$debug_container\")]}{.state.terminated.reason}{end}")
      if [[ -n "$running_at" ]]; then
        existing_state="running"
      elif [[ -n "$terminated_reason" ]]; then
        existing_state="terminated"
      fi

      if [[ "$existing_state" == "running" ]]; then
        local debug_mounts=""
        debug_mounts=$("$kubectl_bin" -n "$ns" get pod "$pod" -o jsonpath="{range .spec.ephemeralContainers[?(@.name==\"$debug_container\")].volumeMounts[*]}{.name}{\":\"}{.mountPath}{\"\\n\"}{end}" 2>/dev/null || true)
        if grep -qx "config" <<<"$pod_volumes"; then
          if ! grep -qx "config:/nonexistent" <<<"$debug_mounts"; then
            existing_state="terminated"
          fi
        elif grep -qx "tmpfs" <<<"$pod_volumes"; then
          if ! grep -qx "tmpfs:/nonexistent" <<<"$debug_mounts"; then
            existing_state="terminated"
          fi
        fi
      fi
      if [[ "$existing_state" == "running" ]] && ! container_supports_devcontainers "$debug_container"; then
        existing_state="terminated"
      fi

      if [[ "$existing_state" != "running" ]]; then
        if [[ "$existing_state" == "terminated" ]]; then
          debug_container="${debug_container}-$(date +%s)"
        fi

        if grep -qx "config" <<<"$pod_volumes"; then
          debug_profile=$(mktemp)
          cat >"$debug_profile" <<'EOF'
volumeMounts:
  - name: config
    mountPath: /nonexistent
EOF
          debug_profile_args=(--custom "$debug_profile")
        elif grep -qx "tmpfs" <<<"$pod_volumes"; then
          debug_profile=$(mktemp)
          cat >"$debug_profile" <<'EOF'
volumeMounts:
  - name: tmpfs
    mountPath: /nonexistent
EOF
          debug_profile_args=(--custom "$debug_profile")
        fi

        "$kubectl_bin" -n "$ns" debug "pod/$pod" \
          --profile=general \
          --container="$debug_container" \
          --target="$debug_target" \
          --image="$debug_image" \
          --env="HOME=$home_path" \
          --env="VSCODE_AGENT_FOLDER=$vscode_agent_folder" \
          "${debug_profile_args[@]}" \
          --attach=false \
          --quiet \
          -- sh -lc "sleep infinity" >/dev/null
        if [[ -n "$debug_profile" ]]; then
          rm -f "$debug_profile"
        fi
      fi

      local debug_wait_seconds="${CODE_POD_DEBUG_WAIT_SECONDS:-30}"
      local running_now=""
      local waiting_reason=""
      local i
      for ((i = 0; i < debug_wait_seconds; i++)); do
        running_now=$("$kubectl_bin" -n "$ns" get pod "$pod" -o jsonpath="{range .status.ephemeralContainerStatuses[?(@.name==\"$debug_container\")]}{.state.running.startedAt}{end}" 2>/dev/null || true)
        if [[ -n "$running_now" ]]; then
          break
        fi
        waiting_reason=$("$kubectl_bin" -n "$ns" get pod "$pod" -o jsonpath="{range .status.ephemeralContainerStatuses[?(@.name==\"$debug_container\")]}{.state.waiting.reason}{.state.terminated.reason}{end}" 2>/dev/null || true)
        sleep 1
      done
      if [[ -z "$running_now" ]]; then
        echo "debug container '$debug_container' did not start within ${debug_wait_seconds}s"
        if [[ -n "$waiting_reason" ]]; then
          echo "last state: $waiting_reason"
        fi
        return 1
      fi
      if ! container_supports_devcontainers "$debug_container"; then
        echo "debug container '$debug_container' is not compatible with Dev Containers install path"
        return 1
      fi
      container="$debug_container"
    fi

    local ctx json hex path_esc uri
    if ! "$kubectl_bin" -n "$ns" exec "$pod" -c "$container" -- sh -lc '
uid="$(id -u)"
home="$(awk -F: -v uid="$uid" "\$3==uid{print \$6; exit}" /etc/passwd 2>/dev/null || true)"
[ -n "$home" ] || home="${HOME:-/}"
agent="$home/.vscode-server"
mkdir -p "$agent/data/Machine" || { echo "Dev Containers path not writable: $agent"; exit 12; }
probe="$agent/.code-pod-write-test"
echo ok >"$probe" && rm -f "$probe"
command -v sh >/dev/null 2>&1 || { echo "sh not found"; exit 14; }
command -v tar >/dev/null 2>&1 || { echo "tar not found"; exit 15; }
printf "code_pod preflight ok (uid=%s home=%s agent=%s)\n" "$uid" "$home" "$agent"
'; then
      echo "code_pod preflight failed for ${ns}/${pod} (container=${container})"
      return 1
    fi

    ctx=$("$kubectl_bin" config current-context 2>/dev/null || printf "default")
    json=$(printf '{"context":"%s","podname":"%s","namespace":"%s","name":"%s"}' "$ctx" "$pod" "$ns" "$container")
    hex=$(printf '%s' "$json" | xxd -p -c 999 | tr -d '\n')
    path_esc=${folder// /%20}
    uri="vscode-remote://k8s-container%2B${hex}/${path_esc}"

    if [[ "${CODE_POD_PRINT_ONLY:-false}" == "true" ]] || ! command -v code >/dev/null 2>&1; then
      echo "$uri"
      return 0
    fi

    code --folder-uri="$uri"
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
  zinit light-mode as"program" from"gh-r" \
    bpick"$(
      emulate -L zsh
      typeset arch

      case "$(uname -m)" in
        x86_64)        arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *)             arch="x86_64" ;;
      esac

      print -r -- "atuin-${arch}-unknown-linux-gnu.tar.gz"
    )" \
    mv"atuin*/atuin -> atuin" \
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

# Prefer the system-provided GCR ssh-agent on desktop.
# This avoids spawning ad-hoc ssh-agent processes (which can pile up over time).
if is_desktop && [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}"
  gcr_sock="$runtime_dir/gcr/ssh"
  if [[ -S "$gcr_sock" ]]; then
    export SSH_AUTH_SOCK="$gcr_sock"
  fi
  unset runtime_dir gcr_sock
fi

# Fix SSH agent forwarding for tmux (creates symlink that .tmux.conf expects)
if [[ -n "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock" ]]; then
  ln -sfn "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
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
