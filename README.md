<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [iris-kas](#iris-kas)
    - [Latest release](#latest-release)
    - [Build status](#build-status)
    - [Maintainers](#maintainers)
    - [What is KAS?](#what-is-kas)
    - [How does it work?](#how-does-it-work)
    - [Prerequisites](#prerequisites)
        - [Native Installation](#native-installation)
        - [Docker (default and recommended)](#docker-default-and-recommended)
            - [Docker and SELinux](#docker-and-selinux)
    - [Usage (general)](#usage-general)
        - [Supported environment variables](#supported-environment-variables)
    - [Usage (IRIS developers)](#usage-iris-developers)
        - [Build all images](#build-all-images)
        - [Run interactive QEMU VM](#run-interactive-qemu-vm)
        - [Update all repos](#update-all-repos)
        - [Force update all repos](#force-update-all-repos)
        - [Version pinning for thirdparty layer repositories](#version-pinning-for-thirdparty-layer-repositories)
        - [Prepare a firmware release](#prepare-a-firmware-release)
        - [Prepare a firmware support release](#prepare-a-firmware-support-release)
        - [Cleanup all artifacts](#cleanup-all-artifacts)
    - [Usage (IRIS customers)](#usage-iris-customers)
        - [Build our current base Linux distribution](#build-our-current-base-linux-distribution)
        - [Build our base Linux distribution from a source-code dump](#build-our-base-linux-distribution-from-a-source-code-dump)
    - [Running arbitrary KAS commands](#running-arbitrary-kas-commands)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# iris-kas

## Latest release
[![Latest Release](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/badges/release.svg)](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/releases)


## Build status
The current status of the develop branch is: [![develop status](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/badges/develop/pipeline.svg)](https://gitlab.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas/-/commits/develop)


## Maintainers
- Jasper Orschulko <Jasper [dot] Orschulko [att] iris-sensing.com>
- Erik Schumacher <Erik [dot] Schumacher [att] iris-sensing.com>


## What is KAS?
KAS is a bitbake wrapper developed and maintained by Siemens.
It minimises build setup steps and repository management.


## How does it work?
- The file `kas-irma6-base.yml` is the main configuration file for our custom Linux distribution and describes how KAS should prepare our build environment. It is also used to generate various config files, such as yocto's `local.conf`.
- The file `kas-irma6-pa.yml` contains the recipes and configuration for building our proprietary platform application on top of the iris Linux distribution.

## Prerequisites

### Native Installation
- [native KAS installation](https://kas.readthedocs.io/en/latest/userguide.html#dependencies-installation) on a [supported host system prepared for yocto builds](https://www.yoctoproject.org/docs/3.1/mega-manual/mega-manual.html#brief-compatible-distro)
- as IRIS developer: SSH key configured for accessing our private git repositories. If your SSH key is password protected, configure the usage of a [SSH agent](https://en.wikipedia.org/wiki/Ssh-agent) (`ssh-add /path/to/your/private/key # by default : ~/.ssh/id_xxx where xxx is the encryption algorithm`).
- for release preparation: [yq installed](https://github.com/mikefarah/yq#install)

### Docker (default and recommended)
- Linux, Mac or WSL in Windows (officially we only support Linux)
- [installed and active docker daemon](https://docs.docker.com/engine/install/), make sure the groups are [correctly set](https://docs.docker.com/engine/install/linux-postinstall/)
- installed GNU make
- as IRIS developer: SSH folder containing a SSH key configured for accessing our private git repositories, as well as a ${SSH_DIR}/known_hosts file containing our private git servers SSH signature. If your SSH key is password protected, configure the usage of a [SSH agent](https://en.wikipedia.org/wiki/Ssh-agent) (`ssh-add /path/to/your/private/key # by default : ~/.ssh/id_xxx where xxx is the encryption algorithm`).
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

## Usage (general)

### Supported environment variables

Environment variables can be passed to the make command (e.g. `RELEASE=r2 make build`).

We currently support the following variables:

| Variable    | Description                                                                                                                                                                                                        | Default value                                                                                            |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| KAS_COMMAND | The command for running the KAS executable. By default, KAS will run in a docker container (recommended). Set this to `kas` if you want to use a host installation of KAS                                          | `$(MAKEFILE_DIR)kas/kas-container --ssh-dir $(SSH_DIR) --ssh-agent` |
| SSH_DIR     | Sets the path to a directory containing an authorized SSH key (e.g.: id_rsa, id_ed25519, ...) as well as a known_hosts file containing our private git server. This path will be mounted into the docker container | `~/.ssh`                                                                                                 |
| RELEASE     | Sets the release you wish to build (currently `r1` for sc573-gen6 or `r2` for imx8mp-evk)                                                                                                                          | `r1`                                                                                                     |
| TAG         | Sets the tag to use during the release or support release process (e.g. `2.3.0`, `2.3.0-custom`)                                                                                                                   | None                                                                                                     |


**Optional variable overrides for all make commands:**
- `KAS_COMMAND`
- `SSH_DIR`

## Usage (IRIS developers)

### Build all images

Required variables:
- None

Additional, optional variable overrides:
- `RELEASE`

Commands:
- `[ENV_VARS] make build`


### Run interactive QEMU VM

*Will also expose a SSH server reachable on host machine via localhost:2222*

Required variables:
- None

**Additional, optional variable overrides:**
- `RELEASE`

Commands:
- `[ENV_VARS] make build-qemu` *(run at least 1x after initial clone, re-run regularly for updates)*
- `[ENV_VARS] make run-qemu`


### Update all repos

*Will update repos and checkout refspecs as defined in the manifest files. WARNING: Will skip dirty repos*

Required variables:
- None

Additional, optional variable overrides:
- None

Commands:
- `[ENV_VARS] make pull`


### Force update all repos

*Will force update repos and checkout refspecs as defined in the manifest files. WARNING: Will discard any uncommitted changes in repos*

Required variables:
- None

Additional, optional variable overrides:
- None

Commands:
- `[ENV_VARS] make force-pull`


### Version pinning for thirdparty layer repositories

*Will automatically set fixed commit hashes for thirdparty layer repos in kas-irma6-base-common.yml. Useful for temporary version pinning of the base software*

Required variables:
- None

Additional, optional variable overrides:
- None

Commands:
- `[ENV_VARS] make set-fixed-refspecs`


### Prepare a firmware release

*Will create a release branch, set and commit fixed refspecs in the manifest files*

Required variables:
- `TAG`

Additional, optional variable overrides:
- None

Commands:
- `[ENV_VARS] make start-release`


### Prepare a firmware support release

*Will create a support branch, set and commit fixed refspecs in the manifest files*

Required variables:
- `TAG`

Additional, optional variable overrides:
- None

Commands:
- `[ENV_VARS] make start-support`


### Cleanup all artifacts

*Will delete the content of the build directory*

Required variables:
- None

Additional, optional variable overrides:
- None

Commands:
- `[ENV_VARS] make clean`


## Usage (IRIS customers)

### Build our current base Linux distribution

*As an IRIS customer you might be interested in building our base Linux distribution, which is configured for running our proprietary platform application (not included)*

Required variables:
- None

Additional, optional variable overrides:
- `RELEASE`

Commands:
- `[ENV_VARS] make build-base`


### Build our base Linux distribution from a source-code dump

*As an IRIS customer you might want to build the base Linux image belonging to a specific firmware version using a provided source code dump*

Required variables:
- None

Additional, optional variable overrides:
- `RELEASE`

Commands:
- `[ENV_VARS] make build-base-dump`


## Running arbitrary KAS commands

In advanced use cases, it might become necessary to call KAS directly, e.g. when running custom bitbake commands.

In the case of a local KAS installation, this can be done by calling the `kas` binary directly, e.g.:

`kas shell -c "bitbake foo" kas-irma6-base-deploy.yml:kas-irma6-pa.yml`.

When using the docker based setup, use the `kas/kas-container` script instead ("[]" marks optional Variables):

`kas/kas-container [--ssh-dir <SSH_DIR>] [--ssh-agent] ...` 

For a detailed documentation on using KAS, please visit [https://kas.readthedocs.io/en/latest/](https://kas.readthedocs.io/en/latest/).
