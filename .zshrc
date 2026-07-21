# Skip all customizations if ZSHRC_SKIP_CUSTOMIZATIONS is set
# Useful for AI agents that need a minimal shell
[[ -n "${ZSHRC_SKIP_CUSTOMIZATIONS:-}" ]] && return

source "$HOME/.zsh/helpers.zsh"

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
setopt ignore_eof             # Require explicit exit/logout instead of closing the shell with Ctrl+D
if is_interactive; then
  stty susp undef             # Disable Ctrl+Z suspend (redundant with tmux zoom binding on C-z)
fi
setopt interactivecomments    # Enable the use of comments in interactive shells
typeset -U path fpath

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

# make it more responsive
export KEYTIMEOUT=1

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
(( $+_comps )) && _comps[zinit]=_zinit
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

zinit light-mode lucid for \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-link-man \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-binary-symlink \
  zdharma-continuum/z-a-submods

#
# Programs
#
##########################

# Session helpers for tmux and tmuxinator.
if has "tmux"; then
  tat() {
    emulate -L zsh

    if (( $# > 1 )); then
      print -u2 -- "tat: too many arguments (expected 0 or 1 path)"
      return 1
    fi

    local target="${1:-$PWD}"
    if [[ -z "$target" ]]; then
      print -u2 -- "tat: empty path"
      return 1
    fi

    target="${target:A}"
    if [[ ! -e "$target" ]]; then
      print -u2 -- "tat: path does not exist: $target"
      return 1
    fi
    if [[ ! -d "$target" ]]; then
      print -u2 -- "tat: not a directory: $target"
      return 1
    fi

    local session="${target##*/}"

    # Start new sessions in the requested directory so "everything happens there";
    # existing sessions keep their cwd to avoid surprising shared users.
    if [[ -n "$TMUX" ]]; then
      tmux has-session -t "$session" 2>/dev/null || tmux new-session -ds "$session" -c "$target"
      tmux switch-client -t "$session"
    else
      tmux attach -t "$session" 2>/dev/null || tmux new -s "$session" -c "$target"
    fi
  }
fi

zinit ice wait"1" lucid from"gh-r" sbin"fzf" ; zinit light junegunn/fzf
export ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS="--height 40% --reverse"

# Catppuccin Latte theme for fzf (transparent background)
# Source: https://github.com/catppuccin/fzf/blob/main/themes/catppuccin-fzf-latte.sh
export FZF_DEFAULT_OPTS=" \
--color=bg+:#CCD0DA,spinner:#DC8A78,hl:#D20F39 \
--color=fg:#4C4F69,header:#D20F39,info:#8839EF,pointer:#DC8A78 \
--color=marker:#7287FD,fg+:#4C4F69,prompt:#8839EF,hl+:#D20F39 \
--color=selected-bg:#BCC0CC \
--color=border:#9CA0B0,label:#4C4F69"

# A cat clone with syntax highlighting and Git integration.
zinit light-mode from"gh-r" sbin"bat" mv"bat-*/bat -> bat" for @sharkdp/bat

# A viewer for git and diff output
zinit light-mode from"gh-r" sbin"delta" mv"delta-*/delta -> delta" for @dandavison/delta

# A more intuitive version of du written in rust.
zinit light-mode from"gh-r" sbin"dust" mv"dust-*/dust -> dust" for @bootandy/dust

# eza - modern ls replacement with icons and git integration
zinit light-mode from"gh-r" sbin"eza" for @eza-community/eza
alias l='ls -1a'
alias ll='ls -lh'
alias la='ls -lah'
alias lt='ls -T'  # tree view

# zoxide - smarter cd with frecency
zinit light-mode from"gh-r" sbin"zoxide" \
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

zinit light-mode wait"2" lucid from"gh-r" sbin"just" \
  atclone"JUST_COMPLETE=zsh ./just > _just" atpull"%atclone" \
  for @casey/just

if is_desktop; then
  zinit light-mode as'program' \
      bpick"mise-*$(_ghr_linux).tar.gz" \
      pick'mise/bin/mise' \
      from'gh-r' for \
      @jdx/mise

  zinit light-mode from"gh-r" as"program" \
    atclone"./opencode completion > _opencode; echo 'compdef _opencode_yargs_completions oc' >> _opencode" atpull"%atclone" \
    bpick"opencode-$(_ghr_linux)$([[ $(_ghr_linux) == linux-x64 && -r /proc/cpuinfo ]] && ! grep -qi 'avx2' /proc/cpuinfo 2>/dev/null && echo '-baseline').tar.gz" \
    pick"opencode" \
    for @anomalyco/opencode
fi

if has "tmuxinator" || (has "mise" && mise which tmuxinator &>/dev/null); then
  mux() {
    command tmuxinator "$@"
  }

  setup_tmuxinator_completion() {
    zinit ice as"completion" mv"tmuxinator.zsh -> _tmuxinator"
    zinit snippet https://raw.githubusercontent.com/tmuxinator/tmuxinator/master/completion/tmuxinator.zsh

    if (( $+functions[zcompdef] )); then
      zcompdef _tmuxinator mux tmuxinator
    elif (( $+functions[compdef] )); then
      compdef _tmuxinator mux tmuxinator
    fi
  }
fi

##########################

zinit wait"1" lucid for \
  light-mode \
  atinit"
    # Hash holding paths that shouldn't be grepped (globbed) – blacklist for slow disks, mounts, etc.
    # https://github.com/zdharma-continuum/fast-syntax-highlighting/blob/cf318e06a9b7c9f2219d78f41b46fae6e06011fd9/CHANGELOG.md?plain=1#L104
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

if has "agy"; then
  alias agyp="agy -p"
  alias agyc="agy -c"
fi

if has "codex"; then
  alias codexrl="codex resume --last"
fi

# Guardrails for global package installs when mise is available.
if is_interactive; then
  is_using_mise() {
    [[ -f "${MISE_CONFIG_DIR:-$HOME/.config/mise}/config.toml" ]] || has "mise"
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
            [[ -n "$normalized_pkg" ]] && echo "[guard] Use: mise-local npm:${normalized_pkg}@latest"
          done
        else
          echo "[guard] Use: mise-local npm:<package>@latest"
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
        echo "[guard] Use: mise-local gem:${gem_pkg}@latest"
      else
        echo "[guard] Use: mise-local gem:<package>@latest"
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
alias czysc_dpkg="\sudo apt autoremove -y --purge ; \sudo apt autoclean ; dpkg --list |grep \"^rc\" | cut -d \" \" -f 3 | xargs --no-run-if-empty \sudo dpkg --purge"
alias duze_pakiety="dpkg-query -Wf '\${Installed-Size}\t\${Package}\n' | sort -rn | head -30 | awk '{printf \"%.1f MB\t%s\n\", \$1/1024, \$2}'"
alias apt_obsolete="aptitude search '~o'"

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
    if [[ -z "${target_user}" ]]; then
      echo "Error: Cannot determine target user (SUDO_USER not set and no user with UID 1000 found)." >&2
      return 1
    fi
  fi

  # Resolve target user's home directory
  local target_home
  target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
  if [[ -z "${target_home}" ]]; then
    echo "Error: Cannot resolve home directory for user '${target_user}'." >&2
    return 1
  fi

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
  run_for_target_user () {
    sudo -H -u "${target_user}" env PATH="${user_tool_env_path}" sh -lc "${1}"
  }

  target_user_has () {
    run_for_target_user "command -v ${1} >/dev/null 2>&1"
  }

  # Update mise-managed tools for the target user.
  local mise_command='mise upgrade'
  echo
  if target_user_has "mise"; then
    echo "[mise] Upgrading mise tools"
    run_for_target_user "${mise_command}" >/dev/null 2>&1
    local _mise_ec=$?
    if (( _mise_ec == 0 )); then
      echo "[mise] Update complete"
      # Cleanup old versions of tools to save space.
      echo "[mise] Pruning old tool versions"
      run_for_target_user 'mise prune -y' >/dev/null 2>&1
    else
      echo "[mise] Update failed (exit ${_mise_ec}) try running: 'sudo -H -u ${target_user} env PATH=\"${user_tool_env_path}\" sh -lc \"${mise_command}\"' to see details."
    fi
  else
    echo "[mise] Skipping mise update: mise not found for user '${target_user}'."
  fi

  # Update Neovim plugins via Lazy.nvim
  if target_user_has "nvim"; then
    echo
    echo "[nvim] Updating Lazy.nvim plugins"
    if run_for_target_user 'nvim --headless -c "Lazy! sync" -c "qa"' >/dev/null 2>&1; then
      echo "[nvim] Plugin update complete"
    else
      local _nvim_ec=$?
      echo "[nvim] Plugin update failed (exit ${_nvim_ec}) try running: 'nvim --headless -c "Lazy! sync" -c "qa"' to see details."
    fi
  else
    echo
    echo "[nvim] Skipping Neovim plugin update: nvim not found for user '${target_user}'."
  fi

  if target_user_has "npm"; then
    echo
    echo "[npm] Updating global npm packages"
    if run_for_target_user 'NPM_CONFIG_LOGLEVEL=error npm update -g'; then
      echo "[npm] Update complete"
    else
      echo "[npm] Update failed"
    fi
  else
    echo
    echo "[npm] Skipping npm update: npm not found for user '${target_user}'."
  fi

  if target_user_has "npx"; then
    echo
    echo "[skills] Updating skills via npx"
    if run_for_target_user 'npx --yes skills update --global'; then
      echo "[skills] Update complete"
    else
      local _skills_ec=$?
      echo "[skills] Update failed (exit ${_skills_ec}) try running: 'sudo -H -u ${target_user} env PATH=\"${user_tool_env_path}\" sh -lc \"npx --yes skills update\"' to see details."
    fi
  else
    echo
    echo "[skills] Skipping skills update: npx not found for user '${target_user}'."
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

    git add .
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

  _workmux_lazy_init() {
    (( $+functions[compdef] )) || return 0
    has "workmux" || return 0
    add-zsh-hook -d precmd _workmux_lazy_init
    source <(workmux completions zsh)
  }
  add-zsh-hook precmd _workmux_lazy_init

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
alias dotfiles_update='cd ~/dotfiles && gpl && git submodule update --recursive --remote && if [[ "${DOTFILES_PROFILE:-server}" != "server" ]]; then (cd prv && git pull || echo "⚠ Skipping prv update (no access)" >&2); fi && ./install && cd -'
alias t='tail -f'
alias tailf='tail -f'
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
  alias cat='bat --theme="Catppuccin Latte" -p'
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
    alias rubocop="bundle exec rubocop"
    alias ror='bundle exec rails'
    alias rails='bundle exec rails'
    alias rorc='bundle exec rails console'
    alias rordc='bundle exec rails dbconsole'
    alias rordm='bundle exec rake db:migrate'
    alias rordM='bundle exec rake db:migrate db:test:clone'
    alias rordr='bundle exec rake db:rollback'
    alias rake='noglob bundle exec rake'
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
  alias mise-local="mise use -p \${MISE_CONFIG_DIR}/config.local.toml"

  if is_interactive; then
    # Lazy-load mise activation for faster startup.
    _mise_lazy_init() {
      unfunction _mise_lazy_init
      eval "$(mise activate zsh)"
    }
    add-zsh-hook precmd _mise_lazy_init
  else
    # Non-interactive shells do not reach precmd, so activate mise immediately.
    eval "$(mise activate zsh)"
  fi

  # Cache mise completions; requires `usage` installed via `mise use -g usage`.
  # Regenerate if cache is missing or older than 7 days.
  local mise_completion_cache="${HOME}/.cache/zsh/completions"
  local mise_completion_file="$mise_completion_cache/_mise"
  if [[ ! -f "$mise_completion_file" ]] || [[ -n "$(find "$mise_completion_file" -mtime +7 2>/dev/null)" ]]; then
    mkdir -p "$mise_completion_cache"
    mise completion zsh >| "$mise_completion_file" 2>/dev/null
  fi
  fpath+=("$mise_completion_cache")
fi

agent_browser_skills_dir="${HOME}/.local/share/mise/installs/npm-agent-browser/latest/lib/node_modules/agent-browser/skill-data"
if [[ -d "$agent_browser_skills_dir" ]]; then
  export AGENT_BROWSER_SKILLS_DIR="$agent_browser_skills_dir"
fi
unset agent_browser_skills_dir

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

# Only call the completion hook when tmuxinator defined it during shell init.
(( $+functions[setup_tmuxinator_completion] )) && setup_tmuxinator_completion

# Auto-select starship config based on REMOTE_FS environment variable
# REMOTE_FS=1 indicates a slow/network filesystem mount (e.g., SSHFS)
if [[ -n "${REMOTE_FS:-}" ]]; then
  export STARSHIP_CONFIG="${HOME}/.config/starship-network-fs.toml"
else
  export STARSHIP_CONFIG="${HOME}/.config/starship.toml"
fi

# Fallback ZSH prompt for when Starship is not loaded (e.g. inside Midnight Commander).
# Uses only built-in %-escapes — no forks, no subshells, instant rendering.
# Overridden by Starship when it initializes.
PROMPT='%F{208}%n%f%F{240}@%f%F{blue}%m%f %F{cyan}%~%f %(?.%F{green}❯%f.%F{red}❯%f) '

# Initialize Starship prompt last to avoid recursive ZLE wrappers when using vi-mode/atuin.
# We also use a guard to prevent multiple initializations if .zshrc is sourced again.
# Skip Starship entirely when running inside Midnight Commander subshell (MC_SID is set by mc).
if [[ -z "$STARSHIP_INITIALIZED" && -z "${MC_SID:-}" ]]; then
  zinit ice as"command" from"gh-r" \
            atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
            atpull"%atclone" src"init.zsh"
  zinit light starship/starship
  STARSHIP_INITIALIZED=1
fi

[[ -z "${TMUX:-}" ]] && _title_terminal_pwd

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
  ensure_symlink_target "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
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


# Added by Antigravity CLI installer
export PATH="/home/omen/.local/bin:$PATH"
