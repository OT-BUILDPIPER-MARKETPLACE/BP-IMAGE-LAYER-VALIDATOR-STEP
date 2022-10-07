FROM alpine
RUN apk add --no-cache --upgrade bash
RUN apk add jq
RUN apk add docker-cli
COPY build.sh . 
RUN chmod +x build.sh
COPY BP-BASE-SHELL-STEPS/functions.sh . 
ENV MAX_ALLOWED_IMAGE_LAYERS 10 
ENV SLEEP_DURATION 5s
ENV COMPONENT_NAME BUILD_REPOSITORY_TAG
ENV ACTIVITY_SUB_TASK_CODE IMAGE_LAYER_VALIDATOR
ENTRYPOINT [ "./build.sh" ]

