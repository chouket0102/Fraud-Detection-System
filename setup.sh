#!/bin/bash
# setup.sh - Initialize project structure for AWS deployment

set -e

echo "============================================"
echo "  Fraud Detection App - Setup Script"
echo "============================================"
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p scripts
mkdir -p .aws-config
mkdir -p .temp  # Create a local temp directory

# Create all helper scripts
echo "Creating helper scripts..."

# ============================================
# scripts/create-infrastructure.sh
# ============================================
cat > scripts/create-infrastructure.sh <<'SCRIPT1'
#!/bin/bash
set -e

AWS_REGION=${AWS_REGION:-us-east-2}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Creating VPC infrastructure..."

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=fraud-detection-vpc}]' \
    --query 'Vpc.VpcId' \
    --output text 2>/dev/null || \
    aws ec2 describe-vpcs --filters "Name=tag:Name,Values=fraud-detection-vpc" --query 'Vpcs[0].VpcId' --output text)

echo "VPC ID: $VPC_ID"

# Enable DNS
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.InternetGatewayId' \
    --output text 2>/dev/null || \
    aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID 2>/dev/null || true

# Create Subnets
SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone ${AWS_REGION}a \
    --query 'Subnet.SubnetId' \
    --output text 2>/dev/null || \
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=cidr-block,Values=10.0.1.0/24" --query 'Subnets[0].SubnetId' --output text)

SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone ${AWS_REGION}b \
    --query 'Subnet.SubnetId' \
    --output text 2>/dev/null || \
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=cidr-block,Values=10.0.2.0/24" --query 'Subnets[0].SubnetId' --output text)

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_2 --map-public-ip-on-launch

# Create Route Table
ROUTE_TABLE=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --query 'RouteTable.RouteTableId' \
    --output text 2>/dev/null || \
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[0].RouteTableId' --output text)

aws ec2 create-route --route-table-id $ROUTE_TABLE --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID 2>/dev/null || true
aws ec2 associate-route-table --subnet-id $SUBNET_1 --route-table-id $ROUTE_TABLE 2>/dev/null || true
aws ec2 associate-route-table --subnet-id $SUBNET_2 --route-table-id $ROUTE_TABLE 2>/dev/null || true

# Create Security Group
SECURITY_GROUP=$(aws ec2 create-security-group \
    --group-name fraud-detection-sg \
    --description "Security group for fraud detection ECS tasks" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text 2>/dev/null || \
    aws ec2 describe-security-groups --filters "Name=group-name,Values=fraud-detection-sg" --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0 2>/dev/null || true

# Save to config file
mkdir -p .aws-config
cat > .aws-config/infrastructure.env <<EOF
VPC_ID=$VPC_ID
IGW_ID=$IGW_ID
SUBNET_1=$SUBNET_1
SUBNET_2=$SUBNET_2
ROUTE_TABLE=$ROUTE_TABLE
SECURITY_GROUP=$SECURITY_GROUP
EOF

echo "Infrastructure created and saved to .aws-config/infrastructure.env"
SCRIPT1

# ============================================
# scripts/create-iam-roles.sh - FIXED VERSION
# ============================================
cat > scripts/create-iam-roles.sh <<'SCRIPT2'
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
SCRIPT2

# ============================================
# scripts/create-parameters.sh
# ============================================
cat > scripts/create-parameters.sh <<'SCRIPT3'
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
SCRIPT3

# ============================================
# scripts/generate-task-definition.sh
# ============================================
cat > scripts/generate-task-definition.sh <<'SCRIPT4'
#!/bin/bash

AWS_REGION=${AWS_REGION:-us-east-2}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO_NAME=${ECR_REPO_NAME:-fraud-detection-app}
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

cat <<EOF
{
  "family": "fraud-detection-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskRole",
  "containerDefinitions": [{
    "name": "fraud-detection-container",
    "image": "${ECR_URI}:latest",
    "essential": true,
    "portMappings": [{
      "containerPort": 8080,
      "protocol": "tcp"
    }],
    "environment": [
      {"name": "SPRING_PROFILES_ACTIVE", "value": "aws"},
      {"name": "AWS_REGION", "value": "${AWS_REGION}"}
    ],
    "secrets": [
      {
        "name": "SPRING_DATA_MONGODB_URI",
        "valueFrom": "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/fraud-detection/prod/mongodb-uri"
      },
      {
        "name": "SPRING_KAFKA_BOOTSTRAP_SERVERS",
        "valueFrom": "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/fraud-detection/prod/kafka-bootstrap-servers"
      },
      {
        "name": "SPRING_AI_OPENAI_API_KEY",
        "valueFrom": "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:/fraud-detection/prod/openai-api-key"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/fraud-detection",
        "awslogs-region": "${AWS_REGION}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"],
      "interval": 30,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 60
    }
  }]
}
EOF
SCRIPT4

# ============================================
# scripts/create-service.sh
# ============================================
cat > scripts/create-service.sh <<'SCRIPT5'
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
SCRIPT5

# ============================================
# scripts/get-task-ip.sh
# ============================================
cat > scripts/get-task-ip.sh <<'SCRIPT6'
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
SCRIPT6

# Make all scripts executable
chmod +x scripts/*.sh

echo ""
echo "✓ All helper scripts created"

# Add to .gitignore
echo "Updating .gitignore..."
cat >> .gitignore <<EOF

# AWS Configuration
.aws-config/
.temp/
task-definition.json
*.pem

# Environment files
.env
.env.local
.env.production
EOF

echo "✓ .gitignore updated"

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Review the Makefile: cat Makefile"
echo "  2. Run setup: make setup-all"
echo "  3. Deploy app: make deploy"
echo ""
echo "Quick commands:"
echo "  make help          # Show all available commands"
echo "  make info          # Show configuration"
echo "  make validate      # Check prerequisites"
echo ""