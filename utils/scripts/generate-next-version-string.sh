#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 iris-GmbH infrared & intelligent sensors
#
# Generate the development firmware version from the newest final or RC tag for
# a product. All fetched tags are considered, including tags on other branches;
# support releases and non-RC suffixes are ignored. An RC keeps develop on the
# same major/minor version, while a final release advances to the next minor.
#
# Minor-release example:
#   Latest tag: irma6r2-6.2-13
#     -> develop version: irma6r2-6.3-dev
#   Latest tag: irma6r2-6.3-14-RC1
#     -> develop stays on: irma6r2-6.3-dev
#   Latest tag: irma6r2-6.3-14
#     -> develop advances to: irma6r2-6.4-dev
#
# Major-release example:
#   Latest tag: irma6r2-6.2-13
#     -> develop version: irma6r2-6.3-dev (the next major is not known yet)
#   Latest tag: irma6r2-7.0-15-RC1
#     -> develop moves to: irma6r2-7.0-dev
#   Latest tag: irma6r2-7.0-15
#     -> develop advances to: irma6r2-7.1-dev

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
  echo "Error: Malformed command: $0 $@" >&2
  usage; exit 1;
fi

# Use the latest final or release candidate tag matching the product. Search all
# fetched tags so that RCs created on a separate release branch are considered.
VERSION_TAGS="$(git -C "${GIT_WORK_DIR}" tag -l --sort=-version:refname | grep -P "^${IRIS_PRODUCT}-\d+\.\d+-\d+(-RC\d+)?$" || true)"
VERSION_TAG="$(echo "${VERSION_TAGS}" | head -n 1)"

# if version tag is not set, this is a new, unreleased product
if test -z "${VERSION_TAG}"; then
  VERSION_TAG="${IRIS_PRODUCT}-0.0-1"
  VERSION_TAGS="${VERSION_TAG}"
fi

PRODUCT_MAJOR_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 1)
PATCH_VERSION=$(echo "${VERSION_TAG}" | cut -d '.' -f 2 | cut -d '-' -f 1)

# A final release advances develop to the next minor version. An RC keeps
# develop on the RC's minor version. Prefer a final release when both tag forms
# exist for the same version.
FINAL_VERSION_TAG=$(echo "${VERSION_TAG}" | sed -E 's/-RC[0-9]+$//')
if echo "${VERSION_TAGS}" | grep -Fqx "${FINAL_VERSION_TAG}"; then
  NEXT_PATCH_VERSION=$((PATCH_VERSION+1))
else
  NEXT_PATCH_VERSION=${PATCH_VERSION}
fi

if test -n "${CI_PIPELINE_ID}"; then
  PIPELINE_VERSION_SUFFIX="-pipeline_${CI_PIPELINE_ID}"
fi
PRODUCT_VERSION="${PRODUCT_MAJOR_VERSION}.${NEXT_PATCH_VERSION}-dev${PIPELINE_VERSION_SUFFIX}"
echo "Product version is set to ${PRODUCT_VERSION}" >&2
echo "${PRODUCT_VERSION}"
