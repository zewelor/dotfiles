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
    local app="${input%%/*}"
    local script="$HOME/.zsh/kubernetes/nvim-pod.zsh"

    if typeset -f _title_terminal_cmd >/dev/null 2>&1; then
      _title_terminal_cmd "nvim_pod $app"
    fi

    if [[ ! -r "$script" ]]; then
      printf 'nvim_pod helper script not found: %s\n' "$script" >&2
      return 1
    fi

    zsh "$script" "$@"
  }

  podmount() {
    mise use -g -q devspace

    local input="${1:-}"
    local app="${input%%/*}"
    local rem_path=""
    [[ "$input" == */* ]] && rem_path="${input#*/}"

    local line ns pod pod_json container mount_path tmp_dir

    # Find pod and namespace using labels (instance first, then name)
    line=$(kubectl get pods -A -l "app.kubernetes.io/instance=$app" -o json | jq -r '
      [
        .items[]
        | select(.status.phase == "Running")
        | (.status.containerStatuses // []) as $statuses
        | select(($statuses | length) > 0)
        | select($statuses | all(.ready == true))
        | {ns: .metadata.namespace, name: .metadata.name}
      ]
      | sort_by(.ns, .name)
      | .[0]
      | if . == null then empty else "\(.ns)\t\(.name)" end
    ')

    if [[ -z "$line" || "$line" == "null" ]]; then
      line=$(kubectl get pods -A -l "app.kubernetes.io/name=$app" -o json | jq -r '
        [
          .items[]
          | select(.status.phase == "Running")
          | (.status.containerStatuses // []) as $statuses
          | select(($statuses | length) > 0)
          | select($statuses | all(.ready == true))
          | {ns: .metadata.namespace, name: .metadata.name}
        ]
        | sort_by(.ns, .name)
        | .[0]
        | if . == null then empty else "\(.ns)\t\(.name)" end
      ')
    fi

    if [[ -z "$line" || "$line" == "null" ]]; then
      printf 'No ready running pod found for app/instance=%s\n' "$app" >&2
      return 1
    fi

    ns="${line%%$'\t'*}"
    pod="${line#*$'\t'}"
    pod_json=$(kubectl get pod "$pod" -n "$ns" -o json)

    # Select container (prefer "app")
    container=$(jq -r '
      [.spec.containers[]?.name]
      | if index("app") then "app" else .[0] // empty end
    ' <<<"$pod_json")

    # Resolve remote path
    if [[ -n "$rem_path" ]]; then
      mount_path="$rem_path"
    else
      # Select mount path (prefer "/config", then anything with "config")
      mount_path=$(jq -r --arg c "$container" '
        .spec.containers[] | select(.name == $c) | .volumeMounts[]? 
        | select(.mountPath == "/config" or (.mountPath | contains("config"))) 
        | .mountPath
      ' <<<"$pod_json" | head -n 1)
      
      if [[ -z "$mount_path" ]]; then
        # Fallback to first writable mount if no config found
        mount_path=$(jq -r --arg c "$container" '
          .spec.containers[] | select(.name == $c) | .volumeMounts[0].mountPath // empty
        ' <<<"$pod_json")
      fi
    fi

    if [[ -z "$mount_path" ]]; then
      printf 'Could not resolve mount path for %s\n' "$app" >&2
      return 1
    fi

    printf 'Pod: %s (%s), Container: %s, Remote Path: %s\n' "$pod" "$ns" "$container" "$mount_path"
    
    tmp_dir=$(mktemp -d -t "ha-sync-${app}-XXXX")
    printf 'Local temporary directory: %s\n' "$tmp_dir"
    
    local session_name="[${app}]"
    if tmux has-session -t "$session_name" 2>/dev/null; then
      printf 'Tmux session %s already exists. Killing it...\n' "$session_name"
      tmux kill-session -t "$session_name"
    fi

    cd "$tmp_dir" || return 1

    # Create session and first window for sync
    tmux new-session -d -s "$session_name" -n "sync" \
      "devspace sync --namespace '$ns' --pod '$pod' --container '$container' --path '${tmp_dir}:${mount_path}'; \
       printf '\nSync stopped. Press any key to exit and cleanup %s...\n' '$tmp_dir'; read -k1; rm -rf '$tmp_dir'; tmux kill-session -t '$session_name'"

    # Create second window for shell in tmp_dir
    tmux new-window -t "$session_name" -n "shell"

    # Switch to the sync window by default and attach
    tmux select-window -t "${session_name}:sync"
    tmux attach-session -t "$session_name"
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
