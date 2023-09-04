#!/usr/bin/env python3
import os
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 iris-GmbH infrared & intelligent sensors

# This script creates a GitLab release by doing the following:
# 1. It ensures that all build artifacts for a release are available.
# 2. It creates a customer cleared archive containing the files required for updating.
# 3. It uploads the release artifacts to the GitLab package registry.
# 4. It creates a GitLab release.

import shutil
import argparse
import subprocess
from os.path import exists

VALID_RELEASE_MULTI_CONFS = "sc573-gen6 imx8mp-irma6r2"
RELEASE_DESCRIPTION_FILE = "release-description.md"


def export_config_environments(config):
    if config == 'sc573-gen6':
        release_name = 'IRMA6'
        release_version = 'r1'
    elif config == 'imx8mp-irma6r2':
        release_name = 'IRMA6'
        release_version = 'r2'
    else:
      raise TypeError('Could not identify release from multi_conf {0}'.format(config))
    os.environ['RELEASE_NAME'] = release_name
    os.environ['RELEASE_VERSION'] = release_version


parser = argparse.ArgumentParser()
parser.add_argument('RELEASE_MULTI_CONFS', required=True)
parser.add_argument('CI_COMMIT_TAG', required=True)
parser.add_argument('CI_PROJECT_DIR', required=True)
parser.add_argument('CI_JOB_TOKEN', required=True)
parser.add_argument('KAS_ARTIFACT_PREFIX', required=True)
parser.add_argument('PACKAGE_REGISTRY_URL', required=True)
parser.add_argument('CI_COMMIT_SHA', required=True)
parser.add_argument('CI_COMMIT_REF_SLUG', required=True)

args = parser.parse_args()

# Check dependencies
if shutil.which('release-cli') is None:
    raise OSError('Error: release-cli binary not found. See https://gitlab.com/gitlab-org/release-cli.')
if shutil.which('jq') is None:
    raise OSError('Error: jq binary not found. See https://github.com/jqlang/jq.')

print('# Assets" > "{0}'.format(RELEASE_DESCRIPTION_FILE))

# test that all provided RELEASE_MULTI_CONFS are valid and that all required artifacts are available
for conf in args.RELEASE_MULTI_CONFS.split():
    if conf not in VALID_RELEASE_MULTI_CONFS:
        raise TypeError('Provided RELEASE_MULTI_CONF {0} is not associated with any release. Valid values '
                        'include:\n{1}'.format(conf, VALID_RELEASE_MULTI_CONFS))

    # translate conf into valid variable name
    confVarName = conf.replace('-', '_')

    # each of these variables should be defined beforehand and point to a existing artifact folder in the CI_PROJECT_DIR
    requiredConfReleaseArtifacts = ("{0}_deploy {0}_maintenance {0}_dev_deploy {0}_sdk {0}_dev {0}_kas_environment"
                                    .format(confVarName))

    print('Verifying that all necessary release artifacts for {0} are available...'.format(conf))
    for artifact in requiredConfReleaseArtifacts.split():
        if not exists('{0}/{1}'.format(args.CI_PROJECT_DIR, artifact)):
            raise RuntimeError('Error: Artifact ${0} not found at ${1}/${0}.'.format(artifact, args.CI_PROJECT_DIR))

    # identify and export release environment vars from MULTI_CONF
    export_config_environments(conf)

    # make referencing artifacts easier by removing the now unnecessary multi_conf prefix from the short variable
    # name. e.g. $sc573_gen6_deploy now becomes $deploy.
    requiredReleaseArtifacts = ''
    for artifact in requiredConfReleaseArtifacts.split():
        # add environment variable without config prefix
        os.environ[artifact.replace(conf, '')] = artifact

        requiredReleaseArtifacts += '{0} '.format(artifact)

        print('Creating artifact archive {0}.tar.gz...'.format(artifact))
        subprocess.run(['tar', '2>&1', '-czf', '{0}.tar.gz'.format(artifact), artifact], shell=True, check=True)
        print('Uploading artifact archive {0}.tar.gz to GitLab package registry...'.format(artifact))
        subprocess.run(['curl', '--retry 5', '--retry-delay 0', '--retry-max-time 40', '--header', '"JOB-TOKEN: {0}"'.format(args.CI_JOB_TOKEN), '--upload-file', '"{0}.tar.gz" "{1}/{2}/{0}.tar.gz"'.format(artifact, args.PACKAGE_REGISTRY_URL, args.CI_COMMIT_REF_SLUG)], shell=True, check=True)

    print('Creating customer-deploy artifact...')
    deployCustomer = '${0}{1}-deploy-customer'.format(args.KAS_ARTIFACT_PREFIX, conf)
    requiredReleaseArtifacts += 'deploy_customer'

    # sc573-gen6 uses the legacy zip update file

