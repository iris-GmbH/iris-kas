USER_ID ?= $(shell id -u)
GROUP_ID ?= $(shell id -g)
SSH_DIR ?= ~/.ssh
KAS_COMMAND ?= USER_ID=$(USER_ID) GROUP_ID=$(GROUP_ID) SSH_DIR=$(SSH_DIR) docker-compose run --rm kas

git-flow:
	git flow init -d

start-release: git-flow
	@[ -n "$(TAG)" ] || { echo "Error: Please specify the TAG variable" >&2; exit 1; }
	git flow release start --showcommands $(TAG) develop
	@echo "Info: Setting fixed refspecs on layer repos for you..."
	$(KAS_COMMAND) for-all-repos kas-irma6-pa.yml 'if [ "$$(echo $${KAS_REPO_NAME})" = "meta-iris" ]; then yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git describe --tags --always)\"" -i ../kas-irma6-pa.yml; else yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git describe --tags --always)\"" -i ../kas-irma6-base.yml; fi'
	git add -A
	git commit -m "Set fixed repo refspecs for release $(TAG)"
	@echo "Warning: Please make sure you adjust "IRMA6_DISTRO_VERSION" in kas-irma6-base.yml and that the changelog is up-to-date before merging the release."

start-support: git-flow
	@[ -n "$(TAG)" ] || { echo "Error: Please specify the TAG variable" >&2; exit 1; }
	git flow support start --showcommands $(TAG) develop
	@echo "Info: Setting fixed refspecs on layer repos for you..."
	$(KAS_COMMAND) for-all-repos kas-irma6-pa.yml 'if [ "$$(echo $${KAS_REPO_NAME})" = "meta-iris" ]; then yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git describe --tags --always)\"" -i ../kas-irma6-pa.yml; else yq e ".repos.$${KAS_REPO_NAME}.refspec = \"$$(git describe --tags --always)\"" -i ../kas-irma6-base.yml; fi'
	git add -A
	git commit -m "Set fixed repo refspecs for support release $(TAG)"
	@echo "Warning: Please make sure you adjust "IRMA6_DISTRO_VERSION" in kas-irma6-base.yml and that the changelog is up-to-date before tagging the support release."
