# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 iris-GmbH infrared & intelligent sensors

MAKEFILE_PATH = $(abspath $(lastword ${MAKEFILE_LIST}))
MAKEFILE_DIR  = $(dir ${MAKEFILE_PATH})

export IRMA6_DISTRO_VERSION := $(shell git -C ${MAKEFILE_DIR} rev-parse --short HEAD)

SSH_DIR                 ?= ~/.ssh
MULTI_CONF              ?= imx8mp-irma6r2
BITBAKE_TARGET          ?= irma6-deploy
BITBAKE_TARGET_IS_IMAGE ?= true
BITBAKE_TASK            ?= build
BUILD_FROM_SCRATCH      ?= false

# whether to include proprietary code. Will require access to iris internal repositories
INCLUDE_PROPRIETARY_LAYERS ?= true

# Note, that building a release is usually only ever done via CI, as key
# material is required. Theoretically it is possible to build a release
# locally, but this requires setting up production keys on the build machine
# (see include/kas-ci-deploy-signing*.yml files), as well as reproducing the CI job steps
# and should only be considered as a last resort.
RELEASE  ?= false
CI_BUILD ?= false

# only change these if you know what you are doing
BUILDDIR    	?= /build
KAS_TMPDIR      ?= ${BUILDDIR}/tmp
DL_DIR      	?= ${BUILDDIR}/dl_dir
SSTATE_DIR  	?= ${BUILDDIR}/sstate_dir

KAS_EXTRA_ARGS ?=
KAS_EXTRA_INCLUDES ?=
BITBAKE_EXTRA_TARGETS ?=
BITBAKE_EXTRA_ARGS ?=

# only relevant if CI_BUILD == false
KAS_CONTAINER_IMAGE ?= registry.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas:latest

KAS_EXE ?= KAS_CONTAINER_IMAGE=${KAS_CONTAINER_IMAGE} ${MAKEFILE_DIR}kas-container \
    --runtime-args " \
    -e IRMA6_DISTRO_VERSION=${IRMA6_DISTRO_VERSION} \
    -e BUILDDIR=${BUILDDIR} \
    -e TMPDIR=${KAS_TMPDIR} \
    -e DL_DIR=${DL_DIR} \
    -e SSTATE_DIR=${SSTATE_DIR} \
	"

KAS_COMMAND ?= ${KAS_EXE} \
    --ssh-dir ${SSH_DIR} --ssh-agent

ifneq (, ${MULTI_CONF})
	_MULTI_CONF = mc:${MULTI_CONF}:
	# check if multiconf target override exists to speed up recipe parse time
	ifneq (,$(wildcard ${MAKEFILE_DIR}include/kas-irma6-${MULTI_CONF}.yml))
		KAS_EXTRA_INCLUDES += :include/kas-irma6-${MULTI_CONF}.yml
	endif
endif

ifeq (${INCLUDE_PROPRIETARY_LAYERS}, true)
	KAS_EXTRA_INCLUDES += :kas-irma6-pa.yml
endif

ifeq (${BUILD_FROM_SCRATCH}, true)
	BITBAKE_EXTRA_ARGS += --no-setscene
endif

## add CI specific configuration
ifeq (${CI_BUILD}, true)
	KAS_COMMAND = kas
	KAS_EXTRA_INCLUDES += :include/ci/kas-ci-common.yml
	ifeq (${RELEASE}, false)
		KAS_EXTRA_INCLUDES += :include/ci/kas-ci-develop.yml
		ifeq (${BRANCH_NAME}, ${CI_DEFAULT_BRANCH})
			KAS_EXTRA_INCLUDES += :include/ci/kas-ci-populate-caches.yml
		endif
		ifeq (${FORCE_POPULATE_CACHES}, true)
			KAS_EXTRA_INCLUDES += :include/ci/kas-ci-populate-caches.yml
		endif
	endif
endif

# add release specific configuration
ifeq (${RELEASE}, true)
	KAS_EXTRA_INCLUDES += :include/kas-release.yml:include/ci/kas-ci-deploy-signing-${MULTI_CONF}.yml
	ifeq (${CI_BUILD}, true)
		KAS_EXTRA_INCLUDES += :include/ci/kas-ci-populate-release-caches.yml
	endif
endif

# if BITBAKE_TARGET contains "irma6-deploy", set distro accordingly
ifeq (irma6-deploy, $(findstring irma6-deploy, ${BITBAKE_TARGET}))
	KAS_EXTRA_INCLUDES += :include/kas-irma6-deploy-distro.yml
endif

# if release 2 multiconf and bitbake build target is an image,
# also build the required swu and uuu files.
ifeq (${MULTI_CONF}, imx8mp-irma6r2)
	ifeq (${BITBAKE_TARGET_IS_IMAGE}, true)
		ifeq (${BITBAKE_TASK}, build)
			BITBAKE_EXTRA_TARGETS += ${_MULTI_CONF}${BITBAKE_TARGET}-uuu ${_MULTI_CONF}${BITBAKE_TARGET}-swuimage
		endif
	endif
endif

KAS_SHELL = ${KAS_COMMAND} shell ${KAS_EXTRA_ARGS}

# finalize KAS_CONFIG into list
$(foreach word,$(KAS_EXTRA_INCLUDES),$(eval KAS_EXTRA_INCLUDES_LIST := $(KAS_EXTRA_INCLUDES_LIST)$(word)))
KAS_CONFIG = kas-irma6-base.yml${KAS_EXTRA_INCLUDES_LIST}

###

# default action
bitbake-${BITBAKE_TASK}:bitbake-${BITBAKE_TASK}-${MULTI_CONF}-${BITBAKE_TARGET}

bitbake-${BITBAKE_TASK}-${MULTI_CONF}-${BITBAKE_TARGET}:
	${KAS_SHELL} -c "bitbake ${_MULTI_CONF}${BITBAKE_TARGET} ${BITBAKE_EXTRA_TARGETS} -c ${BITBAKE_TASK} ${BITBAKE_EXTRA_ARGS}" ${KAS_CONFIG}

# Updates the README table of contents
update-toc:
	doctoc --github --title "**Table of Contents**" README.md

build-container:
	if [ "${CI_BUILD}" = "true" ]; then\
		echo "make target only meant for local container build!";\
		exit 1;\
	fi;\
	docker build -t ${KAS_CONTAINER_IMAGE} -f ${MAKEFILE_DIR}Dockerfile_iris_kas ${MAKEFILE_DIR};\

clean-tmp-dir:
	${KAS_SHELL} -c 'rm -rf $${TMPDIR}' ${KAS_CONFIG}

clean-dl-dir:
	${KAS_SHELL} -c 'rm -rf $${DL_DIR}' ${KAS_CONFIG}

clean-sstate-dir:
	${KAS_SHELL} -c 'rm -rf $${SSTATE_DIR}' ${KAS_CONFIG}

clean-builddir:
	${KAS_SHELL} -c 'rm -rf $${BUILDDIR}' ${KAS_CONFIG}

pull-layers:
	${KAS_COMMAND} checkout --update ${KAS_CONFIG}

force-pull-layers:
	${KAS_COMMAND} checkout --update --force-checkout ${KAS_CONFIG}

run-qemu:
	${KAS_SHELL} -c "runqemu qemux86-64 qemuparams=\"-m $$(($$(free -m | awk '/Mem:/ {print $$2}') /100 *70)) -serial stdio\" slirp" ${KAS_CONFIG}

patch-thirdparty-hostbuild: patch-thirdparty-hostbuild-r2

patch-thirdparty-hostbuild-r1:
	${KAS_SHELL} -c "bitbake mc:qemux86_64-r1:${THIRDPARTY} ${BITBAKE_EXTRA_ARGS} -c do_patch" ${KAS_CONFIG}

patch-thirdparty-hostbuild-r2:
	${KAS_SHELL} -c "bitbake mc:qemux86_64-r2:${THIRDPARTY} ${BITBAKE_EXTRA_ARGS} -c do_patch" ${KAS_CONFIG}

create-kas-lockfile:
	${KAS_COMMAND} dump --lock --inplace ${KAS_CONFIG}

KAS_SHELL_CMD ?= echo Hello World!
kas-shell:
	${KAS_SHELL} -c "${KAS_SHELL_CMD}" ${KAS_CONFIG}

kas-int-shell:
	${KAS_SHELL} ${KAS_CONFIG}

remove-symlinks-image-dir:
	${KAS_SHELL} -c "if [ -d "\$${TMPDIR}/deploy/images" ]; then find \$${TMPDIR}/deploy/images -type l -exec rm -f {} \; ;fi" ${KAS_CONFIG}

export BRANCH_NAME ?= master
checkout-branch-in-iris-layers:
	${KAS_COMMAND} for-all-repos ${KAS_CONFIG} " \
		export BRANCH_NAME=${BRANCH_NAME}; \
		test \"\$${KAS_REPO_NAME}\" = \"this\" || bash ${MAKEFILE_DIR}utils/set_layer_branchname.sh; \
	"

set-fixed-refspecs: create-kas-lockfile
	@echo "Warning: set-fixed-refspec is deprecated and will be removed in the future. Use create-kas-lockfile instead.
