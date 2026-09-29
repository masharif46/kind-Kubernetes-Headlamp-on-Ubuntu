SHELL := /usr/bin/env bash

CLUSTER_NAME ?= k8s-137
MODE ?= single

.PHONY: help install gui create status clusters remove test-ha validate

help:
	@echo "Available commands:"
	@echo "  make install              Install kind, kubectl, and the default cluster"
	@echo "  make gui                  Install Headlamp GUI"
	@echo "  make create MODE=single   Create a single, multinode, or HA cluster"
	@echo "  make status               Show nodes and cluster information"
	@echo "  make clusters             List kind clusters"
	@echo "  make remove               Remove the selected cluster"
	@echo "  make test-ha              Run the automated HA test"
	@echo "  make validate             Run Bash and ShellCheck validation"

install:
	bash install-kind.sh

gui:
	bash install-headlamp.sh

create:
	bash cluster-kind.sh create "$(MODE)" --name "$(CLUSTER_NAME)"

status:
	bash cluster-kind.sh status --name "$(CLUSTER_NAME)"

clusters:
	bash cluster-kind.sh list

remove:
	bash cluster-kind.sh remove --name "$(CLUSTER_NAME)"

test-ha:
	bash test-ha.sh

validate:
	bash -n install-kind.sh cluster-kind.sh install-headlamp.sh test-ha.sh uninstall-kind.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck install-kind.sh cluster-kind.sh install-headlamp.sh test-ha.sh uninstall-kind.sh; \
	else \
		echo "shellcheck is not installed; Bash syntax validation passed."; \
	fi
