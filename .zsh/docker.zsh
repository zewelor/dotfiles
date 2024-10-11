if has "docker"; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1

  zinit ice as"completion" ; zinit snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker

  alias czysc_docker='docker container prune ; dkrmI'

  function dkEsh () {
    dkE $1 sh
  }

  function dkCRsh () {
    docker container run -it --rm --entrypoint "" $1 sh -c "clear; (bash 2>&1 > /dev/null || ash || sh)"
  }

  zpcompdef _docker dkEsh='_docker_complete_containers_names'

  if [ ! -z "`docker compose version`" ]; then

    zpcompdef _docker-compose dkcrs="_docker-compose_services"

    # zinit ice as"completion" ; zinit snippet https://github.com/docker/compose/blob/master/contrib/completion/zsh/_docker-compose

    function dkcrs () {
      dkc stop $1 && dkc up --force-recreate "$@[2,-1]" $1
    }

    zpcompdef _docker-compose dkcrs="_docker-compose_services"

    function dkcrsd () {
      dkcrs $1 -d
    }

    zpcompdef _docker-compose dkcrsd="_docker-compose_services"

    function dkcrsdl () {
      dkcrsd $1 && dkcl -f $1
    }

    zpcompdef _docker-compose dkcrsdl="_docker-compose_services"

    function dkcupdate () {
      dkc stop $1 && dkc pull $1 && dkc up -d $1 && sleep 5 && dkcl -f $1
    }

    zpcompdef _docker-compose dkcupdate="_docker-compose_services"

    function dkcupdated () {
      dkc stop $1 && dkc pull $1 && dkc up -d $1
    }

    zpcompdef _docker-compose dkcupdated="_docker-compose_services"

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

  # Aliases
  # source: https://github.com/sorin-ionescu/prezto/blob/master/modules/docker/alias.zsh
  alias dkC='docker container'
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
fi

