#!/bin/bash

# Function to delete stack and wait for completion
delete_stack() {
    local stack_name=$1
    echo "Deleting $stack_name..."
    
    if aws cloudformation describe-stacks --stack-name $stack_name >/dev/null 2>&1; then
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

# Enhanced function to clean and delete S3 bucket with error handling
clean_and_delete_bucket() {
    local bucket_name=$1
    echo "Cleaning S3 bucket $bucket_name..."
    
    if aws s3api head-bucket --bucket $bucket_name 2>/dev/null; then
        echo "Processing bucket: $bucket_name"
        
        # Disable bucket versioning first
        aws s3api put-bucket-versioning \
            --bucket $bucket_name \
            --versioning-configuration Status=Suspended

        # Remove all versions
        versions=$(aws s3api list-object-versions \
            --bucket $bucket_name \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
            --output json 2>/dev/null)
        
        if [ ! -z "$versions" ] && [ "$versions" != "null" ] && [ "$versions" != "{}" ]; then
            echo "$versions" | aws s3api delete-objects \
                --bucket $bucket_name \
                --delete "$(echo $versions)" >/dev/null 2>&1
        fi

        # Remove all delete markers
        markers=$(aws s3api list-object-versions \
            --bucket $bucket_name \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
            --output json 2>/dev/null)
        
        if [ ! -z "$markers" ] && [ "$markers" != "null" ] && [ "$markers" != "{}" ]; then
            echo "$markers" | aws s3api delete-objects \
                --bucket $bucket_name \
                --delete "$(echo $markers)" >/dev/null 2>&1
        fi

        # Remove remaining objects
        aws s3 rm s3://$bucket_name --recursive

        # Delete the bucket
        if aws s3api delete-bucket --bucket $bucket_name; then
            echo "Successfully deleted bucket: $bucket_name"
        else
            echo "Failed to delete bucket: $bucket_name"
        fi
    else
        echo "Bucket $bucket_name does not exist or access denied"
    fi
}

# Function to clean all pipeline artifact buckets
clean_all_pipeline_buckets() {
    echo "Identifying all pipeline artifact buckets..."
    
    # List all buckets matching the pattern
    buckets=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'cicdstack-pipelineartifactsbucket-')].Name" --output text)
    
    if [ -z "$buckets" ]; then
        echo "No pipeline artifact buckets found"
        return 0
    fi
    
    echo "Found the following buckets to clean:"
    echo "$buckets"
    
    for bucket in $buckets; do
        echo "Processing bucket: $bucket"
        clean_and_delete_bucket "$bucket"
    done
}

# Main deletion sequence
echo "Starting infrastructure deletion..."

# 1. Delete CICD Stack
delete_stack "CICDStack"

# 2. Delete SecurityIAMStack
delete_stack "SecurityIAMStack"

# 3. Delete Monitoring Stack
delete_stack "MonitoringStack"

# 4. Delete Compute Stack
delete_stack "ComputeStack"

# 5. Delete Database Stack
delete_stack "DatabaseStack"

# 6. Clean and delete all pipeline artifact buckets
echo "Cleaning all pipeline artifact buckets..."
clean_all_pipeline_buckets
clean_and_delete_bucket "043309321272-us-east-1-pipeline-artifacts"
delete_stack "StorageStack"

# 7. Delete Network Stack
delete_stack "NetworkStack"

echo "Infrastructure deletion completed"

# Final verification
echo "Verifying all stacks are deleted..."
for stack in "CICDStack" "SecurityIAMStack" "MonitoringStack" "ComputeStack" "DatabaseStack" "StorageStack" "NetworkStack"; do
    if ! aws cloudformation describe-stacks --stack-name $stack >/dev/null 2>&1; then
        echo "$stack: Deleted ✓"
    else
        echo "$stack: Still exists ✗"
    fi
done

# Verify no pipeline buckets remain
remaining_buckets=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'cicdstack-pipelineartifactsbucket-')].Name" --output text)
if [ -z "$remaining_buckets" ]; then
    echo "All pipeline buckets successfully deleted ✓"
else
    echo "Warning: Some pipeline buckets still exist ✗"
    echo "$remaining_buckets"
fi