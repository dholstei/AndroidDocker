#!/bin/bash
# 
#   android_env.sh: Setup libs and emulator for Android
# 

#---if systemd logger operating use it
if [ -z "$LOG" ]; then export LOG=~/docker.log; fi
function LOGGER() { read LOGMSG && echo "[$0:$1 `date`]" $LOGMSG | tee -a $LOG; }

if [ -z "${SRC}" ];         then SRC=lib.tgz; fi
if [ -z "${EMU}" ];         then EMU=android-studio.tgz; fi
if [ -z "${SCRIPT}" ];      then SCRIPT=$(basename $0); fi
if [ -z "${DEST}" ];        then DEST=hostdir; fi
if [ -z "${TAG}" ];         then TAG=android_dev; fi
if [ -z "${DOCKSCRIPT}" ];  then DOCKSCRIPT="/$SCRIPT"; fi

#   Define $INSTALL. System/OS package installer
function installer() {
    INSTALLERS=(apt yum yast);
    for (( i=0; i<${#INSTALLERS[@]}; i++ )); do
        I="${INSTALLERS[i]}";
        if $I --version >/dev/null 2>&1; then INSTALL="${INSTALLERS[i]} install -y ${PACKAGES[i]}"; break; fi;
    done
}

#   Check for command, install if not available
function check_function() {
    if whereis $1 | grep -q $1; then return; fi;
    installer; 
    if $INSTALL;
        then echo "--- \"$INSTALL\": Success  ---" | LOGGER $(($LINENO-1));
        else echo "--- \"$INSTALL\": FAILURE! ---" | LOGGER $(($LINENO-2)); exit 1; fi;
}

#   Check FILE exists and is a regular file
function check_file() {
    if ! [ -f $1 ];
        then echo "--- ERROR: File \"$1\" not found!  ---" | LOGGER $BASH_LINENO[1]; exit 1; fi;
}

#   Check for valid copy/move destination
function check_dest() {
    if ! [ -d $1 ] && ! [ -d $(dirname $1) ];
        then echo "--- ERROR: Invalid destination \"$1\"!  ---" | LOGGER $BASH_LINENO[1]; exit 1; fi;
}

#   Safe copy
function safe_cp() {
    if ! cp $@; then echo "--- ERROR: \"cp $@\" failed! ---" | LOGGER $BASH_LINENO[1]; exit 1; fi;
}

#   Safe move
function safe_mv() {
    if ! mv $@; then echo "--- ERROR: \"mv $@\" failed! ---" | LOGGER $BASH_LINENO[1]; exit 1; fi;
}

#   Compress "packages" from host that will be copied to image.  $1 is archive filename.
function compress_pkgs() {
    if [ $# -lt 2 ]; then echo "--- WARNING: \"${FUNCNAME[0]}\" invoked with insufficient arguments! ---" | LOGGER $BASH_LINENO[1]; return; fi
    ARCH=$1; shift
    if [ "$VERBOSE" = "1" ]; then
        CMD="tar cvz --file=$ARCH"
    else
        CMD="tar cz --file=$ARCH"
        echo "--- INFO: Compression launched, use \"-v\" for verbose. ---" | LOGGER $BASH_LINENO[1]; fi
        
    for IT in $@; do
        CMD="$CMD -C $(dirname $(realpath $IT)) $(basename $IT)";
    done
    if $CMD;
        then echo "--- INFO: \"$CMD\" success. ---" | LOGGER $BASH_LINENO[1];
        else echo "--- ERROR: \"$CMD\" failure! ---" | LOGGER $BASH_LINENO[1]; exit 1; fi;
}

#   Build ARG list for Docker.  NOTE: No protection against blank values
function build_args() {
    if [ $# -eq 0 ]; then return; fi
    for IT in $@; do
        ARGLIST="$ARGLIST --build-arg $IT=${!IT}";
    done
    echo $ARGLIST
}

#   Check docker version, "$1", the docker command is optional
function docker_cmd() {
    if [ -z "${DOCKER}" ]; then DOCKER=docker; fi
    if [ -n "$1" ]; then DOCKER=$1; fi
    VERSION=$($DOCKER version 2>/dev/null;);
    if [ $? -ne 0 ]; then echo "--- ERROR: \"$DOCKER\" couldn't execute! ---" | LOGGER $BASH_LINENO[1]; exit 1; fi
    VERSION=$($DOCKER version 2>/dev/null | grep Version | head -1 | awk '{print $2}')
}

#   Check docker compose version, "$1", the docker compose argument is optional
function docker_compose() {
    if [ -z "${DOCKERCOMPOSE}" ]; then DOCKERCOMPOSE="docker compose"; fi
    if [ -n "$1" ]; then DOCKERCOMPOSE=$1; fi
    VERSION=$($DOCKERCOMPOSE version 2>/dev/null;);
    if [ $? -ne 0 ]; then echo "--- ERROR: \"$DOCKERCOMPOSE\" couldn't execute! ---" | LOGGER $BASH_LINENO[1]; exit 1; fi
    VERSION=$($DOCKERCOMPOSE version 2>/dev/null | awk '{print $4}')
}

#   Build image from dockerfile
function docker_build() {
    docker_cmd $DOCKER;
    if [ $? -eq 0 ]; then echo "--- INFO: \"$DOCKER\" Version "$VERSION" ---" | LOGGER $(($LINENO-1)); else exit 1; fi
    DF="dockerfile"; check_file $DF
    if [ -z "${FULLNAME}" ]; then FULLNAME="$(getent passwd | grep $USER | cut -d : -f 5)"; fi
    UID_=$UID; HOME_=$HOME; USER_=$USER; SHELL_=$SHELL
    CMD="$DOCKER build -t $TAG $(build_args SCRIPT UID_ HOME_ SHELL_ USER_)"
    if $CMD .;
        then echo "--- INFO: \"$CMD\" in $PWD success. ---" | LOGGER $(($LINENO-1));
        else echo "--- ERROR: \"$CMD\" in $PWD failure! ---" | LOGGER $(($LINENO-2)); exit 1; fi;
    docker system prune -f > /dev/null
}

#   Launch container, do stuff
function docker_run() {
    docker_cmd $DOCKER;
    if [ $? -eq 0 ]; then echo "--- INFO: \"$DOCKER\" Version "$VERSION" ---" | LOGGER $(($LINENO-1)); else exit 1; fi
    if [ $($DOCKER images $TAG | wc -l) -eq 1 ]; then echo "--- ERROR: docker image \"$TAG\" not found! ---" | LOGGER $(($LINENO-1)); exit 1; fi
    echo "--- INFO: Launch from image: \"$($DOCKER images $TAG | tail -1)\" ---" | LOGGER $LINENO;

    ARGLIST="--env DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix --device /dev/kvm"; xhost local: > /dev/null;
    CMD="$DOCKER run $DOCKEXTRA $ARGLIST --volume $(realpath ./$DEST):/$DEST $TAG $DOCKSCRIPT"
    if $CMD;
        then echo "--- INFO: \"$CMD\" in $PWD success. ---" | LOGGER $(($LINENO-1));
        else echo "--- ERROR: \"$CMD\" in $PWD failure! ---" | LOGGER $(($LINENO-2)); exit 1; fi;
    $DOCKER system prune -f > /dev/null
}

#   Check docker-compose service. "$1", if specified, is the service.
function check_service() {
    docker_compose "docker compose"
    if [ $? -eq 0 ]; then echo "--- INFO: \"$DOCKERCOMPOSE\" Version "$VERSION" ---" | LOGGER $(($LINENO-1)); else exit 1; fi
    if [ -z "${DOCKERYML}" ]; then DOCKERYML=docker-compose.yml; fi
    check_file $DOCKERYML;
    if [ -n "$1" ]; then SERVICE=$1; fi
    if [ -z $SERVICE ]; then 
        echo "--- ERROR: Must specify (docker compose) \$SERVICE ---" | LOGGER $BASH_LINENO[1]; 
        echo "--- INFO: One of [$(yq '.services | keys | join(" | ")' $DOCKERYML)] ---" | LOGGER $BASH_LINENO[1]; 
        exit 1; fi
    IMAGE=$(yq ".services.$SERVICE.image" $DOCKERYML)
    if [ $IMAGE = "null" ]; then
        echo "--- ERROR: Service \"$SERVICE\" not found! ---" | LOGGER $BASH_LINENO[1]; 
        echo "--- INFO: Specify one of [$(yq '.services | keys | join(" | ")' $DOCKERYML)] ---" | LOGGER $BASH_LINENO[1]; 
        exit 1; fi
    docker_cmd $DOCKER;
    if [ $($DOCKER images $IMAGE | wc -l) -eq 1 ]; then 
        echo "--- ERROR: Service image for \"$SERVICE\", \"$IMAGE\", not found! ---" | LOGGER $BASH_LINENO[1];
        echo "--- INFO: Check \"$DOCKERYML\" and/or build \"$IMAGE\" ---" | LOGGER $BASH_LINENO[1];  exit 1; fi
    echo "--- INFO: Launch \"$SERVICE\" from image: \"$($DOCKER images $IMAGE | tail -1)\" ---" | LOGGER $LINENO;
}

#   Launch container, do stuff
function compose_run() {
    if [ -z $SERVICE ]; then SERVICE=interactive; fi
    if [ -n "$1" ]; then SERVICE=$1; fi
    check_service $SERVICE

    xhost local:;
    CMD="$DOCKERCOMPOSE up --remove-orphans $SERVICE"
    echo $CMD
    if $CMD;
        then echo "--- INFO: \"$CMD\" in $PWD success. ---" | LOGGER $(($LINENO-1));
        else echo "--- ERROR: \"$CMD\" in $PWD failure! ---" | LOGGER $(($LINENO-2)); exit 1; fi;
    docker system prune -f > /dev/null
}

#   Trap CTRL-C to get logging correct
function ctrl_c() {
    echo "=== INFO: User interupt, CTRL-C! ===" | LOGGER;

#   130: Script terminated by Control-C (SIGINT signal).
    exit 130
}

#   Check for successful command execution, -q option is quiet mode
function check_cmd() {
    while getopts "q" o; do
        case "${o}" in
            q)  #   -q quiet
                QUIET='>/dev/null 2>&1'
                shift
                ;;
            ?) break ;;
            *)
                ;;
        esac
    done
    if [ -z "$1" ]; then echo "--- ERROR: \"$FUNCNAME\" requires arguments! ---" | LOGGER $BASH_LINENO[1]; exit 1; fi;
    eval "$@ $QUIET"
    if [ $? -eq 0 ];
        then echo "--- INFO: \"$@\" in $PWD success. ---" | LOGGER $BASH_LINENO[1];
        else echo "--- ERROR: \"$@\" in $PWD failure! ---" | LOGGER $BASH_LINENO[1]; exit 1; fi;
}

#   Launch container stuff
function container_stuff() {
    check_cmd ssh-keygen -A -b 521 -t ecdsa
    check_cmd "/usr/sbin/sshd -D &"
    check_cmd "root/Android/Sdk/emulator/emulator -avd Pixel_7_API_35";
}

function trim_white() { echo "$1" | awk '$1=$1'; }

#   List declared functions for this script.
function list_functions() {
    FUNCTIONS=`declare -F | awk '{if ($2=="-f") printf "%s ", $3;}'`
    BLACKLIST="list_functions LOGGER usage trim_white ctrl_c"
    for Word in $BLACKLIST; do
        FUNCTIONS=${FUNCTIONS//"$Word"/}
    done

    for FUNCTION in $FUNCTIONS; do
        LN=`awk '{if ($1=="function" && $2=="'$FUNCTION'()") print NR;}' $0`;
        if ! [ -z "${LN}" ]; then
            COMMENT=`head -$(($LN-1)) $0 | tail -1 | awk -F# '{print $2}'`
            if [ -z "${MDPREFIX}" ]; then
                printf '%30s %s\n' "$FUNCTION($LN):" "$COMMENT"
            else
                printf '%s `%s`:\n%s\n\n' "$MDPREFIX" "$FUNCTION" "$(trim_white "$COMMENT")"
            fi
        fi
    done
}

while getopts "eiv" o; do
    case "${o}" in
        e)  #   -e Emulator
            DOCKSCRIPT="bash"
            shift
            ;;
        i)  #   -i Run interactive docker run
            DOCKEXTRA="-it"
            DOCKSCRIPT="bash"
            shift
            ;;
        v)  #   -v Verbose
            VERBOSE=1
            shift
            ;;
        *)
            ;;
    esac
done

FUNCTION=$1; shift 1

if [ -z ${FUNCTION} ]; then
    echo "Invoke with \"$0 function\""
	echo '"function" must be one of: '
    list_functions;
else
    trap ctrl_c INT;
    echo "=== INFO: Launched \"$0 $FUNCTION $@\". ===" | LOGGER $(($LINENO-1));
    if ! $FUNCTION $@; then
        echo "Invoke with \"$0 function\""
        echo '"function" must be one of: '
        list_functions;
    fi;
    echo "=== INFO: \"$0\" exit. ===" | LOGGER;
fi


