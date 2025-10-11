#!/bin/bash
set -e

AWS_REGION=${AWS_REGION:-us-east-2}

echo "Creating Parameter Store parameters..."
echo "Please provide the following values:"
echo ""

read -p "MongoDB URI: " MONGODB_URI
read -p "Kafka Bootstrap Servers: " KAFKA_SERVERS
read -sp "OpenAI API Key: " OPENAI_KEY
echo ""

# Create parameters
aws ssm put-parameter \
    --name "/fraud-detection/prod/mongodb-uri" \
    --value "$MONGODB_URI" \
    --type "SecureString" \
    --overwrite 2>/dev/null || true

aws ssm put-parameter \
    --name "/fraud-detection/prod/kafka-bootstrap-servers" \
    --value "$KAFKA_SERVERS" \
    --type "String" \
    --overwrite 2>/dev/null || true

aws secretsmanager create-secret \
    --name "/fraud-detection/prod/openai-api-key" \
    --secret-string "$OPENAI_KEY" 2>/dev/null || \
aws secretsmanager update-secret \
    --secret-id "/fraud-detection/prod/openai-api-key" \
    --secret-string "$OPENAI_KEY"

echo "Parameters created successfully"
