#!/usr/bin/env bash

set -euo pipefail

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source ./login.sh

# ---------------------------------------------------------------
# 🔧 CONFIG
# ---------------------------------------------------------------
COMPONENT_NAME=$(getComponentName)
BUILD_REPOSITORY_TAG=$(getRepositoryTag)
IMAGE="${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG}"

MAX_LAYERS="${MAX_ALLOWED_IMAGE_LAYERS:-20}"
VALIDATION_ACTION="${VALIDATION_FAILURE_ACTION:-FAILURE}"

logInfoMessage "> Starting step: image_layer_validator"
logInfoMessage "> Target image : ${IMAGE}"
logInfoMessage "> Max allowed  : ${MAX_LAYERS} layers"

add_event "INITIALIZATION" "Successful" \
    "Image layer validation initialized" \
    "Image: ${IMAGE} | Max allowed: ${MAX_LAYERS} layers"

sleep "${SLEEP_DURATION:-0}"

# ---------------------------------------------------------------
# 🔐 LOGIN
# ---------------------------------------------------------------
logInfoMessage "> Logging into registry"
login_all_registries

# ---------------------------------------------------------------
# 📦 FETCH MANIFEST
# ---------------------------------------------------------------
logInfoMessage "> Fetching image manifest..."

MANIFEST_RAW=$(skopeo inspect --raw "docker://${IMAGE}" 2>/dev/null || true)

if [[ -z "$MANIFEST_RAW" ]]; then
    logErrorMessage "> Failed to fetch manifest"
    add_event "IMAGE_FETCH_FAILED" "Failed" \
        "Could not fetch manifest" \
        "Image: ${IMAGE}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

TOTAL_LAYERS=0

# ---------------------------------------------------------------
# 🟢 MULTI-ARCH SUPPORT
# ---------------------------------------------------------------
if echo "$MANIFEST_RAW" | jq -e '.manifests' >/dev/null 2>&1; then
    logInfoMessage "> Multi-arch image detected"

    DIGESTS=$(echo "$MANIFEST_RAW" | jq -r '.manifests[].digest')

    for DIGEST in $DIGESTS; do
        logInfoMessage "> Processing digest: $DIGEST"

        CHILD_MANIFEST=$(skopeo inspect --raw "docker://${IMAGE%@*}@${DIGEST}" 2>/dev/null)

        LAYER_COUNT=$(echo "$CHILD_MANIFEST" | jq '[.layers[]] | length')

        if [[ -z "$LAYER_COUNT" || "$LAYER_COUNT" == "null" ]]; then
            logWarningMessage "> Skipping invalid manifest for $DIGEST"
            continue
        fi

        TOTAL_LAYERS=$((TOTAL_LAYERS + LAYER_COUNT))
    done

# ---------------------------------------------------------------
# 🔵 SINGLE ARCH
# ---------------------------------------------------------------
else
    logInfoMessage "> Single-arch image detected"

    TOTAL_LAYERS=$(echo "$MANIFEST_RAW" | jq '[.layers[]] | length')
fi

# ---------------------------------------------------------------
# ❌ VALIDATION: LAYER COUNT
# ---------------------------------------------------------------
if [[ -z "$TOTAL_LAYERS" || "$TOTAL_LAYERS" -eq 0 ]]; then
    logErrorMessage "> Failed to compute layer count"
    add_event "LAYER_COMPUTE_FAILED" "Failed" \
        "Unable to compute layer count" \
        "Image: ${IMAGE}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

UTILIZATION=$((TOTAL_LAYERS * 100 / MAX_LAYERS))

# ---------------------------------------------------------------
# 📊 OUTPUT
# ---------------------------------------------------------------
echo ""
echo "> Image Layer Inspection Summary"
printf '| %-28s | %-48s |\n' "Image" "${IMAGE}"
printf '| %-28s | %-48s |\n' "Layer Count" "${TOTAL_LAYERS}"
printf '| %-28s | %-48s |\n' "Max Allowed" "${MAX_LAYERS}"
printf '| %-28s | %-48s |\n' "Utilization" "${UTILIZATION}%"
echo ""

add_event "LAYER_FETCH_SUCCESS" "Successful" \
    "Layer count calculated successfully" \
    "Image: ${IMAGE} | Layers: ${TOTAL_LAYERS}"

# ---------------------------------------------------------------
# 🚦 VALIDATION
# ---------------------------------------------------------------
if [[ "$TOTAL_LAYERS" -gt "$MAX_LAYERS" ]]; then

    logWarningMessage "> Layer count ${TOTAL_LAYERS} exceeds limit ${MAX_LAYERS}"

    if [[ "$VALIDATION_ACTION" == "FAILURE" ]]; then
        add_event "LAYER_LIMIT_EXCEEDED" "Failed" \
            "Image exceeds allowed layer count" \
            "Image: ${IMAGE} | Layers: ${TOTAL_LAYERS}"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
    else
        add_event "LAYER_LIMIT_EXCEEDED_WARNING" "Warning" \
            "Layer limit exceeded but allowed" \
            "Image: ${IMAGE}"
    fi

else
    logInfoMessage "> Validation passed"

    add_event "IMAGE_LAYER_VALIDATION_PASSED" "Successful" \
        "Layer count within limit" \
        "Image: ${IMAGE} | Layers: ${TOTAL_LAYERS}"
fi

# ---------------------------------------------------------------
# ✅ COMPLETE
# ---------------------------------------------------------------
saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"