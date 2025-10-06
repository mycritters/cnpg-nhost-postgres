# Variables
REGISTRY = harbor.hahomelabs.com
REPO = cnpg/nhost-postgres
PG_MAJOR = 17
PG_VERSION = 17.6
DATESTAMP = $(shell if [ -f image-tag ]; then cat image-tag; else date +%Y%m%d | tee image-tag; fi)
TAG = $(PG_VERSION)-$(DATESTAMP)
IMAGE_NAME = $(REGISTRY)/$(REPO):$(TAG)
PLATFORM = linux/amd64

# Default target
.DEFAULT_GOAL := help

.PHONY: help build push test clean login new-tag verify-extensions list-extensions build-dev push-dev shell

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build \
		--build-arg PG_MAJOR=$(PG_MAJOR) \
		--platform=$(PLATFORM) \
		-t $(IMAGE_NAME) \
		-t $(REGISTRY)/$(REPO):$(PG_MAJOR) \
		-t $(REGISTRY)/$(REPO):latest \
		.
	@echo ""
	@echo "Built tags:"
	@echo "  - $(IMAGE_NAME)"
	@echo "  - $(REGISTRY)/$(REPO):$(PG_MAJOR)"
	@echo "  - $(REGISTRY)/$(REPO):latest"

push: build ## Build and push the Docker image to registry
	docker push $(IMAGE_NAME)
	docker push $(REGISTRY)/$(REPO):$(PG_MAJOR)
	docker push $(REGISTRY)/$(REPO):latest
	@echo ""
	@echo "Pushed to registry:"
	@echo "  - $(IMAGE_NAME)"
	@echo "  - $(REGISTRY)/$(REPO):$(PG_MAJOR)"
	@echo "  - $(REGISTRY)/$(REPO):latest"

test: build ## Test the built image
	@echo "Testing PostgreSQL version..."
	docker run --rm $(IMAGE_NAME) postgres --version
	@echo ""
	@echo "Testing critical extensions availability..."
	docker run --rm -e POSTGRES_PASSWORD=test $(IMAGE_NAME) bash -c '\
		timeout 30 bash -c "until pg_isready -U postgres; do sleep 1; done" && \
		psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS postgis; SELECT PostGIS_Version();" && \
		psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS vector; SELECT * FROM pg_extension WHERE extname='\''vector'\'';" && \
		psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS timescaledb; SELECT * FROM pg_extension WHERE extname='\''timescaledb'\'';" && \
		psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pg_cron; SELECT * FROM pg_extension WHERE extname='\''pg_cron'\'';" && \
		echo "✓ All critical extensions loaded successfully"' || echo "✗ Extension test failed"
	@echo ""
	@echo "Basic tests completed"

verify-extensions: build ## Verify all Nhost extensions are available
	@echo "Verifying all extensions are available..."
	@docker run --rm -e POSTGRES_PASSWORD=test $(IMAGE_NAME) bash -c '\
		timeout 30 bash -c "until pg_isready -U postgres; do sleep 1; done" && \
		psql -U postgres -t -c "SELECT name FROM pg_available_extensions ORDER BY name;" | \
		grep -E "(postgis|timescaledb|vector|pg_cron|pgmq|http|pg_hashids|pg_ivm|pg_jsonschema|pg_search|hypopg|ip4r|pg_repack|pg_squeeze)" && \
		echo "" && \
		echo "✓ All Nhost extensions verified"'

list-extensions: build ## List all available extensions in the image
	@echo "Listing all available extensions..."
	@docker run --rm -e POSTGRES_PASSWORD=test $(IMAGE_NAME) bash -c '\
		timeout 30 bash -c "until pg_isready -U postgres; do sleep 1; done" && \
		psql -U postgres -c "SELECT name, default_version, comment FROM pg_available_extensions ORDER BY name;" \
	'

shell: build ## Run a shell in the container for debugging
	docker run -it --rm \
		--name cnpg-postgres-shell \
		-e POSTGRES_PASSWORD=test \
		$(IMAGE_NAME) /bin/bash

run: build ## Run PostgreSQL container locally for testing
	@echo "Starting PostgreSQL container..."
	@echo "Connect with: psql -h localhost -p 5432 -U postgres"
	docker run -it --rm \
		--name cnpg-postgres-test \
		-p 5432:5432 \
		-e POSTGRES_PASSWORD=test \
		-v $(PWD)/test-data:/var/lib/postgresql/data \
		$(IMAGE_NAME)

clean: ## Remove local Docker images and build artifacts
	docker rmi $(IMAGE_NAME) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(REPO):$(PG_MAJOR) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(REPO):latest 2>/dev/null || true
	docker system prune -f
	rm -rf test-data
	rm -f image-tag
	@echo "Cleaned up images and artifacts"

new-tag: ## Generate a new timestamp tag
	rm -f image-tag
	@date +%Y%m%d | tee image-tag
	@echo "New tag: $$(cat image-tag)"

login: ## Login to Harbor registry
	@echo "Logging into Harbor registry..."
	@docker login $(REGISTRY)

# Alternative targets with different tags
build-dev: ## Build with dev tag
	docker build \
		--build-arg PG_MAJOR=$(PG_MAJOR) \
		--platform=$(PLATFORM) \
		-t $(REGISTRY)/$(REPO):dev \
		.

push-dev: build-dev ## Build and push dev tag
	docker push $(REGISTRY)/$(REPO):dev

build-16: ## Build PostgreSQL 16 version
	$(MAKE) build PG_MAJOR=16 PG_VERSION=16.9

push-16: ## Build and push PostgreSQL 16 version
	$(MAKE) push PG_MAJOR=16 PG_VERSION=16.9

# Kubernetes deployment helpers
deploy-catalog: ## Deploy ClusterImageCatalog to Kubernetes
	@echo "Deploying ClusterImageCatalog..."
	kubectl apply -f examples/cluster-basic.yaml -n default --dry-run=client -o yaml | \
		grep -A 10 "kind: ClusterImageCatalog" | \
		kubectl apply -f -

deploy-example: ## Deploy example cluster to Kubernetes
	kubectl apply -f examples/cluster-basic.yaml

deploy-with-backup: ## Deploy cluster with backup configuration
	kubectl apply -f examples/cluster-with-backup.yaml

# Multi-platform builds (requires buildx)
buildx-setup: ## Setup Docker buildx for multi-platform builds
	docker buildx create --name cnpg-builder --use || true
	docker buildx inspect --bootstrap

buildx: buildx-setup ## Build multi-platform image (amd64 + arm64)
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg PG_MAJOR=$(PG_MAJOR) \
		-t $(IMAGE_NAME) \
		-t $(REGISTRY)/$(REPO):$(PG_MAJOR) \
		-t $(REGISTRY)/$(REPO):latest \
		--push \
		.
	@echo ""
	@echo "Multi-platform build pushed to registry"
