# Load local overrides (gitignored) — set IMAGE there
-include Makefile.local
IMAGE ?= your-dockerhub-username/ai-chats

.PHONY: dev dev-down dev-logs dev-restart release

## Start dev environment — builds image locally and runs on port 4287
dev:
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

## Build production image and push to Docker Hub
release:
	docker build --target production -t $(IMAGE):latest .
	docker push $(IMAGE):latest
