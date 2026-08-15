if command -v kubectl >/dev/null 2>&1; then
  # Ensure KVAULT_TOKEN is unexported in the shell environment even if previously exported.
  typeset -g +x KVAULT_TOKEN || {
    echo "Failed to unexport KVAULT_TOKEN" >&2
    return 1
  }

  kvault() {
    local ns="${VAULT_K8S_NAMESPACE:-kube-system}"
    local pod
    pod="$(kubectl get pod -n "$ns" -l app.kubernetes.io/name=vault,vault-active=true -o jsonpath='{.items[0].metadata.name}')" || return 1
    if [[ -z "$pod" ]]; then
      pod="$(kubectl get pod -n "$ns" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')" || return 1
    fi
    if [[ -z "$pod" ]]; then
      echo "Vault pod not found in $ns" >&2
      return 1
    fi

    local -a exec_flags=(-i)
    if [[ -z "${KVAULT_TOKEN:-}" && -t 0 && -t 1 ]]; then
      exec_flags=(-it)
    fi

    if [[ -n "${KVAULT_TOKEN:-}" ]]; then
      # Frame the token safely via stdin so KVAULT_TOKEN is never exposed in argv or process tables.
      # The remote shell consumes the first line as VAULT_TOKEN, leaving any remaining stdin for vault.
      {
        print -r -- "$KVAULT_TOKEN"
        if [[ ! -t 0 ]]; then
          cat
        fi
      } | kubectl exec -n "$ns" "${exec_flags[@]}" "$pod" -- sh -c 'IFS= read -r VAULT_TOKEN && export VAULT_TOKEN && exec vault "$@"' -- "$@"
    else
      kubectl exec -n "$ns" "${exec_flags[@]}" "$pod" -- vault "$@"
    fi
  }

  kvlogin() {
    local t
    read -rs "?Vault token (hidden): " t
    echo
    if [[ -z "$t" ]]; then
      echo "Vault token cannot be empty" >&2
      return 1
    fi
    typeset -g +x KVAULT_TOKEN || {
      echo "Failed to unexport KVAULT_TOKEN" >&2
      return 1
    }
    KVAULT_TOKEN="$t"
    unset t
    if kvault token lookup >/dev/null; then
      echo "Vault login OK"
    else
      unset KVAULT_TOKEN
      echo "Vault login failed" >&2
      return 1
    fi
  }

  kvlogout() {
    unset KVAULT_TOKEN
    echo "Vault token cleared from shell"
  }
fi
