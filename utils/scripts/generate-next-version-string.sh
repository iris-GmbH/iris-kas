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

# check whether a tag matching the prefix (excluding support releases) is reachable from current HEAD
VERSION_TAG="$(git -C "${GIT_WORK_DIR}" tag -l --sort=-version:refname --merged HEAD | grep -P "^${IRIS_PRODUCT}-\d+\.\d+-\d+$" | head -n 1)"

# if version tag is not set, this is a new, unreleased product
if test -z "${VERSION_TAG}"; then
  VERSION_TAG="${IRIS_PRODUCT}-0.0-1"
fi

PRODUCT_MAJOR_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 1)
PATCH_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 2 | cut -d '-' -f 1)

NEXT_PATCH_VERSION=$((PATCH_VERSION+1))

if test -n "${CI_PIPELINE_ID}"; then
  PIPELINE_VERSION_SUFFIX="-pipeline_${CI_PIPELINE_ID}"
fi

echo "${PRODUCT_MAJOR_VERSION}.${NEXT_PATCH_VERSION}-dev${PIPELINE_VERSION_SUFFIX}"
