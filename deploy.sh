#!/bin/bash

ENVIRONMENT_NAME=$1
CONFIGURATION_PATH=$2
REAL_DEPLOYMENT=${3:-false} # Runs in "dry-run" mode unless true is explicitly passed in here.

# Exit when any command fails
set -e

# Load helper functions.
source ./helpers/formatting.sh

if [[ "$ENVIRONMENT_NAME" == "" || "$ENVIRONMENT_NAME" == "none" ]]
then
    echo_red "Environment name not specified."
    exit 1
fi

if [[ "$CONFIGURATION_PATH" == "" || "$CONFIGURATION_PATH" == "none" ]]
then
    echo_red "Configuration path not specified."
    exit 1
fi

echo_yellow "Environment is '${ENVIRONMENT_NAME}'."
echo_yellow "Configuration path is '${CONFIGURATION_PATH}'."

if [[ "$REAL_DEPLOYMENT" == "true" ]]
then
    echo_red "Carrying out full deployment (not dry run)."
else
    echo_yellow "Running in dry run mode."
    KUBECTL_DRY_RUN_ARGUMENTS="--dry-run=client"
fi

echo_boxed "Looking for kubectl..."
kubectl version --client # Don't look at server version - no connection is set up yet.

echo_boxed "Logging into Kubernetes cluster..."
source ./helpers/login.sh
echo "Done logging into Kubernetes cluster."

echo_boxed "Loading shared variables..."
source ./sharedVariables.sh
echo "Done loading shared variables."

echo_boxed "Loading deployment-specific variables..."
source ${CONFIGURATION_PATH}/variables.sh
if [[ -n "${ADDITIONAL_CONTAINER_CONFIGMAP_NAME}" ]]
then
    export ADDITIONAL_CONTAINER_IMAGE="$(kubectl get configmap -n system $ADDITIONAL_CONTAINER_CONFIGMAP_NAME -o jsonpath=''{$.data.dockerImage}'')"
    echo "Additional container image will be $ADDITIONAL_CONTAINER_IMAGE"
fi
echo "Done loading service-specific variables."

if [[ "$REAL_DEPLOYMENT" == "true" ]]
then
    echo_boxed "Running pre-deploy steps..."
    source ${CONFIGURATION_PATH}/preDeploy.sh
    echo "Done running pre-deploy steps."
else
    echo "Skipping pre-deploy steps for dry run."
fi

function deleteObject()
{
    local kind=$1
    local namespace=$2
    local name=$3

    echo_boxed "Deleting ${kind} named '${name}' in namespace '${namespace}'..."

    kubectl delete --wait=true --ignore-not-found=true $KUBECTL_DRY_RUN_ARGUMENTS $kind $name -n $namespace

    echo "Done deleting ${kind} ${name}."
}

function applyYaml()
{
    local yamlName=$1
    local yamlPath="${CONFIGURATION_PATH}/${yamlName}"

    echo_boxed "Applying ${yamlName}..."

    kubectl apply --wait=true $KUBECTL_DRY_RUN_ARGUMENTS -f <(envsubst < $yamlPath)

    if [[ "$REAL_DEPLOYMENT" == "true" ]]
    then
        local resourceType=`kubectl get -o=jsonpath='{.kind}' -f <(envsubst < $yamlPath)`

        if [[ "$resourceType" == "Deployment" || "$resourceType" == "DaemonSet" ]]
        then
            echo "Checking deployment/daemonset was applied successfully..."
            kubectl rollout status -w --timeout=${BD4BS_DEPLOYMENT_ROLLOUT_TIMEOUT} -f <(envsubst < $yamlPath)
            echo "Deployment/daemonset rollout successful."
        fi
    fi

    echo "Done applying ${yamlName}."
}

while IFS=$'\n' read object; do deleteObject $object; done < ${CONFIGURATION_PATH}/CLEAN_UP
while read yaml; do applyYaml $yaml; done < ${CONFIGURATION_PATH}/MANIFEST

if [[ "$REAL_DEPLOYMENT" == "true" ]]
then
    echo_boxed "Running post-deploy steps..."
    source ${CONFIGURATION_PATH}/postDeploy.sh
    echo "Done running post-deploy steps."
else
    echo "Skipping post-deploy steps for dry run."
fi
