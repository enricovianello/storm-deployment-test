#!/bin/bash
# Exit at first error
set -e

trap "exit 1" TERM
export TOP_PID=$$


# Supported platforms
supported_platforms="SL5, SL6"

# Supported deployment modes
supported_modes="clean, upgrade, update"

# Repo from which scripts should be fetched
script_repo="https://raw.github.com/italiangrid/storm-deployment-test/master"

boolean_values="yes,no"

ARGS=$(getopt -o p:m:r: -l "platform:mode:repo:" -n "storm-deployment-test.sh" -- "$@")

if [ $? -ne 0 ]; then
  echo "No arguments specified"
  exit 1
fi

eval set -- "$ARGS"        

echo "Parsing args..."

while true;
do
        case "$1" in
                -p | --platform)
                shift
                PLATFORM="$1"
                shift
                ;;
                -m | --mode)
                shift
                MODE="$1"
                shift
                ;;
                -r | --repo)
                shift
                REPO="$1"
                shift
                ;;
                --)
                shift
                break
                ;;
        esac
done


usage() {        
        echo
        echo "usage: storm-deployment-test -p <PLATFORM> -m <MODE> [-r REPO]"
        echo
        echo "PLATFORM: $supported_platforms"
        echo "MODE: $supported_modes"
        echo "REPO: A repo url to be used instead of the default repo"
        kill -TERM $TOP_PID
}

## Input validation ##
[[ -z $PLATFORM ]] && echo "Please provide a value for PLATFORM." && usage 
[[ -z $MODE ]] && echo "Please provide a value for MODE." && usage


if [ -n $REPO ]; then
        if [ "$REPO" = "NULL" ]; then
                REPO=""
        fi
fi


[[ $supported_platforms =~ $PLATFORM ]] || ( echo "Invalid platform value: $PLATFORM." && usage )

[[ $supported_modes =~ $MODE ]] || ( echo "Invalid mode value: $MODE." && usage )

export PLATFORM=$PLATFORM

# The platform environment script
env_script=""

# The deployment script
deployment_script=""

# The workdir for this job
workdir=`mktemp -p $PWD storm-deployment.XXXXXXXXXX -d`

echo "Workdir: $workdir"

pushd $workdir

case "$PLATFORM" in
        SL5) 
                case "$MODE" in
                        clean)
                                env_script=( "setup-scripts/SL5/setup-emi3-sl5.sh" )
                                ;;
                        update)
                                env_script=( "setup-scripts/SL5/setup-emi3-sl5.sh" )
                                ;;
                        upgrade)
                                env_script=( "setup-scripts/SL5/setup-emi2-sl5.sh" "setup-scripts/SL5/setup-emi3-sl5.sh")
                                ;;
                esac
                ;;
        SL6)
                case "$MODE" in
                        clean)
                                env_script=( "setup-scripts/SL6/setup-emi3-sl6.sh" )
                                ;;
                        update)
                                env_script=( "setup-scripts/SL6/setup-emi3-sl5.sh" )
                                ;;
                        upgrade)
                                env_script=( "setup-scripts/SL6/setup-emi2-sl5.sh" "setup-scripts/SL6/setup-emi3-sl5.sh")
                                ;;
                esac
                ;;
esac


case "$MODE" in
        clean)
                deployment_script=( "emi-storm-clean-deployment.sh" )
                ;;
        upgrade)
                deployment_script=( "emi-storm-clean-deployment.sh" "emi-storm-upgrade-deployment.sh" )
                ;;
        update)
                deployment_script=( "emi-storm-clean-deployment.sh" "emi-storm-upgrade-deployment.sh" )
                ;;
esac


echo "### StoRM Deployment Test ###"

echo "Host: `hostname -f`"
echo "Date: `date`"
echo "Environment scripts: ${env_script[*]}"        
echo "Deployment scripts: ${deployment_script[*]}"

echo "Fetching environment script from GITHUB..."
echo
mkdir -p setup-scripts/$PLATFORM
for s in "${env_script[@]}"; do
    wget --no-check-certificate $script_repo/$s -O $s
    chmod +x $s
done

echo "Fetching deployment scripts from GITHUB..."
echo
for s in "${deployment_script[@]}"; do
    wget --no-check-certificate $script_repo/$s -O $s
    chmod +x $s
done


if [ -n "$REPO" ]; then
        echo "Setting custom repo to: $REPO"
        export ADDITIONAL_REPO=$REPO
fi


echo "### <Environment> ### "
env
echo "### </Environment> ###"

echo "Starting deployment test"
echo

if [ "$MODE" == "update" ]; then
    echo "Setting environment: ${env_script[0]}"
    source ${env_script[0]}
    SAVED_STORM_REPO=$DEFAULT_STORM_REPO
    unset DEFAULT_STORM_REPO
    echo "Executing ${deployment_script[0]}"
    ./${deployment_script[0]}

    export DEFAULT_STORM_REPO=$SAVED_STORM_REPO
    echo "Executing ${deployment_script[1]}"
    ./${deployment_script[1]}
elif [ "$MODE" == "upgrade" ]; then
    echo "Setting environment: ${env_script[0]}"
    source ${env_script[0]}
    SAVED_STORM_REPO=$DEFAULT_STORM_REPO
    unset DEFAULT_STORM_REPO
    echo "Executing ${deployment_script[0]}"
    ./${deployment_script[0]}

    echo "Setting environment: ${env_script[1]}"
    source ${env_script[1]}
    export DEFAULT_STORM_REPO=$SAVED_STORM_REPO
    echo "Executing ${deployment_script[1]}"
    ./${deployment_script[1]}
else
    echo "Setting environment: ${env_script[0]}"
    source ${env_script[0]}
    echo "Executing ${deployment_script[0]}"
    ./${deployment_script[0]}
fi

popd