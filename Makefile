# SPDX-License-Identifier: MIT
# Copyright (C) 2021 iris-GmbH infrared & intelligent sensors

SSH_DIR 		?= ~/.ssh
RELEASE 		?= r1
KAS_COMMAND 	?= USER_ID=$(USER_ID) GROUP_ID=$(GROUP_ID) SSH_DIR=$(SSH_DIR) docker-compose run --service-ports --rm kas

IMAGE_REGISTRY 	?= 693612562064.dkr.ecr.eu-central-1.amazonaws.com
IMAGE_NAME 		?= kas
# adjust on image build
IMAGE_TAG 		= 2.6.1

USER_ID 		= $(shell id -u)
GROUP_ID 		= $(shell id -g)
MAKEFILE_PATH 	= $(abspath $(lastword ${MAKEFILE_LIST}))
MAKEFILE_DIR 	= $(dir ${MAKEFILE_PATH})

DEPLOY_BASE_KAS_CONFIG      = kas-irma6-base-deploy.yml
MAINTENANCE_PA_KAS_CONFIG   = kas-irma6-base-maintenance.yml:kas-irma6-pa.yml
DEPLOY_PA_KAS_CONFIG        = kas-irma6-base-deploy.yml:kas-irma6-pa.yml

# default action: building ${RELEASE}
build: build-${RELEASE}

update-toc: ## Updates the README table of contents
	doctoc --github --title "**Table of Contents**" README.md

docker-login:
	aws-vault exec -n iris-devops -- aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${IMAGE_REGISTRY}

build-and-push-image: docker-login
	docker buildx build -t ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} --platform linux/amd64,linux/arm64 --build-arg type=ci --push ${MAKEFILE_DIR}

clean:
	${KAS_COMMAND} shell -c 'rm -rf $${BUILDDIR}' kas-irma6-base-common.yml

pull:
	${KAS_COMMAND} checkout --update kas-irma6-pa.yml

force-pull:
	${KAS_COMMAND} checkout --update --force-checkout kas-irma6-pa.yml

build-sdk-r1:
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen6:irma6-maintenance -c do_populate_sdk" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-sc573-gen6.yml

build-sdk-r2:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-irma6r2:irma6-maintenance -c do_populate_sdk" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-imx8mp-irma6r2.yml

build-sdk-r2-evk:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-evk:irma6-maintenance -c do_populate_sdk" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-imx8mp-evk.yml

build-sdk: build-sdk-${RELEASE}

build-sdk-qemu-r1:
	${KAS_COMMAND} shell -c "bitbake mc:qemux86-64-r1:irma6-maintenance -c do_populate_sdk" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-qemux86-64-r1.yml

build-sdk-qemu-r2:
	${KAS_COMMAND} shell -c "bitbake mc:qemux86-64-r2:irma6-maintenance -c do_populate_sdk" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-qemux86-64-r2.yml

build-sdk-qemu: build-sdk-qemu-${RELEASE}

build-qemu-r1:
	${KAS_COMMAND} shell -c "bitbake mc:qemux86-64-r1:irma6-test" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-qemux86-64-r1.yml

build-qemu-r2:
	${KAS_COMMAND} shell -c "bitbake mc:qemux86-64-r2:irma6-test" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-qemux86-64-r2.yml

build-qemu: build-qemu-${RELEASE}

run-qemu:
	${KAS_COMMAND} shell -c "runqemu qemux86-64 qemuparams=\"-m $$(($$(free -m | awk '/Mem:/ {print $$2}') /100 *70)) -serial stdio\" slirp" kas-irma6-pa.yml

build-base-r1:
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen6:irma6-base" ${DEPLOY_BASE_KAS_CONFIG}:include/kas-irma6-sc573-gen6.yml

build-base-r2:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-irma6r2:irma6-base" ${DEPLOY_BASE_KAS_CONFIG}:include/kas-irma6-imx8mp-irma6r2.yml

build-base-r2-evk:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-evk:irma6-base" ${DEPLOY_BASE_KAS_CONFIG}:include/kas-irma6-imx8mp-evk.yml

build-base: build-base-${RELEASE}

build-base-dump-r1:
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen6:irma6-base" ${DEPLOY_BASE_KAS_CONFIG}:include/kas-irma6-sc573-gen6.yml:include/kas-offline-build.yml

build-base-dump-r2:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-irma6r2:irma6-base" ${DEPLOY_BASE_KAS_CONFIG}:include/kas-irma6-imx8mp-irma6r2.yml:include/kas-offline-build.yml

build-base-dump-r2-evk:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-evk:irma6-base" ${DEPLOY_BASE_KAS_CONFIG}:include/kas-irma6-imx8mp-evk.yml:include/kas-offline-build.yml

build-base-dump: build-base-dump-${RELEASE}

build-r1:
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen6:irma6-deploy" ${DEPLOY_PA_KAS_CONFIG}:include/kas-irma6-sc573-gen6.yml
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen6:irma6-maintenance mc:sc573-gen6:irma6-dev" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-sc573-gen6.yml

build-r2:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-irma6r2:irma6-deploy" ${DEPLOY_PA_KAS_CONFIG}:include/kas-irma6-imx8mp-irma6r2.yml
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-irma6r2:irma6-maintenance mc:imx8mp-irma6r2:irma6-dev" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-imx8mp-irma6r2.yml

build-r2-evk:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-evk:irma6-deploy" ${DEPLOY_PA_KAS_CONFIG}:include/kas-irma6-imx8mp-evk.yml
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-evk:irma6-maintenance mc:imx8mp-evk:irma6-dev" ${MAINTENANCE_PA_KAS_CONFIG}:include/kas-irma6-imx8mp-evk.yml

git-flow:
	git flow init -d

start-release: git-flow
	@[ -n "${TAG}" ] || { echo "Error: Please specify the TAG variable" >&2; exit 1; }
	git flow release start --showcommands ${TAG} develop
	@echo "Info: Setting fixed refspecs on thirdparty layer repos for you..."
	${KAS_COMMAND} for-all-repos --update kas-irma6-pa.yml 'if echo "$${KAS_REPO_NAME}" | grep -vq "iris" && [ "$${KAS_REPO_NAME}" != "this" ]; then git checkout $${KAS_REPO_REFSPEC} && yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git rev-parse --verify HEAD)\"" -i ../${DEPLOY_BASE_KAS_CONFIG}; fi'
	git add -A
	git commit -m "Fixed refspecs on thirdparty layers for release ${TAG}"
	@echo "Info: Please make sure you adjust "IRMA6_DISTRO_VERSION" in kas-irma6-base-common.yml, set fixed refspecs for iris layers and that the changelog is up-to-date before merging the release."

start-support: git-flow
	@[ -n "${TAG}" ] || { echo "Error: Please specify the TAG variable. e.g. support/2.2.2-foo" >&2; exit 1; }
	@[ -n "${BASE_COMMIT}" ] || { echo "Error: Please specify the BASE_COMMIT variable. This is a commit on the master branch from which the support release shall be created." >&2; exit 1; }
	git flow support start --showcommands ${TAG} ${BASE_COMMIT}}
	@echo "Info: Setting fixed refspecs on layer repos for you..."
	${KAS_COMMAND} for-all-repos --update kas-irma6-pa.yml 'if echo "$${KAS_REPO_NAME}" | grep -vq "iris" && [ "$${KAS_REPO_NAME}" != "this" ]; then git checkout $${KAS_REPO_REFSPEC} && yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git rev-parse --verify HEAD)\"" -i ../${DEPLOY_BASE_KAS_CONFIG}; fi'
	git add -A
	git commit -m "Fixed refspecs on thirdparty layers for support release ${TAG}"
	@echo "Info: Please make sure you adjust "IRMA6_DISTRO_VERSION" in kas-irma6-base-common.yml, set fixed refspecs for iris layers and that the changelog is up-to-date before tagging the support release."
