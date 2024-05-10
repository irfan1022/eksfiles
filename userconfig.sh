#!/bin/bash
# Executes a deployment config for a particular user container to the Kubernetes cluster.

ENVIRONMENT_NAME=${1:-none}
CONTAINER_PATH=${2:-none}
REAL_DEPLOYMENT=${3:-false} # Explicitly pass true value for "real" deployment instead of dry run.

# Exit when any command fails
set -e

if [ "$CONTAINER_PATH" != "none" ]
then
    CONFIGURATION_PATH="../${CONTAINER_PATH}/deploy"
else
    CONFIGURATION_PATH=none
fi

echo -e "\e[44mDeploying config for user container at '${CONTAINER_PATH}'...\e[0m"
echo
bash ./helpers/deploy.sh $ENVIRONMENT_NAME $CONFIGURATION_PATH $REAL_DEPLOYMENT
echo
echo -e "\e[44mDone deploying config for user container at '${CONTAINER_PATH}'.\e[0m"
