# Music App GitOps Deployment Makefile
# =====================================

# Configuration
CLUSTER_NAME ?= localdev
CLUSTER_DOMAIN ?= local.io
HTTP_PORT ?= 8888
HTTPS_PORT ?= 4443
GIT_REPO_URL ?= https://github.com/your-username/your-repo.git

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)Music App GitOps Deployment$(NC)"
	@echo "================================"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Main workflow:$(NC)"
	@echo "  make infra_setup    # Setup K3D cluster with ArgoCD"
	@echo "  make app_build      # Build the music application"
	@echo "  make app_deploy     # Deploy using GitOps"
	@echo "  make app_test       # Test the deployment"
	@echo ""
	@echo "$(GREEN)Or run everything:$(NC)"
	@echo "  make all            # Complete deployment workflow"
	@echo ""
	@echo "$(GREEN)Configuration:$(NC)"
	@echo "  CLUSTER_NAME=$(CLUSTER_NAME)"
	@echo "  CLUSTER_DOMAIN=$(CLUSTER_DOMAIN)"
	@echo "  HTTP_PORT=$(HTTP_PORT)"
	@echo "  HTTPS_PORT=$(HTTPS_PORT)"
	@echo "  GIT_REPO_URL=$(GIT_REPO_URL)"

# Main workflow targets
.PHONY: all
all: infra_setup app_build app_deploy app_test ## Complete deployment workflow

.PHONY: infra_setup
infra_setup: ## Setup K3D cluster with ArgoCD and all infrastructure
	@echo "$(BLUE)[STEP]$(NC) Setting up infrastructure..."
	@./infra/setup.sh
	@echo "$(GREEN)[INFO]$(NC) Infrastructure setup completed"

.PHONY: app_build
app_build: ## Build the music application
	@echo "$(BLUE)[STEP]$(NC) Building music application..."
	@./apps/music-app/build.sh
	@echo "$(GREEN)[INFO]$(NC) Application build completed"

.PHONY: app_deploy
app_deploy: ## Deploy application using GitOps
	@echo "$(BLUE)[STEP]$(NC) Deploying application with GitOps..."
	@./apps/music-app/deploy.sh
	@echo "$(GREEN)[INFO]$(NC) Application deployment completed"

.PHONY: app_test
app_test: ## Test the deployed application
	@echo "$(BLUE)[STEP]$(NC) Testing application..."
	@./apps/music-app/test.sh
	@echo "$(GREEN)[INFO]$(NC) Application testing completed"

# Individual component targets
.PHONY: infra_status
infra_status: ## Check infrastructure status
	@echo "$(BLUE)[STEP]$(NC) Checking infrastructure status..."
	@./infra/status.sh

.PHONY: infra_cleanup
infra_cleanup: ## Cleanup infrastructure
	@echo "$(BLUE)[STEP]$(NC) Cleaning up infrastructure..."
	@./infra/cleanup.sh

.PHONY: app_cleanup
app_cleanup: ## Cleanup application
	@echo "$(BLUE)[STEP]$(NC) Cleaning up application..."
	@./apps/music-app/cleanup.sh

.PHONY: app_logs
app_logs: ## Show application logs
	@echo "$(BLUE)[STEP]$(NC) Showing application logs..."
	@kubectl logs -f deployment/music-app -n music-app

.PHONY: app_scale
app_scale: ## Scale application replicas
	@echo "$(BLUE)[STEP]$(NC) Scaling application..."
	@kubectl scale deployment music-app --replicas=3 -n music-app

# Development targets
.PHONY: dev_setup
dev_setup: ## Setup development environment
	@echo "$(BLUE)[STEP]$(NC) Setting up development environment..."
	@echo "Development environment setup - use 'make infra_setup' for infrastructure"

.PHONY: dev_test
dev_test: ## Run development tests
	@echo "$(BLUE)[STEP]$(NC) Running development tests..."
	@make app_test

# Utility targets
.PHONY: check-deps
check-deps: ## Check if all dependencies are installed
	@echo "$(BLUE)[STEP]$(NC) Checking dependencies..."
	@./scripts/check-deps.sh

.PHONY: update-configs
update-configs: ## Update configuration files
	@echo "$(BLUE)[STEP]$(NC) Updating configurations..."
	@echo "Configuration files are in configs/ directory"

.PHONY: backup
backup: ## Backup current configuration
	@echo "$(BLUE)[STEP]$(NC) Creating backup..."
	@echo "Backup functionality - manually backup configs/ and apps/ directories"

.PHONY: restore
restore: ## Restore from backup
	@echo "$(BLUE)[STEP]$(NC) Restoring from backup..."
	@echo "Restore functionality - manually restore from backup"

# Clean targets
.PHONY: clean
clean: app_cleanup ## Clean application only

.PHONY: clean-all
clean-all: app_cleanup infra_cleanup ## Clean everything

# Documentation targets
.PHONY: docs
docs: ## Generate documentation
	@echo "$(BLUE)[STEP]$(NC) Generating documentation..."
	@echo "Documentation is in README.md"

.PHONY: readme
readme: ## Update README files
	@echo "$(BLUE)[STEP]$(NC) Updating README files..."
	@echo "README.md is up to date"

# Monitoring targets
.PHONY: monitor
monitor: ## Start monitoring
	@echo "$(BLUE)[STEP]$(NC) Starting monitoring..."
	@echo "Access monitoring at:"
	@echo "  Grafana: http://grafana.$(CLUSTER_DOMAIN):$(HTTP_PORT)"
	@echo "  Prometheus: http://prometheus.$(CLUSTER_DOMAIN):$(HTTP_PORT)"

.PHONY: status
status: ## Show overall status
	@echo "$(BLUE)[STEP]$(NC) Showing overall status..."
	@./scripts/status.sh

# GitOps specific targets
.PHONY: gitops-sync
gitops-sync: ## Sync GitOps application
	@echo "$(BLUE)[STEP]$(NC) Syncing GitOps application..."
	@argocd app sync music-app

.PHONY: gitops-status
gitops-status: ## Check GitOps status
	@echo "$(BLUE)[STEP]$(NC) Checking GitOps status..."
	@argocd app get music-app

# Quick targets for common operations
.PHONY: quick-deploy
quick-deploy: app_build app_deploy ## Quick deploy (skip infra setup)

.PHONY: quick-test
quick-test: app_test ## Quick test only

.PHONY: restart
restart: app_cleanup app_deploy ## Restart application

# Environment-specific targets
.PHONY: dev
dev: ## Deploy to development environment
	@echo "$(BLUE)[STEP]$(NC) Deploying to development environment..."
	@CLUSTER_DOMAIN=dev.local.io make all

.PHONY: staging
staging: ## Deploy to staging environment
	@echo "$(BLUE)[STEP]$(NC) Deploying to staging environment..."
	@CLUSTER_DOMAIN=staging.local.io make all

.PHONY: prod
prod: ## Deploy to production environment
	@echo "$(BLUE)[STEP]$(NC) Deploying to production environment..."
	@CLUSTER_DOMAIN=prod.local.io make all

# Include environment-specific makefiles if they exist
-include Makefile.local
-include Makefile.$(CLUSTER_DOMAIN)

# Print target for debugging
.PHONY: print-vars
print-vars: ## Print all variables
	@echo "CLUSTER_NAME: $(CLUSTER_NAME)"
	@echo "CLUSTER_DOMAIN: $(CLUSTER_DOMAIN)"
	@echo "HTTP_PORT: $(HTTP_PORT)"
	@echo "HTTPS_PORT: $(HTTPS_PORT)"
	@echo "GIT_REPO_URL: $(GIT_REPO_URL)"
