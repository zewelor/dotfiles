#!/bin/zsh

set -u
set -o pipefail

NVIM_POD_DEBUG_IMAGE="ghcr.io/zewelor/nvim:latest"

usage() {
  echo "usage: nvim_pod <app-name>[/path]"
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%s not found in PATH\n' "$command_name" >&2
    return 1
  fi
}

first_non_empty_line() {
  local line

  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      printf '%s\n' "$line"
      return 0
    fi
  done

  return 1
}

find_running_pod() {
  local kubectl_bin="$1"
  local app="$2"
  local pod_json pod_lines line pod_count

  pod_json=$("$kubectl_bin" get pods -A -l app.kubernetes.io/name="$app" -o json) || return 1
  pod_lines=$(jq -r '
    [
      .items[]
      | select(.status.phase == "Running")
      | (.status.containerStatuses // []) as $statuses
      | select(($statuses | length) > 0)
      | select($statuses | all(.ready == true))
      | {ns: .metadata.namespace, name: .metadata.name}
    ]
    | sort_by(.ns, .name)
    | .[]?
    | "\(.ns)\t\(.name)"
  ' <<<"$pod_json") || return 1

  line=$(first_non_empty_line <<<"$pod_lines") || {
    printf 'no ready running pod found for app=%s\n' "$app" >&2
    return 1
  }

  if [[ -z "${line%%$'\t'*}" || -z "${line#*$'\t'}" || "${line#*$'\t'}" == "$line" ]]; then
    printf 'unexpected pod lookup output for app=%s: %s\n' "$app" "$line" >&2
    return 1
  fi

  pod_count=$(grep -c . <<<"$pod_lines")
  if (( pod_count > 1 )); then
    printf 'multiple ready running pods found for app=%s; using first sorted candidate: %s\n' "$app" "$line" >&2
  fi

  printf '%s\n' "$line"
}

select_debug_target() {
  local pod_json="$1"
  local containers container_count
  local -a container_names

  containers=$(jq -r '.spec.containers[]?.name' <<<"$pod_json") || return 1
  container_names=()
  if [[ -n "$containers" ]]; then
    container_names=("${(@f)containers}")
  fi

  if grep -qx "app" <<<"$containers"; then
    printf 'app\n'
    return 0
  fi

  container_count=${#container_names[@]}
  if (( container_count == 1 )); then
    first_non_empty_line <<<"$containers"
    return $?
  fi

  if (( container_count > 1 )); then
    printf 'pod has multiple regular containers and no "app" container: %s\n' "${(j:, :)container_names}" >&2
    printf 'nvim_pod will not guess the debug target container\n' >&2
    return 2
  fi

  return 1
}

extract_git_ssh_command() {
  local pod_json="$1"
  local debug_target="$2"

  jq -r --arg target "$debug_target" '
    .spec.containers[]
    | select(.name == $target)
    | (.env // [])
    | map(select(.name == "GIT_SSH_COMMAND"))
    | .[0].value // empty
  ' <<<"$pod_json"
}

extract_regular_mounts() {
  local pod_json="$1"
  local debug_target="$2"

  jq -r --arg target "$debug_target" '
    .spec.containers[]
    | select(.name == $target)
    | .volumeMounts // []
    | map(select((.subPath // "") == "" and (.subPathExpr // "") == ""))
    | unique_by(.mountPath)
    | sort_by([(.mountPath | length), .mountPath])
    | .[]?
    | [.name, .mountPath, (.readOnly // false), (.mountPropagation // "")]
    | @tsv
  ' <<<"$pod_json"
}

extract_subpath_mounts() {
  local pod_json="$1"
  local debug_target="$2"

  jq -r --arg target "$debug_target" '
    .spec.containers[]
    | select(.name == $target)
    | .volumeMounts // []
    | map(select((.subPath // "") != "" or (.subPathExpr // "") != ""))
    | unique_by(.mountPath)
    | sort_by([(.mountPath | length), .mountPath])
    | .[]?
    | [.name, .mountPath, (.subPath // .subPathExpr // "")]
    | @tsv
  ' <<<"$pod_json"
}

path_is_under_mount() {
  local path="$1"
  local mount_path="$2"

  if [[ "$mount_path" == "/" ]]; then
    [[ "$path" == /* ]]
  else
    [[ "$path" == "$mount_path" || "$path" == "$mount_path/"* ]]
  fi
}

resolve_open_path() {
  local path_fragment="$1"
  local regular_mounts="$2"
  local name mount_path read_only mount_propagation
  local open_path preferred_config="" preferred_fallback="" selection_reason=""

  if [[ -n "$path_fragment" && "$path_fragment" == /* ]]; then
    printf '%s\n' "$path_fragment"
    return 0
  fi

  if [[ -n "$path_fragment" ]]; then
    printf '/%s\n' "$path_fragment"
    return 0
  fi

  while IFS=$'\t' read -r name mount_path read_only mount_propagation; do
    [[ -z "$mount_path" ]] && continue

    if [[ "$read_only" == "true" ]]; then
      continue
    fi

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
  done <<<"$regular_mounts"

  if [[ -n "$preferred_config" ]]; then
    open_path="$preferred_config"
    selection_reason="preferred /config mount"
  elif [[ -n "$preferred_fallback" ]]; then
    open_path="$preferred_fallback"
    selection_reason="first writable non-system mount"
  else
    while IFS=$'\t' read -r name mount_path read_only mount_propagation; do
      [[ -z "$mount_path" ]] && continue
      open_path="$mount_path"
      selection_reason="first available mount"
      break
    done <<<"$regular_mounts"
  fi

  [[ -n "$open_path" ]] || return 1
  if [[ -n "$selection_reason" ]]; then
    printf 'Default path %s selected from %s\n' "$open_path" "$selection_reason" >&2
  fi
  printf '%s\n' "$open_path"
}

find_matching_mount() {
  local open_path="$1"
  local mounts="$2"
  local name mount_path mount_meta

  while IFS=$'\t' read -r name mount_path mount_meta _rest; do
    [[ -z "$mount_path" ]] && continue
    if path_is_under_mount "$open_path" "$mount_path"; then
      printf '%s\t%s\t%s\n' "$name" "$mount_path" "$mount_meta"
      return 0
    fi
  done <<<"$mounts"

  return 1
}

find_workspace_root() {
  local open_path="$1"
  local regular_mounts="$2"
  local workspace_root=""
  local name mount_path read_only mount_propagation best_workspace_len=0

  while IFS=$'\t' read -r name mount_path read_only mount_propagation; do
    [[ -z "$mount_path" ]] && continue
    if path_is_under_mount "$open_path" "$mount_path"; then
      if (( ${#mount_path} > best_workspace_len )); then
        workspace_root="$mount_path"
        best_workspace_len=${#mount_path}
      fi
    fi
  done <<<"$regular_mounts"

  [[ -n "$workspace_root" ]] || return 1
  printf '%s\n' "$workspace_root"
}

find_readonly_mount() {
  local open_path="$1"
  local regular_mounts="$2"
  local name mount_path read_only mount_propagation best_match="" best_len=0

  while IFS=$'\t' read -r name mount_path read_only mount_propagation; do
    [[ -z "$mount_path" ]] && continue
    if [[ "$read_only" == "true" ]] && path_is_under_mount "$open_path" "$mount_path"; then
      if (( ${#mount_path} > best_len )); then
        best_match="$mount_path"
        best_len=${#mount_path}
      fi
    fi
  done <<<"$regular_mounts"

  [[ -n "$best_match" ]] || return 1
  printf '%s\n' "$best_match"
}

collect_omitted_subpaths() {
  local workspace_root="$1"
  local subpath_mounts="$2"
  local name mount_path subpath

  while IFS=$'\t' read -r name mount_path subpath; do
    [[ -z "$mount_path" ]] && continue
    if path_is_under_mount "$mount_path" "$workspace_root"; then
      printf '%s\n' "$mount_path"
    fi
  done <<<"$subpath_mounts"
}

write_debug_profile() {
  local debug_profile="$1"
  local regular_mounts="$2"
  local name mount_path read_only mount_propagation

  {
    printf 'volumeMounts:\n'
    while IFS=$'\t' read -r name mount_path read_only mount_propagation; do
      [[ -z "$mount_path" ]] && continue
      printf '  - name: "%s"\n' "$name"
      printf '    mountPath: "%s"\n' "$mount_path"
      if [[ "$read_only" == "true" ]]; then
        printf '    readOnly: true\n'
      fi
      if [[ -n "$mount_propagation" ]]; then
        printf '    mountPropagation: "%s"\n' "$mount_propagation"
      fi
    done <<<"$regular_mounts"
  } >"$debug_profile"
}

run_nvim_pod() {
  local input="${1:-}"
  local app path_fragment open_path
  local kubectl_bin line ns pod
  local select_target_status
  local pod_json debug_target git_ssh_command
  local regular_mounts subpath_mounts
  local subpath_mount subpath_mount_name subpath_mount_path subpath_value
  local readonly_mount workspace_root session_home
  local debug_container debug_profile="" debug_exit=1
  local omitted_subpaths_output
  local -a nvim_cmd debug_env_args omitted_subpaths

  app="${input%%/*}"
  path_fragment=""
  if [[ "$input" == */* ]]; then
    path_fragment="${input#*/}"
  fi

  if [[ -z "$input" || -z "$app" ]]; then
    usage >&2
    return 1
  fi

  require_command kubectl || return 1
  require_command jq || return 1

  kubectl_bin=$(command -v kubectl) || return 1
  line=$(find_running_pod "$kubectl_bin" "$app") || return 1
  ns="${line%%$'\t'*}"
  pod="${line#*$'\t'}"

  pod_json=$("$kubectl_bin" -n "$ns" get pod "$pod" -o json) || return 1
  debug_target=$(select_debug_target "$pod_json")
  select_target_status=$?
  if (( select_target_status == 2 )); then
    return 1
  fi
  if (( select_target_status != 0 )); then
    printf 'pod %s has no regular containers\n' "$pod" >&2
    return 1
  fi

  git_ssh_command=$(extract_git_ssh_command "$pod_json" "$debug_target") || return 1
  regular_mounts=$(extract_regular_mounts "$pod_json" "$debug_target") || return 1
  subpath_mounts=$(extract_subpath_mounts "$pod_json" "$debug_target") || return 1

  if [[ -z "$regular_mounts" ]]; then
    printf 'container %s in pod %s has no mounted volumes to edit\n' "$debug_target" "$pod" >&2
    return 1
  fi

  open_path=$(resolve_open_path "$path_fragment" "$regular_mounts") || {
    printf 'no mounted paths found for app=%s\n' "$app" >&2
    return 1
  }

  if [[ -z "$path_fragment" ]]; then
    printf 'Starting path %s\n' "$open_path"
  fi

  subpath_mount=$(find_matching_mount "$open_path" "$subpath_mounts")
  if [[ -n "$subpath_mount" ]]; then
    IFS=$'\t' read -r subpath_mount_name subpath_mount_path subpath_value <<<"$subpath_mount"
    printf 'path %s is backed by subPath mount %s\n' "$open_path" "$subpath_mount_path" >&2
    printf 'ephemeral debug containers cannot mount subPath entries; open a parent path outside that subPath\n' >&2
    return 1
  fi

  readonly_mount=$(find_readonly_mount "$open_path" "$regular_mounts")
  if [[ -n "$readonly_mount" ]]; then
    printf 'path %s is backed by read-only mount %s\n' "$open_path" "$readonly_mount" >&2
    printf 'nvim_pod opens an editor for writes; choose a writable mounted path\n' >&2
    return 1
  fi

  workspace_root=$(find_workspace_root "$open_path" "$regular_mounts") || {
    printf 'path %s is not backed by a mounted pod volume\n' "$open_path" >&2
    printf 'nvim_pod only supports mounted paths from container %s\n' "$debug_target" >&2
    return 1
  }

  session_home="$workspace_root"
  if [[ "$session_home" == "/" ]]; then
    session_home="/tmp/nvim-pod-home"
  fi

  debug_container="nvim-debug-$(date +%s%N)"
  debug_profile=$(mktemp) || return 1

  {
    write_debug_profile "$debug_profile" "$regular_mounts" || return 1
    nvim_cmd=(
      sh -c '
        target="$1"
        home_dir="$2"
        status=0

        mkdir -p "$home_dir" || exit 1
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

    debug_env_args=(--env="HOME=$session_home")
    if [[ -n "$git_ssh_command" ]]; then
      debug_env_args+=(--env="GIT_SSH_COMMAND=$git_ssh_command")
    fi
    debug_env_args+=(--env="GIT_USER_NAME=zewelor")
    debug_env_args+=(--env="GIT_USER_EMAIL=zewelor@gmail.com")

    omitted_subpaths=()
    omitted_subpaths_output=$(collect_omitted_subpaths "$workspace_root" "$subpath_mounts")
    if [[ -n "$omitted_subpaths_output" ]]; then
      omitted_subpaths=("${(@f)omitted_subpaths_output}")
    fi

    printf 'Found pod %s in namespace %s (target container: %s)\n' "$pod" "$ns" "$debug_target"
    if (( ${#omitted_subpaths[@]} > 0 )); then
      printf 'Note: subPath mounts are omitted in the debug container: %s\n' "${(j:, :)omitted_subpaths}"
    fi
    printf 'Creating ephemeral debug container %s ...\n' "$debug_container"

    "$kubectl_bin" -n "$ns" debug -it "pod/$pod" \
      --profile=general \
      --container="$debug_container" \
      --target="$debug_target" \
      --image="$NVIM_POD_DEBUG_IMAGE" \
      "${debug_env_args[@]}" \
      --custom "$debug_profile" \
      -- "${nvim_cmd[@]}"
    debug_exit=$?
  } always {
    [[ -n "$debug_profile" ]] && rm -f -- "$debug_profile"
  }

  return "$debug_exit"
}

run_nvim_pod "$@"
