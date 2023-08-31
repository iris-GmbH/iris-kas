<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [iris-kas](#iris-kas)
  - [Latest release](#latest-release)
  - [Build status](#build-status)
  - [What is KAS?](#what-is-kas)
  - [How does it work?](#how-does-it-work)
  - [Prerequisites](#prerequisites)
    - [Docker (default and recommended)](#docker-default-and-recommended)
      - [Docker and SELinux](#docker-and-selinux)
    - [Native Installation](#native-installation)
  - [Usage](#usage)
    - [Running a build (make kas-build)](#running-a-build-make-kas-build)
    - [Updating layer repositories](#updating-layer-repositories)
    - [Creating a release](#creating-a-release)
    - [Advanced use-cases](#advanced-use-cases)
      - [Building the irma6-base image](#building-the-irma6-base-image)
      - [Running arbitrary commands in the KAS shell (make kas(-interactive)-shell)](#running-arbitrary-commands-in-the-kas-shell-make-kas-interactive-shell)
      - [Running KAS manually](#running-kas-manually)
      - [Reproducible pipeline builds](#reproducible-pipeline-builds)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# iris-kas

## Latest release
[![Latest Release](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/badges/release.svg)](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/releases)

## Build status
The current status of the develop branch is: [![develop status](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/badges/develop/pipeline.svg)](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/commits/develop)

## What is KAS?
KAS is a bitbake wrapper developed and maintained by Siemens.
It minimises build setup steps and repository management.

## How does it work?
- The file `kas-irma6-base.yml` is the main configuration file for our custom Linux distribution and describes how KAS should prepare our build environment. It is also used to generate various config files, such as yocto's `local.conf`.
- The file `kas-irma6-pa.yml` contains the recipes and configuration for building our proprietary platform application on top of the iris Linux distribution.
- Depending on the task at hand, additional include configs are used from the `include/` folder.

## Prerequisites
### Docker (default and recommended)
- Linux, Mac or WSL in Windows (officially we only support Linux)
- [installed and active docker daemon](https://docs.docker.com/engine/install/), make sure the groups are [correctly set](https://docs.docker.com/engine/install/linux-postinstall/)
- installed GNU make
- installed jq
- as IRIS developer: SSH folder containing a SSH key configured for accessing our private git repositories, as well as a ${SSH_DIR}/known_hosts file containing our private git servers SSH signature. If your SSH key is password protected, configure the usage of a [SSH agent](https://en.wikipedia.org/wiki/Ssh-agent) (`ssh-add /path/to/your/private/key # by default : ~/.ssh/id_xxx where xxx is the cryptosystem, e.g. rsa`).
- using Docker on a host with SELinux enabled requires additional steps, as described below.

#### Docker and SELinux

When running `make <command>`, the container will mount two directories of the host system. The current iris-kas directory, as well as the `SSH_DIR` defined in Makefile (`~/.ssh` by default)

To access the `SSH_DIR` from within the container, you need to apply a SELinux policy that allows `container_t` processes to read from the `~/.ssh` directory of the current user. First, install the selinux-policy-devel package, which provides the Makefile to compile custom policies.

```
$ make -f /usr/share/selinux/devel/Makefile container_read_sshdir.pp
$ sudo semodule -i container_read_sshdir.pp  # to remove run: semodule -r container_read_sshdir
```
Alternatively, if your SSH key is password protected, ensure you have configured your key for an SSH agent and apply a SELinux policy that allows `container_t` access to the ssh-agent socket.

Afterwards you can run the `make` commands as described below.

### Native Installation
- [native KAS installation](https://kas.readthedocs.io/en/latest/userguide.html#dependencies-installation) on a [supported host system prepared for yocto builds](https://www.yoctoproject.org/docs/3.1/mega-manual/mega-manual.html#brief-compatible-distro)
- as IRIS developer: SSH key configured for accessing our private git repositories. If your SSH key is password protected, configure the usage of a [SSH agent](https://en.wikipedia.org/wiki/Ssh-agent) (`ssh-add /path/to/your/private/key # by default : ~/.ssh/id_xxx where xxx is the cryptosystem, e.g. rsa`).
- for release preparation: [yq installed](https://github.com/mikefarah/yq#install)

## Usage

We recommend using the provided Makefile for running KAS commands, at it does some of the heavy lifting regarding build configuration. Makefile tasks are controlled using environment variables, which are parsed to the make command, e.g. `KAS_TARGET_RECIPE=irma6-deploy-bundle make`.

`kas-build` is the default action when calling make and corresponds to the [kas build plugin](https://kas.readthedocs.io/en/latest/userguide.html#module-kas.plugins.build). As the name implies, this plugins main usage is to build a target recipe, however by overriding the default `KAS_TASK`, the plugin can be used in a much more versatile way.

### Running a build (make kas-build)

> :warning: By default, kas will NOT update layer repositories after an initial clone. See section [Updating layer repositories](#updating-layer-repositories).

These are the basic settings for controlling kas-related make tasks and should cover most use-cases.

| VARIABLE   | DESCRIPTION | DEFAULT VALUE |
|------------|-------------|---------------|
| MULTI_CONF | Controls the used [multiconf](https://docs.yoctoproject.org/singleindex.html#building-images-for-multiple-targets-using-multiple-configurations). We use multiconfs for differentiating between the various target platforms. E.g. `sc573-gen6` corresponds to IRMA6 R1 and `imx8mp-irma6r2` corresponds to IRMA6 R2. Click [here](https://github.com/iris-GmbH/meta-iris-base/tree/develop/conf/multiconfig) for all supported multiconfigs. | `imx8mp-irma6r2` |
| KAS_TARGET_RECIPE | Defines one or more bitbake recipes to build. Common targets include `irma6-maintenance-bundle`, `irma6-deploy-bundle`, `irma6-dev-bundle` | `irma6-maintenance-bundle` |
| KAS_TASK | The bitbake task to perform. Common tasks include `build`, `populate_sdk`, `fetch`, `clean`, ... Check the Yocto docs for a more complete list. | `build` |
| SSH_DIR | Specifies the folder containing a SSH key for authenticating against iris' proprietary repositories. | `~/.ssh` |

### Updating layer repositories

You should regularly update your layer repositories, to ensure your build is working and up-to-date.

There are multiple options to update layer repositories:

1. run your make commands with the variable `KASOPTIONS=--update`. Be advised that this option will cause your builds to ignore potentially existing KAS lock files.
2. run `make kas-update`, which will do a one-time update of layer repositories. Note, that this skip repositories with uncommitted changes and will remove locally committed but not pushed changes on the specified branch (use `git reflog` to restore).
3. run `make kas-force-update`, which will do a one-time update of layer repositories, discarding any changes that are uncommitted or locally committed but not pushed.

### Running an interactive KAS shell (make kas-shell)

You can start an interactive shell within the KAS/bitbake build environment by running `make kas-shell`.

### Creating a release

> :information_source: Before creating a release in iris-kas, ensure you have appropriate releases in meta-iris(-base) layer repositories.

1. Ensure your develop branch is up-to-date: `git checkout develop && git pull --ff-only`
2. Create a release or support branch, branching of the current develop (e.g. `release/3.0.0`, `support/3.0.0-support-suffix`): `git checkout -b release/3.0.0`
3. Run `make prepare-release`, which will force-update layer repositories, checkout the master branch on meta-iris(-base) layer repositories and create a KAS lock file `kas-irma6-base.lock.yml`.
4. Verify the content of the lock file. If you are doing a support release on the meta-iris(-base) repositories, manually update the commit hashes in the lock file appropriately.
5. create a commit: `git commit -m "Prepare release <RELEASE_VERSION>"`
6. create a commit tag: `git tag <RELEASE_VERSION>`
7. Push commit and commit tag to remote: `git push && git push --tags`
8. Wait for the automatically triggered GitLab release pipeline to reach the manually triggerable `set-release-multi-confs` job. The pipeline will now be in a "blocked" state, waiting for user input. If you plan to release for a single multi-conf (e.g. sc573-gen6), you may now override the variable `RELEASE_MULTI_CONFS` (by default this variable is set to `imx8mp-irma6r2 sc573-gen6`) and trigger the job. Note that due to a [limitation in GitLab
   CI](https://gitlab.com/gitlab-org/gitlab/-/issues/11549), all releases will be currently built independently of the content of `RELEASE_MULTI_CONFS`. The latter will only affect the publication of build artifacts on GitLab packages and the GitLab release page.
9. If the release build was successful run the manual `release-clean-sstate-cache` job to finalize the release pipeline.

### Advanced use-cases
#### Running arbitrary KAS commands (make kas)

In some rare cases the KAS `build` plugin might not be flexible enough for you. In these cases, you can run arbitrary KAS commands by utilizing the `make kas` command.

By default `make kas` behaves identical to `make kas-build`, however it allows for a complete override of the KAS arguments by setting the `KAS_ARGS` environment variable, e.g.:

- `KAS_ARGS="shell -c \"bitbake mc:sc573-gen6:irma6-maintenance-bundle\"" make kas`
- `KAS_ARGS="checkout" make kas`

#### Reproducible pipeline builds

We try our best to keep our builds reproducible.

For tagged releases this is ensured by verifying the existence of a kas lockfile (*.lock.yml), locking meta-layer repositories to a fixed commit.
Additionally, the generated [yocto buildhistory](https://docs.yoctoproject.org/singleindex.html#maintaining-build-output-quality) is stored together with the build artifacts.
Combining the iris-kas release commit, the lockfile and the buildhistory output, it is possible to reconstruct the complete build setup and all used package versions.

For development builds, only builds done from the trunk branch (develop) are kept reproducible, since we cannot guarantee that the git history on other branches are not rewritten.

To achieve this, each development build done in the pipeline will include the unique pipeline ID in the DISTRO_VERSION variable. Using the pipeline ID, the developer may identify the corresponding pipeline in GitLab and download the kas lockfile and buildhistory from the `trunk-build-reproducibility` job. These artifacts are kept on a best-effort basis for a maximum of 10 years.
