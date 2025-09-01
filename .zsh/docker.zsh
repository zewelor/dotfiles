if has "docker"; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1

  # Aliases
  # source: https://github.com/sorin-ionescu/prezto/blob/master/modules/docker/alias.zsh
  alias dkC='docker container'
  alias dkCrm='docker container rm'
  alias dkCls='docker container ls'

  ## Image (I)
  alias dkI='docker image'
  alias dkIin='docker image inspect'
  alias dkIls='docker image ls'
  alias dkIpr='docker image prune'
  alias dkIpl='docker image pull'
  alias dkIrm='docker image rm'

  ## Volume (V)
  alias dkV='docker volume'
  alias dkVin='docker volume inspect'
  alias dkVls='docker volume ls'
  alias dkVpr='docker volume prune'
  alias dkVrm='docker volume rm'

  ## Network (N)
  alias dkN='docker network'
  alias dkNin='docker network inspect'
  alias dkNls='docker network ls'
  alias dkNpr='docker network prune'
  alias dkNrm='docker network rm'

  ## Compose (c)
  alias dkc='docker compose'
  alias dkcr='docker compose run'
  alias dkcR='docker compose run --rm'
  # zinit ice as"completion" ; zinit snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker

  # Lazy load Docker completions to improve shell startup time
  function _docker() {
    # Remove the function to prevent recursion on subsequent calls
    unfunction $0

    # Ensure the completion system is initialized
    if ! type compinit &>/dev/null; then
        autoload -Uz compinit
        compinit
    fi

    eval "$(docker completion zsh)"

    $0 "$@"
  }


  # https://github.com/docker/cli/issues/993
  zstyle ':completion:*:*:docker:*' option-stacking yes

  alias dkcl='docker compose logs'

  function dkEsh () {
    docker exec -it $1 sh
  }

  # Small helper: list running container names (one per line)
  function _docker_running_container_names() {
    docker ps --format '{{.Names}}' 2>/dev/null
  }

  # Small helper: list local image references as repo:tag (non-dangling)
  function _docker_local_image_tags() {
    docker image ls --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | \
      grep -v '^<none>:' | grep -v ':<none>$'
  }

  # Completion for dkEsh: list running containers
  function _dkEsh() {
    local -a containers
    containers=(${(f)"$(_docker_running_container_names)"})
    compadd -a containers
  }

  zpcompdef _dkEsh dkEsh

  function dkCRsh () {
    docker container run -it --rm --entrypoint "" $1 sh -c "clear; (bash 2>&1 > /dev/null || ash || sh)"
  }

  # Completion for dkCRsh: list local images (repo:tag)
  function _dkCRsh() {
    local -a images
    images=(${(f)"$(_docker_local_image_tags)"})
    compadd -a images
  }

  zpcompdef _dkCRsh dkCRsh

  if [ ! -z "`docker compose version`" ]; then

    # Small helper: list docker compose service names in current project
    function _docker_compose_service_names() {
      docker compose config --services 2>/dev/null
    }

    function dkcrs () {
      docker compose stop $1 && docker compose up --force-recreate "$@[2,-1]" $1
    }

    # Completion: service names for dkcrs
    function _dkcrs() {
      local -a services
      services=(${(f)"$(_docker_compose_service_names)"})
      compadd -a services
    }
    zpcompdef _dkcrs dkcrs

    function dkcrsd () {
      dkcrs $1 -d
    }

    # Completion: service names for dkcrsd
    function _dkcrsd() {
      local -a services
      services=(${(f)"$(_docker_compose_service_names)"})
      compadd -a services
    }
    zpcompdef _dkcrsd dkcrsd

    function dkcrsdl () {
      dkcrsd $1 && docker compose logs -f $1
    }

    # Completion: service names for dkcrsdl
    function _dkcrsdl() {
      local -a services
      services=(${(f)"$(_docker_compose_service_names)"})
      compadd -a services
    }
    zpcompdef _dkcrsdl dkcrsdl

    function dkcupdate () {
      docker compose stop $1 && docker compose pull $1 && docker compose up -d $1 && sleep 5 && docker compose logs -f $1
    }

    # Completion: service names for dkcupdate
    function _dkcupdate() {
      local -a services
      services=(${(f)"$(_docker_compose_service_names)"})
      compadd -a services
    }
    zpcompdef _dkcupdate dkcupdate

    function dkcupdated () {
      docker compose stop $1 && docker compose pull $1 && docker compose up -d $1
    }

    # Completion: service names for dkcupdated
    function _dkcupdated() {
      local -a services
      services=(${(f)"$(_docker_compose_service_names)"})
      compadd -a services
    }
    zpcompdef _dkcupdated dkcupdated

    function docker_compose_run_or_exec() {
      local FLAGS
      if [ ! -t 0 ]; then
        FLAGS="-T"
      else
        FLAGS="-it"
      fi

      if docker compose ps | grep -q $1; then
        docker compose --progress quiet exec $FLAGS $1 "$@[2,-1]"
      else
        docker compose --progress quiet run --rm $FLAGS $1 "$@[2,-1]"
      fi
    }

    # Completion: service name for docker_compose_run_or_exec (first arg only)
    function _docker_compose_run_or_exec() {
      if (( CURRENT == 2 )); then
        local -a services
        services=(${(f)"$(_docker_compose_service_names)"})
        compadd -a services
      else
        return 1
      fi
    }
    zpcompdef _docker_compose_run_or_exec docker_compose_run_or_exec
  fi

fi
