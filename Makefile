# SPDX-License-Identifier: MIT
# Copyright (C) 2021 iris-GmbH infrared & intelligent sensors

MAKEFILE_PATH 	= $(abspath $(lastword ${MAKEFILE_LIST}))
MAKEFILE_DIR 	= $(dir ${MAKEFILE_PATH})

SSH_DIR 			?= ~/.ssh
RELEASE 			?= r2
CONTAINER_IMAGE 	?= registry.devops.defra01.iris-sensing.net/public-projects/yocto/iris-kas:latest
KAS_COMMAND 		?= KAS_CONTAINER_IMAGE=${CONTAINER_IMAGE} ${MAKEFILE_DIR}kas-container --ssh-dir ${SSH_DIR} --ssh-agent

DEPLOY_BASE_KAS_CONFIG      = kas-irma6-base-deploy.yml
MAINTENANCE_PA_KAS_CONFIG   = kas-irma6-base-maintenance.yml:kas-irma6-pa.yml
DEPLOY_PA_KAS_CONFIG        = kas-irma6-base-deploy.yml:kas-irma6-pa.yml

ifeq (${RELEASE}, r1)
	TARGET_MULTI_CONF = sc573-gen6
	QEMU_MULTI_CONF = qemux86-64-r1
endif
ifeq (${RELEASE}, r2)
	TARGET_MULTI_CONF = imx8mp-irma6r2
	QEMU_MULTI_CONF = qemux86-64-r2
endif
ifeq (${RELEASE}, r2-evk)
	TARGET_MULTI_CONF = imx8mp-evk
	QEMU_MULTI_CONF = qemux86-64-r2
endif

# default action: building ${RELEASE}
build: build-${RELEASE}
build-qemu: build-qemu-${RELEASE}
build-sdk: build-sdk-${RELEASE}
build-sdk-qemu: build-sdk-qemu-${RELEASE}
build-base: build-base-${RELEASE}
build-base-dump: build-base-dump-${RELEASE}
patch-thirdparty-hostbuild: patch-thirdparty-hostbuild-${RELEASE}
shell: shell-${RELEASE}

# Updates the README table of contents
update-toc:
	doctoc --github --title "**Table of Contents**" README.md

build-container:
	docker build -t ${CONTAINER_IMAGE} -f ${MAKEFILE_DIR}Dockerfile_iris_kas ${MAKEFILE_DIR}

clean:
	${KAS_COMMAND} shell -c 'rm -rf $${BUILDDIR}' kas-irma6-base-common.yml

pull:
	${KAS_COMMAND} checkout --update ${MAINTENANCE_PA_KAS_CONFIG}

force-pull:
	${KAS_COMMAND} checkout --update --force-checkout ${MAINTENANCE_PA_KAS_CONFIG}

run-qemu:
	${KAS_COMMAND} shell -c "runqemu qemux86-64 qemuparams=\"-m $$(($$(free -m | awk '/Mem:/ {print $$2}') /100 *70)) -serial stdio\" slirp" ${MAINTENANCE_PA_KAS_CONFIG}

build-sdk-${RELEASE}:
	${KAS_COMMAND} shell -c "bitbake mc:${TARGET_MULTI_CONF}:irma6-maintenance -c do_populate_sdk" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-${TARGET_MULTI_CONF}.yml

build-sdk-qemu-${RELEASE}:
	${KAS_COMMAND} shell -c "bitbake mc:${QEMU_MULTI_CONF}:irma6-maintenance -c do_populate_sdk" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-${QEMU_MULTI_CONF}.yml

build-qemu-${RELEASE}:
	${KAS_COMMAND} shell -c "bitbake mc:${QEMU_MULTI_CONF}:irma6-test" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-${QEMU_MULTI_CONF}.yml

build-base-${RELEASE}:
	${KAS_COMMAND} shell -c "bitbake mc:${TARGET_MULTI_CONF}:irma6-base" ${DEPLOY_BASE_KAS_CONFIG}:include/kas-irma6-${TARGET_MULTI_CONF}.yml

build-base-dump-${RELEASE}:
	${KAS_COMMAND} shell -c "bitbake mc:${TARGET_MULTI_CONF}:irma6-base" ${DEPLOY_BASE_KAS_CONFIG}:include/kas-irma6-${TARGET_MULTI_CONF}.yml:include/kas-offline-build.yml

build-${RELEASE}:
	${KAS_COMMAND} shell -c "bitbake mc:${TARGET_MULTI_CONF}:irma6-deploy" ${DEPLOY_PA_KAS_CONFIG}:include/kas-irma6-${TARGET_MULTI_CONF}.yml
	${KAS_COMMAND} shell -c "bitbake mc:${TARGET_MULTI_CONF}:irma6-maintenance mc:${TARGET_MULTI_CONF}:irma6-dev" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-${TARGET_MULTI_CONF}.yml

patch-thirdparty-hostbuild-${RELEASE}:
	${KAS_COMMAND} shell -c "bitbake ${THIRDPARTY} -c do_patch" ${DEPLOY_PA_KAS_CONFIG}:include/kas-irma6-${TARGET_MULTI_CONF}.yml

shell-${RELEASE}:
	${KAS_COMMAND} shell ${DEPLOY_PA_KAS_CONFIG}:include/kas-irma6-${TARGET_MULTI_CONF}.yml

git-flow:
	git flow init -d

start-release: git-flow
	@[ -n "${TAG}" ] || { echo "Error: Please specify the TAG variable" >&2; exit 1; }
	git flow release start --showcommands ${TAG} develop
	@echo "Info: Setting fixed refspecs on thirdparty layer repos for you..."
	${KAS_COMMAND} for-all-repos --update kas-irma6-base-common.yml:kas-irma6-pa.yml 'if echo "$${KAS_REPO_NAME}" | grep -vq "iris" && [ "$${KAS_REPO_NAME}" != "this" ]; then git checkout $${KAS_REPO_REFSPEC} && yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git rev-parse --verify HEAD)\"" -i ../kas-irma6-base-common.yml; fi'
	git add -A
	git commit -m "Fixed refspecs on thirdparty layers for release ${TAG}"
	@echo "Info: Please make sure you adjust "IRMA6_DISTRO_VERSION" in kas-irma6-base-common.yml, set fixed refspecs for iris layers and that the changelog is up-to-date before merging the release."

start-support: git-flow
	@[ -n "${TAG}" ] || { echo "Error: Please specify the TAG variable. e.g. support/2.2.2-foo" >&2; exit 1; }
	@[ -n "${BASE_COMMIT}" ] || { echo "Error: Please specify the BASE_COMMIT variable. This is a commit on the master branch from which the support release shall be created." >&2; exit 1; }
	git flow support start --showcommands ${TAG} ${BASE_COMMIT}
	@echo "Info: Please make sure you adjust "IRMA6_DISTRO_VERSION" in kas-irma6-base-common.yml, set fixed refspecs for iris layers and that the changelog is up-to-date before tagging the support release."

set-fixed-refspecs:
	@echo "Info: Setting fixed refspecs on thirdparty layer repos for you..."
	${KAS_COMMAND} for-all-repos --update kas-irma6-base-common.yml:kas-irma6-pa.yml 'if echo "$${KAS_REPO_NAME}" | grep -vq "iris" && [ "$${KAS_REPO_NAME}" != "this" ]; then git checkout $${KAS_REPO_REFSPEC} && yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git rev-parse --verify HEAD)\"" -i ../kas-irma6-base-common.yml; fi'
