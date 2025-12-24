if has "kubectl"; then
  # lazy-load kubectl completion
  _kubectl() {
    unset -f _kubectl
    eval "$(command kubectl completion zsh)"
  }

  zpcompdef _kubectl kubectl

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
                -s|--secure)
                    has_s=1
                    ;;
                -n|--number)
                    has_n=1
                    ;;
                -1)
                    has_n=1
                    ;;
                *)
                    ;;
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
