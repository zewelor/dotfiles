if has "kubectl"; then
  # lazy-load kubectl completion
  _kubectl() {
    unset -f _kubectl
    eval "$(command kubectl completion zsh)"
  }

  zpcompdef _kubectl kubectl

  # Open a file inside a pod with a bare neovim via ephemeral debug container
  nvim_pod() {
    local input="${1:-}"
    local app folder open_path
    app="${input%%/*}"
    folder=""
    if [[ $input == */* ]]; then
      folder="${input#*/}"
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
      -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.namespace} {.metadata.name}{"\n"}{end}' \
      | head -n1)
    ns=${line%% *}
    pod=${line#* }
    if [[ -z $pod || -z $ns || $pod == "$line" ]]; then
      echo "no running pod found for app=$app"
      return 1
    fi

    local pod_json containers
    pod_json=$("$kubectl_bin" -n "$ns" get pod "$pod" -o json) || return 1
    containers=$(jq -r '.spec.containers[]?.name' <<<"$pod_json")

    local debug_container="nvim-debug"
    local debug_target="app"
    local debug_image="ghcr.io/zewelor/nvim:latest"
    local debug_profile=""
    local -a debug_profile_args
    debug_profile_args=()

    if ! grep -qx "$debug_target" <<<"$containers"; then
      debug_target="$(head -n1 <<<"$containers")"
    fi

    local mount_table
    mount_table=$(jq -r --arg target "$debug_target" '
      .spec as $spec |
      ($spec.volumes // []) as $volumes |
      [
        $spec.containers[]
        | select(.name == $target)
        | .volumeMounts // []
        | map(select(has("subPath") | not))
        | unique_by(.name + "|" + .mountPath)
        | .[]
        | . as $mount
        | ($volumes[]? | select(.name == $mount.name)) as $volume
        | [
            $mount.name,
            $mount.mountPath,
            (if $mount.readOnly then "ro" else "rw" end),
            (if $volume.persistentVolumeClaim then "pvc"
             elif $volume.configMap then "configMap"
             elif $volume.secret then "secret"
             elif $volume.projected then "projected"
             elif $volume.emptyDir then "emptyDir"
             elif $volume.hostPath then "hostPath"
             else "other"
             end)
          ]
        | @tsv
      ]
      | .[]?
    ' <<<"$pod_json")

    if [[ -n "$folder" && "$folder" == /* ]]; then
      open_path="$folder"
    elif [[ -n "$folder" ]]; then
      open_path="/$folder"
    else
      local mount_name mount_path mount_access mount_type
      local preferred_config=""
      local preferred_pvc=""
      local preferred_fallback=""

      while IFS=$'\t' read -r mount_name mount_path mount_access mount_type; do
        [[ -z "$mount_path" ]] && continue

        if [[ "$mount_path" == "/config" ]]; then
          preferred_config="$mount_path"
          break
        fi

        if [[ -z "$preferred_pvc" && "$mount_type" == "pvc" ]]; then
          preferred_pvc="$mount_path"
        fi

        if [[ -z "$preferred_fallback" ]]; then
          case "$mount_path" in
          /var/run/* | /run/*) ;;
          *)
            preferred_fallback="$mount_path"
            ;;
          esac
        fi
      done <<<"$mount_table"

      if [[ -n "$preferred_config" ]]; then
        open_path="$preferred_config"
      elif [[ -n "$preferred_pvc" ]]; then
        open_path="$preferred_pvc"
      elif [[ -n "$preferred_fallback" ]]; then
        open_path="$preferred_fallback"
      else
        open_path="/"
      fi

      printf 'Auto-selected starting path %s\n' "$open_path"
    fi

    local -a nvim_cmd
    nvim_cmd=(
      sh -lc '
        target="$1"
        status=0

        if [ -d "$target" ]; then
          if cd "$target"; then
            nvim .
            status=$?
          else
            printf "Could not enter %s\n" "$target" >&2
            status=1
          fi
        else
          parent="${target%/*}"
          [ -n "$parent" ] || parent=/
          if cd "$parent"; then
            nvim "$target"
            status=$?
          else
            printf "Could not enter %s\n" "$parent" >&2
            status=1
          fi
        fi

        printf "\nNeovim exited with status %s. Staying in %s\n" "$status" "$PWD"
        if command -v bash >/dev/null 2>&1; then
          exec bash
        fi
        exec sh
      ' sh "$open_path"
    )

    printf 'Found pod %s in namespace %s (target container: %s)\n' "$pod" "$ns" "$debug_target"

    local existing_state="" running_at="" terminated_reason=""
    running_at=$(jq -r --arg name "$debug_container" '
      .status.ephemeralContainerStatuses[]?
      | select(.name == $name)
      | .state.running.startedAt // empty
    ' <<<"$pod_json")
    terminated_reason=$(jq -r --arg name "$debug_container" '
      .status.ephemeralContainerStatuses[]?
      | select(.name == $name)
      | .state.terminated.reason // empty
    ' <<<"$pod_json")
    if [[ -n "$running_at" ]]; then
      existing_state="running"
    elif [[ -n "$terminated_reason" ]]; then
      existing_state="terminated"
    fi

    if [[ "$existing_state" == "running" ]]; then
      local debug_mounts=""
      debug_mounts=$(jq -r --arg name "$debug_container" '
        .spec.ephemeralContainers[]?
        | select(.name == $name)
        | .volumeMounts[]?
        | "\(.name):\(.mountPath)"
      ' <<<"$pod_json")

      while IFS=$'\t' read -r mount_name mount_path mount_access mount_type; do
        [[ -z "$mount_name" || -z "$mount_path" ]] && continue
        if ! grep -qx "$mount_name:$mount_path" <<<"$debug_mounts"; then
          existing_state="terminated"
          break
        fi
      done <<<"$mount_table"
    fi

    if [[ "$existing_state" == "running" ]]; then
      printf 'Reusing existing debug container %s\n' "$debug_container"
      printf 'Opening %s ...\n' "$open_path"
      printf 'Exit the shell to return to your local terminal.\n'
      "$kubectl_bin" -n "$ns" exec -it "$pod" -c "$debug_container" -- "${nvim_cmd[@]}"
      return $?
    fi

    if [[ "$existing_state" == "terminated" ]]; then
      debug_container="${debug_container}-$(date +%s)"
    fi

    printf 'Creating ephemeral debug container %s ...\n' "$debug_container"

    debug_profile=$(mktemp)
    {
      # Ephemeral containers cannot use subPath, so reuse only top-level mounts.
      printf 'volumeMounts:\n'
      jq -r --arg target "$debug_target" '
          .spec.containers[] | select(.name == $target) | .volumeMounts // [] |
          map(select(has("subPath") | not)) |
          unique_by(.name + .mountPath) |
          .[] |
          "  - name: \(.name)\n" +
          "    mountPath: \(.mountPath)" +
          (if .readOnly then "\n    readOnly: true" else "" end)
        ' <<<"$pod_json"
    } >"$debug_profile"
    debug_profile_args=(--custom "$debug_profile")

    printf 'Attaching to %s ...\n' "$debug_container"
    printf 'Exit the shell to return to your local terminal.\n'

    "$kubectl_bin" -n "$ns" debug -it "pod/$pod" \
      --profile=general \
      --container="$debug_container" \
      --target="$debug_target" \
      --image="$debug_image" \
      --env="HOME=/tmp/nvim-pod" \
      "${debug_profile_args[@]}" \
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
