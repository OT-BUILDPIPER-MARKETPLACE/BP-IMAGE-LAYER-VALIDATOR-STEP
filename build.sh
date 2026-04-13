#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source ./login.sh

export ACTIVITY_SUB_TASK_CODE="image_layer_validator"

COMPONENT_NAME=`getComponentName`
BUILD_REPOSITORY_TAG=`getRepositoryTag`
IMAGE="${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG}"

# Event for checking local image
add_event "IMAGE SEARCH" "Successful" \
            "Checking local availability" \
            "Image: $IMAGE"

logInfoMessage "I'll check the docker image layers for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
sleep  $SLEEP_DURATION

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    logInfoMessage " Image found locally: $IMAGE"
else
    logWarningMessage "Image not found locally. Pulling $IMAGE"
    logInfoMessage "Logging into configured registries"
    
    # Event for pulling image
    add_event "IMAGE PULL INITIATED" "Successful" \
                "Image not found locally" \
                "Pulling $IMAGE from registry"

    login_all_registries
    docker pull "$IMAGE"
    
    if [[ $? -ne 0 ]]; then
        # Event for pull failure
        add_event "IMAGE PULL FAILED" "Failed" \
                    "Failed to pull image: $IMAGE" \
                    "Check registry login or network"
        logErrorMessage "Failed to pull image: $IMAGE"
        exit 1
    fi
    
    # Event for pull success
    add_event "IMAGE PULL SUCCESS" "Successful" \
                "Image successful pull" \
                "Image: $IMAGE"
    logInfoMessage "Image successful pull $IMAGE"
fi

# Cleaner way to get layer count
IMAGE_LAYER=$(docker inspect "${IMAGE}" | jq '.[0].RootFS.Layers | length')

logInfoMessage "Number of Layers in image are $IMAGE_LAYER"
logInfoMessage "Number of Layers are allowed is $MAX_ALLOWED_IMAGE_LAYERS"

if [[ $IMAGE_LAYER -gt $MAX_ALLOWED_IMAGE_LAYERS ]]
then
    generateOutput IMAGE_LAYER_VALIDATOR false "Build failed please check!!!!!"
   if [[ $VALIDATION_FAILURE_ACTION == "FAILURE" ]]
   then
        # Event for blocking failure
        add_event "LAYER LIMIT EXCEEDED" "Failed" \
                    "Build failed: $IMAGE_LAYER layers exceeds $MAX_ALLOWED_IMAGE_LAYERS" \
                    "Optimization required for $IMAGE"
        logErrorMessage "Number of layers are more then expected layers count"
        logErrorMessage "build unsucessfull"
        exit 1
   else
        # Event for non-blocking warning
        add_event "LAYER LIMIT WARNING" "Warning" \
                    "Layer count $IMAGE_LAYER is high" \
                    "Proceeding as per VALIDATION_FAILURE_ACTION"
        logWarningMessage "Number of layers are more then expected layers count please check!!!!!"
   fi
else
        # Event for success
        add_event "LAYER LIMIT PASSED" "Successful" \
                    "Image layer count is under limit" \
                    "Count: $IMAGE_LAYER | Limit: $MAX_ALLOWED_IMAGE_LAYERS"
        generateOutput IMAGE_LAYER_VALIDATOR true "Congratulations build succeeded!!!"
        logInfoMessage "Number of layers in docker image is  under expected layers count"
        logInfoMessage "build sucessfull"
fi
 
TASK_STATUS=$?
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}