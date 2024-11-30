#!/bin/bash

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

# Function to get Grafana endpoint
get_grafana_endpoint() {
    local cluster_name=$1
    local service_name=$2
    
    echo "Getting Grafana endpoint..."
    
    # Wait for the service to be stable
    aws ecs wait services-stable \
        --cluster $cluster_name \
        --services $service_name
    
    # Get task ID
    TASK_ID=$(aws ecs list-tasks \
        --cluster $cluster_name \
        --service-name $service_name \
        --query 'taskArns[0]' \
        --output text)
    
    if [ -z "$TASK_ID" ] || [ "$TASK_ID" == "None" ]; then
        echo "No running tasks found"
        return 1
    fi
    
    # Get network interface
    NETWORK_INTERFACE=$(aws ecs describe-tasks \
        --cluster $cluster_name \
        --tasks $TASK_ID \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
        --output text)
    
    # Get public IP
    GRAFANA_IP=$(aws ec2 describe-network-interfaces \
        --network-interface-ids $NETWORK_INTERFACE \
        --query 'NetworkInterfaces[0].Association.PublicIp' \
        --output text)
    
    echo "Grafana endpoint: http://$GRAFANA_IP:3000"
    return 0
}

echo "Starting infrastructure deployment..."

# 1. Deploy NetworkStack first
echo "Deploying NetworkStack using network.yaml"
aws cloudformation deploy \
    --stack-name NetworkStack \
    --template-file network.yaml \
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

# 2. Deploy StorageStack
echo "Deploying StorageStack using storage.yaml"
aws cloudformation deploy \
    --stack-name StorageStack \
    --template-file storage.yaml \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "StorageStack"

# 3. Deploy DatabaseStack
echo "Deploying DatabaseStack using database.yaml"
aws cloudformation deploy \
    --stack-name DatabaseStack \
    --template-file database.yaml \
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

# 4. Deploy ComputeStack
echo "Deploying ComputeStack using compute.yaml"
aws cloudformation deploy \
    --stack-name ComputeStack \
    --template-file compute.yaml \
    --parameter-overrides \
        VPCId=$VPC_ID \
        PublicSubnet1=$PUBLIC_SUBNET_1 \
        PublicSubnet2=$PUBLIC_SUBNET_2 \
        RDSInstanceEndpoint=$RDS_ENDPOINT \
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

# 5. Deploy MonitoringStack
echo "Deploying MonitoringStack using monitoring.yaml"
aws cloudformation deploy \
    --stack-name MonitoringStack \
    --template-file monitoring.yaml \
    --parameter-overrides \
        LoadBalancerName=$LOAD_BALANCER_NAME \
        AutoScalingGroupName=$INSTANCE_ID \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "MonitoringStack"

# Generate a random password for Grafana admin
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 12)

# 6. Deploy GrafanaStack
echo "Deploying GrafanaStack using grafana-ecs-simple.yaml"
aws cloudformation deploy \
    --stack-name GrafanaStack \
    --template-file grafana-ecs-simple.yaml \
    --parameter-overrides \
        VPCId=$VPC_ID \
        PublicSubnet1=$PUBLIC_SUBNET_1 \
        GrafanaAdminPassword=$GRAFANA_ADMIN_PASSWORD \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "GrafanaStack"

# Get Grafana Stack outputs
GRAFANA_CLUSTER=$(aws cloudformation describe-stacks \
    --stack-name GrafanaStack \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSCluster`].OutputValue' \
    --output text)

GRAFANA_SERVICE=$(aws cloudformation describe-stacks \
    --stack-name GrafanaStack \
    --query 'Stacks[0].Outputs[?OutputKey==`GrafanaServiceName`].OutputValue' \
    --output text)

# 7. Deploy CICDStack
echo "Deploying CICDStack using cicd.yaml"
aws cloudformation deploy \
    --stack-name CICDStack \
    --template-file cicd.yaml \
    --parameter-overrides \
        GitHubOwner=guirgsilva \
        GitHubRepo=confidant \
        GitHubBranch=master \
        GitHubTokenSecretId=github/token \
        ExistingPipelineBucketName=043309321272-us-east-1-pipeline-artifacts \
    --capabilities CAPABILITY_NAMED_IAM

wait_for_stack "CICDStack"

# Store Grafana credentials in SSM Parameter Store
aws ssm put-parameter \
    --name "/grafana/admin/password" \
    --value "$GRAFANA_ADMIN_PASSWORD" \
    --type SecureString \
    --overwrite

# Get and verify Grafana endpoint
get_grafana_endpoint $GRAFANA_CLUSTER $GRAFANA_SERVICE
GRAFANA_STATUS=$?

echo "
Deployment Summary:
------------------
VPC ID: $VPC_ID
RDS Endpoint: $RDS_ENDPOINT
Load Balancer Name: $LOAD_BALANCER_NAME
Grafana Cluster: $GRAFANA_CLUSTER
Grafana Admin Username: admin
Grafana Admin Password: $GRAFANA_ADMIN_PASSWORD

Important Notes:
1. Save these credentials securely
2. The Grafana admin password is stored in SSM Parameter Store as '/grafana/admin/password'
3. Allow a few minutes for the Grafana container to fully initialize
"

if [ $GRAFANA_STATUS -eq 0 ]; then
    echo "Waiting for Grafana to be ready..."
    until curl -s -o /dev/null -w "%{http_code}" http://$GRAFANA_IP:3000 | grep -q "200\|302"; do
        echo "Waiting for Grafana to be ready..."
        sleep 10
    done
    echo "Grafana is ready!"
fi

echo "All stacks deployed successfully!"