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

    local debug_container="nvim-debug-$(date +%s%N)"
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
        | map(select((.subPath // "") == "" and (.subPathExpr // "") == ""))
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
             end),
            (if $volume.persistentVolumeClaim then $volume.persistentVolumeClaim.claimName
             elif $volume.configMap then $volume.configMap.name
             elif $volume.secret then $volume.secret.secretName
             elif $volume.projected then "projected"
             elif $volume.emptyDir then "emptyDir"
             elif $volume.hostPath then $volume.hostPath.path
             else ""
             end)
          ]
        | @tsv
      ]
      | .[]?
    ' <<<"$pod_json")

    local selected_mount=""
    local workspace_root=""
    local home_path=""
    if [[ -n "$folder" && "$folder" == /* ]]; then
      open_path="$folder"
    elif [[ -n "$folder" ]]; then
      open_path="/$folder"
    else
      local mount_name mount_path mount_access mount_type mount_source
      local preferred_config=""
      local preferred_pvc=""
      local preferred_fallback=""
      local -a pvc_choices
      pvc_choices=()

      while IFS=$'\t' read -r mount_name mount_path mount_access mount_type mount_source; do
        [[ -z "$mount_path" ]] && continue

        if [[ -z "$preferred_config" && "$mount_path" == "/config" ]]; then
          preferred_config="$mount_path"
        fi

        if [[ -z "$preferred_pvc" && "$mount_type" == "pvc" ]]; then
          preferred_pvc="$mount_path"
        fi

        if [[ "$mount_type" == "pvc" ]]; then
          pvc_choices+=("$mount_path"$'\t'"$mount_source"$'\t'"$mount_access")
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

      if (( ${#pvc_choices[@]} > 1 )); then
        if [[ -t 0 ]]; then
          local idx=1 pvc_choice pvc_input pvc_path pvc_claim pvc_access

          printf 'Multiple PVC mounts found for %s:\n' "$app"
          for pvc_choice in "${pvc_choices[@]}"; do
            IFS=$'\t' read -r pvc_path pvc_claim pvc_access <<<"$pvc_choice"
            if [[ -n "$pvc_claim" ]]; then
              printf '  %d) %s (%s, %s)\n' "$idx" "$pvc_path" "$pvc_claim" "$pvc_access"
            else
              printf '  %d) %s (%s)\n' "$idx" "$pvc_path" "$pvc_access"
            fi
            idx=$((idx + 1))
          done

          while true; do
            read -r "?Select PVC [1-${#pvc_choices[@]}]: " pvc_input || return 1
            if [[ "$pvc_input" == <-> ]] && (( pvc_input >= 1 && pvc_input <= ${#pvc_choices[@]} )); then
              IFS=$'\t' read -r selected_mount _ _ <<<"${pvc_choices[$pvc_input]}"
              break
            fi

            printf 'Invalid selection. Choose 1-%d.\n' "${#pvc_choices[@]}"
          done
        else
          IFS=$'\t' read -r selected_mount _ _ <<<"${pvc_choices[1]}"
          printf 'Multiple PVC mounts found; stdin is not interactive, defaulting to %s\n' "$selected_mount"
        fi
      fi

      if [[ -n "$selected_mount" ]]; then
        open_path="$selected_mount"
      elif [[ -n "$preferred_config" ]]; then
        open_path="$preferred_config"
      elif [[ -n "$preferred_pvc" ]]; then
        open_path="$preferred_pvc"
      elif [[ -n "$preferred_fallback" ]]; then
        open_path="$preferred_fallback"
      else
        open_path="/"
      fi

      printf 'Starting path %s\n' "$open_path"
    fi

    local best_workspace_len=0
    while IFS=$'\t' read -r mount_name mount_path mount_access mount_type mount_source; do
      [[ -z "$mount_path" ]] && continue
      if [[ "$open_path" == "$mount_path" || "$open_path" == "$mount_path/"* ]]; then
        if [[ -z "$workspace_root" || ${#mount_path} -lt best_workspace_len ]]; then
          workspace_root="$mount_path"
          best_workspace_len=${#mount_path}
        fi
      fi
    done <<<"$mount_table"

    if [[ -z "$workspace_root" ]]; then
      if [[ -n "$selected_mount" ]]; then
        workspace_root="$selected_mount"
      elif [[ "$open_path" == */* ]]; then
        workspace_root="${open_path%/*}"
        [[ -n "$workspace_root" ]] || workspace_root="/"
      else
        workspace_root="$open_path"
      fi
    fi

    home_path="$workspace_root"

    local session_root="/tmp/nvim-pod-workspace"
    local base_root="/tmp/nvim-pod-base"
    local overlay_root="/tmp/nvim-pod-mirrors"
    local session_open_path="$open_path"
    local session_home_path="$home_path"
    local workspace_source=""
    local workspace_target=""
    local workspace_access="rw"
    local direct_mounts_yaml=""
    local overlay_mounts_yaml=""
    local overlay_manifest=""
    local use_workspace_copy="0"

    while IFS=$'\t' read -r mount_name mount_path mount_access mount_type mount_source; do
      if [[ "$mount_path" == "$workspace_root" ]]; then
        workspace_access="$mount_access"
        break
      fi
    done <<<"$mount_table"

    overlay_mounts_yaml=$(jq -r --arg target "$debug_target" --arg root "$workspace_root" --arg overlay_root "$overlay_root" '
      .spec.containers[]
      | select(.name == $target)
      | .volumeMounts // []
      | to_entries
      | map(select(
          .value.mountPath != $root and
          (if $root == "/" then
            true
          else
            (.value.mountPath | startswith($root + "/"))
          end)
        ))
      | sort_by([(.value.mountPath | length), .value.mountPath, .key])
      | .[]
      | "  - name: \(.value.name | @json)\n" +
        "    mountPath: \(($overlay_root + "/mount-" + (.key | tostring) + "-" + .value.name) | @json)" +
        "\n    readOnly: true" +
        (if (.value.mountPropagation // "") != "" then "\n    mountPropagation: \(.value.mountPropagation | @json)" else "" end)
    ' <<<"$pod_json")

    overlay_manifest=$(jq -r --arg target "$debug_target" --arg root "$workspace_root" --arg session_root "$session_root" --arg overlay_root "$overlay_root" '
      .spec.containers[]
      | select(.name == $target)
      | .volumeMounts // []
      | to_entries
      | map(select(
          .value.mountPath != $root and
          (if $root == "/" then
            true
          else
            (.value.mountPath | startswith($root + "/"))
          end)
        ))
      | sort_by([(.value.mountPath | length), .value.mountPath, .key])
      | .[]
      | [
          ($session_root + .value.mountPath),
          ($overlay_root + "/mount-" + (.key | tostring) + "-" + .value.name),
          (.value.subPath // ""),
          (.value.subPathExpr // "")
        ]
      | @tsv
    ' <<<"$pod_json")

    if [[ -n "$overlay_manifest" && "$workspace_root" != "/" ]]; then
      use_workspace_copy="1"
      workspace_source="${base_root}${workspace_root}"
      workspace_target="${session_root}${workspace_root}"
      session_open_path="${session_root}${open_path}"
      session_home_path="${session_root}${home_path}"

      direct_mounts_yaml=$(jq -r --arg target "$debug_target" --arg root "$workspace_root" --arg base_root "$base_root" '
        .spec.containers[]
        | select(.name == $target)
        | .volumeMounts // []
        | map(select(.mountPath == $root))
        | .[]?
        | "  - name: \(.name | @json)\n" +
          "    mountPath: \(($base_root + .mountPath) | @json)" +
          (if .readOnly then "\n    readOnly: true" else "" end) +
          (if (.mountPropagation // "") != "" then "\n    mountPropagation: \(.mountPropagation | @json)" else "" end)
      ' <<<"$pod_json")
    else
      overlay_mounts_yaml=""
      overlay_manifest=""

      direct_mounts_yaml=$(jq -r --arg target "$debug_target" --arg root "$workspace_root" '
        .spec.containers[]
        | select(.name == $target)
        | .volumeMounts // []
        | map(select(
            ((.subPath // "") == "") and
            ((.subPathExpr // "") == "") and
            (if $root == "/" then
              true
            else
              .mountPath == $root or (.mountPath | startswith($root + "/"))
            end)
          ))
        | unique_by(.name + "|" + .mountPath)
        | sort_by([(.mountPath | length), .mountPath, .name])
        | .[]
        | "  - name: \(.name | @json)\n" +
          "    mountPath: \(.mountPath | @json)" +
          (if .readOnly then "\n    readOnly: true" else "" end) +
          (if (.mountPropagation // "") != "" then "\n    mountPropagation: \(.mountPropagation | @json)" else "" end)
      ' <<<"$pod_json")
    fi

    local -a nvim_cmd
    nvim_cmd=(
      sh -c '
        target="$1"
        session_home="$2"
        overlay_manifest="$3"
        copy_mode="$4"
        workspace_source="$5"
        workspace_target="$6"
        workspace_access="$7"
        status=0
        shell_status=0
        tab=$(printf "\t")

        cleanup_overlays() {
          [ -n "$overlay_manifest" ] || return 0
          printf "%s\n" "$overlay_manifest" | while IFS="$tab" read -r mount_path helper_path sub_path sub_path_expr; do
            [ -n "$mount_path" ] || continue

            if [ -e "$mount_path" ] || [ -L "$mount_path" ]; then
              rm -rf "$mount_path" 2>/dev/null || true
            fi

            parent="${mount_path%/*}"
            [ -n "$parent" ] || parent=/
            while [ "$parent" != "$workspace_target" ] && [ "$parent" != "/" ]; do
              rmdir "$parent" 2>/dev/null || break
              parent="${parent%/*}"
              [ -n "$parent" ] || parent=/
            done
          done
        }

        apply_overlays() {
          [ -n "$overlay_manifest" ] || return 0
          printf "%s\n" "$overlay_manifest" | while IFS="$tab" read -r mount_path helper_path sub_path sub_path_expr; do
            [ -n "$mount_path" ] || continue

            source_path="$helper_path"
            if [ -n "$sub_path" ]; then
              source_path="$helper_path/$sub_path"
            elif [ -n "$sub_path_expr" ]; then
              source_path="$helper_path/$sub_path_expr"
            fi

            parent="${mount_path%/*}"
            [ -n "$parent" ] || parent=/
            mkdir -p "$parent" 2>/dev/null || true

            if [ -e "$mount_path" ] || [ -L "$mount_path" ]; then
              rm -rf "$mount_path" 2>/dev/null || true
            fi

            if ! ln -s "$source_path" "$mount_path" 2>/dev/null; then
              printf "Warning: could not mirror nested mount %s -> %s\n" "$mount_path" "$source_path" >&2
            fi
          done
        }

        if [ "$copy_mode" = "1" ]; then
          rm -rf "$workspace_target" 2>/dev/null || true
          mkdir -p "$workspace_target" 2>/dev/null || true
          if [ -d "$workspace_source" ]; then
            cp -a "$workspace_source"/. "$workspace_target"/ || {
              printf "Could not prepare workspace copy from %s\n" "$workspace_source" >&2
              exit 1
            }
          else
            printf "Could not prepare workspace copy from %s\n" "$workspace_source" >&2
            exit 1
          fi
        fi

        if [ -n "$overlay_manifest" ]; then
          apply_overlays
        fi

        if [ -n "$session_home" ] && [ ! -d "$session_home" ]; then
          session_home="${session_home%/*}"
          [ -n "$session_home" ] || session_home=/
        fi

        export HOME="$session_home"

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
          bash -i
          shell_status=$?
        else
          sh -i
          shell_status=$?
        fi

        if [ "$copy_mode" = "1" ]; then
          cleanup_overlays
          if [ "$workspace_access" != "ro" ] && [ -d "$workspace_source" ] && [ -d "$workspace_target" ]; then
            cp -a "$workspace_target"/. "$workspace_source"/ || {
              printf "Warning: could not sync workspace back to %s\n" "$workspace_source" >&2
            }
          fi
        fi

        exit "$shell_status"
      ' sh "$session_open_path" "$session_home_path" "$overlay_manifest" "$use_workspace_copy" "$workspace_source" "$workspace_target" "$workspace_access"
    )

    if typeset -f _title_terminal_cmd >/dev/null 2>&1; then
      _title_terminal_cmd "nvim_pod $app"
    fi

    printf 'Found pod %s in namespace %s (target container: %s)\n' "$pod" "$ns" "$debug_target"
    printf 'Creating ephemeral debug container %s ...\n' "$debug_container"

    debug_profile=$(mktemp)
    {
      # Mirror mounts without subPath directly and reconstruct nested mounts inside a temp workspace when needed.
      if [[ -n "$direct_mounts_yaml" || -n "$overlay_mounts_yaml" ]]; then
        printf 'volumeMounts:\n'
        [[ -n "$direct_mounts_yaml" ]] && printf '%s\n' "$direct_mounts_yaml"
        [[ -n "$overlay_mounts_yaml" ]] && printf '%s\n' "$overlay_mounts_yaml"
      else
        printf 'volumeMounts: []\n'
      fi
    } >"$debug_profile"
    debug_profile_args=(--custom "$debug_profile")

    printf 'Attaching to %s ...\n' "$debug_container"
    printf 'Exit the shell to return to your local terminal.\n'

    "$kubectl_bin" -n "$ns" debug -it "pod/$pod" \
      --profile=general \
      --container="$debug_container" \
      --target="$debug_target" \
      --image="$debug_image" \
      --env="HOME=$session_home_path" \
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
