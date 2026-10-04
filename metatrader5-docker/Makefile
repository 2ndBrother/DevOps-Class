SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help init config build up down restart status logs smoke backup export checksums validate

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "%-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Create .env and the local VNC password
	./scripts/init.sh

config: ## Render and validate the Compose model
	VNC_PASSWORD_FILE_HOST=/dev/null docker compose config --quiet

build: ## Build or refresh the MT5 image
	docker compose build --pull

up: ## Start the service in the background
	docker compose up -d

down: ## Stop the service without deleting persistent data
	docker compose down

restart: ## Restart the MT5 service
	docker compose restart mt5

status: ## Show container and supervised-process state
	./scripts/status.sh

logs: ## Follow container and MT5 journal output
	docker compose logs -f --tail=200 mt5

smoke: ## Wait for and verify a healthy deployment
	./scripts/smoke-test.sh

backup: ## Create a stopped-volume backup under backups/
	./scripts/backup-data.sh

export: ## Export the reusable image under backups/
	./scripts/export-image.sh

checksums: ## Regenerate the repository integrity manifest
	./scripts/update-checksums.sh

validate: ## Run local static and integrity checks
	./scripts/validate.sh
