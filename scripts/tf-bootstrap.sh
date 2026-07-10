#!/bin/bash
# One-time setup: Create S3 bucket + DynamoDB table for Terraform state
# Prerequisites: AWS CLI installed and configured (aws configure)
set -euo pipefail

REGION="ap-southeast-1"
BUCKET="unimart-terraform-state"
TABLE="unimart-terraform-lock"

echo "Creating S3 bucket for Terraform state..."
aws s3api create-bucket \
  --bucket $BUCKET \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket $BUCKET \
  --versioning-configuration Status=Enabled

echo "Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket $BUCKET \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket $BUCKET \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name $TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION

echo ""
echo "============================================"
echo "Terraform backend infrastructure created!"
echo "============================================"
echo "Next steps:"
echo "  cd terraform"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
