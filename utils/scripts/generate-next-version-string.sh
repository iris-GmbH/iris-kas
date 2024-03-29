#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 iris-GmbH infrared & intelligent sensors

set -e

usage() { echo "usage: $0:  [-p IRIS_PRODUCT] [-g GIT_WORK_DIR] [optional: -i CI_PIPELINE_ID]" 1>&2; }

while getopts p:g:i:h option
do
    case $option in
    p)  IRIS_PRODUCT="$OPTARG";;
    g)  GIT_WORK_DIR="$OPTARG";;
    i)  CI_PIPELINE_ID="$OPTARG";;
    h | ?) usage; exit 2;;
    esac
done

if test -z "${IRIS_PRODUCT}" || test -z "${GIT_WORK_DIR}"; then
    usage; exit 1;
fi

FALLBACK_SCHEMA=false
VERSION_TAG="$(git -C "${GIT_WORK_DIR}" tag -l | grep -P "^${IRIS_PRODUCT}-\d+\.\d+$" | tail -n 1)"

# Use fallback versioning if current schema not in use
if test -z "${VERSION_TAG}"; then
    FALLBACK_SCHEMA=true
    VERSION_TAG="$(git -C "${GIT_WORK_DIR}" tag -l | grep -P "^\d+\.\d+\.\d+$" | tail -n 1)"
fi
if test -z "${VERSION_TAG}"; then
    exit 1
fi

# Get patch version substring, increment and concatenate afterwards.
if ${FALLBACK_SCHEMA}; then
    MAJOR_MINOR_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 1,2)
    PATCH_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 3)
else
    PRODUCT_MAJOR_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 1)
    PATCH_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 2)
fi

NEXT_PATCH_VERSION=$((PATCH_VERSION+1))

if test -n "${CI_PIPELINE_ID}"; then
  PIPELINE_VERSION_SUFFIX="-pipeline-${CI_PIPELINE_ID}"
fi

# Keep versioning schema for output schema.
if ${FALLBACK_SCHEMA}; then
    echo "${MAJOR_MINOR_VERSION}.${NEXT_PATCH_VERSION}${PIPELINE_VERSION_SUFFIX}-dev"    
else
    echo "${PRODUCT_MAJOR_VERSION}.${NEXT_PATCH_VERSION}${PIPELINE_VERSION_SUFFIX}-dev"
fi
