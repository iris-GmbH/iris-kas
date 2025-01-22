#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 iris-GmbH infrared & intelligent sensors

set -e

usage() {
  echo "usage: ${0}:  [-u DEPENDENCYTRACK_API_URL] [-k DEPENDENCYTRACK_API_KEY] [-p EXISTING_DEPENDENCYTRACK_PROJECT_ID] [-b PATH_TO_CYCLONEDX_SBOM] [optional: -v PATH_TO_CYCLONEDX_VEX -t BOM_PROCESSING_TIMEOUT]" 1>&2;
}

while getopts u:k:p:b:p:v:t:h option
do
  case ${option} in
    u)  DEPENDENCYTRACK_API_URL="${OPTARG}";;
    k)  DEPENDENCYTRACK_API_KEY="${OPTARG}";;
    p)  EXISTING_DEPENDENCYTRACK_PROJECT_ID="${OPTARG}";;
    b)  PATH_TO_CYCLONEDX_SBOM="${OPTARG}";;
    v)  PATH_TO_CYCLONEDX_VEX="${OPTARG}";;
    t)  BOM_PROCESSING_TIMEOUT=${OPTARG};;
    h | ?) usage; exit 2;;
  esac
done

if test -z "${DEPENDENCYTRACK_API_URL}" || \
   test -z "${DEPENDENCYTRACK_API_KEY}" || \
   test -z "${PATH_TO_CYCLONEDX_SBOM}" || \
   test -z "${EXISTING_DEPENDENCYTRACK_PROJECT_ID}"; then
    usage; exit 1;
fi

if ! command -v curl >/dev/null; then
  echo "Error: curl not installed." >&2; exit 1;
fi
if ! command -v jq >/dev/null; then
  echo "Error: jq not installed." >&2; exit 1;
fi

echo "Determinating DependencyTrack version." >&2
resp=$(mktemp)
curl \
  -sS \
  -o "${resp}" \
  "${DEPENDENCYTRACK_API_URL}/version"

dt_version="$(jq -r '.version' "${resp}")"
if test -n "${dt_version}"; then
  echo "DependencyTrack version is ${dt_version}." >&2
else
  echo "Error Determinating DependencyTrack Version." >&2
  exit 1
fi

# /token/{uuid} api endpoint has been deprecated in 4.11.0
if [ "$(echo "${dt_version} " | sort -V | head -n1)" != "4.11.0" ]; then
  token_api_url="${DEPENDENCYTRACK_API_URL}/v1/event/token"
else
  token_api_url="${DEPENDENCYTRACK_API_URL}/v1/bom/token"
fi
sbom_api_url="${DEPENDENCYTRACK_API_URL}/v1/bom"
vex_api_url="${DEPENDENCYTRACK_API_URL}/v1/vex"

echo "Uploading BOM ${PATH_TO_CYCLONEDX_SBOM} to project ${EXISTING_DEPENDENCYTRACK_PROJECT_ID}." >&2
curl \
  -sS \
  -H "X-API-Key: ${DEPENDENCYTRACK_API_KEY}" \
  -X POST \
  -F project="${EXISTING_DEPENDENCYTRACK_PROJECT_ID}" \
  -F bom=@"${PATH_TO_CYCLONEDX_SBOM}" \
  -o "${resp}" \
  "${sbom_api_url}"

token="$(jq -r '.token' "${resp}")"
if test -n "${token}"; then
  echo "BOM uploaded successfully." >&2
else
  echo "Error uploading BOM file." >&2
  exit 1
fi

if test -z "${PATH_TO_CYCLONEDX_VEX}"; then
  echo "No VEX file specified. Done." >&2
  exit 0;
fi

if test -z "${BOM_PROCESSING_TIMEOUT}"; then
  BOM_PROCESSING_TIMEOUT=300
fi
printf "Waiting for BOM to be processed (timeout: %ss) ..." "${BOM_PROCESSING_TIMEOUT}" >&2
timeout=0
while true; do
  sleep 1
  timeout=$((timeout+1))
  curl \
    -sS \
    -H "X-API-Key: ${DEPENDENCYTRACK_API_KEY}" \
    -H  "accept: application/json" \
    -o "${resp}" \
    "${token_api_url}/${token}"
  if [ "$(jq -r '.processing' "${resp}")" = "false" ]; then
    printf "\nCompleted processing BOM.\n" >&2
    break
  fi
  if [ "${timeout}" -eq "${BOM_PROCESSING_TIMEOUT}" ]; then
    echo "Error: Timeout ${BOM_PROCESSING_TIMEOUT} reached while processing BOM for uploading VEX." >&2
    exit 1
  fi
  printf "." >&2
done

echo "Uploading VEX ${PATH_TO_CYCLONEDX_VEX} to project ${EXISTING_DEPENDENCYTRACK_PROJECT_ID}." >&2
curl \
  -sS \
  -H "X-API-Key: ${DEPENDENCYTRACK_API_KEY}" \
  -X POST \
  -F project="${EXISTING_DEPENDENCYTRACK_PROJECT_ID}" \
  -F vex=@"${PATH_TO_CYCLONEDX_VEX}" \
  "${vex_api_url}"
echo "Done." >&2
