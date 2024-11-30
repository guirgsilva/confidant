#!/bin/bash

# Function to delete stack and wait for completion
delete_stack() {
    local stack_name=$1
    echo "Deleting $stack_name..."
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name $stack_name >/dev/null 2>&1; then
        # Delete stack
        aws cloudformation delete-stack --stack-name $stack_name
        
        echo "Waiting for $stack_name deletion to complete..."
        if aws cloudformation wait stack-delete-complete --stack-name $stack_name; then
            echo "$stack_name deleted successfully"
        else
            echo "Failed to delete $stack_name"
            exit 1
        fi
    else
        echo "$stack_name does not exist, skipping..."
    fi
}

# Function to completely clean and delete S3 bucket
clean_and_delete_bucket() {
    local bucket_name=$1
    echo "Cleaning S3 bucket $bucket_name..."
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket $bucket_name 2>/dev/null; then
        # Remove all versions and delete markers
        echo "Removing all versions and delete markers..."
        versions=$(aws s3api list-object-versions \
            --bucket $bucket_name \
            --output=json \
            --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null)
        
        if [ ! -z "$versions" ] && [ "$versions" != "null" ]; then
            echo "$versions" | aws s3api delete-objects \
                --bucket $bucket_name \
                --delete "$(echo $versions)" >/dev/null 2>&1
        fi

        # Remove all delete markers
        delete_markers=$(aws s3api list-object-versions \
            --bucket $bucket_name \
            --output=json \
            --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null)
        
        if [ ! -z "$delete_markers" ] && [ "$delete_markers" != "null" ]; then
            echo "$delete_markers" | aws s3api delete-objects \
                --bucket $bucket_name \
                --delete "$(echo $delete_markers)" >/dev/null 2>&1
        fi

        # Remove remaining objects
        echo "Removing remaining objects..."
        aws s3 rm s3://$bucket_name --recursive

        # Delete the bucket
        echo "Deleting bucket..."
        aws s3api delete-bucket --bucket $bucket_name

        echo "Bucket $bucket_name cleaned and deleted successfully"
    else
        echo "Bucket $bucket_name does not exist, skipping..."
    fi
}

# Function to clean up EFS
clean_and_delete_efs() {
    local stack_name=$1
    echo "Cleaning up EFS for $stack_name..."
    
    # Get EFS ID from stack
    EFS_ID=$(aws cloudformation describe-stack-resources \
        --stack-name $stack_name \
        --query "StackResources[?ResourceType=='AWS::EFS::FileSystem'].PhysicalResourceId" \
        --output text)
    
    if [ ! -z "$EFS_ID" ]; then
        echo "Removing mount targets for EFS $EFS_ID..."
        
        # Get and delete mount targets
        MOUNT_TARGETS=$(aws efs describe-mount-targets \
            --file-system-id $EFS_ID \
            --query 'MountTargets[*].MountTargetId' \
            --output text)
        
        for mt in $MOUNT_TARGETS; do
            echo "Deleting mount target $mt..."
            aws efs delete-mount-target --mount-target-id $mt
        done
        
        # Wait for mount targets to be deleted
        echo "Waiting for mount targets to be deleted..."
        sleep 30
    fi
}

# Main deletion sequence
echo "Starting infrastructure deletion..."

# 1. Delete CICD Stack
delete_stack "CICDStack"

# 2. Delete Grafana Stack with EFS cleanup
clean_and_delete_efs "GrafanaStack"
delete_stack "GrafanaStack"

# 3. Delete Monitoring Stack
delete_stack "MonitoringStack"

# 4. Delete Compute Stack
delete_stack "ComputeStack"

# 5. Delete Database Stack
delete_stack "DatabaseStack"

# 6. Clean and delete Storage Stack
clean_and_delete_bucket "043309321272-us-east-1-pipeline-artifacts"
delete_stack "StorageStack"

# 7. Delete Network Stack
delete_stack "NetworkStack"

# Delete Grafana password from SSM Parameter Store
echo "Removing Grafana credentials from Parameter Store..."
aws ssm delete-parameter --name "/grafana/admin/password" || true

echo "Infrastructure deletion completed"

# Final verification
echo "Verifying all stacks are deleted..."
for stack in "CICDStack" "GrafanaStack" "MonitoringStack" "ComputeStack" "DatabaseStack" "StorageStack" "NetworkStack"; do
    if ! aws cloudformation describe-stacks --stack-name $stack >/dev/null 2>&1; then
        echo "$stack: Deleted ✓"
    else
        echo "$stack: Still exists ✗"
    fi
done