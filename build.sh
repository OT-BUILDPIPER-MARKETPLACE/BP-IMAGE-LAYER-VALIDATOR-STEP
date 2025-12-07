#!/bin/bash
source functions.sh

COMPONENT_NAME=`getComponentName`
BUILD_REPOSITORY_TAG=`getRepositoryTag`
IMAGE="${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG}"
logInfoMessage "I'll check the docker image layers for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
sleep  $SLEEP_DURATION

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    logInfoMessage " Image found locally: $IMAGE"
else
    logWarningMessage "Image not found locally. Pulling $IMAGE"
    docker pull "$IMAGE"
    if [[ $? -ne 0 ]]; then
        logErrorMessage "Failed to pull image: $IMAGE"
        exit 1
    fi
fi

LAYERS=$(docker inspect ${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG} | jq .[].RootFS.Layers | wc -l)
IMAGE_LAYER=$(expr $LAYERS - 2)

logInfoMessage "Number of Layers in image are $IMAGE_LAYER"
logInfoMessage "Number of Layers are allowed is $MAX_ALLOWED_IMAGE_LAYERS"

if [[ $IMAGE_LAYER -gt $MAX_ALLOWED_IMAGE_LAYERS ]]
then
   	generateOutput IMAGE_LAYER_VALIDATOR false "Build failed please check!!!!!"
   if [[ $VALIDATION_FAILURE_ACTION == "FAILURE" ]]
   then
        logErrorMessage "Number of layers are more then expected layers count"
        logErrorMessage "build unsucessfull"
        exit 1

   else
        logWarningMessage "Number of layers are more then expected layers count please check!!!!!"
   fi
else
        generateOutput IMAGE_LAYER_VALIDATOR true "Congratulations build succeeded!!!"
        logInfoMessage "Number of layers in docker image is  under expected layers count"
        logInfoMessage "build sucessfull"
fi
 
TASK_STATUS=$?
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
      	
     
