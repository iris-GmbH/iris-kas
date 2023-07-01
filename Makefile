# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 iris-GmbH infrared & intelligent sensors

MAKEFILE_PATH := $(abspath $(lastword ${MAKEFILE_LIST}))
MAKEFILE_DIR := $(dir ${MAKEFILE_PATH})
.DEFAULT_GOAL := kas-build
USER_ID := $(shell id -u)
GROUP_ID := $(shell id -g)

.PHONY: kas-build kas

######################
### BASIC SETTINGS ###
######################

export MULTI_CONF ?= imx8mp-irma6r2
export KAS_TARGET_RECIPE ?= irma6-maintenance
export KAS_TARGET_RECIPE_IS_IMAGE ?= true
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
export KAS_BUILD_DIR ?= ${MAKEFILE_DIR}/build
export KAS_TMPDIR ?= ${MAKEFILE_DIR}/build/tmp
export DL_DIR ?= ${MAKEFILE_DIR}/build/dl_dir
export SSTATE_DIR ?= ${MAKEFILE_DIR}/build/sstate_dir

####################################
### ADVANCED GITVERSION SETTINGS ###
####################################

export GITVERSION_REPO_PATH ?= /repo
# TODO: add renovate regex rule
export GITVERSION_CONTAINER_IMAGE ?= gittools/gitversion:6.0.0-alpine.3.17-7.0
export GITVERSION_CMD ?= docker run --rm --user ${USER_ID}:${GROUP_ID} -v ${MAKEFILE_DIR}:${GITVERSION_REPO_PATH} ${GITVERSION_CONTAINER_IMAGE}
export IRMA6_DISTRO_VERSION ?= $(shell ${GITVERSION_CMD} ${GITVERSION_REPO_PATH} | jq -r '.MajorMinorPatch')${IRMA6_DISTRO_VERSION_DEV_SUFFIX}

#####################################
### ADVANCED KAS RUNTIME SETTINGS ###
#####################################

export KAS_CONTAINER_TAG ?= latest
export KAS_CONTAINER_IMAGE ?= registry.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas:${KAS_CONTAINER_TAG}
export KAS_CONTAINER_OPTIONS ?= --ssh-dir ${SSH_DIR} --ssh-agent
export IRIS_KAS_CONTAINER_PULL ?= always
export KAS_EXE ?= KAS_CONTAINER_IMAGE=${KAS_CONTAINER_IMAGE} ${MAKEFILE_DIR}kas-container \
	--runtime-args " \
	--pull ${IRIS_KAS_CONTAINER_PULL} \
	-e IRMA6_DISTRO_VERSION=${IRMA6_DISTRO_VERSION} \
	-e BRANCH_NAME=${BRANCH_NAME} \
	" ${KAS_CONTAINER_OPTIONS}

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
IRMA6_DISTRO_VERSION_DEV_SUFFIX := -dev
endif

ifeq (${RELEASE}, true)
KASFILE_EXTRA += :include/kas-release.yml
endif

ifneq (, ${MULTI_CONF})
# check if multiconf target override exists to speed up recipe parse time
ifneq (,$(wildcard ${MAKEFILE_DIR}include/kas-irma6-${MULTI_CONF}.yml))
KASFILE_EXTRA += :include/kas-irma6-${MULTI_CONF}.yml
endif
endif

ifeq (${INCLUDE_PROPRIETARY_LAYERS}, true)
KASFILE_EXTRA += :kas-irma6-pa.yml
export KAS_PREMIRRORS ?= ^https://github\.com/iris-GmbH/meta-iris-base\.git$$ git@gitlab.devops.defra01.iris-sensing.net:public-projects/yocto/meta-iris-base.git
endif

ifeq (${BUILD_FROM_SCRATCH}, true)
KAS_EXTRA_BITBAKE_ARGS += --no-setscene
endif

# if KAS_TARGET_RECIPE contains "irma6-deploy", set distro accordingly
ifeq (irma6-deploy, $(findstring irma6-deploy, ${KAS_TARGET_RECIPE}))
export KAS_DISTRO = poky-iris-deploy
endif


$(foreach word, ${KAS_TARGET_RECIPE},$(eval KAS_TARGET ?= ${KAS_TARGET} mc:${MULTI_CONF}:$(word)))
# if release 2 target multiconf and bitbake build target is an image,
# also build the required swu and uuu files.
# FIXME: this distinction should be done in yocto recipe itself
ifeq (${MULTI_CONF}, imx8mp-irma6r2)
ifeq (${KAS_TARGET_RECIPE_IS_IMAGE}, true)
ifeq (${KAS_TASK}, build)
$(foreach word, ${KAS_TARGET},$(eval KAS_TARGET ?= ${KAS_TARGET} $(word)-uuu $(word)-swuimage))
endif
endif
endif
export KAS_TARGET

# finalize KASFILE into list
$(foreach word,${KASFILE_EXTRA},$(eval KASFILE_EXTRA_LIST := ${KASFILE_EXTRA_LIST}$(word)))
KASFILE_GENERATED := kas-irma6-base.yml${KASFILE_EXTRA_LIST}

######################
### MAKEFILE TASKS ###
######################

# default task: run kas build
kas-build:
	${KAS_COMMAND} build ${KASOPTIONS} ${KASFILE} -- ${KAS_EXTRA_BITBAKE_ARGS}

kas:
	${KAS_COMMAND} ${KAS_ARGS} ${KASOPTIONS} ${KASFILE}

kas-shell:
	${KAS_COMMAND} shell ${KASOPTIONS} ${KASFILE}

# Updates the README table of contents
update-toc:
	doctoc --github --title "**Table of Contents**" README.md

build-iris-kas-container:
	docker build -t ${KAS_CONTAINER_IMAGE} -f ${MAKEFILE_DIR}Dockerfile_iris_kas ${MAKEFILE_DIR}

clean-tmp-dir:
	rm -rf ${KAS_TMPDIR}

clean-dl-dir:
	rm -rf ${DL_DIR}

clean-sstate-dir:
	rm -rf ${SSTATE_DIR}

clean-builddir:
	rm -rf ${KAS_BUILD_DIR}

kas-update:
	${KAS_COMMAND} checkout --update ${KASFILE}

kas-force-update:
	${KAS_COMMAND} checkout --update --force-checkout ${KASFILE}

run-qemu:
	${KAS_SHELL} -c "runqemu qemux86-64 qemuparams=\"-m $$(($$(free -m | awk '/Mem:/ {print $$2}') /100 *70)) -serial stdio\" slirp" ${KASFILE}

kas-dump-lockfile:
	${KAS_COMMAND} dump --lock --inplace ${KASFILE}

kas-checkout-branch-in-iris-layers:
	${KAS_COMMAND} for-all-repos ${KASFILE}:include/kas-branch-name-env.yml ' \
		if echo "$${KAS_REPO_NAME}" | grep -qvE "^meta-iris(-base)?$$"; then \
			exit 0; \
		fi; \
		echo "Trying to checkout $${BRANCH_NAME} in $${KAS_REPO_NAME}"; \
		if git checkout "$${BRANCH_NAME}" 2>/dev/null; then \
			echo "Branch $${BRANCH_NAME} has been checked out in $${KAS_REPO_NAME}"; \
			if [ "$${KAS_REPO_NAME}" = "meta-iris" ]; then \
				KASFILE_FILE="kas-irma6-pa.yml"; \
			else \
				KASFILE_FILE="kas-irma6-base.yml"; \
			fi; \
			yq ".repos.$${KAS_REPO_NAME}.branch = \"$${BRANCH_NAME}\"" -i $${KAS_WORK_DIR}/$${KASFILE_FILE}; \
		fi; \
		'

prepare-release: kas-force-update kas-checkout-branch-in-iris-layers kas-dump-lockfile

patch-thirdparty-hostbuild-r1:
	@echo "Warning: patch-thirdparty-hostbuild is deprecated and will be removed in the future."
	${KAS_SHELL} -c "bitbake ${THIRDPARTY} ${KAS_EXTRA_BITBAKE_ARGS} -c do_patch" ${KASFILE}

patch-thirdparty-hostbuild-r2:
	@echo "Warning: patch-thirdparty-hostbuild is deprecated and will be removed in the future."
	${KAS_SHELL} -c "bitbake ${THIRDPARTY} ${KAS_EXTRA_BITBAKE_ARGS} -c do_patch" ${KASFILE}
