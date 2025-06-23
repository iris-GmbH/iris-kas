#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (C) 2023 iris-GmbH infrared & intelligent sensors

import os
import tarfile
import click
import shutil
import logging
import tempfile
from pathlib import Path
from gitlab import Gitlab
from gitlab.v4.objects.projects import Project
from gitlab.exceptions import GitlabGetError


def prepare_release_artifacts(multi_conf: str, project_dir: str, tmpdir: tempfile.TemporaryDirectory, kas_artifact_prefix: str, logging: logging.Logger) -> dict:
  """
  Defines required release artifacts.
  All release multi-confs must contain the artifacts 'deploy', 'dev_deploy', 'maintenance', 'dev', 'sdk-maintenance', 'sdk-deploy', 'deploy_customer' and 'kas_environment'.
  Returns an artifacts dict, which is used throughout the script for accessing relevant artifact information.
  """
  artifacts = {
    'deploy': {
      'description': 'Firmware package containing the image for initial flashing as well as update files for the production firmware (deploy).',
      'clearance': 'Internal'
    },
    'dev_deploy': {
      'description': 'Identical to deploy but built with dev keys. Used for testing the release. Also, contains copyleft sources for license compliance.',
      'clearance': 'Internal/Customer (ONLY for license compliance source code)'
    },
    'maintenance': {
      'description': 'Firmware package containing image suitable for debugging.',
      'clearance': 'Internal'
    },
    'dev': {
      'description': 'Firmware package containing image suitable for developing.',
      'clearance': 'Internal'
    },
    'sdk-maintenance': {
      'description': 'Yocto Maintenance SDK: used for cross-compiling and for core dump debugging of the maintenance firmware',
      'clearance': 'Internal'
    },
    'sdk-deploy': {
      'description': 'Yocto Deploy SDK: used for core dump debugging of the deploy firmware',
      'clearance': 'Internal'
    },
    'deploy_customer': {
      'description': 'Production Firmware - update files only.',
      'clearance': 'Customer'
    },
    'kas_environment': {
      'name': 'Environment containing configuration files used for building copyleft software. Part of license compliance.',
      'description': 'Environment containing configuration files used for building copyleft software. Part of license compliance.',
      'clearance': 'Customer'
    }
  }

  create_deploy_customer_artifact_files(multi_conf, project_dir, tmpdir, kas_artifact_prefix, logging)
  for artifact_type, _ in artifacts.items():
    artifact_path = get_artifact_path(multi_conf, project_dir, artifact_type, logging)
    artifact_archive = create_artifact_archive(artifact_path, tmpdir, logging)
    artifacts[artifact_type].update({
      'path': artifact_archive
    })
  return artifacts


def get_conf_var_name(multi_conf: str) -> str:
  """
  Translates a given multi-conf into a valid variable name by replacing "-" with "_".
  Used for constructing the appropriate environment variable key for artifact path retrieval.
  """
  # translate multi_conf into valid variable name
  return multi_conf.replace('-', '_')


def get_artifact_path(multi_conf: str, project_dir: str, artifact_type: str, logging: logging.Logger) -> str:
  """
  Retrieves the artifact path for a given multi-conf and artifact type from the approriate environment variable (previously set by CI).
  """
  conf_var_name = get_conf_var_name(multi_conf)
  try:
    artifact_path = os.path.join(project_dir, os.environ[f'{conf_var_name}_{artifact_type}'])
  except KeyError as e:
    raise KeyError(f'Missing environment variable {conf_var_name}_{artifact_type} defining the artifact path')
  logging.debug(f'Environment variable {conf_var_name}_{artifact_type} is set to {artifact_path}')
  if not os.path.exists(artifact_path):
    raise FileNotFoundError(f'Required release artifact {conf_var_name}_{artifact_type} not found at {artifact_path}')
  return artifact_path


def create_deploy_customer_artifact_files(multi_conf: str, project_dir: str, tmpdir: tempfile.TemporaryDirectory, kas_artifact_prefix: str, logging: logging.Logger) -> None:
  """
  Finds and copies customer-cleared installation files and license information from the deploy image artifacts folder into a seperate artifact folder.
  The path to the newly created artifact is stored in an environment variable (identically to the other artifact types) for later consumption.
  """
  logging.info(f'Creating deploy customer artifact files for multi-conf {multi_conf}')
  deploydir = get_artifact_path(multi_conf, project_dir, "deploy", logging)
  logging.info(f'Identifying customer deploy artifacts for multi-conf {multi_conf}')
  logging.debug(f'deploy directory for multi-conf {multi_conf} has been identified as {deploydir}')
  artifact_paths = []

  # sc573-gen6 uses the legacy zip update files
  # firmware and bootloader are seperate
  if multi_conf == "sc573-gen6":
    firmware_glob = 'firmware-*.zip'
    bootloader_glob = 'bootloader-*.zip'
    for path in Path(deploydir).rglob(bootloader_glob):
      if os.path.islink(path):
        continue
      logging.info(f'Found sc573-gen6 bootloader at path {path}')
      artifact_paths.append(path)
    for path in Path(deploydir).rglob(firmware_glob):
      if os.path.islink(path):
        continue
      logging.info(f'Found sc573-gen6 firmware at path {path}')
      artifact_paths.append(path)
    logging.debug(f'sc573-gen6 artifact_paths is {artifact_paths}')
    if len(artifact_paths) != 2:
      raise ValueError(f"Could not clearly identify firmware and bootloader update files for {multi_conf}")

  # newer releases use swupdate
  else:
    swu_glob = "*.swu"
    for path in Path(deploydir).rglob(swu_glob):
      if os.path.islink(path):
        continue
      logging.info(f'Found swu file at path {path}')
      artifact_paths.append(path)
      logging.debug(f'artifact_paths is {artifact_paths}')
    if len(artifact_paths) != 1:
      raise ValueError(f"Could not clearly identify swupdate file for {multi_conf}")

  dirname = os.path.join(tmpdir, f'{kas_artifact_prefix}{multi_conf}-deploy-customer')
  logging.info(f'Creating customer deploy artifact dir at {dirname}')
  os.mkdir(dirname)
  for path in artifact_paths:
    copy_dest = os.path.join(dirname, os.path.basename(path))
    logging.debug(f'Copying {path} to {copy_dest}')
    shutil.copyfile(path, copy_dest)
  logging.info(f'Adding license information to customer deploy artifact')
  license_src_dir = os.path.join(deploydir, 'deploy/licenses')
  license_dest_dir = os.path.join(dirname, 'licenses')
  logging.debug(f'Copying {license_src_dir} to {license_dest_dir}')
  shutil.copytree(license_src_dir, license_dest_dir, symlinks=False, ignore_dangling_symlinks=True)
  # export newly created deploy_customer artifacts as environment variable
  deploy_customer_env_var = f'{get_conf_var_name(multi_conf)}_deploy_customer'
  logging.info(f'Setting environment variable {deploy_customer_env_var} to {dirname}')
  os.environ[deploy_customer_env_var] = dirname


def create_artifact_archive(artifact_path: str, tmpdir: tempfile.TemporaryDirectory, logging: logging.Logger) -> str:
  """
  Creates an artifact archive file (tar.gz) from given path. Returns the path to the newly created archive file.
  """
  artifact_name = os.path.basename(artifact_path)
  tar_path = os.path.join(tmpdir, f'{artifact_name}.tar.gz')
  logging.info(f'Creating artifact archive {tar_path}')
  with tarfile.open(tar_path, 'w:gz') as tar:
    logging.info(f'Adding artifact {artifact_path} to artifact archive {tar_path}')
    tar.add(artifact_path)
  return tar_path


def upload_artifacts_to_registry(gl: Gitlab, artifacts: dict, gitlab_project: Project, project_name: str, release_version: str, dry_run: bool, logging: logging.Logger):
  """
  Uploads release artifacts to the Gitlab generic package registry. Ensures an appropriate release tag exists.
  """
  logging.info(f'Uploading artifacts as package {project_name} in version {release_version} to GitLab project {project_name} (ID {gitlab_project.id})')
  for artifact_type in artifacts:
    path = artifacts[artifact_type]['path']
    file_name = os.path.basename(path)
    if dry_run is False:
      logging.debug(f'Uploading artifact_type {artifact_type} at path {path} to registry')
      gitlab_project.generic_packages.upload(
        package_name = project_name,
        package_version = release_version,
        file_name = file_name,
        path = path
      )
    else:
      logging.info(f'Dry-run: Would upload {path} as file {file_name} in package {project_name} in version {release_version} to GitLab project {project_name} (ID {gitlab_project.id})')


def generate_release_description(multi_conf: str, artifacts: dict, logging: logging.Logger) -> str:
  """
  Does release description generation for given multi configs and required artifact types.
  """
  logging.info('Generating release description')
  release_description = '# Assets'
  release_description += f'\n## {multi_conf}\n | Asset Name | Description | Clearance |\n| --- | --- | --- |\n'
  for artifact_type in artifacts:
    artifact_name = os.path.basename(artifacts[artifact_type]['path'])
    artifact_description = artifacts[artifact_type]['description']
    artifact_clearance = artifacts[artifact_type]['clearance']
    release_description += f'| {artifact_name} | {artifact_description} | {artifact_clearance} |\n'
  logging.debug(f'Release description is:\n{release_description}')
  return release_description


def create_gitlab_release(multi_conf: str, artifacts: dict, gl: Gitlab, gitlab_project: Project, project_name: str, release_version: str, dry_run: bool, logging: logging.Logger):
  """
  Creates a Gitlab Release, including a generated release description and links to the release artifacts.
  """
  release_description = generate_release_description(multi_conf, artifacts, logging)
  release_configs = multi_conf
  release_name = f'Release {release_version} for {release_configs}'
  if dry_run is False:
    logging.info(f'Creating GitLab release "{release_name}" for tag {release_version} within GitLab project {project_name} (ID {gitlab_project.id})')
    release = gitlab_project.releases.create({
        'name': release_name,
        'tag_name': release_version,
        'description': release_description,
    })
  else:
    logging.info(f'Dry-run: Would create GitLab release "{release_name}" for tag {release_version} within GitLab project {project_name} (ID {gitlab_project.id})')

  for artifact_type in artifacts:
    artifact_name = os.path.basename(artifacts[artifact_type]['path'])
    artifact_url = f'{gl.api_url}/projects/{gitlab_project.id}/packages/generic/{project_name}/{release_version}/{artifact_name}'
    if dry_run is False:
      release.links.create({
          'name': artifact_name,
          'url': artifact_url
      })
    else:
      logging.info(f'Dry-run: Would create release asset link for {artifact_name} at {artifact_url}')


def auth(gitlab_server_url: str, gitlab_access_token: str) -> Gitlab:
  """
  Returns an authenticated Gitlab object for API communication.
  """
  return Gitlab(gitlab_server_url, gitlab_access_token)


def run(gitlab_server_url: str, gitlab_access_token: str, dry_run: bool, multi_conf: str, kas_artifact_prefix: str, project_dir: str, gitlab_project_id: int, release_name: str, release_version: str, logging: logging.Logger):
  gl = auth(gitlab_server_url, gitlab_access_token)
  # lazy=True to avoid actual server request via projects API, which is not covered by the CI_JOB_TOKEN permissions
  gitlab_project = gl.projects.get(gitlab_project_id, lazy=True)
  # verify release exists
  gitlab_project.tags.get(release_version)
  logging.debug(f'Gitlab Project object is {gitlab_project}')
  with tempfile.TemporaryDirectory() as tmpdir:
    artifacts = prepare_release_artifacts(multi_conf, project_dir, tmpdir, kas_artifact_prefix, logging)
    upload_artifacts_to_registry(gl, artifacts, gitlab_project, release_name, release_version, dry_run, logging)
  create_gitlab_release(multi_conf, artifacts, gl, gitlab_project, release_name, release_version, dry_run, logging)


@click.command()
@click.option('--gitlab-server-url', envvar='CI_SERVER_URL', type=str, required=True, help='The base URL of the GitLab instance, including protocol and port. For example https://gitlab.example.com:8080')
@click.option('--gitlab-access-token', type=str, required=True, help='The GitLab access token to use for API requests. Should have write access to API and registry')
@click.option('--gitlab-project-id', envvar='CI_PROJECT_ID', type=str, required=True, help='The ID of the GitLab project in which packages and releases shall be created')
@click.option('--dry-run', type=bool, default=False, help='Set to true to skip the actual uploading and releasing of artifacts')
@click.option('--multi-conf', envvar='MULTI_CONF', type=str, required=True, help='The name of the config this release is for')
@click.option('--kas-artifact-prefix', envvar='KAS_ARTIFACT_PREFIX', type=str, required=True, help='The filename prefix used when creating customer artifact files')
@click.option('--project-dir', envvar='CI_PROJECT_DIR', type=str, required=True, help='The absolute path to the folder where the raw build artifacts have been stored beforehand')
@click.option('--project-name', envvar='CI_PROJECT_NAME', type=str, required=True, help='The release name')
@click.option('--release-version', envvar='CI_COMMIT_TAG', type=str, required=True, help='The release version')
@click.option('--debug', type=bool, default=False, help='Whether to enable debug output')
def cli(gitlab_server_url: str, gitlab_access_token: str, dry_run: bool, multi_conf: str, kas_artifact_prefix: str, project_dir: str, gitlab_project_id: int, project_name: str, release_version: str, debug: bool):

  if debug is True:
    logging.basicConfig(level=logging.DEBUG)
  else:
    logging.basicConfig(level=logging.INFO)
  run(gitlab_server_url, gitlab_access_token, dry_run, multi_conf, kas_artifact_prefix, project_dir, gitlab_project_id, project_name, release_version, logging)

if __name__ == '__main__':
  cli()
