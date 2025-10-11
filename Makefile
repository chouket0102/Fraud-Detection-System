# Fraud Detection App - AWS Deployment Makefile
# Usage: make <target>
# Example: make deploy-all

# =============================================
# Configuration Variables
# =============================================
AWS_REGION ?= us-east-2
ECR_REPO_NAME ?= fraud-detection-app
CLUSTER_NAME ?= fraud-detection-cluster
SERVICE_NAME ?= fraud-detection-service
TASK_FAMILY ?= fraud-detection-task

# Auto-detect AWS Account ID
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_URI := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME)

# Version tags
VERSION ?= $(shell date +%Y%m%d-%H%M%S)
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")


BUILD_IMAGE ?= $(ECR_REPO_NAME)
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# =============================================
# Helper Targets
# =============================================
.PHONY: help
help: ## Show this help message
	@echo "Fraud Detection App - AWS Deployment"
	@echo ""
	@echo "Configuration:"
	@echo "  AWS Account: $(AWS_ACCOUNT_ID)"
	@echo "  Region:      $(AWS_REGION)"
	@echo "  ECR URI:     $(ECR_URI)"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

.PHONY: check-aws
check-aws: ## Verify AWS CLI is configured
	@echo "Checking AWS configuration..."
	@aws sts get-caller-identity > /dev/null || (echo "AWS CLI not configured!" && exit 1)
	@echo "✓ AWS CLI configured for account: $(AWS_ACCOUNT_ID)"

.PHONY: check-docker
check-docker: ## Verify Docker is running
	@echo "Checking Docker..."
	@docker info > /dev/null 2>&1 || (echo "Docker is not running!" && exit 1)
	@echo "✓ Docker is running"

# =============================================
# ECR Setup
# =============================================
.PHONY: ecr-create
ecr-create: check-aws ## Create ECR repository
	@echo "Creating ECR repository: $(ECR_REPO_NAME)..."
	@aws ecr describe-repositories --repository-names $(ECR_REPO_NAME) --region $(AWS_REGION) 2>/dev/null || \
	aws ecr create-repository \
		--repository-name $(ECR_REPO_NAME) \
		--region $(AWS_REGION) \
		--image-scanning-configuration scanOnPush=true \
		--encryption-configuration encryptionType=AES256
	@echo "✓ ECR repository ready"

.PHONY: ecr-login
ecr-login: check-aws check-docker ## Login to ECR
	@echo "Logging into ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	@echo "✓ Logged into ECR"

.PHONY: ecr-list
ecr-list: ## List images in ECR repository
	@echo "Images in $(ECR_REPO_NAME):"
	@aws ecr list-images --repository-name $(ECR_REPO_NAME) --region $(AWS_REGION)

# =============================================
# Docker Build & Push
# =============================================
.PHONY: build
build: check-docker ## Build Docker image locally
	@echo "Building Docker image..."
	@docker build -t $(ECR_REPO_NAME):latest .
	@echo "✓ Docker image built: $(ECR_REPO_NAME):latest"


build-image:
	docker buildx build --platform "linux/amd64" --tag "$(BUILD_IMAGE):$(GIT_SHA)-build" --target "build" .
	docker buildx build --cache-from "$(BUILD_IMAGE):$(GIT_SHA)-build" --platform "linux/amd64" --tag "$(BUILD_IMAGE):$(GIT_SHA)" .

.PHONY: build-no-cache
build-no-cache: check-docker ## Build Docker image without cache
	@echo "Building Docker image (no cache)..."
	@docker build --no-cache -t $(ECR_REPO_NAME):latest .
	@echo "✓ Docker image built: $(ECR_REPO_NAME):latest"

.PHONY: test-local
test-local: build ## Test Docker image locally
	@echo "Testing Docker image locally..."
	@docker run -d --name fraud-detection-test \
		-p 8080:8080 \
		-e SPRING_PROFILES_ACTIVE=local \
		$(ECR_REPO_NAME):latest
	@echo "✓ Container started. Waiting for health check..."
	@sleep 10
	@curl -f http://localhost:8080/actuator/health && echo "✓ Health check passed" || echo "✗ Health check failed"
	@docker logs fraud-detection-test
	@docker stop fraud-detection-test
	@docker rm fraud-detection-test

.PHONY: tag
tag: ## Tag Docker image for ECR
	@echo "Tagging Docker image..."
	@docker tag $(ECR_REPO_NAME):latest $(ECR_URI):latest
	@docker tag $(ECR_REPO_NAME):latest $(ECR_URI):$(VERSION)
	@docker tag $(ECR_REPO_NAME):latest $(ECR_URI):$(GIT_COMMIT)
	@echo "✓ Image tagged with: latest, $(VERSION), $(GIT_COMMIT)"

.PHONY: push
push: ecr-login tag ## Push Docker image to ECR
	@echo "Pushing Docker image to ECR..."
	@docker push $(ECR_URI):latest
	@docker push $(ECR_URI):$(VERSION)
	@docker push $(ECR_URI):$(GIT_COMMIT)
	@echo "✓ Image pushed to ECR"

.PHONY: build-push
build-push: build push ## Build and push Docker image

# =============================================
# Infrastructure Setup
# =============================================
.PHONY: infra-create
infra-create: check-aws ## Create VPC, subnets, security groups
	@echo "Creating infrastructure..."
	@./scripts/create-infrastructure.sh
	@echo "✓ Infrastructure created"

.PHONY: iam-create
iam-create: check-aws ## Create IAM roles for ECS
	@echo "Creating IAM roles..."
	@./scripts/create-iam-roles.sh
	@echo "✓ IAM roles created"

.PHONY: params-create
params-create: check-aws ## Create Parameter Store parameters
	@echo "Creating Parameter Store parameters..."
	@./scripts/create-parameters.sh
	@echo "✓ Parameters created"

.PHONY: logs-create
logs-create: check-aws ## Create CloudWatch log group
	@echo "Creating CloudWatch log group..."
	@aws logs create-log-group --log-group-name /ecs/fraud-detection --region $(AWS_REGION) 2>/dev/null || true
	@aws logs put-retention-policy --log-group-name /ecs/fraud-detection --retention-in-days 7 --region $(AWS_REGION) 2>/dev/null || true
	@echo "✓ Log group created"

# =============================================
# ECS Deployment
# =============================================
.PHONY: cluster-create
cluster-create: check-aws ## Create ECS cluster
	@echo "Creating ECS cluster: $(CLUSTER_NAME)..."
	@aws ecs create-cluster \
		--cluster-name $(CLUSTER_NAME) \
		--region $(AWS_REGION) \
		--settings name=containerInsights,value=enabled 2>/dev/null || echo "Cluster may already exist"
	@echo "✓ ECS cluster ready"


build-image-push: build-push

build-image-pull:
	@echo "Pulling image from ECR..."
	@docker pull $(ECR_URI):latest

build-image-promote:
	@echo "Promoting image with tag $(BUILD_TAG)..."
	@docker tag $(ECR_URI):latest $(ECR_URI):$(BUILD_TAG)
	@docker push $(ECR_URI):$(BUILD_TAG)

up:
	@docker compose up -d

down:
	@docker compose down
