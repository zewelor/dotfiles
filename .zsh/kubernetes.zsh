if has "kubectl"; then
  zinit light-mode from"gh-r" as"program" mv"hetzner-k3s-* -> hetzner-k3s" for @vitobotta/hetzner-k3s

  # lazy-load kubectl completion
  _kubectl() {
    unset -f _kubectl
    eval "$(command kubectl completion zsh)"
  }

  zpcompdef _kubectl kubectl

  function start-k8s-work() {
    alias k="kubectl"
    alias kmurder="kubectl delete pod --grace-period=0 --force"

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

    if [ -z "$(typeset -p POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS | \grep kubecontext)" ]; then
      typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION='$P9K_KUBECONTEXT_NAMESPACE'
      typeset -ga POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=($POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS kubecontext)
    fi

    zinit light-mode from"gh-r" as"program" for @derailed/k9s
    zinit light-mode from"gh-r" as"program" mv"krew-* -> kubectl-krew" for @kubernetes-sigs/krew

    helm_template_debug_with_deps() {
      local dir="${1:-.}"
      local output
      output=$(helm template --debug "$dir" 2>&1)

      if echo "$output" | grep -q 'You may need to run `helm dependency build`'; then
        echo "Missing dependencies detected. Running 'helm dependency build'..."
        helm dependency build
        echo "Re-running 'helm_template_debug_with_deps' recursively..."
        helm_template_debug_with_deps "$dir"
      elif echo "$output" | grep -q 'Please update the dependencies'; then
        echo "Outdated dependencies detected. Running 'helm dependency update'..."
        helm dependency update
        echo "Re-running 'helm_template_debug_with_deps' recursively..."
        helm_template_debug_with_deps "$dir"
      else
        echo "$output"
      fi
    }

    # zinit ice lucid wait has"minikube" for id-as"minikube_completion" as"completion" atclone"minikube completion zsh > _minikube" atpull"%atclone" run-atpull zdharma-continuum/null
    # zinit light-mode from"gh-r" as"program" mv"kubeseal-* -> kubeseal" for @bitnami-labs/sealed-secrets

    for krew_plugin in get-all view-allocations pod-lens ns pv-migrate; do
      if [ ! -f "$HOME/.krew/receipts/$krew_plugin.yaml" ]; then
        kubectl krew install $krew_plugin
      fi
    done
  }
fi
