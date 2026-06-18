if has "git"; then
  # Resolve the default branch for the current repo or an explicit git dir.
  function git_default_branch_name () {
    local repo_dir="${1:-.}"
    local head_ref=""

    head_ref=$(git -C "$repo_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
    if [[ -n "$head_ref" ]]; then
      echo "${head_ref#origin/}"
      return 0
    fi

    head_ref=$(git -C "$repo_dir" ls-remote --symref origin HEAD 2>/dev/null | sed -n 's#^ref: refs/heads/\(.*\)\s\+HEAD#\1#p' | head -n 1)
    if [[ -n "$head_ref" ]]; then
      echo "$head_ref"
      return 0
    fi

    return 1
  }

  function git_main_branch () {
    git_default_branch_name "${1:-.}"
  }

  # Bootstrap a normal clone into <repo>/<default-branch>/ layout for worktrees.
  function gwtclone () {
    local repo_url="${1:-}"
    local target_dir="${2:-}"
    local repo_name=""
    local default_branch=""
    local clone_path=""

    if [[ -z "$repo_url" ]]; then
      echo "Usage: gwtclone <repo-url> [target-dir]"
      return 1
    fi

    if [[ -z "$target_dir" ]]; then
      repo_name="${repo_url:t}"
      repo_name="${repo_name%.git}"
      target_dir="$repo_name"
    fi

    if [[ -z "$target_dir" ]]; then
      echo "Error: Could not derive target directory from repository URL." >&2
      return 1
    fi

    if [[ -e "$target_dir" ]] && [[ ! -d "$target_dir" ]]; then
      echo "Error: Target path exists and is not a directory: $target_dir" >&2
      return 1
    fi

    if [[ -d "$target_dir" ]] && [[ -n "$(ls -A -- "$target_dir" 2>/dev/null)" ]]; then
      echo "Error: Target directory must not exist or must be empty: $target_dir" >&2
      return 1
    fi

    mkdir -p -- "$target_dir"
    target_dir=$(cd "$target_dir" && pwd)

    echo "Detecting default branch..."
    default_branch=$(git ls-remote --symref "$repo_url" HEAD 2>/dev/null | awk '/^ref:/{sub("refs/heads/",""); print $2; exit}')
    if [[ -z "$default_branch" ]]; then
      echo "Error: Could not detect default branch for '$repo_url'. Ensure the repository exists and is accessible." >&2
      return 1
    fi

    clone_path="$target_dir/$default_branch"
    if [[ -e "$clone_path" ]]; then
      echo "Error: Clone path already exists: $clone_path" >&2
      return 1
    fi

    echo "Cloning $default_branch into $clone_path"
    git clone --branch "$default_branch" -- "$repo_url" "$clone_path" || return 1

    echo "Bootstrap complete"
    echo "  Clone root: $clone_path"
    echo "  Default branch: $default_branch"

    cd "$clone_path" || return 1
  }

  # Change into an existing worktree by branch name.
  function gwtcd() {
    local branch="$1"
    local target=""

    if [[ -z "$branch" ]]; then
      echo "Usage: gwtcd <branch>"
      return 1
    fi

    target=$(git worktree list --porcelain 2>/dev/null | awk -v b="$branch" '
      /^worktree / {
        wt = $0
        sub(/^worktree /, "", wt)
      }
      $1 == "branch" {
        sub("^refs/heads/", "", $2)
        if ($2 == b) {
          print wt
          exit
        }
      }
    ')
    if [[ -z "$target" ]]; then
      echo "No worktree found for branch: $branch" >&2
      return 1
    fi

    cd "$target" || return 1
  }

  # Complete gwtcd with branch names that currently have worktrees.
  _gwtcd() {
    local -a branches
    branches=(${(f)"$(git worktree list --porcelain 2>/dev/null | awk '$1 == "branch" { sub("^refs/heads/", "", $2); print $2 }')"})
    (( ${#branches} == 0 )) && return 1
    compadd -a branches
  }

  alias gwtls='git worktree list'
  # Remove a worktree directory and optionally delete the branch.
  function gwtrm() {
    if [[ -z "$1" ]]; then
      echo "Usage: gwtrm <worktree-dir|branch-name>" >&2
      return 1
    fi

    local target="$1"
    local worktree_dir="$target"

    if [[ ! -d "$worktree_dir" ]]; then
      # Try to resolve by branch name
      worktree_dir=$(git worktree list --porcelain 2>/dev/null | awk -v b="$target" '
        /^worktree / {
          wt = $0
          sub(/^worktree /, "", wt)
        }
        $1 == "branch" {
          sub("^refs/heads/", "", $2)
          if ($2 == b) {
            print wt
            exit
          }
        }
      ')
    fi

    if [[ -z "$worktree_dir" || ! -d "$worktree_dir" ]]; then
      echo "Error: Directory or branch '$target' does not exist." >&2
      return 1
    fi

    # Resolve the branch name from the worktree directory
    local branch=""
    if [[ -f "$worktree_dir/.git" ]]; then
      branch=$(git -C "$worktree_dir" symbolic-ref --short HEAD 2>/dev/null)
    fi

    git worktree remove "$worktree_dir" || return 1

    if [[ -n "$branch" ]]; then
      echo -n "Delete branch '$branch'? [y/N] "
      read -k 1 confirm
      echo
      if [[ "$confirm" =~ ^[yY]$ ]]; then
        git branch -D "$branch"
      else
        echo "Branch '$branch' left intact."
      fi
    fi
  }

  alias gwtpr='git worktree prune'

  function gwta() {
    local branch=$1
    local base=${2:-$(git_main_branch)}
    local dir="$PWD"
    local root=""
    local new_wt_path=""
    local is_bare=0
    local files_to_link=( ".env" )

    if [[ -z "$branch" ]]; then
      echo "Usage: gwta <branch-name> [base]"
      return 1
    fi

    if [[ "$branch" =~ "/" ]]; then
      echo "Error: Branch name cannot contain '/' to prevent accidental subdirectory creation."
      return 1
    fi

    if git rev-parse --is-bare-repository 2>/dev/null | grep -q "true"; then
      is_bare=1
      root="$PWD"
      echo "Found bare repository at: $root"
    fi

    if [[ $is_bare -eq 0 ]]; then
      while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.bare" ]]; then
          root="$dir"
          break
        fi
        dir=$(dirname "$dir")
      done
    fi

    local git_dir=""
    if [[ $is_bare -eq 1 ]]; then
      git_dir="$root"
      new_wt_path="$root/$branch"
    elif [[ -n "$root" ]]; then
      git_dir="$root/.bare"
      new_wt_path="$root/$branch"
    fi

    if [[ -n "$git_dir" ]]; then
      git -C "$git_dir" worktree add -b "$branch" "$new_wt_path" "$base"
    else
      echo "No bare repo or .bare found, assuming standard repo."
      new_wt_path="${PWD:h}/$branch"
      git worktree add -b "$branch" "../$branch" "$base"
    fi

    local ret=$?
    if [[ $ret -eq 0 ]]; then
      local main_branch_name
      main_branch_name=$(git_main_branch 2>/dev/null)

      if [[ -n "$main_branch_name" ]]; then
        local main_wt_path=""
        if [[ -n "$git_dir" ]]; then
          main_wt_path=$(git -C "$git_dir" worktree list | grep " \[${main_branch_name}\]$" | awk '{print $1}' | head -n 1)
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
    if [[ $ret -eq 0 && -d "$new_wt_path" ]]; then
      cd "$new_wt_path"
    fi
    return $ret
  }

  function gcm() {
    local main_branch=""
    local checkout_output=""
    local checkout_status=0
    local target=""

    main_branch=$(git_main_branch) || return 1

    checkout_output=$(git checkout "$main_branch" 2>&1)
    checkout_status=$?
    if [[ $checkout_status -eq 0 ]]; then
      [[ -n "$checkout_output" ]] && print -u2 -- "$checkout_output"
      return 0
    fi

    if [[ "$checkout_output" == *"already used by worktree"* ]]; then
      target=$(git worktree list --porcelain 2>/dev/null | awk -v b="$main_branch" '
        /^worktree / {
          wt = $0
          sub(/^worktree /, "", wt)
        }
        $1 == "branch" {
          sub("^refs/heads/", "", $2)
          if ($2 == b) {
            print wt
            exit
          }
        }
      ')
      if [[ -n "$target" ]]; then
        cd "$target" || return 1
        return 0
      fi
    fi

    print -u2 -- "$checkout_output"
    return $checkout_status
  }

  _gwtrm() {
    local -a branches
    branches=(${(f)"$(git worktree list --porcelain 2>/dev/null | awk '$1 == "branch" { sub("^refs/heads/", "", $2); print $2 }')"})
    _alternative \
      'branches:worktree branch:compadd -a branches' \
      'directories:worktree directory:_files -/'
  }

  ZINIT_COMPDEF_REPLAY+=("_gwtcd gwtcd _gwtrm gwtrm")
fi
