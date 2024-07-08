#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (C) 2024 iris-GmbH infrared & intelligent sensors

# Script run during release to check for an existing DT project /
# create a new DT project if required
# and return the projects UUID.

# requires a DependencyTrack access key with the following permissions:
# - VIEW_PORTFOLIO
# - PORTFOLIO_MANAGEMENT

set -e

usage() { echo "usage: $0: [-u DEPENDENCYTRACK_API_URL] [-p DEPENDENCYTRACK_API_KEY] [-n PROJECT_NAME] [-v PROJECT_VERSION]" >&2; }

while getopts u:p:n:v:h option
do
  case $option in
    u)  DEPENDENCYTRACK_API_URL="$OPTARG";;
    p)  DEPENDENCYTRACK_API_KEY="$OPTARG";;
    n)  PROJECT_NAME="$OPTARG";;
    v)  PROJECT_VERSION="$OPTARG";;
    h | ?) usage; exit 2;;
  esac
done

# ensure curl is available
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl not available on system" >&2
  exit 1
fi

# ensure all required variables are set
if test -z "${DEPENDENCYTRACK_API_URL}" || test -z "${DEPENDENCYTRACK_API_KEY}" || test -z "${PROJECT_NAME}" || test -z "${PROJECT_VERSION}"; then
  usage
  exit 1
fi

RESP="$(mktemp)"
# first: check if a project for this name+version already exists (e.g. this could be due to a canceled CI job)
curl \
  --connect-timeout 5 \
  --max-time 10 \
  --retry 5 \
  --retry-delay 0 \
  --retry-max-time 40 \
  -o "${RESP}" \
  -H "X-API-Key: ${DEPENDENCYTRACK_API_KEY}" \
  "${DEPENDENCYTRACK_API_URL}/v1/project/lookup?name=${PROJECT_NAME}&version=${PROJECT_VERSION}"
# attempt to assign DEPENDENCYTRACK_PROJECT to the UUID of the matching project ...
DEPENDENCYTRACK_PROJECT="$(jq -r ".uuid" < "${RESP}" 2>/dev/null)" || true
if test -n "${DEPENDENCYTRACK_PROJECT}"; then
  echo "DependencyTrack project for name \"${PROJECT_NAME}\" in version \"${PROJECT_VERSION}\" already exists. Returning its UUID." >&2
  DEPENDENCYTRACK_PROJECT="$(jq -r ".uuid" < "${RESP}")"
# ... if DEPENDENCYTRACK_PROJECT is an empty string, we presume that a matching name+version project does not yet exist
# thus we create a new project
else
  echo "DependencyTrack project for name \"${PROJECT_NAME}\" in version \"${PROJECT_VERSION}\" does not yet exist, creating a new one." >&2
  curl \
    --connect-timeout 5 \
    --max-time 10 \
    --retry 5 \
    --retry-delay 0 \
    --retry-max-time 40 \
    -o "${RESP}" \
    -s \
    -H "X-API-Key: ${DEPENDENCYTRACK_API_KEY}" \
    -X PUT \
    -H "Content-Type: application/json" \
    --data "{\"name\": \"${PROJECT_NAME}\", \"version\": \"${PROJECT_VERSION}\", \"classifier\": \"FIRMWARE\"}" \
    "${DEPENDENCYTRACK_API_URL}/v1/project"
  DEPENDENCYTRACK_PROJECT="$(jq -r ".uuid" < "${RESP}")";
fi

# return the project uuid
echo "$DEPENDENCYTRACK_PROJECT"
