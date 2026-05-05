#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source ./login.sh

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

COMPONENT_NAME=$(getComponentName)
BUILD_REPOSITORY_TAG=$(getRepositoryTag)
IMAGE="${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG}"

# ---------------------------------------------------------------
# 1. Initialization
# ---------------------------------------------------------------
logInfoMessage "> Starting step: image_layer_validator"
logInfoMessage "> Target image : ${IMAGE}"
logInfoMessage "> Max allowed  : ${MAX_ALLOWED_IMAGE_LAYERS} layers"

add_event "INITIALIZATION" "Successful" \
    "Image layer validation initialized" \
    "Image: ${IMAGE} | Max allowed: ${MAX_ALLOWED_IMAGE_LAYERS} layers"

sleep "$SLEEP_DURATION"

# ---------------------------------------------------------------
# 2. Image Availability Check
# ---------------------------------------------------------------
logInfoMessage "> Checking if image is available locally..."

if docker image inspect "$IMAGE" > /dev/null 2>&1; then
    logInfoMessage "> Image found locally: ${IMAGE}"
    add_event "IMAGE_AVAILABILITY" "Successful" \
        "Image found in local Docker cache" \
        "Image: ${IMAGE}"
else
    logWarningMessage "> Image not found locally. Initiating pull..."
    logInfoMessage "> Logging into configured registries"

    add_event "IMAGE_PULL_INITIATED" "Successful" \
        "Image not found locally — pulling from registry" \
        "Image: ${IMAGE}"

    login_all_registries
    docker pull "$IMAGE"

    if [[ $? -ne 0 ]]; then
        logErrorMessage "> Failed to pull image ${IMAGE} from registry."
        add_event "IMAGE_PULL_FAILED" "Failed" \
            "Could not pull image from registry" \
            "Image: ${IMAGE} | Verify auth, tag, and network connectivity"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
    fi

    logInfoMessage "> Successfully pulled image: ${IMAGE}"
    add_event "IMAGE_PULL_COMPLETE" "Successful" \
        "Image pulled successfully from registry" \
        "Image: ${IMAGE}"
fi

# ---------------------------------------------------------------
# 3. Layer Inspection
# ---------------------------------------------------------------
logInfoMessage "> Inspecting image layer count..."

IMAGE_LAYER=$(docker inspect "${IMAGE}" | jq '.[0].RootFS.Layers | length')

echo ""
echo "> Image Layer Inspection Summary"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Parameter" "Value"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Image" "${IMAGE}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Actual Layer Count" "${IMAGE_LAYER}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Max Allowed Layers" "${MAX_ALLOWED_IMAGE_LAYERS}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Utilization" "$((IMAGE_LAYER * 100 / MAX_ALLOWED_IMAGE_LAYERS))% of limit"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
echo ""

logInfoMessage "> Image layer count : ${IMAGE_LAYER}"
logInfoMessage "> Allowed layer count: ${MAX_ALLOWED_IMAGE_LAYERS}"
logInfoMessage "> Utilization        : $((IMAGE_LAYER * 100 / MAX_ALLOWED_IMAGE_LAYERS))% of allowed limit"

# ---------------------------------------------------------------
# 4. Validation Result
# ---------------------------------------------------------------
if [[ "${IMAGE_LAYER}" -gt "${MAX_ALLOWED_IMAGE_LAYERS}" ]]; then

    logWarningMessage "> Image has ${IMAGE_LAYER} layers which exceeds the configured limit of ${MAX_ALLOWED_IMAGE_LAYERS}"

    generateOutput image_layer_validator false \
        "Image layer validation failed. Current layers: ${IMAGE_LAYER} exceeds allowed limit: ${MAX_ALLOWED_IMAGE_LAYERS}. Consider squashing layers or reducing RUN statements in your Dockerfile."

    if [[ "$VALIDATION_FAILURE_ACTION" == "FAILURE" ]]; then
        logErrorMessage "> Action: Blocking build (VALIDATION_FAILURE_ACTION=FAILURE)"
        add_event "LAYER_LIMIT_EXCEEDED" "Failed" \
            "Image has ${IMAGE_LAYER} layers — exceeds limit of ${MAX_ALLOWED_IMAGE_LAYERS} — build blocked" \
            "Image: ${IMAGE} | Action: FAILURE | Squash layers or reduce RUN steps to proceed"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
    else
        logWarningMessage "> Action: Proceeding with warning (VALIDATION_FAILURE_ACTION=${VALIDATION_FAILURE_ACTION})"
        add_event "LAYER_LIMIT_EXCEEDED_WARNING" "Warning" \
            "Image has ${IMAGE_LAYER} layers — exceeds limit but build is allowed to continue" \
            "Image: ${IMAGE} | Action: ${VALIDATION_FAILURE_ACTION} | Review Dockerfile layer optimization"
    fi

else
    logInfoMessage "> Validation passed: ${IMAGE_LAYER} layers is within the ${MAX_ALLOWED_IMAGE_LAYERS} layer limit"

    generateOutput image_layer_validator true \
        "Image layer validation passed. Image: ${IMAGE} | Layers: ${IMAGE_LAYER} | Build meets defined layer constraints."

    add_event "IMAGE_LAYER_VALIDATION_PASSED" "Successful" \
        "Image ${IMAGE} layer count validated successfully: ${IMAGE_LAYER} within limit of ${MAX_ALLOWED_IMAGE_LAYERS}" \
        "Utilization: $((IMAGE_LAYER * 100 / MAX_ALLOWED_IMAGE_LAYERS))% of allowed layers"

    logInfoMessage "> Build successful"
fi

sleep "$SLEEP_DURATION"
saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"