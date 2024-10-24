PROJECT := cookiecutter-python
VERSION := 0.5.0
ROOT_DIR := $(shell git rev-parse --show-toplevel)
MAKEFILE_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))

# Find all .tool-versions files in the project directory
# This variable will contain the full paths to all .tool-versions files
#
# Example:
# If ROOT_DIR is /home/user/project, and the following .tool-versions files exist:
#   /home/user/project/.tool-versions
#   /home/user/project/subdir/.tool-versions
#   /home/user/project/another/nested/dir/.tool-versions
#
# Then TOOL_VERSION_FILES will contain:
#   /home/user/project/.tool-versions
#   /home/user/project/subdir/.tool-versions
#   /home/user/project/another/nested/dir/.tool-versions
TOOL_VERSION_FILES := $(shell find $(ROOT_DIR) -type f -name '.tool-versions')
ENV_EXAMPLE_FILES := $(shell find $(ROOT_DIR) -type f -name 'env.example')

# Define TOOL_VERSION_FILE_TARGETS by removing the ROOT_DIR prefix from each TOOL_VERSION_FILES path
# and replacing any '/' with '_' to create valid Makefile targets
#
# This creates a list of relative paths for .tool-versions files, with directory separators replaced
#
# Examples:
# If ROOT_DIR is /home/user/project and TOOL_VERSION_FILES contains:
#   /home/user/project/.tool-versions
#   /home/user/project/subdir/.tool-versions
#   /home/user/project/deep/nested/dir/.tool-versions
# Then TOOL_VERSION_FILE_TARGETS will contain:
#   .tool-versions
#   subdir_.tool-versions
#   deep_nested_dir_.tool-versions
TOOL_VERSION_FILE_TARGETS := $(subst /,_,$(TOOL_VERSION_FILES:$(ROOT_DIR)/%=%))
ENV_EXAMPLE_FILE_TARGETS := $(subst /,_,$(ENV_EXAMPLE_FILES:$(ROOT_DIR)/%=%))

# Define ASDF_PLUGIN_TARGETS as a list of unique plugin names from all .tool-versions files
#
# This variable will contain a sorted list of unique plugin names extracted from
# all .tool-versions files in the project.
#
# Example:
# If TOOL_VERSION_FILES contains:
#   /home/user/project/.tool-versions (content: "python 3.9.0\nnode 14.15.0")
#   /home/user/project/subdir/.tool-versions (content: "ruby 3.0.0\nnode 14.15.0")
#
# Then ASDF_PLUGIN_TARGETS will contain:
#   node python ruby
ASDF_PLUGIN_TARGETS := $(shell awk 'NF {print $$1}' $(TOOL_VERSION_FILES) | sort -u)

.PHONY: reset
reset: clean
	@rm -f Brewfile.lock.json
	@rm -rf node_modules
	@rm -f .git/hooks/commit-msg

.PHONY: clean
clean: --clean-build --clean-pyc --clean-venv

--clean-build:
	@rm -rf $(ROOT_DIR)/dist
	@rm -rf $(ROOT_DIR)/.eggs
	@find $(ROOT_DIR) -name '*.egg-info' -exec rm -rf {} +
	@find $(ROOT_DIR) -name '*.egg' -exec rm -rf {} +

--clean-pyc:
	@find $(ROOT_DIR) -name '*.pyc' -exec rm -f {} +
	@find $(ROOT_DIR) -name '*.pyo' -exec rm -f {} +
	@find $(ROOT_DIR) -name '*~' -exec rm -f {} +
	@find $(ROOT_DIR) -name '__pycache__' -exec rm -rf {} +

--clean-venv:
	@rm -rf $(VIRTUAL_ENV)
	@rm -f requirements-dev.txt
	@rm -f requirements.txt

.PHONY: install
install: sync-venv
install: $(ENV_EXAMPLE_FILE_TARGETS)
install: node_modules/.package-lock.json
install: .git/hooks/commit-msg
install: $(ASDF_PLUGIN_TARGETS) $(TOOL_VERSION_FILE_TARGETS)
install: Brewfile.lock.json
	@pip install --no-deps -e .

Brewfile.lock.json: Brewfile
	@brew bundle

$(ASDF_PLUGIN_TARGETS): ASDF_PLUGIN = $@
$(ASDF_PLUGIN_TARGETS):
	@asdf plugin add $(ASDF_PLUGIN) || true

$(TOOL_VERSION_FILE_TARGETS): TOOL_VERSION_FILE = $(ROOT_DIR)/$(subst _,/,$(@))
$(TOOL_VERSION_FILE_TARGETS):
	@cd `dirname $(TOOL_VERSION_FILE)` && asdf install

node_modules/.package-lock.json: package.json
	@npm install

.git/hooks/commit-msg: .pre-commit-config.yaml
	@pre-commit install --hook-type commit-msg

$(ENV_EXAMPLE_FILE_TARGETS): ENV_EXAMPLE_FILE = $(ROOT_DIR)/$(subst _,/,$(@))
$(ENV_EXAMPLE_FILE_TARGETS):
	@cd `dirname $(ENV_EXAMPLE_FILE)` \
	&& if ! [ -f .env ]; then \
		cp .env.example .env; \
	fi

.PHONY: sync-venv
sync-venv: $(VIRTUAL_ENV)/pyvenv.cfg requirements-dev.txt
	@pip-sync requirements-dev.txt

$(VIRTUAL_ENV)/pyvenv.cfg:
	@python -m venv $(VIRTUAL_ENV)
	@pip install --upgrade pip
	@pip install --upgrade pip-tools

requirements-dev.txt: pyproject.toml
	@pip-compile --generate-hashes --allow-unsafe --extra dev --output-file $@ pyproject.toml

requirements.txt: pyproject.toml
	@pip-compile --generate-hashes --allow-unsafe pyproject.toml

.PHONY: format
format: --format-python --format-other

--format-python:
	# unused imports
	@autoflake --in-place \
		--exclude "$$VIRTUAL_ENV" \
		--recursive \
		--remove-all-unused-imports \
		--ignore-init-module-imports \
		--remove-duplicate-keys \
		--remove-unused-variables .

	# sort imports
	@isort --virtual-env="$$VIRTUAL_ENV" .

	# python code
	@black .

--format-other:
	@npm run format

.PHONY: lint
lint: --lint-python --lint-docker

--lint-python:
	@flake8 --show-source --statistics

--lint-docker:
	@docker run --rm -i hadolint/hadolint:latest < $(ROOT_DIR)/Dockerfile

.PHONY: scan
scan: --scan-dockle --scan-trivy

# scan docker image for best practices
--scan-dockle: DOCKLE_IGNORES = $(shell awk 'NF {print $1}' $(ROOT_DIR)/.dockleignore | paste -s -d, -)
--scan-dockle: build
	@docker run --rm \
		--env DOCKER_CONTENT_TRUST=1 \
		--env DOCKLE_IGNORES=$(DOCKLE_IGNORES) \
		-v /var/run/docker.sock:/var/run/docker.sock \
		goodwithtech/dockle:latest \
			--timeout 10m \
			--exit-code 1 \
			--exit-level warn \
			$(PROJECT):$(VERSION)

# scan OS and app dependencies for vulnerabilities
--scan-trivy: build
	@docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $${XDG_CACHE_HOME:-$$HOME/.cache}:/root/.cache/ \
		aquasec/trivy:latest \
		image \
			--timeout 10m \
			--ignore-unfixed \
			--exit-code 1 \
			--severity HIGH,CRITICAL \
			$(PROJECT):$(VERSION)

.PHONY: build
build: DOCKER_CONTENT_TRUST=1
build:
	@docker build \
		-t $(PROJECT) \
		-t $(PROJECT):$(VERSION) \
		--build-arg APP_NAME="$(PROJECT)" \
		--build-arg APP_VERSION="$(VERSION)" \
		--build-arg APP_REVISION="$(shell git rev-parse --short HEAD)" \
		.

.PHONY: start
start: build
	@docker run $(PROJECT)

.PHONY: release
release: lint scan version build
	@git push --follow-tags

.PHONY: version
version:
	@cz bump --yes

.gitignore:
	@git ignore-io homebrew python node > .gitignore
