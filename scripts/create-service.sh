#!/bin/bash
set -e

AWS_REGION=${AWS_REGION:-us-east-2}
CLUSTER_NAME=${CLUSTER_NAME:-fraud-detection-cluster}
SERVICE_NAME=${SERVICE_NAME:-fraud-detection-service}

# Load infrastructure config
source .aws-config/infrastructure.env

echo "Creating ECS service..."

aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition fraud-detection-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={
        subnets=[$SUBNET_1,$SUBNET_2],
        securityGroups=[$SECURITY_GROUP],
        assignPublicIp=ENABLED
    }" \
    --region $AWS_REGION

echo "ECS service created successfully"
