#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (C) 2023 iris-GmbH infrared & intelligent sensors

# This script creates a GitLab release by doing the following:
# 1. It ensures that all build artifacts for a release are available.
# 2. It creates a customer cleared archive containing the files required for updating.
# 3. It uploads the release artifacts to the GitLab package registry.
# 4. It creates a GitLab release.

import json
import os

required_vars=[
  "RELEASE_MULTI_CONFS",
  "CI_COMMIT_TAG",
  "CI_PROJECT_DIR",
  "CI_JOB_TOKEN",
  "KAS_ARTIFACT_PREFIX",
  "PACKAGE_REGISTRY_URL",
  "CI_COMMIT_SHA",
  "CI_COMMIT_REF_SLUG"
]

for i in required_vars:
  try:
    key = os.environ([i])
  except ValueError(f'Required environment variable {i} not defined.'):




