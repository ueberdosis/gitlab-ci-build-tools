 #!/usr/bin/env bash
set -e

# set default compose file and a base namespace for the compose project,
# can be overridden
COMPOSE_PROJECT_NAME_BASE=${COMPOSE_PROJECT_NAME:-"ci-$CI_PROJECT_ID-$CI_PIPELINE_ID"}
COMPOSE_FILE_BASE=${COMPOSE_FILE:-"docker-compose.build.yml"}

# parse options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --older_than)
        OLDER_THAN="$2"
        shift # past argument
        shift # past value
        ;;
        --keep_n)
        KEEP_N="$2"
        shift # past argument
        shift # past value
        ;;
        --name_regex)
        NAME_REGEX="$2"
        shift # past argument
        shift # past value
        ;;
        -c|--copy)
        COPY="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# copy stuff from a container
function copy_from_container() {
    if [ ! -z "$1" ]; then
        CONTAINER_NAME=$(echo $1 | cut -d':' -f 1)
        CONTAINER_PATH=$(echo $1 | cut -d':' -f 2)
        CONTAINER_ID=$(docker-compose ps -q $CONTAINER_NAME)
        docker cp $CONTAINER_ID:$CONTAINER_PATH .
    fi
}

if [ $# -gt 0 ]; then

    # initializes the current job, sets the compose project name
    # to allow concurrent jobs and logs in to the gitlab container registry.
    # you can overwrite the default compose file by providing an argument.
    if [ "$1" == "init" ]; then
        shift
        if [ ! -z "$1" ]; then
            COMPOSE_FILE_BASE="docker-compose.$1.yml"
            shift
        fi
        echo "export COMPOSE_FILE=$COMPOSE_FILE_BASE"
        echo "export COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME_BASE"
        if [ ! -z "$REGISTRY_USER" ]; then
            docker login -u $REGISTRY_USER -p $REGISTRY_PASSWORD $REGISTRY  &>/dev/null
        elif [ ! -z "$CI_BUILD_TOKEN" ]; then
            docker login -u gitlab-ci-token -p $CI_BUILD_TOKEN $CI_REGISTRY &>/dev/null
        fi

    # spins up containers and executes the code piped in from stdin.
    # makes sure the containers will be shut down even something fails.
    # to allow concurrency, pass a unique identifier as argument.
    # to copy something from a running container use the copy option
    elif [ "$1" == "run" ]; then
        shift
        if [ ! -z "$1" ]; then
            export COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME_BASE-$1
            shift
        fi
        docker-compose up -d --no-build --remove-orphans --quiet-pull
        sleep 10
        {
            bash -c "$(cat)"
        } || {
            copy_from_container "$COPY"
            docker-compose down
            exit 1
        }
        copy_from_container "$COPY"
        docker-compose down

     elif [ "$1" == "down" ]; then
        shift
        if [ ! -z "$1" ]; then
            export COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME_BASE-$1
            shift
        fi
        docker-compose down

    # sets ssh keys stored in SSH_KEY and SSH_KEY_PUB
    # and remove ssh host key verification.
    elif [ "$1" == "ssh" ]; then
        if [ -z "$SSH_KEY" ] || [ -z "$SSH_KEY_PUB" ]; then
            echo "ERROR! SSH_KEY or SSH_KEY_PUB not set!"
            exit 1
        fi

        export SSH_KEY_PATH=~/.ssh
        mkdir -p $SSH_KEY_PATH
        echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > $SSH_KEY_PATH/config
        echo "$SSH_KEY" > id_rsa
        chmod 600 id_rsa
        mv id_rsa $SSH_KEY_PATH/id_rsa
        echo "$SSH_KEY_PUB" > id_rsa.pub
        chmod 644 id_rsa.pub
        mv id_rsa.pub $SSH_KEY_PATH/id_rsa.pub

    # Clean the GitLab docker registry
    elif [ "$1" == "clean-registry" ]; then
        shift
        : "${GITLAB_ACCESS_TOKEN:?is not set!}"

        if [ -z "$1" ]; then
            echo "You need to provide an image name"
            exit 1
        fi

        REPOSITORY_ID=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/registry/repositories" | jq '.[] | select (.name=="'"$1"'") | .id')

        if [ -z "$REPOSITORY_ID" ]; then
            echo "Image not found"
            exit 1
        fi

        RESPONSE=$(curl -s --request DELETE --data "name_regex=${NAME_REGEX:-.*}" --data "keep_n=${KEEP_N:-5}" --data  "older_than=${OLDER_THAN:-14d}" --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" "$CI_API_V4_URL/projects/$CI_PROJECT_ID/registry/repositories/$REPOSITORY_ID/tags")

        if [ "$RESPONSE" != "202" ]; then
            echo "Error: $RESPONSE"
            exit 1
        fi

        echo "Registry cleaned successfully"
        exit 0

    # wait until the given service is ready
    elif [ "$1" == "wait-for" ]; then
        shift
        CONTAINER=$(docker-compose -f docker-compose.ci.yml ps -q $1)
        STATUS="starting"

        while [ "$STATUS" != "healthy" ]; do
            STATUS=$(docker inspect -f {{.State.Health.Status}} $CONTAINER)
            sleep 1
        done

    # get the git user of the last commit
    elif [ "$1" == "git-user" ]; then
        echo "$(git --no-pager show -s --format='%an' $(git log --format="%H" -n 1))"

    # hash the given file and truncate the checksum
    elif [ "$1" == "hash" ]; then
        shift
        FILE=$1
        shift
        sha512sum $FILE | awk "{print $1}" | cut -c1-16
    fi
fi
