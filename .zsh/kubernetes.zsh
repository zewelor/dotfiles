if has "kubectl"; then
  # lazy-load kubectl completion
  _kubectl() {
    unset -f _kubectl
    eval "$(command kubectl completion zsh)"
  }

  zpcompdef _kubectl kubectl

  function start-k8s-work () {
    alias k="kubectl"
    alias kmurder="kubectl delete pod --grace-period=0 --force"

    function kcRsh () {
      kubectl run $2 --image=$1 --attach -ti --restart=Never --rm --command -- sh -c "clear; (bash 2>&1 > /dev/null || ash || sh)"
    }

    function kcEsh () {
      kubectl exec -ti $1 -- sh -c "clear; (bash 2>&1 > /dev/null || ash || sh)"
    }

    function k8s-secret-encode () {
      echo -n $(read v; echo $v) | base64 -w 0
    }

    if [ -z "$(typeset -p POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS | \grep kubecontext)" ] ; then
      typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION='$P9K_KUBECONTEXT_NAMESPACE'
      typeset -ga POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=($POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS kubecontext)
    fi

    zinit light-mode from"gh-r" as"program" for @derailed/k9s
    zinit light-mode from"gh-r" as"program" mv"krew-* -> kubectl-krew" for @kubernetes-sigs/krew
    zinit ice svn pick"init.zsh"; zinit snippet 'https://github.com/prezto-contributions/prezto-kubectl/trunk'

    # zinit light-mode from"gh-r" as"program" mv"kubeseal-* -> kubeseal" for @bitnami-labs/sealed-secrets

    for krew_plugin in get-all view-allocations pod-lens ns pv-migrate; do
      if [ ! -f "$HOME/.krew/receipts/$krew_plugin.yaml" ]; then
        kubectl krew install $krew_plugin
      fi
    done
  }
fi

