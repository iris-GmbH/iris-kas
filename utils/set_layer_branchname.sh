#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 iris-GmbH infrared & intelligent sensors
#
# This script will set the refspec for iris meta-layers within the kas config files to the
# current branch of iris-kas (if existing). Meant to be called within kas for-all-repos.
# See .gitlab/develop-template.yml.

required_vars="KAS_REPO_NAME BRANCH_NAME"
for var in ${required_vars}; do
    eval val="\$${var}"
    [ -n "${val}" ] || { echo "Error: required variable ${var} not set."; exit 1; }
done

if echo "${KAS_REPO_NAME}" | grep -qvE '.*iris.*'; then
    exit 0
fi

echo "Trying to checkout ${BRANCH_NAME} in ${KAS_REPO_NAME}";
if git checkout "${BRANCH_NAME}" 2>/dev/null; then
    echo "Branch ${BRANCH_NAME} has been checked out in ${KAS_REPO_NAME}"

    # select the appropriate config file to update, depending on the layer repo name
    if [ "${KAS_REPO_NAME}" = "meta-iris" ]; then
        KAS_CONFIG_FILE="kas-irma6-pa.yml"
    else
        KAS_CONFIG_FILE="kas-irma6-base-common.yml"
    fi

    # update the refspec for the layer repo name in the appropriate kas config file
    yq ".repos.${KAS_REPO_NAME}.refspec = \"${BRANCH_NAME}\"" -i ../${KAS_CONFIG_FILE}
else
    echo "Branch ${BRANCH_NAME} not found in ${KAS_REPO_NAME}";
fi
