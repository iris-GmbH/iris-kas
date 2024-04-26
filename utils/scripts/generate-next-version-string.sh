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
if test -n "${VERSION_TAG}"; then
  FALLBACK_SCHEMA=false
# else fallback to old version schema
else
  VERSION_TAG="$(git -C "${GIT_WORK_DIR}" tag -l --sort=-version:refname --merged HEAD | grep -P "^\d+\.\d+\.\d+$" | head -n 1)"
  FALLBACK_SCHEMA=true
fi

if test -z "${VERSION_TAG}"; then
  echo "Could not determinate next version tag" >&2
  exit 1
fi

if ${FALLBACK_SCHEMA}; then
  PRODUCT_MAJOR_VERSION=${IRIS_PRODUCT}-$(echo "${VERSION_TAG}" | cut -d '.' -f 1)
  PATCH_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 2)
else
  PRODUCT_MAJOR_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 1)
  PATCH_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 2 | cut -d '-' -f 1)
fi

NEXT_PATCH_VERSION=$((PATCH_VERSION+1))

if test -n "${CI_PIPELINE_ID}"; then
  PIPELINE_VERSION_SUFFIX="-pipeline_${CI_PIPELINE_ID}"
fi

echo "${PRODUCT_MAJOR_VERSION}.${NEXT_PATCH_VERSION}-dev${PIPELINE_VERSION_SUFFIX}"
