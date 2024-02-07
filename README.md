<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [iris-kas](#iris-kas)
  - [Latest release](#latest-release)
  - [Build status](#build-status)
  - [What is KAS?](#what-is-kas)
  - [What does this repository contain?](#what-does-this-repository-contain)
  - [Prerequisites](#prerequisites)
    - [Docker (default and recommended)](#docker-default-and-recommended)
      - [Docker and SELinux](#docker-and-selinux)
    - [Native Installation](#native-installation)
  - [Usage (make)](#usage-make)
    - [Running a build (make kas-build)](#running-a-build-make-kas-build)
    - [Updating layer repositories](#updating-layer-repositories)
    - [Running an interactive KAS shell (make kas-shell)](#running-an-interactive-kas-shell-make-kas-shell)
    - [Creating a Release](#creating-a-release)
    - [Advanced use-cases](#advanced-use-cases)
      - [Running arbitrary KAS commands (make kas)](#running-arbitrary-kas-commands-make-kas)
      - [Reproducible builds](#reproducible-builds)
        - [Reproducing a release build](#reproducing-a-release-build)
        - [Preparing a develop build for reproducibility](#preparing-a-develop-build-for-reproducibility)
          - [Local build](#local-build)
          - [CI build](#ci-build)
          - [Working with the KAS lock file](#working-with-the-kas-lock-file)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# iris-kas

## Latest release
[![Latest Release](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/badges/release.svg)](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/releases)

## Build status
The current status of the develop branch is: [![develop status](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/badges/develop/pipeline.svg)](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/commits/develop)

## What is KAS?
[KAS](https://github.com/siemens/kas) is a bitbake wrapper tool developed and maintained by Siemens. It drastically improves automation capability and flexibility of bitbake based projects.

Amongst others things, we use KAS to:

1. Minimize setup steps for getting a build configured and running.
2. Dynamically load configuration files into our bitbake jobs.
3. Modify third-party layers in a minimally invasiv fashion by using patch files.

See the [KAS documentation](https://kas.readthedocs.io) for further details on the KAS project.

## What does this repository contain?
This repository contains:

1. KAS configuration files used for defining our various workflows. Especially noteworthy is the `kas-irma6-base.yml` file, which is the main configuration file and provides the minimal steps for building our custom Linux distribution based on Yocto Poky. In addition, the `kas-irma6-pa.yml` can optionally be included for installing our proprietary components on top. Lastly, various additional KAS configuration files can be dynamically included from `include/` to provide additional configurations (mostly useful for specific CI or Makefile jobs).
2. Dockerfile `Dockerfile_iris_kas` defining the build container image, including the kas binary, as well as any other required tooling.
3. Dockerfile `Dockerfile_sdk`, which is used by CI to build a containerized SDK runtime environment.
4. Automation scripts and tooling, most noteworthy the GitLab CI configuration in `.gitlab-ci.yml`, as well as support tooling in the `utils` folder.
5. A `Makefile` that does additionally wrapping around the KAS tooling, for simplifying the usage for our developers.

## Prerequisites
> :information_source: iris-employees: When using the development VM you may directly jump to [Usage (make)](#usage-make), as all prerequisites have been taken care of for you.

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

## Usage (make)

Clone this project into your local workspace and navigate to the top-level directory of this project.

If you plan on building anything other than the latest developmental state, make sure to adjust the meta-layer repositories according to your needs. Usually this means adjusting the referenced branch name for the `meta-iris-base` (see `kas-irma6-base.yml`) or `meta-iris` (see `kas-irma6-pa.yml`) repositories according to your used branch names within these repositories.

For starting the build, we recommend using the provided Makefile for running KAS commands, at it does some of the heavy lifting regarding build configuration. Makefile tasks are controlled using environment variables, which are parsed to the make command, e.g. `KAS_TARGET_RECIPE=irma6-deploy-bundle make`.

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

For example `MULTI_CONF=sc573-gen6 KAS_TARGET_RECIPE=irma6-deploy-bundle make` will build the deploy bundle for the IRMA6 R1 target.

### Updating layer repositories

You should regularly update your layer repositories, to ensure your build is working and up-to-date.

There are multiple options to update layer repositories:

1. run your make commands with the variable `KASOPTIONS=--update`. Be advised that this option will cause your builds to ignore potentially existing KAS lock files.
2. run `make kas-update`, which will do a one-time update of layer repositories. Note, that this skip repositories with uncommitted changes and will remove locally committed but not pushed changes on the specified branch (use `git reflog` to restore).
3. run `make kas-force-update`, which will do a one-time update of layer repositories, discarding any changes that are uncommitted or locally committed but not pushed.

### Running an interactive KAS shell (make kas-shell)

You can start an interactive shell within the KAS/bitbake build environment by running `make kas-shell`.

Note, that the interactive shell is always limited to the configured `MULTI_CONF`. For example, if you intend to start an interactive shell for the IRMA6 R1 build environment, use the following command: `MULTI_CONF=sc573-gen6 make kas-shell`

### Creating a Release

> :information_source: Before creating a release in iris-kas, ensure you have appropriate releases in meta-iris(-base) layer repositories.

> :information_source: A release always represents a single release target (e.g. IRMA6R1 OR IRMA6R2), which is determined by the commit prefix. Currently supported commit prefixes are: `irma6r1-`, `irma6r2-`. Thus, the <RELEASE_VERSION> placeholder must match the following REGEX: `^irma6r[1-2]-\d+\.\d+\.\d+(-\w+)?$`. Click [here](https://regex101.com/r/Sq45x0/1) to easily validate your <RELEASE_VERSION> string.

1. Ensure your `iris-kas` develop branch is up-to-date: `git checkout develop && git pull --ff-only`.
2. Create a release or support branch, branching of the current develop (e.g. `release/irma6r1-3.0.0`, `support/irma6r2-3.0.0-support_suffix`): `git checkout -b release/<RELEASE_VERSION>`.
3. Run `make prepare-release`, which will force-update layer repositories, checkout the master branch on meta-iris(-base) layer repositories and create a KAS lock file `kas-irma6-base.lock.yml`.
4. Verify the content of the lock file. If you are doing a support release on the meta-iris(-base) repositories, manually update the commit hashes in the lock file appropriately.
5. create a commit: `git commit -m "Prepare release <RELEASE_VERSION>"`.
6. create a commit tag: `git tag <RELEASE_VERSION>`.
7. Push commit and commit tag to remote: `git push && git push origin <RELEASE_VERSION>`.
8. Wait for the automatically triggered pipeline to succeed.

### Advanced use-cases
#### Running arbitrary KAS commands (make kas)

In some rare cases the KAS `build` plugin might not be flexible enough for you. In these cases, you can run arbitrary KAS commands by utilizing the `make kas` command.

By default `make kas` behaves identical to `make kas-build`, however it allows for a complete override of the KAS arguments by setting the `KAS_ARGS` environment variable, e.g.:

- `KAS_ARGS="shell -c \"bitbake mc:sc573-gen6:irma6-maintenance-bundle\"" make kas`
- `KAS_ARGS="checkout" make kas`

#### Reproducible builds

> :information_source: Currently it is only possible to reproduce builds locally, not in CI. Amongst others, this is blocked by https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/merge_requests/309

We try our best to keep our builds reproducible. However, due to the nature of a floating develop HEAD split over multiple repositories, this is not a simple feat.

##### Reproducing a release build

For tagged releases, build reproducibility is ensured by verifying the existence of a kas lockfile (*.lock.yml) and locking meta-layer repositories to a fixed commit.
Additionally, the generated [yocto buildhistory](https://docs.yoctoproject.org/singleindex.html#maintaining-build-output-quality) is stored together with the build artifacts.
Combining the iris-kas release commit, the lockfile and the buildhistory output, it is possible to reconstruct the complete build setup and all used package versions.

##### Preparing a develop build for reproducibility

By default, only CI builds from the trunk branch (develop) are kept reproducible, since we cannot guarantee that the git history on other branches will not be rewritten.

Additionally, it is possible to force build-reproducibility on other branches, either for a local build or for a CI build, **however** it is up to the developer to ensure that commits on meta-layer and **all** component repositories stay available.

This means that each referenced commit in all build relevant iris repositories that is **not** part of a trunk branch during the build **must** be part of a protected branch (i.e. delete and git history rewrite protected). These branches are identified by their name prefix `fixed/`, e.g.: `fixed/jaor/DEVOPS-777_reproducible_build`. Basically you need to ensure protected branches throughout the build hierarchy.

For example, if you want to create a reproducible build of the current development state with code modifications to a component referenced in a iris-specific recipe in meta-iris:

1. Create and push a `fixed/...` branch from the trunk branch in the repository specified in the recipe containing your code changes. Note, that if your changes include updating submodule commit references to commits outside of their respective trunk branch, these commits must also be part of a `fixed/...` branch within their respective repository.
2. create and push a `fixed/...` branch from the trunk branch in meta-iris and in its respective recipe, adjust the repository version to the branch created in step #1.
3. create and push a `fixed/...` branch from the trunk branch in iris-kas and adjust the branch config for the meta-iris repository in the appropriate KAS config file to reference the branch created in step #2.

Continue to [Local build](#local-build) or [CI build](#ci-build) for starting the reproducible build.

###### Local build

> :information_source: The usefulness of a local build is mostly limited to reproducing a single build (that is the combination of **one** multi-conf and **one** target recipe), as the lock file will be specific to this build configuration. If you wish to reproduce multiple build types, use a CI build instead.

1. Create a build as described in [Running a build (make kas-build)](#running-a-build-make-kas-build).
2. Run `make kas-buildhistory-collect-srcrevs` which will generate a `*.lock.yml` file within the top-dir.
3. Commit the `*.lock.yml` to your iris-kas branch, ensuring it's availability in the future.
4. Local rebuild of the **same** build configuration will use the fixed srcrevs. **WARNING:** Using the `*.lock.yml` file for a different build configuration might not have the desired effect, due to diverging recipes.

###### CI build

1. Set the variable `REPRODUCIBLE_BUILD=true` when starting the CI build for your iris-kas branch. Also, remember to include **all** build configurations that you wish to be able to reproduce later on.
2. After the pipeline completed successfully, KAS `*.lock.yml` artifacts will be available as artifacts in the `develop-build-reproducibility` job. These artifacts are kept for 10 years within the pipeline.
3. When reproducing a build, download the `*.lock.yml` file for the desired build configuration from the pipeline.
4. Local rebuild of the **same** build target will use the fixed srcrevs. **WARNING:** Using the `*.lock.yml` file for a different build configuration might not have the desired effect, due to diverging recipes.

###### Working with the KAS lock file

The KAS `*.lock.yml` file generated during the reproducible build setup steps contains the exact git hashes for both the meta-layers, as well as the recipe components that were used at the time of building. KAS will automatically include this file if it is present next to the original configuration file at the time of running the `kas` command.

You can adjust the used source revision of one or more components simply by opening the lock file within an editor and updating the appropriate `SRCREV` value to a new valid commit. Keep in mind, that if you wish to keep the updated lock file reproducible, the same rules regarding commit availability applies to the new commits referenced by the updated commit SHAs.
