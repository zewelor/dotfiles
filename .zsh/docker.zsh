if has "docker"; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1

  # Aliases (these expand for completion - subcommands work via docker completion)
  # source: https://github.com/sorin-ionescu/prezto/blob/master/modules/docker/alias.zsh
  alias dkC='docker container'
  alias dkCls='docker container ls'

  ## Image (I)
  alias dkI='docker image'
  alias dkIls='docker image ls'
  alias dkIpr='docker image prune'
  alias dkIpl='docker image pull'

  ## Volume (V)
  alias dkV='docker volume'
  alias dkVls='docker volume ls'
  alias dkVpr='docker volume prune'

  ## Network (N)
  alias dkN='docker network'
  alias dkNls='docker network ls'
  alias dkNpr='docker network prune'

  # Functions (not expanded - use custom completion for image/container/volume/network names)
  dkCrm() { docker container rm "$@"; }
  dkIin() { docker image inspect "$@"; }
  dkIrm() { docker image rm "$@"; }
  dkVin() { docker volume inspect "$@"; }
  dkVrm() { docker volume rm "$@"; }
  dkNin() { docker network inspect "$@"; }
  dkNrm() { docker network rm "$@"; }

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

  # Completion functions for docker aliases (with aligned descriptions)
  # -V keeps original order (newest first from docker), -l shows as list
  _dkEsh() {
    local -a names descriptions
    names=(${(f)"$(docker ps --format '{{.Names}}' 2>/dev/null)"})
    descriptions=(${(f)"$(docker ps --format '{{.Names}}|{{.Image}}|{{.Status}}' 2>/dev/null | awk -F'|' '{printf "%-30s -- %-30s (%s)\n", $1, $2, $3}')"})
    compadd -V unsorted -l -d descriptions -a names
  }
  _dkCRsh() {
    local -a names descriptions
    names=(${(f)"$(docker image ls --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>')"})
    descriptions=(${(f)"$(docker image ls --format '{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}' 2>/dev/null | grep -v '<none>' | awk -F'|' '{
      size = $2
      if (size ~ /GB/) { gsub(/GB/, "", size); size = int(size * 1024) "MB" }
      else if (size ~ /MB/) { gsub(/[^0-9.]/, "", size); size = int(size) "MB" }
      else if (size ~ /KB/) { gsub(/KB/, "", size); size = int(size / 1024) "MB" }
      match($3, /([0-9]+) ([a-z]+)/, arr)
      printf "%-45s -- %6s, %3s %-10s\n", $1, size, arr[1], arr[2]
    }')"})
    compadd -V unsorted -l -d descriptions -a names
  }
  _dkIin() { _dkCRsh; }
  _dkIrm() { _dkCRsh; }
  _dkCrm() {
    local -a names descriptions
    names=(${(f)"$(docker ps -a --format '{{.Names}}' 2>/dev/null)"})
    descriptions=(${(f)"$(docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}' 2>/dev/null | awk -F'|' '{printf "%-30s -- %-30s (%s)\n", $1, $2, $3}')"})
    compadd -V unsorted -l -d descriptions -a names
  }
  _dkVin() {
    local -a names descriptions
    names=(${(f)"$(docker volume ls --format '{{.Name}}' 2>/dev/null)"})
    descriptions=(${(f)"$(docker volume ls --format '{{.Name}}|{{.Driver}}|{{.Scope}}' 2>/dev/null | awk -F'|' '{printf "%-40s -- %s, %s\n", $1, $2, $3}')"})
    compadd -V unsorted -l -d descriptions -a names
  }
  _dkVrm() { _dkVin; }
  _dkNin() {
    local -a names descriptions
    names=(${(f)"$(docker network ls --format '{{.Name}}' 2>/dev/null)"})
    descriptions=(${(f)"$(docker network ls --format '{{.Name}}|{{.Driver}}|{{.Scope}}' 2>/dev/null | awk -F'|' '{printf "%-30s -- %s, %s\n", $1, $2, $3}')"})
    compadd -V unsorted -l -d descriptions -a names
  }
  _dkNrm() { _dkNin; }

  # Register completions via zinit's zicdreplay mechanism
  # This queues compdef calls until compinit runs
  ZINIT_COMPDEF_REPLAY+=("_dkIin dkIin" "_dkIrm dkIrm" "_dkCRsh dkCRsh")
  ZINIT_COMPDEF_REPLAY+=("_dkCrm dkCrm")
  ZINIT_COMPDEF_REPLAY+=("_dkVin dkVin" "_dkVrm dkVrm")
  ZINIT_COMPDEF_REPLAY+=("_dkNin dkNin" "_dkNrm dkNrm")
  ZINIT_COMPDEF_REPLAY+=("_dkEsh dkEsh")

  if [ ! -z "`docker compose version`" ]; then

    # Small helper: list docker compose service names in current project
    function _docker_compose_service_names() {
      local out status
      out=$(docker compose config --services 2>/dev/null)
      status=$?
      if (( status != 0 )); then
        echo "Docker Compose file not detected in this directory." >&2
        echo "Run in a Compose project (compose.yaml/docker-compose.yml) or set COMPOSE_FILE." >&2
        return $status
      fi
      print -r -- "$out"
    }

    function dkcrs () {
      docker compose stop $1 && docker compose up --force-recreate "$@[2,-1]" $1
    }

    # Reusable completion for compose service names
    function _complete_compose_services() {
      local -a services
      services=(${(f)"$(_docker_compose_service_names 2>/dev/null)"})
      if (( ${#services} == 0 )); then
        _message 'No Compose file here (compose.yaml/docker-compose.yml).'
        return 1
      fi
      compadd -a services
    }

    function dkcrsd () {
      dkcrs $1 -d
    }

    function dkcrsdl () {
      dkcrsd $1 && docker compose logs -f $1
    }

    function dkcupdate () {
      docker compose stop $1 && docker compose pull $1 && docker compose up -d $1 && sleep 5 && docker compose logs -f $1
    }

    function dkcupdated () {
      docker compose stop $1 && docker compose pull $1 && docker compose up -d $1
    }

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
        services=(${(f)"$(_docker_compose_service_names 2>/dev/null)"})
        if (( ${#services} == 0 )); then
          _message 'No Compose file here (compose.yaml/docker-compose.yml).'
          return 1
        fi
        compadd -a services
      else
        return 1
      fi
    }

    # Register compose completions
    ZINIT_COMPDEF_REPLAY+=("_complete_compose_services dkcrs")
    ZINIT_COMPDEF_REPLAY+=("_complete_compose_services dkcrsd")
    ZINIT_COMPDEF_REPLAY+=("_complete_compose_services dkcrsdl")
    ZINIT_COMPDEF_REPLAY+=("_complete_compose_services dkcupdate")
    ZINIT_COMPDEF_REPLAY+=("_complete_compose_services dkcupdated")
    ZINIT_COMPDEF_REPLAY+=("_docker_compose_run_or_exec docker_compose_run_or_exec")
  fi

fi
