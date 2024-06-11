# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 iris-GmbH infrared & intelligent sensors

.RECIPEPREFIX := >
MAKEFILE_PATH := $(abspath $(lastword ${MAKEFILE_LIST}))
MAKEFILE_DIR := $(dir ${MAKEFILE_PATH})
.DEFAULT_GOAL := kas-build
USER_ID := $(shell id -u)
GROUP_ID := $(shell id -g)
DEFAULT_IRMA_DISTRO_VERSION := 0.0-unknown

.PHONY: kas-build kas

######################
### BASIC SETTINGS ###
######################

export MULTI_CONF ?= imx8mp-irma6r2
export KAS_TARGET_RECIPE ?= irma-maintenance-bundle
export KAS_TASK ?= build
export SSH_DIR ?= ~/.ssh

###############################
### ADVANCED BUILD SETTINGS ###
###############################

export BUILD_FROM_SCRATCH ?= false
export INCLUDE_PROPRIETARY_LAYERS ?= true
# Note, that building a release is usually only ever done via CI, as key
# material is required. Theoretically it is possible to build a release
# locally, but this requires setting up production keys on the build machine
# (see include/kas-ci-deploy-signing*.yml files), as well as reproducing the CI job steps
# and should only be considered as a last resort.
export RELEASE ?= false

################################
### ADVANCED FOLDER SETTINGS ###
################################

export KAS_WORK_DIR ?= ${MAKEFILE_DIR}
export KAS_BUILD_DIR ?= ${KAS_WORK_DIR}/build
export KAS_TMPDIR ?= ${KAS_BUILD_DIR}/tmp
export DL_DIR ?= ${KAS_BUILD_DIR}/dl_dir
export SSTATE_DIR ?= ${KAS_BUILD_DIR}/sstate_dir

#####################################
### ADVANCED KAS RUNTIME SETTINGS ###
#####################################

export KAS_CONTAINER_TAG ?= latest
export KAS_CONTAINER_IMAGE ?= registry.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas:${KAS_CONTAINER_TAG}
# TODO: Use --ssh-agent instead of --ssh-dir. Adjust SELinux rules and resolve remote host validation failure.
export KAS_CONTAINER_OPTIONS ?= --ssh-dir ${SSH_DIR}
export IRIS_KAS_CONTAINER_PULL ?= always
export IRMA_DISTRO_VERSION ?= ${DEFAULT_IRMA_DISTRO_VERSION}
export KAS_EXE ?= KAS_CONTAINER_IMAGE=${KAS_CONTAINER_IMAGE} ${MAKEFILE_DIR}kas-container \
	--runtime-args " \
	--pull ${IRIS_KAS_CONTAINER_PULL} \
	-e IRMA_DISTRO_VERSION=${IRMA_DISTRO_VERSION} \
	-e BRANCH_NAME=${BRANCH_NAME} \
	" ${KAS_CONTAINER_OPTIONS}
export KAS_BASE_CONFIG_FILE ?= kas-${MULTI_CONF}.yml
export KAS_BASE_CONFIG_LOCK_FILE = $(subst .yml,.lock.yml,${KAS_BASE_CONFIG_FILE})

#####################################
### ADVANCED KAS COMMAND SETTINGS ###
#####################################

export KAS_EXTRA_BITBAKE_ARGS ?=
export KAS_LOG_LEVEL ?= info
export OPTIONS ?= --log-level ${KAS_LOG_LEVEL}
export KASOPTIONS ?=
export KASFILE ?= ${KASFILE_GENERATED}
export KASFILE_EXTRA ?=
export KAS_COMMAND ?= TMPDIR="${KAS_TMPDIR}" ${KAS_EXE} ${OPTIONS}

#########################
### KAS TASK SETTINGS ###
#########################

export KAS_ARGS ?= shell -c "bitbake ${KAS_TARGET} -c ${KAS_TASK} ${KAS_EXTRA_BITBAKE_ARGS}"

###############################################
### CHECKOUT-BRANCH-IN-IRIS-LAYERS SETTINGS ###
###############################################

export BRANCH_NAME ?= master


######################
### MAKEFILE RULES ###
######################

ifeq (${RELEASE}, false)
	IRMA_DISTRO_VERSION_DEV_SUFFIX := -dev
endif

ifeq (${RELEASE}, true)
	KASFILE_EXTRA += :include/kas-release.yml
endif

ifeq (${INCLUDE_PROPRIETARY_LAYERS}, true)
	KASFILE_EXTRA += :include/kas-meta-iris.yml
	export KAS_PREMIRRORS ?= ^https://github\.com/iris-GmbH/meta-iris-base\.git$$ git@gitlab.devops.defra01.iris-sensing.net:public-projects/yocto/meta-iris-base.git
endif

ifeq (${BUILD_FROM_SCRATCH}, true)
	KAS_EXTRA_BITBAKE_ARGS += --no-setscene
endif

# if KAS_TARGET_RECIPE contains "irma-deploy", set distro accordingly
ifeq (irma-deploy, $(findstring irma-deploy, ${KAS_TARGET_RECIPE}))
	export KAS_DISTRO ?= poky-iris-deploy
endif

$(foreach word, ${KAS_TARGET_RECIPE},$(eval KAS_TARGET ?= ${KAS_TARGET} mc:${MULTI_CONF}:$(word)))
export KAS_TARGET

# finalize KASFILE into list
$(foreach word,${KASFILE_EXTRA},$(eval KASFILE_EXTRA_LIST := ${KASFILE_EXTRA_LIST}$(word)))
KASFILE_GENERATED := ${KAS_BASE_CONFIG_FILE}${KASFILE_EXTRA_LIST}

# Get iris product name from inside of the KAS environment
# This export variable may NOT be called IRIS_PRODUCT itself,
# otherwise there is a chicken-egg problem, since Makefile will
# first export the variable with an empty string before running the
# KAS command to assign the actual value, thus overriding the default IRIS_PRODUCT value
# set as a "env" in the product specific KAS config file.
export _IRIS_PRODUCT ?= $(shell ${KAS_COMMAND} shell -c 'echo $${IRIS_PRODUCT}' ${KASFILE})
# Re-assigning the variable with := prevents re-running the KAS command everytime the variable is referenced
export _IRIS_PRODUCT := ${_IRIS_PRODUCT}
# Use the _IRIS_PRODUCT variable to identify the products next version if version is not explicitly set
ifeq (${DEFAULT_IRMA_DISTRO_VERSION}, ${IRMA_DISTRO_VERSION})
	ifneq (${CI_PIPELINE_ID},)
		GENERATE_NEXT_VERSION_PIPELINE_ARGS := -i ${CI_PIPELINE_ID}
	endif
	export IRMA_DISTRO_VERSION = $(shell ${MAKEFILE_DIR}utils/scripts/generate-next-version-string.sh -p ${_IRIS_PRODUCT} -g ${MAKEFILE_DIR} ${GENERATE_NEXT_VERSION_PIPELINE_ARGS})
endif

######################
### MAKEFILE TASKS ###
######################

# default task: run kas build
kas-build:
> ${KAS_COMMAND} build ${KASOPTIONS} ${KASFILE} -- ${KAS_EXTRA_BITBAKE_ARGS}

kas:
> ${KAS_COMMAND} ${KAS_ARGS} ${KASOPTIONS} ${KASFILE}

kas-shell:
> ${KAS_COMMAND} shell ${KASOPTIONS} ${KASFILE}

kas-for-all-repos:
> ${KAS_COMMAND} for-all-repos ${KASOPTIONS} ${KASFILE} ${KAS_FOR_ALL_REPOS_COMMAND}

# Updates the README table of contents
update-toc:
> doctoc --github --title "**Table of Contents**" README.md

build-iris-kas-container:
> docker build -t ${KAS_CONTAINER_IMAGE} -f ${MAKEFILE_DIR}Dockerfile_iris_kas ${MAKEFILE_DIR}

clean-tmp-dir:
> rm -rf ${KAS_TMPDIR}

clean-dl-dir:
> rm -rf ${DL_DIR}

clean-sstate-dir:
> rm -rf ${SSTATE_DIR}

clean-builddir:
> rm -rf ${KAS_BUILD_DIR}

kas-update:
> ${KAS_COMMAND} checkout --update ${KASFILE}

kas-force-update:
> ${KAS_COMMAND} checkout --update --force-checkout ${KASFILE}

run-qemu:
> ${KAS_COMMAND} shell -c "runqemu qemux86-64 qemuparams=\"-m $$(($$(free -m | awk '/Mem:/ {print $$2}') /100 *70)) -serial stdio\" slirp" ${KASFILE}

kas-dump-lockfile:
> ${KAS_COMMAND} dump --lock --inplace --update ${KASFILE}

kas-buildhistory-collect-srcrevs:
> @# only create a kas lockfile, if it does not yet exist
> if ! ls ${MAKEFILE_DIR}/${KAS_BASE_CONFIG_LOCK_FILE} >/dev/null 2>&1; then \
>	echo "No previous lockfile detected, creating one..."; \
>	${KAS_COMMAND} dump --lock --inplace --update ${KASFILE}; \
> fi
> @# collect srcrevs from the previous buildhistory (do some sed magic to escape double quotes in the resulting string) into the kas lock file
> ${KAS_COMMAND} shell -c 'srcrevs=$$(buildhistory-collect-srcrevs | sed "s/\\\"/\\\\\"/g") && yq -P -i "(.local_conf_header.srcrevs |= \"$${srcrevs}\")" $${KAS_WORK_DIR}/${KAS_BASE_CONFIG_LOCK_FILE}' ${KASFILE}

develop-prepare-reproducible-build: kas-buildhistory-collect-srcrevs
> @echo "Prepared a reproducible build for target mc:${MULTI_CONF}:${KAS_TARGET_RECIPE}."
> @echo "Please commit the generated lock file to your feature branch within this project."
> @echo "CAUTION: We can only guarantee reproducibility for changes commited to protected branches within yocto layer and component repositories!"

kas-checkout-branch-in-iris-layers:
> ${KAS_COMMAND} for-all-repos ${KASFILE}:include/kas-branch-name-env.yml ' \
> 	if echo "$${KAS_REPO_NAME}" | grep -qvE "^meta-iris(-base)?$$"; then \
> 		exit 0; \
> 	fi; \
> 	echo "Trying to checkout $${BRANCH_NAME} in $${KAS_REPO_NAME}"; \
> 	if git checkout "$${BRANCH_NAME}" 2>/dev/null; then \
> 		echo "Branch $${BRANCH_NAME} has been checked out in $${KAS_REPO_NAME}"; \
> 		if [ "$${KAS_REPO_NAME}" = "meta-iris" ]; then \
> 			KASFILE_FILE="include/kas-meta-iris.yml"; \
> 		else \
>			KASFILE_FILE="include/kas-meta-iris-base.yml"; \
>		fi; \
>		yq ".repos.$${KAS_REPO_NAME}.branch = \"$${BRANCH_NAME}\"" -i $${KAS_WORK_DIR}/$${KASFILE_FILE}; \
>	fi; \
>	'

prepare-release: kas-force-update kas-checkout-branch-in-iris-layers kas-dump-lockfile

patch-thirdparty-hostbuild:
> @echo "Warning: patch-thirdparty-hostbuild is deprecated and will be removed in the future."
> ${KAS_COMMAND} shell -c "bitbake ${THIRDPARTY} ${KAS_EXTRA_BITBAKE_ARGS} -c do_patch" ${KASFILE}
