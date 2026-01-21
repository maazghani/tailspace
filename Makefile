.PHONY: help test install-local install-cli build clean

.DEFAULT_GOAL := help

help:
	@echo "Tailspace Dev Container"
	@echo ""
	@echo "Targets:"
	@echo "  test               Run verification tests"
	@echo "  install-local      Run the setup script"
	@echo "  install-cli        Install @devcontainers/cli"
	@echo "  build              Build devcontainer image"
	@echo "  clean              Clean up images"
	@echo ""

test:
	@bash test.sh

install-local:
	@bash .devcontainer/devcontainer-setup.sh

install-cli:
	@command -v npm > /dev/null || (echo "npm not found. Please install Node.js"; exit 1)
	npm install -g @devcontainers/cli

build: install-cli
	@devcontainer build --workspace-folder . --image-name tailspace/devcontainer:local

clean:
	@docker rmi -f tailspace/devcontainer:local 2>/dev/null || true
