# iris-kas

## Maintainers
- Jasper Orschulko <Jasper [dot] Orschulko [att] iris-sensing.com>
- Erik Schumacher <Erik [dot] Schumacher [att] iris-sensing.com>


## What is KAS?
KAS is a bitbake wrapper developed and maintained by Siemens.
It minimises build setup steps and repository management.


## How does it work?
- The file `kas-irma6-base.yml` is the main configuration file for our custom Linux distribution and describes how KAS should prepare our build environment. It is also used to generate various config files, such as yocto's `local.conf`.
- The file `kas-irma6-pa.yml` contains the recipes and configuration for building our proprietary platform application on top of the iris Linux distribution.

For a detailed documentation on KAS, please visit [https://kas.readthedocs.io/en/latest/](https://kas.readthedocs.io/en/latest/)

## Prerequisites

### Native Installation
- [native KAS installation](https://kas.readthedocs.io/en/latest/userguide.html#dependencies-installation) on a [supported host system prepared for yocto builds](https://www.yoctoproject.org/docs/3.1/mega-manual/mega-manual.html#brief-compatible-distro)
- as IRIS developer: SSH key (without password protection) configured for accessing our private git repositories
- for release preparation: [yq installed](https://github.com/mikefarah/yq#install)

### Docker (default & recommended)
- Linux, Mac or WSL in Windows (officially we only support Linux)
- [installed and active docker daemon](https://docs.docker.com/engine/install/)
- [installed docker-compose](https://docs.docker.com/compose/install/)
- installed GNU make
- as IRIS developer: SSH folder containing a SSH key (without password protection) configured for accessing our private git repositories, as well as a ${SSH_DIR}/known_hosts file containing our private git servers SSH signature
- using Docker on a host with SELinux enabled requires additional steps, as described below.

#### Docker and SELinux

The container described in `docker-compose.yml` will mount two directories of the host system. The current directory, the iris-kas repository, is mounted with the `:z` flag. This will relabel everything inside the current directory as `container_file_t`, making it read/writeable by any container process.

To access the `SSHDIR` from within the container, you need to apply a SELinux policy that allows `container_t` processes to read from the `.ssh` directory of the current user. First, install the selinux-policy-devel package, which provides the Makefile to compile custom policies.

```
$ make -f /usr/share/selinux/devel/Makefile container_read_sshdir.pp
$ sudo semodule -i container_read_sshdir.pp  # to remove run: semodule -r container_read_sshdir
```

Afterwards you can run the `docker-compose` commands as described above.

## Usage (general)

### Supported environment variables

Environment variables can be passed to the make command (e.g. `RELEASE=r2 make build`).

We currently support the following variables:

| Variable    | Description                                                                                                                                                                                                        | Default value                                                                                            |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| KAS_COMMAND | The command for running the KAS executable. By default, KAS will run in a docker container (recommended). Set this to `kas` if you want to use a host installation of KAS                                          | `USER_ID=$(USER_ID) GROUP_ID=$(GROUP_ID) SSH_DIR=$(SSH_DIR) docker-compose run --service-ports --rm kas` |
| USER_ID     | Sets the user ID of the KAS user within a docker build. This will affect the ownership of the generated files                                                                                                      | `id -u`                                                                                                  |
| GROUP_ID    | Sets the primary group ID of the KAS user within a docker build. This will affect the ownership of the generated files                                                                                             | `id -g`                                                                                                  |
| SSH_DIR     | Sets the path to a directory containing an authorized SSH key (e.g.: id_rsa, id_ed25519, ...) as well as a known_hosts file containing our private git server. This path will be mounted into the docker container | `~/.ssh`                                                                                                 |
| RELEASE     | Sets the release you wish to build (currently `r1` for sc573-gen6 or `r2` for imx8mp-evk)                                                                                                                          | `r1`                                                                                                     |
| TAG         | Sets the tag to use during the release or support release process (e.g. `2.3.0`, `2.3.0-custom`)                                                                                                                   | None                                                                                                     |


**Optional variable overrides for all make commands:**
- `KAS_COMMAND`
- `USER_ID`
- `GROUP_ID`
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
