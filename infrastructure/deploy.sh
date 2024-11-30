#!/bin/bash

# Function to check and handle existing stack
handle_existing_stack() {
    local stack_name=$1
    echo "Checking status of $stack_name..."
    
    if aws cloudformation describe-stacks --stack-name $stack_name >/dev/null 2>&1; then
        STATUS=$(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --output text)
        
        if [ "$STATUS" == "ROLLBACK_COMPLETE" ]; then
            echo "$stack_name is in ROLLBACK_COMPLETE state. Deleting it first..."
            aws cloudformation delete-stack --stack-name $stack_name
            echo "Waiting for $stack_name deletion to complete..."
            aws cloudformation wait stack-delete-complete --stack-name $stack_name
            echo "Stack deleted successfully"
        fi
    fi
}

# Function to wait for stack completion and get outputs
wait_for_stack() {
    local stack_name=$1
    echo "Waiting for $stack_name to complete..."
    
    while true; do
        STATUS=$(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --output text)
        echo "Current status of $stack_name: $STATUS"
        
        if [[ "$STATUS" == "CREATE_COMPLETE" || "$STATUS" == "UPDATE_COMPLETE" ]]; then
            echo "$stack_name created/updated successfully!"
            break
        elif [[ "$STATUS" == "ROLLBACK_COMPLETE" || "$STATUS" == "DELETE_COMPLETE" || "$STATUS" == "UPDATE_ROLLBACK_COMPLETE" ]]; then
            echo "Error: $stack_name failed with status $STATUS"
            exit 1
        fi
        sleep 10
    done
}

# Function to get stack output
get_stack_output() {
    local stack_name=$1
    local export_name=$2
    aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --query "Stacks[0].Outputs[?ExportName=='$export_name'].OutputValue" \
        --output text
}

# Set script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

echo "Starting infrastructure deployment..."

# 1. Handle and Deploy SecurityIAMStack first
handle_existing_stack "SecurityIAMStack"

echo "Deploying SecurityIAMStack using security-iam.yaml"
aws cloudformation deploy \
    --stack-name SecurityIAMStack \
    --template-file "${TEMPLATES_DIR}/security-iam.yaml" \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "SecurityIAMStack"

# Get Security IAM Role ARN
SECURITY_ROLE_ARN=$(get_stack_output "SecurityIAMStack" "SecurityIAMStack-SecurityCheckRoleArn")

if [[ -z "$SECURITY_ROLE_ARN" ]]; then
    echo "Error: Missing Security Role ARN after SecurityIAMStack deployment."
    exit 1
fi

# 2. Handle and Deploy NetworkStack
handle_existing_stack "NetworkStack"

echo "Deploying NetworkStack using network.yaml"
aws cloudformation deploy \
    --stack-name NetworkStack \
    --template-file "${TEMPLATES_DIR}/network.yaml" \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "NetworkStack"

# Get Network Stack outputs
echo "Getting NetworkStack outputs..."
VPC_ID=$(get_stack_output "NetworkStack" "VPCId")
PRIVATE_SUBNET_1=$(get_stack_output "NetworkStack" "PrivateSubnet1")
PRIVATE_SUBNET_2=$(get_stack_output "NetworkStack" "PrivateSubnet2")
PUBLIC_SUBNET_1=$(get_stack_output "NetworkStack" "PublicSubnet1")
PUBLIC_SUBNET_2=$(get_stack_output "NetworkStack" "PublicSubnet2")

# Verify network parameters
if [[ -z "$VPC_ID" || -z "$PRIVATE_SUBNET_1" || -z "$PRIVATE_SUBNET_2" ]]; then
    echo "Error: Missing network parameters after NetworkStack deployment."
    exit 1
fi

# 3. Handle and Deploy StorageStack
handle_existing_stack "StorageStack"

echo "Deploying StorageStack using storage.yaml"
aws cloudformation deploy \
    --stack-name StorageStack \
    --template-file "${TEMPLATES_DIR}/storage.yaml" \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "StorageStack"

# 4. Handle and Deploy DatabaseStack
handle_existing_stack "DatabaseStack"

echo "Deploying DatabaseStack using database.yaml"
aws cloudformation deploy \
    --stack-name DatabaseStack \
    --template-file "${TEMPLATES_DIR}/database.yaml" \
    --parameter-overrides \
        VPCId=$VPC_ID \
        PrivateSubnet1=$PRIVATE_SUBNET_1 \
        PrivateSubnet2=$PRIVATE_SUBNET_2 \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "DatabaseStack"

# Get RDS Endpoint
RDS_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name DatabaseStack \
    --query "Stacks[0].Outputs[?ExportName=='RDSInstanceEndpoint'].OutputValue" \
    --output text)

if [[ -z "$RDS_ENDPOINT" ]]; then
    echo "Error: Missing RDS endpoint after DatabaseStack deployment."
    exit 1
fi

# 5. Handle and Deploy ComputeStack
handle_existing_stack "ComputeStack"

echo "Deploying ComputeStack using compute.yaml"
aws cloudformation deploy \
    --stack-name ComputeStack \
    --template-file "${TEMPLATES_DIR}/compute.yaml" \
    --parameter-overrides \
        VPCId=$VPC_ID \
        PublicSubnet1=$PUBLIC_SUBNET_1 \
        PublicSubnet2=$PUBLIC_SUBNET_2 \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "ComputeStack"

# Get Compute Stack outputs
LOAD_BALANCER_NAME=$(aws cloudformation describe-stacks \
    --stack-name ComputeStack \
    --query "Stacks[0].Outputs[?ExportName=='ComputeStack-ApplicationLoadBalancerName'].OutputValue" \
    --output text)

INSTANCE_ID=$(aws cloudformation describe-stack-resources \
    --stack-name ComputeStack \
    --query "StackResources[?ResourceType=='AWS::AutoScaling::AutoScalingGroup'].PhysicalResourceId" \
    --output text)

if [[ -z "$LOAD_BALANCER_NAME" || -z "$INSTANCE_ID" ]]; then
    echo "Error: Missing ComputeStack outputs."
    exit 1
fi

# 6. Handle and Deploy MonitoringStack
handle_existing_stack "MonitoringStack"

echo "Deploying MonitoringStack using monitoring.yaml"
aws cloudformation deploy \
    --stack-name MonitoringStack \
    --template-file "${TEMPLATES_DIR}/monitoring.yaml" \
    --parameter-overrides \
        LoadBalancerName=$LOAD_BALANCER_NAME \
        AutoScalingGroupName=$INSTANCE_ID \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "MonitoringStack"

# 7. Handle and Deploy CICD Stack
handle_existing_stack "CICDStack"

echo "Deploying CICDStack using cicd.yaml"
aws cloudformation deploy \
    --stack-name CICDStack \
    --template-file "${TEMPLATES_DIR}/cicd.yaml" \
    --parameter-overrides \
        GitHubOwner=guirgsilva \
        GitHubRepo=confidant \
        GitHubBranch=master \
        GitHubTokenSecretId=github/token \
        SecurityRoleArn=$SECURITY_ROLE_ARN \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "CICDStack"

echo "All stacks deployed successfully!"

echo "
Deployment Summary:
------------------
VPC ID: $VPC_ID
RDS Endpoint: $RDS_ENDPOINT
Load Balancer Name: $LOAD_BALANCER_NAME
Security Role ARN: $SECURITY_ROLE_ARN
"