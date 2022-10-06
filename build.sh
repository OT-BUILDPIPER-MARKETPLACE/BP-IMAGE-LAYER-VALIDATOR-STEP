#!/bin/bash
source functions.sh

COMPONENT_NAME=`cat /bp/data/environment_build | jq -r .build_detail.repository.name`
BUILD_REPOSITORY_TAG=`cat /bp/data/environment_build | jq -r .build_detail.repository.tag`

echo "I'll check the docker image layers for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
sleep  $SLEEP_DURATION

LAYERS=$(docker inspect ${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG} | jq .[].RootFS.Layers | wc -l)
IMAGE_LAYER=$(expr $LAYERS - 2)

echo "Number of Layers in image are $IMAGE_LAYER"
echo "Number of Layers are allowed is $MAX_ALLOWED_IMAGE_LAYERS"

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

