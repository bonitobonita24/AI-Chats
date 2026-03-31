# Load local overrides (gitignored)
-include Makefile.local
IMAGE ?= your-dockerhub-username/chatstash

.PHONY: dev dev-down dev-logs dev-restart release setup test

## First-time setup — copy example files to real ones
setup:
	@test -f docker-compose.dev.yml || (cp docker-compose.dev.example.yml docker-compose.dev.yml && echo "Created docker-compose.dev.yml")
	@test -f docker-compose.staging.yml || (cp docker-compose.staging.example.yml docker-compose.staging.yml && echo "Created docker-compose.staging.yml")
	@test -f docker-compose.komodo.yml || (cp docker-compose.komodo.example.yml docker-compose.komodo.yml && echo "Created docker-compose.komodo.yml")
	@test -f .env.dev || (cp .env.example .env.dev && echo "Created .env.dev — edit with your values")
	@test -f tampermonkey-script.md || (cp tampermonkey-script.example.md tampermonkey-script.md && echo "Created tampermonkey-script.md — edit API_URL")
	@echo "Setup complete. Edit the created files with your values."

## Start dev environment — builds image locally and runs on port 4287
dev:
	@test -f docker-compose.dev.yml || (echo "Run 'make setup' first" && exit 1)
	docker compose -f docker-compose.dev.yml up -d --build

## Stop dev environment
dev-down:
	docker compose -f docker-compose.dev.yml down

## Stream dev container logs
dev-logs:
	docker compose -f docker-compose.dev.yml logs -f

## Restart dev container without rebuilding
dev-restart:
	docker compose -f docker-compose.dev.yml restart

## Build production image and push to Docker Hub (tagged with git SHA + latest)
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_TAG := $(shell git describe --tags --exact-match 2>/dev/null || echo "")

release:
	docker build --target production -t $(IMAGE):$(GIT_SHA) -t $(IMAGE):latest .
	docker push $(IMAGE):$(GIT_SHA)
	docker push $(IMAGE):latest
	@if [ -n "$(GIT_TAG)" ]; then \
		docker tag $(IMAGE):$(GIT_SHA) $(IMAGE):$(GIT_TAG); \
		docker push $(IMAGE):$(GIT_TAG); \
		echo "Also pushed $(IMAGE):$(GIT_TAG)"; \
	fi
	@echo "Released $(IMAGE):$(GIT_SHA) + :latest"

## Run browser smoke test
test:
	node scripts/browser-test.mjs
