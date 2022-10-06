#!/bin/bash
source functions.sh
source function.sh

echo "I'll check the docker image layers for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
sleep  $SLEEP_DURATION

LAYERS=$(docker inspect ${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG} | jq .[].RootFS.Layers | wc -l)
IMAGE_LAYER=$(expr $LAYERS - 2)

function logInfoMessage() {
    $MESSAGE="Number of Layers in image are $IMAGE_LAYER"
    $MESSAGE1="Number of Layers are allowed is $MAX_ALLOWED_IMAGE_LAYERS"
    CURRENT_DATE=`date "+%D: %T"`
    echo "[$CURRENT_DATE] [INFO] $MESSAGE"
    echo "[$CURRENT_DATE] [INFO] $MESSAGE1"
}

logInfoMessage 

if [[ $IMAGE_LAYER -gt $MAX_ALLOWED_IMAGE_LAYERS ]]
then
   	generateOutput IMAGE_LAYER_VALIDATOR false "Build failed please check!!!!!"
        echo "Number of layers are more then expected layers count"
        echo "build unsucessfull"
        exit 1
else
	generateOutput IMAGE_LAYER_VALIDATOR true "Congratulations build succeeded!!!"
	echo "Number of layers in docker image is  under expected layers count"
	echo "build sucessfull"
fi

