#!/bin/bash


COMPONENT_NAME=`cat /bp/data/environment_build | jq -r .build_detail.repository.name`
BUILD_REPOSITORY_TAG=`cat /bp/data/environment_build | jq -r .build_detail.repository.tag`

