FROM alpine


RUN apk update && \
    apk add --no-cache --upgrade \
        bash \
        jq \
        docker-cli \
        coreutils


RUN addgroup -g 65522 buildpiper && \
    adduser -D -u 65522 -G buildpiper -h /home/buildpiper buildpiper && \
    chown -R buildpiper:buildpiper /home/buildpiper

ENV SLEEP_DURATION=5s


RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir \
        tabulate \
        cryptography

# Set environment variables to use the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

ENV DOCKER_CONFIG=/tmp/.docker
RUN mkdir -p /tmp/.docker && chmod 700 /tmp/.docker

RUN mkdir -p \
        /src/reports \
        /bp/data \
        /bp/execution_dir \
        /opt/buildpiper/shell-functions \
        /opt/buildpiper/data \
        /bp/workspace && \
    chown -R buildpiper:buildpiper /src /bp /opt /home/buildpiper/ /tmp/.docker
    
COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh

COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

RUN chmod +x /home/buildpiper/build.sh && \
    chown -R buildpiper:buildpiper /bp/workspace && \
    mkdir -p /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /home/buildpiper

USER buildpiper

WORKDIR /home/buildpiper

ENV MAX_ALLOWED_IMAGE_LAYERS 10 
ENV SLEEP_DURATION 5s
ENV VALIDATION_FAILURE_ACTION FAILURE
ENV COMPONENT_NAME BUILD_REPOSITORY_TAG
ENV ACTIVITY_SUB_TASK_CODE IMAGE_LAYER_VALIDATOR

ENTRYPOINT [ "./build.sh" ]
