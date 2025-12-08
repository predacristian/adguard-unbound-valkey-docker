.PHONY: help build up down restart logs test test-unbound test-valkey test-adguard clean shell status health

# Default target
.DEFAULT_GOAL := help

# Docker Compose command
COMPOSE := docker-compose

# Image name (override with: make push IMAGE_NAME=yourname/dns-stack)
IMAGE_NAME ?= dns-stack
IMAGE_TAG ?= latest

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@echo "$(BLUE)DNS Stack - Makefile Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(YELLOW)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build

build: ## Build the Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	$(COMPOSE) build

rebuild: ## Rebuild the Docker image from scratch (no cache)
	@echo "$(BLUE)Rebuilding Docker image (no cache)...$(NC)"
	$(COMPOSE) build --no-cache

##@ Local Development

up: ## Start the DNS stack locally
	@echo "$(GREEN)Starting DNS stack...$(NC)"
	$(COMPOSE) up -d
	@echo "$(GREEN)DNS stack is starting. Use 'make logs' to view logs or 'make status' to check status.$(NC)"
	@echo ""
	@echo "$(BLUE)Access points:$(NC)"
	@echo "  DNS: localhost:53"
	@echo "  DNS over TLS: localhost:853"
	@echo "  AdGuard Web UI: http://localhost:3000"
	@echo "  Default credentials: admin/admin"

down: ## Stop the DNS stack
	@echo "$(YELLOW)Stopping DNS stack...$(NC)"
	$(COMPOSE) down

restart: ## Restart the DNS stack
	@echo "$(YELLOW)Restarting DNS stack...$(NC)"
	$(COMPOSE) restart

logs: ## View logs (follow mode)
	$(COMPOSE) logs -f

status: ## Show container status
	@echo "$(BLUE)Container Status:$(NC)"
	@$(COMPOSE) ps

health: ## Check health status
	@echo "$(BLUE)Health Status:$(NC)"
	@docker inspect --format='{{.State.Health.Status}}' dns-stack 2>/dev/null || echo "$(RED)Container not running$(NC)"

##@ Testing

test: build ## Run all tests (builds image first, includes integration tests)
	@echo "$(BLUE)Running all tests...$(NC)"
	@echo ""
	@echo "$(YELLOW)Starting test container...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(YELLOW)Waiting for services to be healthy (max 90s)...$(NC)"
	@counter=0; \
	while [ $$counter -lt 18 ]; do \
		if docker inspect --format='{{.State.Health.Status}}' dns-stack 2>/dev/null | grep -q "healthy"; then \
			echo "$(GREEN)Services are healthy!$(NC)"; \
			break; \
		fi; \
		counter=$$((counter + 1)); \
		if [ $$counter -eq 18 ]; then \
			echo "$(RED)Timeout waiting for services to be healthy$(NC)"; \
			$(COMPOSE) logs; \
			exit 1; \
		fi; \
		echo "Waiting... ($$counter/18)"; \
		sleep 5; \
	done
	@echo ""
	@echo "$(BLUE)=== Running Smoke Tests ===$ $(NC)"
	@echo "$(BLUE)Running Unbound tests...$(NC)"
	@docker exec dns-stack /tests/test_unbound.sh || (echo "$(RED)Unbound tests failed$(NC)" && exit 1)
	@echo ""
	@echo "$(BLUE)Running Valkey tests...$(NC)"
	@docker exec dns-stack /tests/test_valkey.sh || (echo "$(RED)Valkey tests failed$(NC)" && exit 1)
	@echo ""
	@echo "$(BLUE)Running AdGuard tests...$(NC)"
	@docker exec dns-stack /tests/test_adguard.sh || (echo "$(RED)AdGuard tests failed$(NC)" && exit 1)
	@echo ""
	@echo "$(BLUE)=== Running Integration Tests ===$(NC)"
	@echo "$(BLUE)Running cache integration tests...$(NC)"
	@docker exec dns-stack /tests/test_cache_integration.sh || (echo "$(RED)Cache integration tests failed$(NC)" && exit 1)
	@echo ""
	@echo "$(BLUE)Running E2E query tests...$(NC)"
	@docker exec dns-stack /tests/test_e2e_query.sh || (echo "$(RED)E2E tests failed$(NC)" && exit 1)
	@echo ""
	@echo "$(BLUE)Running ad blocking tests...$(NC)"
	@docker exec dns-stack /tests/test_ad_blocking.sh || (echo "$(RED)Ad blocking tests failed$(NC)" && exit 1)
	@echo ""
	@echo "$(BLUE)Running DoT tests...$(NC)"
	@docker exec dns-stack /tests/test_dot.sh || echo "$(YELLOW)DoT tests skipped (not configured)$(NC)"
	@echo ""
	@echo "$(GREEN)✓ All tests passed!$(NC)"
	@$(COMPOSE) down

test-bats: build ## Run BATS integration tests
	@echo "$(BLUE)Running BATS integration tests...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(YELLOW)Waiting for services (45s)...$(NC)"
	@sleep 45
	@docker exec dns-stack bats /tests/integration.bats || (echo "$(RED)BATS tests failed$(NC)" && $(COMPOSE) down && exit 1)
	@echo "$(GREEN)✓ BATS tests passed!$(NC)"
	@$(COMPOSE) down

test-smoke: ## Run only smoke tests (basic functionality)
	@echo "$(BLUE)Running smoke tests...$(NC)"
	@docker exec dns-stack /tests/test_unbound.sh && \
	 docker exec dns-stack /tests/test_valkey.sh && \
	 docker exec dns-stack /tests/test_adguard.sh && \
	 echo "$(GREEN)✓ Smoke tests passed!$(NC)" || echo "$(RED)✗ Smoke tests failed$(NC)"

test-integration: ## Run only integration tests (container must be running)
	@echo "$(BLUE)Running integration tests...$(NC)"
	@docker exec dns-stack /tests/test_cache_integration.sh && \
	 docker exec dns-stack /tests/test_e2e_query.sh && \
	 docker exec dns-stack /tests/test_ad_blocking.sh && \
	 echo "$(GREEN)✓ Integration tests passed!$(NC)" || echo "$(RED)✗ Integration tests failed$(NC)"

test-unbound: ## Run only Unbound tests (container must be running)
	@echo "$(BLUE)Running Unbound tests...$(NC)"
	@docker exec dns-stack /tests/test_unbound.sh

test-valkey: ## Run only Valkey tests (container must be running)
	@echo "$(BLUE)Running Valkey tests...$(NC)"
	@docker exec dns-stack /tests/test_valkey.sh

test-adguard: ## Run only AdGuard tests (container must be running)
	@echo "$(BLUE)Running AdGuard tests...$(NC)"
	@docker exec dns-stack /tests/test_adguard.sh

test-cache: ## Run only cache integration tests (container must be running)
	@echo "$(BLUE)Running cache integration tests...$(NC)"
	@docker exec dns-stack /tests/test_cache_integration.sh

test-e2e: ## Run only E2E query path tests (container must be running)
	@echo "$(BLUE)Running E2E query tests...$(NC)"
	@docker exec dns-stack /tests/test_e2e_query.sh

test-ad-blocking: ## Run only ad blocking tests (container must be running)
	@echo "$(BLUE)Running ad blocking tests...$(NC)"
	@docker exec dns-stack /tests/test_ad_blocking.sh

test-dot: ## Run only DoT tests (container must be running)
	@echo "$(BLUE)Running DoT tests...$(NC)"
	@docker exec dns-stack /tests/test_dot.sh

quick-test: ## Quick smoke test without rebuild (uses existing image)
	@echo "$(YELLOW)Quick test mode - using existing image$(NC)"
	@$(COMPOSE) up -d
	@echo "$(YELLOW)Waiting for services (45s)...$(NC)"
	@sleep 45
	@echo "$(BLUE)Running tests...$(NC)"
	@docker exec dns-stack /tests/test_unbound.sh && \
	 docker exec dns-stack /tests/test_valkey.sh && \
	 docker exec dns-stack /tests/test_adguard.sh && \
	 echo "$(GREEN)✓ All tests passed!$(NC)" || echo "$(RED)✗ Tests failed$(NC)"
	@$(COMPOSE) down

##@ Utilities

shell: ## Open a shell in the running container
	@docker exec -it dns-stack /bin/sh

watch: ## Watch logs in real-time with timestamps
	$(COMPOSE) logs -f --timestamps

ps: ## Show detailed container information
	@docker ps -a --filter "name=dns-stack" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

clean: ## Remove containers and volumes
	@echo "$(RED)Cleaning up containers and volumes...$(NC)"
	$(COMPOSE) down -v
	@echo "$(YELLOW)Removing data directory...$(NC)"
	@rm -rf ./data
	@echo "$(GREEN)Cleanup complete!$(NC)"

clean-all: clean ## Remove everything including Docker images
	@echo "$(RED)Removing Docker images...$(NC)"
	@docker rmi dns-stack:latest 2>/dev/null || true
	@echo "$(GREEN)Full cleanup complete!$(NC)"

##@ Docker Registry

tag: ## Tag the image (usage: make tag IMAGE_NAME=user/dns-stack IMAGE_TAG=v1.0.0)
	@echo "$(BLUE)Tagging image as $(IMAGE_NAME):$(IMAGE_TAG)...$(NC)"
	@docker tag dns-stack:latest $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)Tagged as $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"

push: tag ## Tag and push to Docker registry
	@echo "$(BLUE)Pushing $(IMAGE_NAME):$(IMAGE_TAG) to registry...$(NC)"
	@docker push $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)Image pushed successfully!$(NC)"
