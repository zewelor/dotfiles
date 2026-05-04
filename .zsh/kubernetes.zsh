if has "kubectl"; then
  # lazy-load kubectl completion
  _kubectl() {
    unset -f _kubectl
    eval "$(command kubectl completion zsh)"
  }

  zpcompdef _kubectl kubectl

  # Open a mounted pod path with a bare neovim via ephemeral debug container.
  nvim_pod() {
    local input="${1:-}"
    local app path_fragment open_path
    app="${input%%/*}"
    path_fragment=""
    if [[ $input == */* ]]; then
      path_fragment="${input#*/}"
    fi
    if [[ -z $input || -z $app ]]; then
      echo "usage: nvim_pod <app-name>[/path]"
      return 1
    fi

    local kubectl_bin
    kubectl_bin=$(command -v kubectl) || {
      echo "kubectl not found in PATH"
      return 1
    }

    local line ns pod
    line=$("$kubectl_bin" get pods -A -l app.kubernetes.io/name="$app" \
      -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' \
      | head -n1)
    ns=${line%%$'\t'*}
    pod=${line#*$'\t'}
    if [[ -z $pod || -z $ns || $pod == "$line" ]]; then
      echo "no running pod found for app=$app"
      return 1
    fi

    local pod_json containers
    pod_json=$("$kubectl_bin" -n "$ns" get pod "$pod" -o json) || return 1
    containers=$(jq -r '.spec.containers[]?.name' <<<"$pod_json")

    local debug_target="app"
    if ! grep -qx "$debug_target" <<<"$containers"; then
      debug_target="$(head -n1 <<<"$containers")"
    fi
    if [[ -z "$debug_target" ]]; then
      echo "pod $pod has no regular containers"
      return 1
    fi

    local git_ssh_command=""
    git_ssh_command=$(jq -r --arg target "$debug_target" '
      .spec.containers[]
      | select(.name == $target)
      | (.env // [])
      | map(select(.name == "GIT_SSH_COMMAND"))
      | .[0].value // empty
    ' <<<"$pod_json")

    local mount_roots subpath_mount_paths volume_mounts_yaml
    mount_roots=$(jq -r --arg target "$debug_target" '
      .spec.containers[]
      | select(.name == $target)
      | .volumeMounts // []
      | map(select((.subPath // "") == "" and (.subPathExpr // "") == ""))
      | unique_by(.mountPath)
      | sort_by([(.mountPath | length), .mountPath])
      | .[]?
      | .mountPath
    ' <<<"$pod_json")
    subpath_mount_paths=$(jq -r --arg target "$debug_target" '
      .spec.containers[]
      | select(.name == $target)
      | .volumeMounts // []
      | map(select((.subPath // "") != "" or (.subPathExpr // "") != ""))
      | unique_by(.mountPath)
      | sort_by([(.mountPath | length), .mountPath])
      | .[]?
      | .mountPath
    ' <<<"$pod_json")
    volume_mounts_yaml=$(jq -r --arg target "$debug_target" '
      .spec.containers[]
      | select(.name == $target)
      | .volumeMounts // []
      | map(select((.subPath // "") == "" and (.subPathExpr // "") == ""))
      | unique_by(.mountPath)
      | sort_by([(.mountPath | length), .mountPath])
      | .[]?
      | "  - name: \(.name | @json)\n" +
        "    mountPath: \(.mountPath | @json)" +
        (if .readOnly then "\n    readOnly: true" else "" end) +
        (if (.mountPropagation // "") != "" then "\n    mountPropagation: \(.mountPropagation | @json)" else "" end)
    ' <<<"$pod_json")

    if [[ -z "$volume_mounts_yaml" ]]; then
      printf 'container %s in pod %s has no mounted volumes to edit\n' "$debug_target" "$pod" >&2
      return 1
    fi

    if [[ -n "$path_fragment" && "$path_fragment" == /* ]]; then
      open_path="$path_fragment"
    elif [[ -n "$path_fragment" ]]; then
      open_path="/$path_fragment"
    else
      local mount_path preferred_config="" preferred_fallback=""
      while IFS= read -r mount_path; do
        [[ -z "$mount_path" ]] && continue

        if [[ -z "$preferred_config" && "$mount_path" == "/config" ]]; then
          preferred_config="$mount_path"
        fi

        if [[ -z "$preferred_fallback" ]]; then
          case "$mount_path" in
          /dev/* | /proc/* | /run/* | /sys/* | /var/run/*) ;;
          *)
            preferred_fallback="$mount_path"
            ;;
          esac
        fi
      done <<<"$mount_roots"

      if [[ -n "$preferred_config" ]]; then
        open_path="$preferred_config"
      elif [[ -n "$preferred_fallback" ]]; then
        open_path="$preferred_fallback"
      else
        open_path="$(head -n1 <<<"$mount_roots")"
      fi

      if [[ -z "$open_path" ]]; then
        echo "no mounted paths found for app=$app"
        return 1
      fi

      printf 'Starting path %s\n' "$open_path"
    fi

    local subpath_mount=""
    local mount_path
    while IFS= read -r mount_path; do
      [[ -z "$mount_path" ]] && continue
      if [[ "$open_path" == "$mount_path" || "$open_path" == "$mount_path/"* ]]; then
        subpath_mount="$mount_path"
        break
      fi
    done <<<"$subpath_mount_paths"

    if [[ -n "$subpath_mount" ]]; then
      printf 'path %s is backed by subPath mount %s\n' "$open_path" "$subpath_mount" >&2
      printf 'ephemeral debug containers cannot mount subPath entries; open a parent path outside that subPath\n' >&2
      return 1
    fi

    local workspace_root=""
    local best_workspace_len=0
    while IFS= read -r mount_path; do
      [[ -z "$mount_path" ]] && continue
      if [[ "$open_path" == "$mount_path" || "$open_path" == "$mount_path/"* ]]; then
        if (( ${#mount_path} > best_workspace_len )); then
          workspace_root="$mount_path"
          best_workspace_len=${#mount_path}
        fi
      fi
    done <<<"$mount_roots"

    if [[ -z "$workspace_root" ]]; then
      printf 'path %s is not backed by a mounted pod volume\n' "$open_path" >&2
      printf 'nvim_pod only supports mounted paths from container %s\n' "$debug_target" >&2
      return 1
    fi

    local session_home="$workspace_root"
    if [[ "$session_home" == "/" ]]; then
      session_home="/tmp/nvim-pod-home"
    fi

    local debug_container="nvim-debug-$(date +%s%N)"
    local debug_image="ghcr.io/zewelor/nvim:latest"
    local debug_profile
    debug_profile=$(mktemp) || return 1

    {
      printf 'volumeMounts:\n'
      printf '%s\n' "$volume_mounts_yaml"
    } >"$debug_profile"

    local -a nvim_cmd
    nvim_cmd=(
      sh -c '
        target="$1"
        home_dir="$2"
        status=0

        mkdir -p "$home_dir" 2>/dev/null || true
        export HOME="$home_dir"

        if [ -d "$target" ]; then
          cd "$target" || exit 1
          nvim .
          status=$?
        else
          parent="${target%/*}"
          [ -n "$parent" ] || parent=/
          cd "$parent" || exit 1
          nvim "$target"
          status=$?
        fi

        printf "\nNeovim exited with status %s. Staying in %s\n" "$status" "$PWD"
        if command -v bash >/dev/null 2>&1; then
          exec bash -i
        fi
        exec sh -i
      ' sh "$open_path" "$session_home"
    )

    if typeset -f _title_terminal_cmd >/dev/null 2>&1; then
      _title_terminal_cmd "nvim_pod $app"
    fi

    local -a debug_env_args
    debug_env_args=(--env="HOME=$session_home")
    if [[ -n "$git_ssh_command" ]]; then
      debug_env_args+=(--env="GIT_SSH_COMMAND=$git_ssh_command")
    fi

    local -a omitted_subpaths
    omitted_subpaths=()
    while IFS= read -r mount_path; do
      [[ -z "$mount_path" ]] && continue
      if [[ "$mount_path" == "$workspace_root" || "$mount_path" == "$workspace_root/"* ]]; then
        omitted_subpaths+=("$mount_path")
      fi
    done <<<"$subpath_mount_paths"

    printf 'Found pod %s in namespace %s (target container: %s)\n' "$pod" "$ns" "$debug_target"
    if (( ${#omitted_subpaths[@]} > 0 )); then
      printf 'Note: subPath mounts are omitted in the debug container: %s\n' "${(j:, :)omitted_subpaths}"
    fi
    printf 'Creating ephemeral debug container %s ...\n' "$debug_container"

    "$kubectl_bin" -n "$ns" debug -it "pod/$pod" \
      --profile=general \
      --container="$debug_container" \
      --target="$debug_target" \
      --image="$debug_image" \
      "${debug_env_args[@]}" \
      --custom "$debug_profile" \
      -- "${nvim_cmd[@]}"

    local debug_exit=$?
    rm -f "$debug_profile"
    return $debug_exit
  }

  function start-k8s-work() {
    alias k="kubectl"
    alias kmurder="kubectl delete pod --grace-period=0 --force"

    function kexec() {
      kubectl exec -it "$1" -- sh -c '(bash > /dev/null 2>&1 || ash || sh)'
    }

    function kcRsh() {
      kubectl run $2 --image=$1 --attach -ti --restart=Never --rm --command -- sh -c "clear; (bash 2>&1 > /dev/null || ash || sh)"
    }

    function kcEsh() {
      kubectl exec -ti $1 -- sh -c "clear; (bash 2>&1 > /dev/null || ash || sh)"
    }

    function k8s-secret-encode() {
      read v
      echo -n "$v" | base64 -w 0
      echo
    }

    kvault() {
      local ns="${VAULT_K8S_NAMESPACE:-kube-system}"
      local pod
      pod="$(kubectl get pod -n "$ns" -l app.kubernetes.io/name=vault,vault-active=true -o jsonpath='{.items[0].metadata.name}')"
      [[ -z "$pod" ]] && pod="$(kubectl get pod -n "$ns" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')"
      [[ -z "$pod" ]] && {
        echo "Vault pod not found in $ns" >&2
        return 1
      }
      if [[ -n "${KVAULT_TOKEN:-}" ]]; then
        if [[ -t 1 ]]; then
          kubectl exec -n "$ns" -it "$pod" -- env VAULT_TOKEN="$KVAULT_TOKEN" vault "$@"
        else
          kubectl exec -n "$ns" -i "$pod" -- env VAULT_TOKEN="$KVAULT_TOKEN" vault "$@"
        fi
      else
        if [[ -t 1 ]]; then
          kubectl exec -n "$ns" -it "$pod" -- vault "$@"
        else
          kubectl exec -n "$ns" -i "$pod" -- vault "$@"
        fi
      fi
    }
    kvlogin() {
      local t
      read -rs "?Vault token (hidden): " t
      echo
      export KVAULT_TOKEN="$t"
      unset t
      kvault token lookup >/dev/null && echo "Vault login OK" || echo "Vault login failed"
    }
    kvlogout() {
      unset KVAULT_TOKEN
      echo "Vault token cleared from shell env"
    }
    # Usage:
    #   k8ssecretgen [pwgen options]
    # Examples:
    #   k8ssecretgen                 # Uses default: -s 30 -1
    #   k8ssecretgen -s 50           # Overrides default length to 50
    #   k8ssecretgen -A -n 5         # Generates 5 passwords with additional options
    k8ssecretgen() {
      # Define default options
      local defaults=("-1" "-s" "30")

      # Initialize an array for final pwgen arguments
      local args=()

      # Flags to check if certain options are provided
      local has_s=0
      local has_n=0

      # Iterate over the input arguments to detect if -s or -n/-1 are provided
      for arg in "$@"; do
        case "$arg" in
        -s | --secure)
          has_s=1
          ;;
        -n | --number)
          has_n=1
          ;;
        -1)
          has_n=1
          ;;
        *) ;;
        esac
      done

      # If -n or -1 is not provided, append default -1
      if [[ $has_n -eq 0 ]]; then
        args+=("-1")
      fi

      # If -s is not provided, append default -s 30
      if [[ $has_s -eq 0 ]]; then
        args+=("-s" "30")
      fi

      # Append user-provided arguments
      args+=("$@")

      echo "Generating password with the following arguments: ${args[@]}"
      # Execute the pwgen command with the constructed arguments, remove newline, and encode in Base64
      pwgen "${args[@]}" | tr -d '\n' | base64 -w 0

      # Add a newline for better readability
      echo
    }

    zinit light-mode from"gh-r" as"program" for @derailed/k9s
    zinit light-mode from"gh-r" as"program" mv"krew-* -> kubectl-krew" for @kubernetes-sigs/krew

    # cnpg plugin completion
    if kubectl cnpg version &>/dev/null; then
      source <(kubectl cnpg completion zsh)
    fi

    helm_template_debug_with_deps() {
      local dir="${1:-.}"
      local output
      helm dependency update "$dir"
      output=$(helm template --debug "$dir" 2>&1)

      if echo "$output" | grep -q 'You may need to run `helm dependency build`'; then
        echo "Missing dependencies detected. Running 'helm dependency build'..."
        helm dependency build "$dir"
        echo "Re-running 'helm_template_debug_with_deps' recursively..."
        helm_template_debug_with_deps "$dir"
      elif echo "$output" | grep -q 'Please update the dependencies'; then
        echo "Outdated dependencies detected. Running 'helm dependency update'..."
        helm dependency update "$dir"
        echo "Re-running 'helm_template_debug_with_deps' recursively..."
        helm_template_debug_with_deps "$dir"
      else
        echo -e "$output"
      fi
    }

    # zinit ice lucid wait has"minikube" for id-as"minikube_completion" as"completion" atclone"minikube completion zsh > _minikube" atpull"%atclone" run-atpull zdharma-continuum/null
    # zinit light-mode from"gh-r" as"program" mv"kubeseal-* -> kubeseal" for @bitnami-labs/sealed-secrets

    for krew_plugin in get-all view-allocations ns pv-migrate; do
      if [ ! -f "$HOME/.krew/receipts/$krew_plugin.yaml" ]; then
        kubectl krew install $krew_plugin
      fi
    done
  }
fi
