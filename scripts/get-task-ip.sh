#!/bin/bash

AWS_REGION=${AWS_REGION:-us-east-2}
CLUSTER_NAME=${CLUSTER_NAME:-fraud-detection-cluster}
SERVICE_NAME=${SERVICE_NAME:-fraud-detection-service}

# Get first task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --region $AWS_REGION \
    --query 'taskArns[0]' \
    --output text)

if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
    echo "No tasks running"
    exit 1
fi

# Get ENI ID
ENI_ID=$(aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)

# Get public IP
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids $ENI_ID \
    --region $AWS_REGION \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)

echo $PUBLIC_IP
