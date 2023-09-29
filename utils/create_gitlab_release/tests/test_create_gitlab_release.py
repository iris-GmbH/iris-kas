#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (C) 2023 iris-GmbH infrared & intelligent sensors

import pytest
import pathlib
import os
import urllib
import logging
from src.create_gitlab_release import auth
from src.create_gitlab_release import run
from src.create_gitlab_release import get_conf_var_name
from src.create_gitlab_release import prepare_release_artifacts
from src.create_gitlab_release import upload_artifacts_to_registry
from gitlab import Gitlab
from gitlab.exceptions import GitlabGetError
from gitlab.v4.objects.groups import Group
from gitlab.v4.objects.projects import Project

logging.basicConfig(level=logging.DEBUG)
required_artifacts = ['deploy','dev_deploy','maintenance','dev','sdk','deploy_customer', 'kas_environment']
gitlab_url = 'http://localhost:8000'
gitlab_token = 'devtoken'
default_branch = 'main'
release_tag = '1.0.0'

@pytest.fixture(scope='module')
def authed_gitlab() -> Gitlab:
    gl = auth(gitlab_url, gitlab_token)
    gl.enable_debug()
    return gl


@pytest.fixture
def group(authed_gitlab: Gitlab, tmp_path: pathlib.Path) -> Group:
    group = authed_gitlab.groups.create(
        dict(name=tmp_path.name, path=urllib.parse.quote_plus(tmp_path.name)))
    yield group
    authed_gitlab.groups.delete(group.id)


def create_project_in_group(authed_gitlab: Gitlab, group: Group, name: str) -> Project:
    project = authed_gitlab.projects.create(
        dict(name=name, namespace_id=group.id, initialize_with_readme='true', default_branch=default_branch))
    return project


def create_test_artifact_vars(project_dir: str, conf: str, logging: logging.Logger):
  conf_var_name = get_conf_var_name(conf)
  for artifact_type in required_artifacts:
    artifact_path = os.path.join(project_dir, f'{conf_var_name}_{artifact_type}')
    logging.debug(f'artifact_path for artifact_type {artifact_type} set to {artifact_path}')
    os.environ[f'{conf_var_name}_{artifact_type}'] = artifact_path


def create_test_artifact_files(project_dir: str, conf: str, logging: logging.Logger):
  conf_var_name = get_conf_var_name(conf)
  for artifact_type in required_artifacts:
    artifact_path = os.environ[f'{conf_var_name}_{artifact_type}']
    logging.debug(f'artifact_path for conf {conf} and artifact_type {artifact_type} read as {artifact_path}')
    logging.debug(f'Creating artifact folder at {artifact_path} for conf {conf} and artifact_type {artifact_type}')
    os.makedirs(artifact_path)
    if artifact_type == 'deploy':
      deploy_dir = os.path.join(artifact_path, 'deploy')
      os.makedirs(deploy_dir)
      os.makedirs(os.path.join(deploy_dir, 'licenses'))
      subdir = os.path.join(deploy_dir, artifact_type)
      os.makedirs(subdir)
      if conf == 'sc573-gen6':
        pathlib.Path(os.path.join(subdir, 'firmware-foo.zip')).touch()
        pathlib.Path(os.path.join(subdir, 'bootloader-foo.zip')).touch()
      else:
        pathlib.Path(os.path.join(subdir, 'foo.swu')).touch()


def test_without_artifact_files(authed_gitlab: Gitlab, group: Group, tmpdir):
  confs = ['sc573-gen6']
  project_dir = tmpdir.mkdir("project_dir")
  create_test_artifact_vars(project_dir, confs[0], logging)
  project = create_project_in_group(authed_gitlab, group, 'test-project')
  project.tags.create
  with pytest.raises(FileNotFoundError):
    run(gitlab_url, gitlab_token, False, confs, 'irma6-', project_dir, project.id, project.path, release_tag, logging)
  assert len(project.packages.list()) == 0
  assert len(project.releases.list()) == 0

def test_without_release_tag(authed_gitlab: Gitlab, group: Group, tmpdir):
  confs = ['sc573-gen6']
  project_dir = tmpdir.mkdir("project_dir")
  create_test_artifact_vars(project_dir, confs[0], logging)
  create_test_artifact_files(project_dir, confs[0], logging)
  project = create_project_in_group(authed_gitlab, group, 'test-project')
  with pytest.raises(GitlabGetError, match='404: 404 Tag Not Found'):
    run(gitlab_url, gitlab_token, False, confs, 'irma6-', project_dir, project.id, project.path, release_tag, logging)
  assert len(project.packages.list()) == 0
  assert len(project.releases.list()) == 0

def test_create_gitlab_single_release(authed_gitlab: Gitlab, group: Group, tmpdir):
  confs = ['sc573-gen6']
  project_dir = tmpdir.mkdir("project_dir")
  create_test_artifact_vars(project_dir, confs[0], logging)
  create_test_artifact_files(project_dir, confs[0], logging)
  project = create_project_in_group(authed_gitlab, group, 'test-project')
  project.tags.create({'tag_name': release_tag, 'ref': default_branch})
  run(gitlab_url, gitlab_token, False, confs, 'irma6-', str(project_dir), project.id, project.path, release_tag, logging)
  package = project.packages.list()[0]
  assert len(package.package_files.list()) == len(required_artifacts) * len(confs)
  assert len(project.releases.list()) == 1

def test_create_gitlab_multi_release(authed_gitlab: Gitlab, group: Group, tmpdir):
  confs = ['sc573-gen6', 'imx8mp-irma6r2']
  project_dir = tmpdir.mkdir("project_dir")
  for conf in confs:
    create_test_artifact_vars(project_dir, conf, logging)
    create_test_artifact_files(project_dir, conf, logging)
  project = create_project_in_group(authed_gitlab, group, 'test-project')
  project.tags.create({'tag_name': release_tag, 'ref': default_branch})
  run(gitlab_url, gitlab_token, False, confs, 'irma6-', str(project_dir), project.id, project.path, release_tag, logging)
  package = project.packages.list()[0]
  assert len(package.package_files.list()) == len(required_artifacts) * len(confs)
  assert len(project.releases.list()) == 1

def test_dry_run(authed_gitlab: Gitlab, group: Group, tmpdir):
  confs = ['sc573-gen6']
  project_dir = tmpdir.mkdir("project_dir")
  create_test_artifact_vars(project_dir, confs[0], logging)
  create_test_artifact_files(project_dir, confs[0], logging)
  project = create_project_in_group(authed_gitlab, group, 'test-project')
  project.tags.create({'tag_name': release_tag, 'ref': default_branch})
  run(gitlab_url, gitlab_token, True, confs, 'irma6-', str(project_dir), project.id, project.path, release_tag, logging)
  assert len(project.packages.list()) == 0
  assert len(project.releases.list()) == 0
