#!/bin/bash
# deploy.sh
# Usage: ./deploy.sh <TAG> <SERVICE_NAME>

set -e

TAG=$1
SERVICE_NAME=$2
CLUSTER_NAME=${CLUSTER_NAME:-fraud-detection-cluster}
AWS_REGION=${AWS_DEFAULT_REGION:-us-west-2}
TASK_FAMILY=${TASK_FAMILY:-fraud-detection-task}

if [ -z "$TAG" ] || [ -z "$SERVICE_NAME" ]; then
  echo "Usage: ./deploy.sh <TAG> <SERVICE_NAME>"
  echo "Example: ./deploy.sh staging fraud-detection-service"
  exit 1
fi

echo "============================================"
echo "Deploying to ECS"
echo "============================================"
echo "Tag: $TAG"
echo "Service: $SERVICE_NAME"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO_NAME=${ECR_REPO_NAME:-fraud-detection-app}
NEW_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${TAG}"

echo "New image: $NEW_IMAGE"

# Get current task definition
echo "Fetching current task definition..."
TASK_DEFINITION=$(aws ecs describe-task-definition \
    --task-definition $TASK_FAMILY \
    --region $AWS_REGION \
    --query 'taskDefinition')

# Update image in task definition
echo "Creating new task definition..."
NEW_TASK_DEF=$(echo $TASK_DEFINITION | jq --arg IMAGE "$NEW_IMAGE" '
    .containerDefinitions[0].image = $IMAGE |
    del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)
')

# Register new task definition
echo "Registering new task definition..."
NEW_TASK_ARN=$(echo $NEW_TASK_DEF | aws ecs register-task-definition \
    --cli-input-json file:///dev/stdin \
    --region $AWS_REGION \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "New task definition: $NEW_TASK_ARN"

# Update service
echo "Updating ECS service..."
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --task-definition "$NEW_TASK_ARN" \
    --force-new-deployment \
    --region "$AWS_REGION"

echo ""
echo "✓ Deployment initiated successfully!"