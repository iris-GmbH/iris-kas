# SPDX-License-Identifier: MIT
# Copyright (C) 2021 iris-GmbH infrared & intelligent sensors

USER_ID 	?= $(shell id -u)
GROUP_ID 	?= $(shell id -g)
SSH_DIR 	?= ~/.ssh
RELEASE 	?= r1
KAS_COMMAND ?= USER_ID=$(USER_ID) GROUP_ID=$(GROUP_ID) SSH_DIR=$(SSH_DIR) docker-compose run --service-ports --rm kas
MAKEFILE_PATH = $(abspath $(lastword ${MAKEFILE_LIST}))
MAKEFILE_DIR = $(dir ${MAKEFILE_PATH})
DOCKER_TAG = $(shell grep -E 'ARG\s+KAS_VER=' ${MAKEFILE_DIR}/Dockerfile | sed -e 's/ARG\s\+KAS_VER=//g')

docker-login:
	aws-vault exec -n iris-devops -- aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 693612562064.dkr.ecr.eu-central-1.amazonaws.com

push-jenkins-image: docker-login
	docker buildx build -t 693612562064.dkr.ecr.eu-central-1.amazonaws.com/kas:latest -t 693612562064.dkr.ecr.eu-central-1.amazonaws.com/kas:${DOCKER_TAG} --platform linux/amd64,linux/arm64 --build-arg type=jenkins --push ${MAKEFILE_DIR}

clean:
	${KAS_COMMAND} shell -c 'rm -rf $${BUILDDIR}' kas-irma6-base.yml

pull:
	${KAS_COMMAND} checkout --update kas-irma6-pa.yml

force-pull:
	${KAS_COMMAND} checkout --update --force-checkout kas-irma6-pa.yml

build-sdk-r1:
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen6:irma6-maintenance -c do_populate_sdk" kas-irma6-pa.yml:include/kas-irma6-sc573-gen6.yml

build-sdk-r2:
	${KAS_COMMAND} shell -c "bitbake mc:imxmp-evk:irma6-maintenance -c do_populate_sdk" kas-irma6-pa.yml:include/kas-irma6-imxmp-evk.yml

build-sdk: build-sdk-${RELEASE}

build-sdk-qemu-r1:
	${KAS_COMMAND} shell -c "bitbake mc:qemux86-64-r1:irma6-maintenance -c do_populate_sdk" kas-irma6-pa.yml:include/kas-irma6-qemux86-64-r1.yml

build-sdk-qemu-r2:
	${KAS_COMMAND} shell -c "bitbake mc:qemux86-64-r2:irma6-maintenance -c do_populate_sdk" kas-irma6-pa.yml:include/kas-irma6-qemux86-64-r2.yml

build-sdk-qemu: build-sdk-${RELEASE}

build-qemu-r1:
	${KAS_COMMAND} shell -c "bitbake mc:qemux86-64-r1:irma6-test" kas-irma6-pa.yml:include/kas-irma6-qemux86-64-r1.yml

build-qemu-r2:
	${KAS_COMMAND} shell -c "bitbake mc:qemux86-64-r2:irma6-test" kas-irma6-pa.yml:include/kas-irma6-qemux86-64-r2.yml

build-qemu: build-qemu-${RELEASE}

run-qemu:
	${KAS_COMMAND} shell -c "runqemu qemux86-64 qemuparams=\"-m $$(($$(free -m | awk '/Mem:/ {print $$2}') /100 *70)) -serial stdio\" slirp" kas-irma6-pa.yml

build-base-r1:
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen6:irma6-base" kas-irma6-base.yml

build-base-r2:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-evk:irma6-base" kas-irma6-base.yml

build-base: build-base-${RELEASE}

build-base-dump-r1:
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen6:irma6-base" kas-irma6-base.yml:include/kas-offline-build.yml

build-base-dump-r2:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-evk:irma6-base" kas-irma6-base.yml:include/kas-offline-build.yml

build-base-dump: build-base-dump-${RELEASE}

build-r1:
	${KAS_COMMAND} shell -c "bitbake mc:sc573-gen:irma6-deploy mc:sc573-gen6:irma6-maintenance mc:sc573-gen6:irma6-dev mc:qemux86-64-r1:irma6-test" kas-irma6-base.yml

build-r2:
	${KAS_COMMAND} shell -c "bitbake mc:imx8mp-evk:irma6-deploy mc:imx8mp-evk:irma6-maintenance mc:imx8mp-evk:irma6-dev mc:qemux86-64-r2:irma6-test" kas-irma6-base.yml

build: build-${RELEASE}

git-flow:
	git flow init -d

start-release: git-flow
	@[ -n "${TAG}" ] || { echo "Error: Please specify the TAG variable" >&2; exit 1; }
	git flow release start --showcommands ${TAG} develop
	@echo "Info: Setting fixed refspecs on layer repos for you..."
	${KAS_COMMAND} for-all-repos kas-irma6-pa.yml 'if [ "$${KAS_REPO_NAME}" = "meta-iris" ]; then yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git describe --tags --always)\"" -i ../kas-irma6-pa.yml; elif [ "$${KAS_REPO_NAME}" != "this" ]; then yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git describe --tags --always)\"" -i ../kas-irma6-base.yml; fi'
	git add -A
	git commit -m "Set fixed repo refspecs for release ${TAG}"
	@echo "Warning: Please make sure you adjust "IRMA6_DISTRO_VERSION" in kas-irma6-base.yml and that the changelog is up-to-date before merging the release."

start-support: git-flow
	@[ -n "${TAG}" ] || { echo "Error: Please specify the TAG variable" >&2; exit 1; }
	git flow support start --showcommands ${TAG} develop
	@echo "Info: Setting fixed refspecs on layer repos for you..."
	${KAS_COMMAND} for-all-repos kas-irma6-pa.yml 'if [ "$${KAS_REPO_NAME}" = "meta-iris" ]; then yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git describe --tags --always)\"" -i ../kas-irma6-pa.yml; elif [ "$${KAS_REPO_NAME} != "this" ]; then yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git describe --tags --always)\"" -i ../kas-irma6-base.yml; fi'
	git add -A
	git commit -m "Set fixed repo refspecs for support release ${TAG}"
	@echo "Warning: Please make sure you adjust "IRMA6_DISTRO_VERSION" in kas-irma6-base.yml and that the changelog is up-to-date before tagging the support release."
