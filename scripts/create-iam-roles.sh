#!/bin/bash
set -e

AWS_REGION=${AWS_REGION:-us-east-2}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Creating IAM roles..."

# Create temporary directory in project root (works on Windows)
mkdir -p .temp

# Trust policy
cat > .temp/ecs-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ecs-tasks.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Create execution role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://.temp/ecs-trust-policy.json 2>/dev/null || echo "Execution role exists"

aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true

# Create task role
aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file://.temp/ecs-trust-policy.json 2>/dev/null || echo "Task role exists"

# Parameter Store policy
cat > .temp/parameter-store-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParameter*"],
      "Resource": "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/fraud-detection/*"
    },
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:/fraud-detection/*"
    },
    {
      "Effect": "Allow",
      "Action": ["kms:Decrypt"],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name ecsTaskRole \
    --policy-name ParameterStoreAccess \
    --policy-document file://.temp/parameter-store-policy.json

echo "IAM roles created successfully"

# Clean up temp files
rm -f .temp/ecs-trust-policy.json
rm -f .temp/parameter-store-policy.json
