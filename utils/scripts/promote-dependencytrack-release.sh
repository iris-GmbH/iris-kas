#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (C) 2026 iris-GmbH infrared & intelligent sensors

set -e

usage() {
  echo "usage: $0 -u DEPENDENCYTRACK_API_URL -k DEPENDENCYTRACK_API_KEY -d DEVELOP_PROJECT_UUID -n PROJECT_NAME -v PROJECT_VERSION -t TAG_NAME" >&2
}

while getopts u:k:d:n:v:t:h option
do
  case "${option}" in
    u) DEPENDENCYTRACK_API_URL="${OPTARG}" ;;
    k) DEPENDENCYTRACK_API_KEY="${OPTARG}" ;;
    d) DEVELOP_PROJECT_UUID="${OPTARG}" ;;
    n) PROJECT_NAME="${OPTARG}" ;;
    v) PROJECT_VERSION="${OPTARG}" ;;
    t) TAG_NAME="${OPTARG}" ;;
    h | *) usage; exit 2 ;;
  esac
done

if test -z "${DEPENDENCYTRACK_API_URL}" || \
   test -z "${DEPENDENCYTRACK_API_KEY}" || \
   test -z "${DEVELOP_PROJECT_UUID}" || \
   test -z "${PROJECT_NAME}" || \
   test -z "${PROJECT_VERSION}" || \
   test -z "${TAG_NAME}"; then
  usage
  exit 1
fi

for tool in curl jq
do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Error: ${tool} not available on system" >&2
    exit 1
  fi
done

RESP="$(mktemp)"
trap 'rm -f "${RESP}"' EXIT

TAG_API_URL="${DEPENDENCYTRACK_API_URL}/v1/tag/${TAG_NAME}/project"
request() {
  curl --fail-with-body --silent --show-error \
    -H "X-API-Key: ${DEPENDENCYTRACK_API_KEY}" "$@"
}

request --get \
  --data-urlencode "name=${PROJECT_NAME}" \
  --data-urlencode "version=${PROJECT_VERSION}" \
  "${DEPENDENCYTRACK_API_URL}/v1/project/lookup" -o "${RESP}"
RELEASE_PROJECT_UUID="$(jq -er '.uuid | select(type == "string" and length > 0)' "${RESP}")"

# Ensure that both the develop and new release projects carry the tag first.
PROJECTS="$(jq -cn --arg develop "${DEVELOP_PROJECT_UUID}" --arg release "${RELEASE_PROJECT_UUID}" '[ $develop, $release ] | unique')"
request -X POST -H 'Content-Type: application/json' --data "${PROJECTS}" "${TAG_API_URL}" -o /dev/null

request "${TAG_API_URL}?pageSize=1000" -o "${RESP}"
OLD_RELEASES="$(jq -ce --arg develop "${DEVELOP_PROJECT_UUID}" --arg release "${RELEASE_PROJECT_UUID}" \
  '[.[] | select(.uuid != $develop and .uuid != $release) | .uuid]' "${RESP}")"

if test "${OLD_RELEASES}" != '[]'; then
  request -X DELETE -H 'Content-Type: application/json' --data "${OLD_RELEASES}" "${TAG_API_URL}" -o /dev/null
fi

echo "DependencyTrack tag ${TAG_NAME} now identifies develop and release ${RELEASE_PROJECT_UUID}." >&2
