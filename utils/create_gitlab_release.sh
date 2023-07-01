#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (C) 2023 iris-GmbH infrared & intelligent sensors

# This script creates a GitLab release by doing the following:
# 1. It ensures that all build artifacts for a release are available.
# 2. It creates a customer cleared archive containing the files required for updating.
# 3. It uploads the release artifacts to the GitLab package registry.
# 4. It creates a GitLab release.

set -eo pipefail

if ! command -v release-cli >/dev/null 2>&1; then
    echo "Error: release-cli binary not found. See https://gitlab.com/gitlab-org/release-cli."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq binary not found. See https://github.com/jqlang/jq."
    exit 1
fi

REQUIRED_VARS="MULTI_CONF CI_COMMIT_TAG CI_PROJECT_DIR CI_JOB_TOKEN KAS_ARTIFACT_PREFIX PACKAGE_REGISTRY_URL RELEASE_NAME RELEASE_VERSION CI_COMMIT_SHA CI_COMMIT_REF_SLUG"
for var in ${REQUIRED_VARS}; do
    if test -z "${var}"; then
        echo "Error: Required variable ${var} not set."
        exit 1
    fi
done

# translate multiconf into valid variable names
MULTI_CONF_TR="$(echo "${MULTI_CONF}" | tr '-' '_')"

# each of these variables should be defined beforehand and point to a existing artifact folder in the CI_PROJECT_DIR
REQUIRED_MULTI_CONF_RELEASE_ARTIFACT_VARS="${MULTI_CONF_TR}_deploy ${MULTI_CONF_TR}_maintenance ${MULTI_CONF_TR}_dev_deploy ${MULTI_CONF_TR}_sdk ${MULTI_CONF_TR}_dev ${MULTI_CONF_TR}_kas_environment"

echo "Verifying all necessary release artifacts are available..."
for ARTIFACT_VAR in ${REQUIRED_MULTI_CONF_RELEASE_ARTIFACT_VARS}; do
    if test -z "${!ARTIFACT_VAR}"; then
        echo "Error: Artifact variable ${ARTIFACT_VAR} not defined."
        exit 1
    fi
    if test ! -e "${CI_PROJECT_DIR}/${!ARTIFACT_VAR}"; then
        echo "Error: Artifact ${ARTIFACT_VAR} not found at ${CI_PROJECT_DIR}/${!ARTIFACT_VAR}."
        exit 1
    fi
done

# make referencing artifacts easier by removing the now unnecessary multi_conf prefix from the short variable name. e.g. sc573_gen6_deploy now becomes deploy.
REQUIRED_RELEASE_ARTIFACT_VARS=""
for var in ${REQUIRED_MULTI_CONF_RELEASE_ARTIFACT_VARS}; do
    export "${var//${MULTI_CONF_TR}_/}"="${!var}"
    REQUIRED_RELEASE_ARTIFACT_VARS="${REQUIRED_RELEASE_ARTIFACT_VARS} ${var}"
done

for ARTIFACT_VAR in ${REQUIRED_RELEASE_ARTIFACT_VARS}; do
    echo "Creating artifact archive ${!ARTIFACT_VAR}.tar.gz..."
    tar 2>&1 -czf "${!ARTIFACT_VAR}.tar.gz" "${!ARTIFACT_VAR}"
    echo "Uploading artifact archive ${!ARTIFACT_VAR}.tar.gz to GitLab package registry..."
    curl --connect-timeout 5 \
    --retry 5 \
    --retry-delay 0 \
    --retry-max-time 40 \
    --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
    --upload-file "${!ARTIFACT_VAR}.tar.gz" "${PACKAGE_REGISTRY_URL}/${CI_COMMIT_REF_SLUG}/${!ARTIFACT_VAR}.tar.gz"
done

echo "Creating customer-deploy artifact..."
deploy_customer="${KAS_ARTIFACT_PREFIX}${MULTI_CONF}-deploy-customer"
REQUIRED_RELEASE_ARTIFACT_VARS="${REQUIRED_RELEASE_ARTIFACT_VARS} deploy_customer"
# sc573-gen6 uses the legacy zip update file
if test "${MULTI_CONF}" == "sc573-gen6"; then
    if ! find "${deploy}/deploy/images/${MULTI_CONF}/update_files" -type f -name "bootloader-*" || ! find "${deploy}/deploy/images/${MULTI_CONF}/update_files" -type f -name "firmware-*" ; then
        echo "Error: Could not find update_files in ${deploy}."
        exit 1
    fi
    tar 2>&1 -czf "${deploy_customer}.tar.gz" \
        "${!ARTIFACT_VAR}/deploy/licenses" \
        "$(find "${!ARTIFACT_VAR}" -type d -name 'update_files')" \
# newer firmware uses swu.
else
    if ! find "${deploy}" -type f -name "*.swu"; then
        echo "Error: Could not find any swu file in ${deploy}."
        exit 1
    fi
    tar 2>&1 -czf "${deploy_customer}.tar.gz" \
        "${!ARTIFACT_VAR}/deploy/licenses" \
        "$(find "${!ARTIFACT_VAR}" -type f -name '*.swu')"
fi
echo "Uploading customer deploy archive ${deploy_customer}.tar.gz to GitLab package registry..."
curl --connect-timeout 5 \
--retry 5 \
--retry-delay 0 \
--retry-max-time 40 \
--header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
--upload-file "${deploy_customer}.tar.gz" "${PACKAGE_REGISTRY_URL}/${CI_COMMIT_REF_SLUG}/${deploy_customer}.tar.gz"

RELEASE_DESCRIPTION_FILE="${MULTI_CONF}-release-description.md"
echo "Creating release description file..."
cat > "${RELEASE_DESCRIPTION_FILE}" <<EOF
# Assets
## ${MULTI_CONF} (${RELEASE_NAME}-${RELEASE_VERSION})
| Asset Name | Description | Clearance |
| ---------- | ----------- | --------- |
| ${deploy} | Firmware package containing the image for initial flashing as well as update files for the production firmware (deploy). | Internal |
| ${dev_deploy} | Identical to ${deploy} but built with dev keys. Used for testing the release. Also contains copyleft sources for license compliance. | Internal |
| ${maintenance} | Firmware package containing image suitable for debugging. | Internal |
| ${dev} | Firmware package containing image suitable for developing. | Internal |
| ${sdk} | Yocto SDK used for cross-compiling. | Internal |
| ${deploy_customer} | Update package for the production firmware (deploy). | Customer |
| ${kas_environment} | Environment containing configuration files used for building copyleft software. Part of license compliance. | Customer |
EOF

ASSET_LINK=$( \
    for artifact in $REQUIRED_RELEASE_ARTIFACT_VARS; do
        jq -n \
            --arg name "${!artifact}" \
            --arg url "${PACKAGE_REGISTRY_URL}/${CI_COMMIT_REF_SLUG}/${!artifact}.tar.gz" \
            '{name: $name, url: $url}' \
    ; done \
    | jq -nc '. |= [inputs]' \
)

echo "ASSET_LINK string is ${ASSET_LINK}"

echo "Publishing release on GitLab..."
release-cli create --name "Release ${MULTI_CONF} ${CI_COMMIT_TAG}" --tag-name "${CI_COMMIT_TAG}" --ref "${CI_COMMIT_SHA}" \
    --description "${RELEASE_DESCRIPTION_FILE}" \
    --assets-link "${ASSET_LINK}"
