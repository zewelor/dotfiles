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

  function dkCRsh () {
    docker container run -it --rm --entrypoint "" $1 sh -c "clear; (bash 2>&1 > /dev/null || ash || sh)"
  }

  zpcompdef _docker dkEsh='_docker_complete_containers_names'

  if [ ! -z "`docker compose version`" ]; then

    # zpcompdef _docker-compose dkcrs="_docker-compose_services"

    function dkcrs () {
      docker compose stop $1 && docker compose up --force-recreate "$@[2,-1]" $1
    }

    # zpcompdef _docker-compose dkcrs="_docker-compose_services"

    function dkcrsd () {
      dkcrs $1 -d
    }

    # zpcompdef _docker-compose dkcrsd="_docker-compose_services"

    function dkcrsdl () {
      dkcrsd $1 && docker compose logs -f $1
    }

    # zpcompdef _docker-compose dkcrsdl="_docker-compose_services"

    function dkcupdate () {
      docker compose stop $1 && docker compose pull $1 && docker compose up -d $1 && sleep 5 && docker compose logs -f $1
    }

    # zpcompdef _docker-compose dkcupdate="_docker-compose_services"

    function dkcupdated () {
      docker compose stop $1 && docker compose pull $1 && docker compose up -d $1
    }

    # zpcompdef _docker-compose dkcupdated="_docker-compose_services"

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
  fi

fi

